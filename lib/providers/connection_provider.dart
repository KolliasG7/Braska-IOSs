// lib/providers/connection_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/telemetry.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';
import '../services/notification_service.dart';
import '../services/error_formatter.dart';

enum ConnState { idle, connecting, connected, error, needsAuth }

class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider();

  String _rawInput = '';
  bool   _isTunnel = false;
  String get rawInput  => _rawInput;
  bool   get isTunnel  => _isTunnel;

  String _token = '';
  String get token => _token;
  bool   get hasToken => _token.isNotEmpty;

  ConnState _connState = ConnState.idle;
  String?   _error;
  ConnState get connState   => _connState;
  String?   get error       => _error;
  bool      get isConnected => _connState == ConnState.connected;

  ApiService? _api;
  WsService?  _ws;
  ApiService? get api => _api;
  WsService?  get ws  => _ws;

  TelemetryFrame? _frame;
  TelemetryFrame? get frame => _frame;

  StreamSubscription? _wsSub;
  StreamSubscription? _wsStateSub;
  Timer? _frameNotifyTimer;
  DateTime _lastFrameNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minFrameNotifyGap = Duration(milliseconds: 160);

  final List<double> cpuHistory  = [];
  final List<double> ramHistory  = [];
  final List<double> tempHistory = [];
  final List<double> fanHistory  = [];

  bool _showCpuGraph      = true;
  bool _showRamGraph      = true;
  bool _showThermalGraph  = true;
  bool _showNotifications = true;
  bool _reduceMotion      = false;
  bool get showCpuGraph      => _showCpuGraph;
  bool get showRamGraph      => _showRamGraph;
  bool get showThermalGraph  => _showThermalGraph;
  bool get showNotifications => _showNotifications;
  bool get reduceMotion      => _reduceMotion;

  void toggleCpuGraph(bool v)      { _showCpuGraph = v;      _save(); notifyListeners(); }
  void toggleRamGraph(bool v)      { _showRamGraph = v;      _save(); notifyListeners(); }
  void toggleThermalGraph(bool v)  { _showThermalGraph = v;  _save(); notifyListeners(); }
  void toggleReduceMotion(bool v)  { _reduceMotion = v;      _save(); notifyListeners(); }
  void toggleNotifications(bool v) {
    _showNotifications = v; _save();
    if (!v) NotificationService.cancelStatus();
    notifyListeners();
  }

  bool _critNotifSent = false;
  String? _lastNotifBody;

  Future<void> loadSaved() async {
    try {
      final p = await SharedPreferences.getInstance();
      _rawInput          = p.getString('ps4_addr')          ?? '';
      _isTunnel          = p.getBool('ps4_is_tunnel')        ?? false;
      _token             = p.getString('ps4_token')          ?? '';
      _showCpuGraph      = p.getBool('show_cpu_graph')       ?? true;
      _showRamGraph      = p.getBool('show_ram_graph')       ?? true;
      _showThermalGraph  = p.getBool('show_thermal_graph')   ?? true;
      _showNotifications = p.getBool('show_notifications')   ?? true;
      _reduceMotion      = p.getBool('reduce_motion')        ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('[ConnectionProvider] Error loading saved data: $e');
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('ps4_addr',            _rawInput);
      await p.setBool  ('ps4_is_tunnel',       _isTunnel);
      await p.setString('ps4_token',           _token);
      await p.setBool  ('show_cpu_graph',      _showCpuGraph);
      await p.setBool  ('show_ram_graph',      _showRamGraph);
      await p.setBool  ('show_thermal_graph',  _showThermalGraph);
      await p.setBool  ('show_notifications',  _showNotifications);
      await p.setBool  ('reduce_motion',       _reduceMotion);
    } catch (e) {
      debugPrint('[ConnectionProvider] Error saving preferences: $e');
    }
  }

  Future<void> _saveToken(String t) async {
    try {
      _token = t;
      final p = await SharedPreferences.getInstance();
      await p.setString('ps4_token', t);
    } catch (e) {
      debugPrint('[ConnectionProvider] Error saving token: $e');
    }
  }

  Future<void> connect(String input) async {
    bool authRequired = false;
    _rawInput  = _normalizeInput(input.trim());
    if (!_isValidInput(_rawInput)) {
      _error = 'Invalid host or URL. Use host:port (e.g. 192.168.1.116:8765) or https://...';
      _connState = ConnState.error;
      notifyListeners();
      return;
    }
    _isTunnel  = _detectTunnel(_rawInput);
    _error     = null;
    _connState = ConnState.connecting;
    notifyListeners();
    _teardown();
    final base = _effectiveBase(_rawInput);
    _api = ApiService(base, token: _token);
    try {
      final health = await _api!.getHealth().timeout(const Duration(seconds: 10));
      if (health['status'] != 'ok' && health['status'] != 'degraded') {
        throw Exception('Server unhealthy: ${health['status']}');
      }
      authRequired = health['auth_required'] == true;
    } catch (e) {
      _error = ErrorFormatter.userMessage(e);
      _connState = ConnState.error;
      notifyListeners();
      return;
    }
    if (!authRequired) {
      await _save();
      _connectWs(base);
      return;
    }
    final tokenOk = await _api!.verifyToken();
    if (!tokenOk) {
      _connState = ConnState.needsAuth;
      notifyListeners();
      return;
    }
    await _save();
    _connectWs(base);
  }

  Future<void> login(String password) async {
    if (_api == null) return;
    _error = null;
    notifyListeners();
    try {
      final t = await _api!.login(password).timeout(const Duration(seconds: 10));
      await _saveToken(t);
    } catch (e) {
      _error = ErrorFormatter.userMessage(e);
      notifyListeners();
      return;
    }
    await _save();
    _connectWs(_api!.baseUrl);
  }

  void _connectWs(String base) async {
    try {
      final profs = await _api!.getLedProfiles().timeout(const Duration(seconds: 5));
      final p = await SharedPreferences.getInstance();
      await p.setString('ps4_led_profiles', profs.join(','));
    } catch (e) {
      debugPrint('[ConnectionProvider] Error loading LED profiles: $e');
    }
    _ws = WsService(base, token: _token);
    _wsStateSub = _ws!.state.listen((s) {
      if (s == WsState.connected && _connState != ConnState.connected) {
        _connState = ConnState.connected;
        notifyListeners();
      } else if (s == WsState.disconnected && _connState == ConnState.connected) {
        _connState = ConnState.connecting;
        notifyListeners();
      }
    });
    _wsSub = _ws!.stream.listen(_onFrame);
    _ws!.connect();
    notifyListeners();
  }

  void _onFrame(TelemetryFrame f) {
    // Don't process frames if we're being torn down
    if (_ws == null) return;
    
    _frame = f;
    _connState = ConnState.connected;
    if (f.cpu != null) { cpuHistory.add(f.cpu!.percent); if (cpuHistory.length > 50) cpuHistory.removeAt(0); }
    if (f.ram != null) { ramHistory.add(f.ram!.percent); if (ramHistory.length > 50) ramHistory.removeAt(0); }
    if (f.fan != null) {
      tempHistory.add(f.fan!.apuTempC); if (tempHistory.length > 50) tempHistory.removeAt(0);
      fanHistory.add(f.fan!.rpm.toDouble()); if (fanHistory.length > 50) fanHistory.removeAt(0);
    }
    final tunnelUrl = f.tunnel?.url;
    if (tunnelUrl != null && f.tunnel!.isRunning && _isTunnel) {
      if (_ws != null && _ws!.currentState != WsState.connected) {
        _ws!.updateUrl(tunnelUrl);
      }
    }
    _sendNotification(f);
    _notifyForFrame();
  }

  void _notifyForFrame() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastFrameNotifyAt);
    if (elapsed >= _minFrameNotifyGap) {
      _lastFrameNotifyAt = now;
      notifyListeners();
      return;
    }
    if (_frameNotifyTimer != null) return;
    _frameNotifyTimer = Timer(_minFrameNotifyGap - elapsed, () {
      _frameNotifyTimer = null;
      _lastFrameNotifyAt = DateTime.now();
      notifyListeners();
    });
  }

  Future<String> startTunnel() async {
    final result = await _api!.startTunnel().timeout(const Duration(seconds: 35));
    final url = result['url'] as String?;
    if (url == null) throw Exception('No URL returned');
    _rawInput = url;
    _isTunnel = true;
    await _save();
    final newApi = ApiService(url, token: _token);
    final newWs  = WsService(url, token: _token);
    await Future.delayed(const Duration(seconds: 5));
    _teardown();
    _api = newApi;
    _ws  = newWs;
    _wsStateSub = _ws!.state.listen((s) {
      if (s == WsState.connected) { _connState = ConnState.connected; notifyListeners(); }
    });
    _wsSub = _ws!.stream.listen(_onFrame);
    _ws!.connect();
    notifyListeners();
    return url;
  }

  Future<void> stopTunnel() async => _api?.stopTunnel();

  /// Disconnect but keep saved address (can reconnect later).
  void disconnect() {
    _teardown();
    _connState = ConnState.idle;
    _frame     = null;
    notifyListeners();
    NotificationService.cancelStatus();
  }

  /// BUG FIX: Disconnect AND clear saved address so _Root won't auto-reconnect.
  Future<void> disconnectAndForget() async {
    _teardown();
    _rawInput  = '';
    _isTunnel  = false;
    _connState = ConnState.idle;
    _frame     = null;
    await _save();
    notifyListeners();
    NotificationService.cancelStatus();
  }

  /// Clear only the saved auth token (without disconnecting).
  Future<void> clearToken() async {
    await _saveToken('');
    if (_api != null) _api!.token = '';
  }

  /// Rotates the remote password on the backend and persists the fresh
  /// token the backend emits, so the session keeps working without a
  /// re-login. Throws on failure (wrong current password, network,
  /// server error) — the Settings screen surfaces the message.
  Future<void> rotatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_api == null) {
      throw StateError('Not connected.');
    }
    final t = await _api!.rotatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _saveToken(t);
    // ApiService.rotatePassword already updated its own .token on the
    // success path; re-assign here for defensiveness in case that ever
    // changes. WsService.token is the important one: it's a mutable
    // field read on every reconnect attempt, and the backend invalidates
    // the old token the moment the rotation persists. Without this line,
    // the next socket drop (Wi-Fi hiccup, background, etc.) would try
    // to re-auth with the stale token and fail 401, silently breaking
    // the telemetry stream even though the user saw a success toast.
    _api!.token = t;
    _ws?.token = t;
    notifyListeners();
  }

  void _teardown() {
    _frameNotifyTimer?.cancel();
    _frameNotifyTimer = null;
    _wsSub?.cancel();
    _wsStateSub?.cancel();
    _ws?.dispose();
    _ws = null; _wsSub = null; _wsStateSub = null;
  }

  void _sendNotification(TelemetryFrame f) {
    if (!_showNotifications) return;
    final cpu  = f.cpu?.percent    ?? 0;
    final temp = f.fan?.apuTempC   ?? 0;
    final rpm  = f.fan?.rpm        ?? 0;
    final ram  = f.ram?.percent    ?? 0;
    final net  = f.primaryNet;
    String netStr = '';
    if (net != null) {
      final txMbps = (net.bytesSentS / 1024 / 1024).toStringAsFixed(1);
      final rxMbps = (net.bytesRecvS / 1024 / 1024).toStringAsFixed(1);
      netStr = '  ▼${rxMbps}M/s ▲${txMbps}M/s';
    }
    final body = 'CPU ${cpu.toStringAsFixed(0)}% • RAM ${ram.toStringAsFixed(0)}%\n'
                '${temp.toStringAsFixed(0)}°C • ${rpm == 0 ? "Fan off" : "$rpm RPM"} • Up ${f.uptimeFormatted}\n'
                'Net ${net?.iface ?? "lo"}$netStr';
    if (body != _lastNotifBody) {
      _lastNotifBody = body;
      NotificationService.showStatus(title: 'PlayStation4', body: body);
      NotificationService.storeLastTemp(temp);
    }
    if (temp >= 90 && !_critNotifSent) {
      _critNotifSent = true;
      NotificationService.showAlert(title: '⚠️ PS4 Temp Critical',
        body: 'APU temperature: ${temp.toStringAsFixed(0)}°C');
    } else if (temp < 85) {
      _critNotifSent = false;
    }
  }

  bool _detectTunnel(String s) =>
    s.startsWith('https://') || s.startsWith('http://') ||
    s.contains('.trycloudflare.com') || s.contains('.cloudflare');

  String _effectiveBase(String input) {
    if (_detectTunnel(input)) {
      final normalized = input.startsWith('http') ? input : 'https://$input';
      return normalized.endsWith('/') ? normalized.substring(0, normalized.length - 1) : normalized;
    }
    // Support local inputs like "192.168.1.10:8765/" or with a path by
    // normalizing to host[:port] for ApiService local mode.
    final maybe = Uri.tryParse('http://$input');
    if (maybe != null && maybe.host.isNotEmpty) {
      final hasPort = maybe.hasPort && maybe.port > 0;
      return hasPort ? '${maybe.host}:${maybe.port}' : maybe.host;
    }
    return input;
  }

  String _normalizeInput(String input) {
    final s = input.trim();
    if (s.isEmpty) return s;
    // Keep tunnel URLs as full URLs, just drop a trailing slash.
    if (_detectTunnel(s)) {
      return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
    }
    // For local hosts, tolerate trailing slash / extra path from paste.
    final u = Uri.tryParse('http://$s');
    if (u == null || u.host.isEmpty) return s;
    if (u.hasPort && u.port > 0) return '${u.host}:${u.port}';
    return u.host;
  }

  bool _isValidInput(String input) {
    if (input.isEmpty) return false;
    if (_detectTunnel(input)) {
      final normalized = input.startsWith('http') ? input : 'https://$input';
      final uri = Uri.tryParse(normalized);
      return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    }
    final localUri = Uri.tryParse('http://$input');
    if (localUri == null || localUri.host.isEmpty) return false;
    if (!localUri.hasPort) return true;
    final p = localUri.port;
    return p >= 1 && p <= 65535;
  }

  @override
  void dispose() { _teardown(); super.dispose(); }
}

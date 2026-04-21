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
    _rawInput  = input.trim();
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
    notifyListeners();
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

  void _teardown() {
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
    if (_detectTunnel(input)) return input.startsWith('http') ? input : 'https://$input';
    return input;
  }

  @override
  void dispose() { _teardown(); super.dispose(); }
}

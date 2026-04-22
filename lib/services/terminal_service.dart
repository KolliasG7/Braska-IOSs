// lib/services/terminal_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

enum TermState { disconnected, connecting, connected }

class TerminalService {
  TerminalService(this._baseUrl, {required this.token});

  final String _baseUrl;
  String token;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  // Cancellable reconnect handle. The prior Future.delayed path was the
  // same non-cancellable bug class that already got fixed in ws_service —
  // a stale timer could fire after dispose()/connect() and leak a socket.
  Timer? _reconnectTimer;

  final _outCtrl   = StreamController<String>.broadcast();
  final _stateCtrl = StreamController<TermState>.broadcast();

  Stream<String>    get output => _outCtrl.stream;
  Stream<TermState> get state  => _stateCtrl.stream;

  TermState _state = TermState.disconnected;
  TermState get currentState => _state;

  bool _disposed = false;
  int  _retryS   = 2;

  void connect() {
    if (_disposed) return;
    _retryS = 2;
    disconnect();
    _tryConnect();
  }

  void _tryConnect() {
    if (_disposed) return;
    _setState(TermState.connecting);

    // Auth is sent via the Authorization: Bearer header on the WS upgrade
    // request — same motivation as ws_service: keep the token out of
    // access logs / router logs / journalctl URL fields.
    Uri uri;
    try {
      if (_baseUrl.startsWith('https://')) {
        uri = Uri.parse(
          '${_baseUrl.replaceFirst('https://', 'wss://')}/ws/terminal');
      } else if (_baseUrl.startsWith('http://')) {
        uri = Uri.parse(
          '${_baseUrl.replaceFirst('http://', 'ws://')}/ws/terminal');
      } else {
        uri = Uri.parse('ws://$_baseUrl/ws/terminal');
      }
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    try {
      _ch = IOWebSocketChannel.connect(
        uri,
        headers: <String, String>{'Authorization': 'Bearer $token'},
      );
      _ch!.ready.then((_) {
        if (_disposed) return;
        _retryS = 2;
        _setState(TermState.connected);
      }).catchError((e) {
        if (!_disposed) {
          _scheduleReconnect();
        }
      });
    } catch (e) {
      _scheduleReconnect();
      return;
    }

    _sub = _ch!.stream.listen(
      (raw) {
        if (raw is String) {
          _outCtrl.add(raw);
        } else if (raw is List<int>) {
          _outCtrl.add(utf8.decode(raw, allowMalformed: true));
        }
      },
      onError: (e) {
        if (!_disposed) {
          _scheduleReconnect();
        }
      },
      onDone:  () {
        if (!_disposed) {
          _scheduleReconnect();
        }
      },
      cancelOnError: true,
    );
  }

  void sendInput(String text) {
    try {
      _ch?.sink.add(text);
    } catch (_) {}
  }

  void sendResize(int cols, int rows) {
    final msg = jsonEncode({'type': 'resize', 'cols': cols, 'rows': rows});
    try {
      _ch?.sink.add(msg);
    } catch (_) {}
  }

  void _setState(TermState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _setState(TermState.disconnected);
    // Cancel any in-flight timer first so overlapping onError/onDone
    // callbacks can't stack up two pending _tryConnect calls.
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retryS), () {
      _reconnectTimer = null;
      _tryConnect();
    });
    _retryS = (_retryS * 2).clamp(2, 30);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
    _ch?.sink.close();
    _ch = null;
    _setState(TermState.disconnected);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _outCtrl.close();
    _stateCtrl.close();
  }
}

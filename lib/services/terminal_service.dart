// lib/services/terminal_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum TermState { disconnected, connecting, connected }

class TerminalService {
  TerminalService(this._baseUrl, {required this.token});

  String _baseUrl;
  String token;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;

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

    Uri uri;
    try {
      final t = Uri.encodeQueryComponent(token);
      if (_baseUrl.startsWith('https://')) {
        uri = Uri.parse(
          '${_baseUrl.replaceFirst('https://', 'wss://')}/ws/terminal?token=$t');
      } else if (_baseUrl.startsWith('http://')) {
        uri = Uri.parse(
          '${_baseUrl.replaceFirst('http://', 'ws://')}/ws/terminal?token=$t');
      } else {
        uri = Uri.parse('ws://$_baseUrl/ws/terminal?token=$t');
      }
    } catch (_) { 
      _scheduleReconnect();
      return; 
    }

    try {
      _ch = WebSocketChannel.connect(uri);
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

  /// Send raw keystrokes/text to the shell
  void sendInput(String text) {
    try { 
      _ch?.sink.add(text); 
    } catch (_) {}
  }

  /// Send terminal resize
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
    Future.delayed(Duration(seconds: _retryS), _tryConnect);
    _retryS = (_retryS * 2).clamp(2, 30);
  }

  void disconnect() {
    _sub?.cancel();
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

// lib/services/api_service.dart - WITH RETRY LOGIC AND ALL IMPORTS
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/process_info.dart';
import 'retry_policy.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  bool get isUnauth => statusCode == 401;
  @override String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService(this.baseUrl, {this.token = ''});

  final String baseUrl;
  String token;
  
  // Retry policy with exponential backoff
  final _retry = const RetryPolicy(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 2.0,
  );

  bool get isTunnel =>
    baseUrl.startsWith('https://') || baseUrl.startsWith('http://') ||
    baseUrl.contains('.trycloudflare.com');

  Uri _u(String path) {
    if (isTunnel) {
      final b = baseUrl.startsWith('http') ? baseUrl : 'https://$baseUrl';
      return Uri.parse('$b$path');
    }
    return Uri.parse('http://$baseUrl$path');
  }

  Map<String, String> get _h => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // ── Auth ───────────────────────────────────────────────────────────

  Future<String> login(String password) async {
    return _retry.execute(
      () async {
        final r = await http.post(_u('/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'password': password}),
        ).timeout(const Duration(seconds: 10));
        _chk(r);
        final t = jsonDecode(r.body)['token'] as String?;
        if (t == null || t.isEmpty) {
          throw ApiException(500, 'No token in response');
        }
        token = t;
        return t;
      },
      retryIf: RetryConditions.isFatal,
    );
  }

  Future<bool> verifyToken() async {
    if (token.isEmpty) return false;
    try {
      return await _retry.execute(
        () async {
          final r = await http.get(_u('/auth/verify'), headers: _h)
              .timeout(const Duration(seconds: 8));
          return r.statusCode == 200;
        },
        retryIf: RetryConditions.isConnectionError,
      );
    } catch (e) { 
      return false; 
    }
  }

  /// Rotates the remote password. Requires a valid bearer token (the
  /// caller's current session) *and* the current plaintext password —
  /// both checks are enforced server-side. Returns the fresh token the
  /// backend emits so the client can keep the session open without a
  /// round-trip through /auth/login.
  ///
  /// Not wrapped in the retry policy on purpose: a 500 here could mean
  /// the new hash was persisted but the response was dropped, in which
  /// case a naive retry would fail with "current password incorrect"
  /// (the hash has already rotated). Let the caller decide.
  Future<String> rotatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final r = await http.post(
      _u('/auth/change-password'),
      headers: _h,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    ).timeout(const Duration(seconds: 10));
    _chk(r);
    final decoded = jsonDecode(r.body);
    final t = (decoded is Map ? decoded['token'] : null) as String?;
    if (t == null || t.isEmpty) {
      throw ApiException(500, 'No token in rotate-password response');
    }
    token = t;
    return t;
  }

  // ── Logs (journalctl tail) ──────────────────────────────────────────

  /// Tails the strawberry-manager systemd unit's journal.
  ///
  /// [lines] is clamped server-side to 1..2000; we send whatever the user
  /// picks and let the backend decide. [priority] is optional and, if
  /// provided, must be a single digit "0".."7" (journald syslog levels) —
  /// the backend 400s anything else.
  ///
  /// Returns the decoded envelope: `{ unit, lines: [..], count, priority }`.
  /// Throws on network / HTTP failure so the UI can surface the reason.
  Future<Map<String, dynamic>> fetchLogs({
    int lines = 500,
    String? priority,
  }) async {
    return _retry.execute(
      () async {
        final qp = <String, String>{'lines': '$lines'};
        if (priority != null && priority.isNotEmpty) {
          qp['priority'] = priority;
        }
        final uri = _u('/api/system/logs').replace(queryParameters: qp);
        final r = await http.get(uri, headers: _h)
            .timeout(const Duration(seconds: 15));
        _chk(r);
        final decoded = jsonDecode(r.body);
        return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  // ── Health ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHealth() async {
    return _retry.execute(
      () async {
        final r = await http.get(_u('/')).timeout(const Duration(seconds: 8));
        _chk(r); 
        return jsonDecode(r.body) as Map<String, dynamic>? ?? {};
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  // ── Fan ────────────────────────────────────��───────────────────────

  Future<int> getFanThreshold() async {
    return _retry.execute(
      () async {
        final r = await http.get(_u('/api/fan/threshold'), headers: _h)
            .timeout(const Duration(seconds: 8));
        _chk(r); 
        final threshold = jsonDecode(r.body)['threshold'];
        return (threshold as num?)?.toInt() ?? 30;
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<int> setFanThreshold(int c) async {
    return _retry.execute(
      () async {
        final r = await http.post(_u('/api/fan/threshold'),
          headers: _h, body: jsonEncode({'threshold': c}),
        ).timeout(const Duration(seconds: 10));
        _chk(r); 
        final confirmed = jsonDecode(r.body)['threshold_confirmed'];
        return (confirmed as num?)?.toInt() ?? c;
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  // ── LED ────────────────────────────────────────────────────────────

  Future<List<String>> getLedProfiles() async {
    return _retry.execute(
      () async {
        final r = await http.get(_u('/api/led/profiles'), headers: _h)
            .timeout(const Duration(seconds: 8));
        _chk(r); 
        final profiles = jsonDecode(r.body)['profiles'];
        return profiles is List ? List<String>.from(profiles) : [];
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<String> setLed(String p) async {
    return _retry.execute(
      () async {
        final r = await http.post(_u('/api/led'), headers: _h,
          body: jsonEncode({'profile': p}),
        ).timeout(const Duration(seconds: 8));
        _chk(r); 
        return jsonDecode(r.body)['profile'] as String? ?? p;
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<String?> getActiveLed() async {
    return _retry.execute(
      () async {
        final r = await http.get(_u('/api/led/active'), headers: _h)
            .timeout(const Duration(seconds: 8));
        _chk(r); 
        return jsonDecode(r.body)['active'] as String?;
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  // ── System ──────────────────────────────────────────────────────────

  Future<List<ProcessInfo>> getProcesses({int limit = 50, String sortBy = 'cpu'}) async {
    return _retry.execute(
      () async {
        final r = await http.get(
          _u('/api/system/processes?limit=$limit&sort_by=$sortBy'), headers: _h,
        ).timeout(const Duration(seconds: 10));
        _chk(r);
        final body = jsonDecode(r.body) as Map<String, dynamic>?;
        if (body == null) return const [];
        final processes = body['processes'];
        if (processes is! List) return const [];
        return processes
            .whereType<Map>()
            .map((e) => ProcessInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<void> killProcess(int pid, {String signal = 'SIGTERM'}) async {
    return _retry.execute(
      () async {
        final r = await http.post(_u('/api/system/process/kill'),
          headers: _h, body: jsonEncode({'pid': pid, 'signal': signal}),
        ).timeout(const Duration(seconds: 10));
        _chk(r);
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  // ── Tunnel ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startTunnel() async {
    return _retry.execute(
      () async {
        final r = await http.post(_u('/api/tunnel/start'), headers: _h)
            .timeout(const Duration(seconds: 40));
        _chk(r); 
        return jsonDecode(r.body) as Map<String, dynamic>? ?? {};
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<void> stopTunnel() async {
    return _retry.execute(
      () async {
        final r = await http.post(_u('/api/tunnel/stop'), headers: _h)
            .timeout(const Duration(seconds: 15));
        _chk(r);
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<Map<String, dynamic>> getTunnelStatus() async {
    return _retry.execute(
      () async {
        final r = await http.get(_u('/api/tunnel/status'), headers: _h)
            .timeout(const Duration(seconds: 8));
        _chk(r); 
        return jsonDecode(r.body) as Map<String, dynamic>? ?? {};
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  // ── Power ───────────────────────────────────────────────────────────

  Future<void> powerAction(String action) async {
    return _retry.execute(
      () async {
        final r = await http.post(_u('/api/power/$action'), headers: _h)
            .timeout(const Duration(seconds: 15));
        _chk(r);
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  // ── Files ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> listFiles(String path) async {
    return _retry.execute(
      () async {
        final encoded = Uri.encodeQueryComponent(path);
        final r = await http.get(_u('/api/files/list?path=$encoded'), headers: _h)
            .timeout(const Duration(seconds: 15));
        _chk(r); 
        return jsonDecode(r.body) as Map<String, dynamic>? ?? {};
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<Uint8List> downloadFile(String path) async {
    return _retry.execute(
      () async {
        final encoded = Uri.encodeQueryComponent(path);
        final r = await http.get(_u('/api/files/download?path=$encoded'), headers: _h)
            .timeout(const Duration(seconds: 120));
        _chk(r); 
        return r.bodyBytes;
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<Map<String, dynamic>> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String destDir,
  }) async {
    return _retry.execute(
      () async {
        final encoded = Uri.encodeQueryComponent(destDir);
        final headers = {
          ...?(_h.isNotEmpty ? _h : null),
          'Content-Type':  'application/octet-stream',
          'X-File-Name':   filename,
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        };
        final r = await http.post(
          _u('/api/files/upload?dest=$encoded'),
          headers: headers,
          body: bytes,
        ).timeout(const Duration(seconds: 120));
        _chk(r); 
        return jsonDecode(r.body) as Map<String, dynamic>? ?? {};
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  Future<void> deleteFile(String path) async {
    return _retry.execute(
      () async {
        final encoded = Uri.encodeQueryComponent(path);
        final r = await http.delete(_u('/api/files/delete?path=$encoded'), headers: _h)
            .timeout(const Duration(seconds: 15));
        _chk(r);
      },
      retryIf: RetryConditions.isConnectionError,
    );
  }

  void _chk(http.Response r) {
    if (r.statusCode >= 400) {
      String d = r.body;
      try { 
        final decoded = jsonDecode(r.body);
        d = (decoded is Map ? decoded['detail'] : null) ?? d;
      } catch (_) {}
      throw ApiException(r.statusCode, d);
    }
  }
}

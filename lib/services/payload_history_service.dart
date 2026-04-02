// lib/services/payload_history_service.dart — Braška payload history
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PayloadRecord {
  final String ip;
  final int port;
  final String fileName;
  final String filePath;
  final DateTime sentAt;

  PayloadRecord({
    required this.ip,
    required this.port,
    required this.fileName,
    required this.filePath,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'port': port,
    'fileName': fileName,
    'filePath': filePath,
    'sentAt': sentAt.toIso8601String(),
  };

  factory PayloadRecord.fromJson(Map<String, dynamic> j) => PayloadRecord(
    ip: j['ip'] as String? ?? '',
    port: j['port'] as int? ?? 9023,
    fileName: j['fileName'] as String? ?? '',
    filePath: j['filePath'] as String? ?? '',
    sentAt: DateTime.tryParse(j['sentAt'] as String? ?? '') ?? DateTime.now(),
  );

  /// Short display label
  String get label => '$ip:$port → $fileName';
}

class PayloadHistoryService {
  static const _key = 'payload_history';
  static const _maxRecords = 10;

  static Future<List<PayloadRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) {
      try {
        return PayloadRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<PayloadRecord>().toList();
  }

  static Future<void> save(PayloadRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await load();

    // Remove duplicate (same ip+port+fileName)
    list.removeWhere((r) =>
      r.ip == record.ip &&
      r.port == record.port &&
      r.fileName == record.fileName);

    // Insert at the top
    list.insert(0, record);

    // Trim to max
    while (list.length > _maxRecords) {
      list.removeLast();
    }

    await prefs.setStringList(
      _key,
      list.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

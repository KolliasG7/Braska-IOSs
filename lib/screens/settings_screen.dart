// lib/screens/settings_screen.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/connection_provider.dart';
import '../services/payload_history_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipCtrl   = TextEditingController();
  final _portCtrl = TextEditingController(text: '9023');

  List<PayloadRecord> _history = [];
  File? _selectedFile;
  bool  _sending = false;

  @override
  void initState() {
    super.initState();
    _loadPayloadHistory();
    _loadSavedTarget();
  }

  Future<void> _loadSavedTarget() async {
    final p = await SharedPreferences.getInstance();
    final ip   = p.getString('payload_ip')   ?? '';
    final port = p.getInt   ('payload_port') ?? 9023;
    if (mounted) {
      _ipCtrl.text   = ip;
      _portCtrl.text = port.toString();
    }
  }

  Future<void> _saveTarget(String ip, int port) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('payload_ip',   ip);
    await p.setInt   ('payload_port', port);
  }

  Future<void> _loadPayloadHistory() async {
    final h = await PayloadHistoryService.load();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    setState(() => _selectedFile = File(result.files.single.path!));
  }

  Future<void> _injectPayload(String ip, int port, File file) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Bk.surface2,
      content: Text('Connecting to $ip:$port...',
        style: const TextStyle(color: Bk.white, fontSize: 12))));

    try {
      final socket = await Socket.connect(ip, port,
        timeout: const Duration(seconds: 10));
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      final fileName = file.path.split(Platform.pathSeparator).last;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Bk.surface2,
        content: Text('Sending $fileName...',
          style: const TextStyle(color: Bk.textSec, fontSize: 12))));

      await socket.addStream(file.openRead());
      await socket.flush();
      socket.destroy();

      await PayloadHistoryService.save(PayloadRecord(
        ip:       ip,
        port:     port,
        fileName: fileName,
        filePath: file.path,
        sentAt:   DateTime.now(),
      ));
      _loadPayloadHistory();

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Payload sent successfully!',
          style: TextStyle(color: Colors.white, fontSize: 12,
            fontWeight: FontWeight.w900)),
        backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e',
          style: const TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: Colors.red.shade900));
    }
  }

  Future<void> _sendPayload() async {
    final ip   = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9023;
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a target IP address')));
      return;
    }
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select a payload file first')));
      return;
    }
    await _saveTarget(ip, port);
    setState(() => _sending = true);
    await _injectPayload(ip, port, _selectedFile!);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();

    return Scaffold(
      backgroundColor: Bk.oled,
      appBar: AppBar(
        backgroundColor: Bk.oled,
        title: const Text('SETTINGS',
          style: TextStyle(
            color: Bk.textPri, fontSize: 13,
            fontWeight: FontWeight.w900, letterSpacing: 2.5)),
        iconTheme: const IconThemeData(color: Bk.textDim),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
        children: [

          // ── Dashboard display ──────────────────────────────────────
          _SectionHeader('DASHBOARD'),
          _ToggleTile(
            label: 'CPU Graph',
            value: cp.showCpuGraph,
            onChanged: cp.toggleCpuGraph,
          ),
          _ToggleTile(
            label: 'RAM Graph',
            value: cp.showRamGraph,
            onChanged: cp.toggleRamGraph,
          ),
          _ToggleTile(
            label: 'Thermal Graph',
            value: cp.showThermalGraph,
            onChanged: cp.toggleThermalGraph,
          ),
          _ToggleTile(
            label: 'Status Notifications',
            value: cp.showNotifications,
            onChanged: cp.toggleNotifications,
          ),

          const SizedBox(height: 24),

          // ── Payload injection ──────────────────────────────────────
          _SectionHeader('PAYLOAD INJECTION'),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(
              flex: 3,
              child: _InputField(
                controller: _ipCtrl,
                hint: 'Target IP',
                keyboard: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _InputField(
                controller: _portCtrl,
                hint: 'Port',
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ]),

          const SizedBox(height: 8),

          GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Bk.surface1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Bk.border),
              ),
              child: Row(children: [
                const Icon(Icons.attach_file_outlined,
                  color: Bk.textDim, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _selectedFile != null
                    ? _selectedFile!.path.split(Platform.pathSeparator).last
                    : 'Select payload file…',
                  style: TextStyle(
                    color: _selectedFile != null ? Bk.textPri : Bk.textDim,
                    fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                )),
                const Icon(Icons.chevron_right, color: Bk.textDim, size: 16),
              ]),
            ),
          ),

          const SizedBox(height: 10),

          GestureDetector(
            onTap: _sending ? null : _sendPayload,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _sending ? Bk.surface2 : Bk.white,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: _sending
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      color: Bk.oled, strokeWidth: 2))
                : const Text('SEND PAYLOAD',
                    style: TextStyle(
                      color: Bk.oled, fontSize: 12,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          ),

          // ── History ────────────────────────────────────────────────
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(children: [
              _SectionHeader('HISTORY'),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await PayloadHistoryService.clear();
                  _loadPayloadHistory();
                },
                child: const Text('CLEAR',
                  style: TextStyle(
                    color: Bk.textDim, fontSize: 9, letterSpacing: 1.5)),
              ),
            ]),
            const SizedBox(height: 8),
            ...(_history.map((r) => _HistoryTile(
              record: r,
              onTap: () {
                _ipCtrl.text   = r.ip;
                _portCtrl.text = r.port.toString();
                setState(() =>
                  _selectedFile = File(r.filePath).existsSync()
                    ? File(r.filePath) : null);
              },
            ))),
          ],

          const SizedBox(height: 24),

          // ── Connection ─────────────────────────────────────────────
          if (cp.isConnected) ...[
            _SectionHeader('CONNECTION'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                await cp.clearToken();
                cp.disconnect();
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Bk.surface1,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Bk.border),
                ),
                alignment: Alignment.center,
                child: const Text('DISCONNECT & CLEAR TOKEN',
                  style: TextStyle(
                    color: Colors.redAccent, fontSize: 12,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: const TextStyle(
      color: Bk.textDim, fontSize: 9,
      fontWeight: FontWeight.w700, letterSpacing: 2)),
  );
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: Bk.surface1,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Bk.border),
    ),
    child: Row(children: [
      Expanded(child: Text(label,
        style: const TextStyle(color: Bk.textPri, fontSize: 13))),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Bk.white,
        inactiveThumbColor: Bk.textDim,
        inactiveTrackColor: Bk.surface2,
      ),
    ]),
  );
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboard = TextInputType.text,
    this.inputFormatters,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboard;
  final List<TextInputFormatter>? inputFormatters;

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Bk.surface1,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Bk.border),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Bk.textPri, fontSize: 13),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        hintStyle: const TextStyle(color: Bk.textDim, fontSize: 12),
        isDense: true,
      ),
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.onTap});
  final PayloadRecord record;
  final VoidCallback onTap;

  @override Widget build(BuildContext context) {
    final dt = record.sentAt;
    final ts = '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Bk.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Bk.border),
        ),
        child: Row(children: [
          const Icon(Icons.history_outlined, color: Bk.textDim, size: 14),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.fileName,
                style: const TextStyle(color: Bk.textPri, fontSize: 12),
                overflow: TextOverflow.ellipsis),
              Text('${record.ip}:${record.port}  •  $ts',
                style: const TextStyle(color: Bk.textDim, fontSize: 10)),
            ],
          )),
          const Icon(Icons.chevron_right, color: Bk.textDim, size: 14),
        ]),
      ),
    );
  }
}

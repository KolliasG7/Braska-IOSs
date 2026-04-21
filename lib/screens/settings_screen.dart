// lib/screens/settings_screen.dart — Glass settings panel
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/connection_provider.dart';
import '../services/payload_history_service.dart';
import '../services/payload_sender_service.dart';
import '../services/error_formatter.dart';
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
  bool  _disconnecting = false;
  bool  _clearingToken = false;
  final _payloadSender = const PayloadSenderService();

  @override
  void initState() {
    super.initState();
    _loadPayloadHistory();
    _loadSavedTarget();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
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

  void _snack(String msg, {bool danger = false, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Bk.surface1,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md)),
      content: Text(msg, style: TextStyle(
        color: danger ? Bk.danger : success ? Bk.success : Bk.textPri,
        fontSize: 13)),
    ));
  }

  Future<void> _injectPayload(String ip, int port, File file) async {
    if (!mounted) return;
    _snack('Connecting to $ip:$port…');
    try {
      await _payloadSender.send(
        ip: ip, port: port, file: file,
        timeout: const Duration(seconds: 10),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      final fileName = file.path.split(Platform.pathSeparator).last;
      _snack('Sending $fileName…');

      await PayloadHistoryService.save(PayloadRecord(
        ip: ip, port: port, fileName: fileName,
        filePath: file.path, sentAt: DateTime.now(),
      ));
      _loadPayloadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _snack('Payload sent', success: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _snack('Error: ${ErrorFormatter.userMessage(e)}', danger: true);
    }
  }

  Future<void> _sendPayload() async {
    final ip   = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9023;
    if (ip.isEmpty) { _snack('Enter a target IP address', danger: true); return; }
    if (_selectedFile == null) {
      _snack('Select a payload file first', danger: true); return;
    }
    await _saveTarget(ip, port);
    setState(() => _sending = true);
    await _injectPayload(ip, port, _selectedFile!);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _doDisconnect() async {
    HapticFeedback.mediumImpact();
    setState(() => _disconnecting = true);
    final cp = context.read<ConnectionProvider>();
    await cp.disconnectAndForget();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _doClearToken() async {
    HapticFeedback.mediumImpact();
    setState(() => _clearingToken = true);
    final cp = context.read<ConnectionProvider>();
    await cp.clearToken();
    if (!mounted) return;
    setState(() => _clearingToken = false);
    _snack('Token cleared — re-authenticate to continue');
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            _Header(),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.md,
                  AppSpacing.xl, AppSpacing.xxxl),
              child: Column(children: [
                _Section(
                  icon: Icons.visibility_outlined,
                  title: 'Display',
                  rows: [
                    _ToggleRow(
                      label: 'CPU graph',
                      sub: 'Show processor usage sparkline',
                      value: cp.showCpuGraph,
                      onChanged: cp.toggleCpuGraph,
                    ),
                    _ToggleRow(
                      label: 'RAM graph',
                      sub: 'Show memory usage sparkline',
                      value: cp.showRamGraph,
                      onChanged: cp.toggleRamGraph,
                    ),
                    _ToggleRow(
                      label: 'Thermal graph',
                      sub: 'Show temperature sparkline',
                      value: cp.showThermalGraph,
                      onChanged: cp.toggleThermalGraph,
                    ),
                    _ToggleRow(
                      label: 'Status notifications',
                      sub: 'Enable system notifications',
                      value: cp.showNotifications,
                      onChanged: cp.toggleNotifications,
                    ),
                    _ToggleRow(
                      label: 'Reduce motion',
                      sub: 'Minimize animations',
                      value: cp.reduceMotion,
                      onChanged: cp.toggleReduceMotion,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  icon: Icons.send_outlined,
                  title: 'Payload Injection',
                  content: Column(children: [
                    Row(children: [
                      Expanded(flex: 3, child: TextField(
                        controller: _ipCtrl,
                        style: T.mono,
                        cursorColor: Bk.accent,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: glassInputDecoration(
                          hintText: 'Target IP',
                          prefixIcon: Icons.lan_outlined,
                          dense: true,
                        ),
                      )),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 1, child: TextField(
                        controller: _portCtrl,
                        style: T.mono,
                        cursorColor: Bk.accent,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: glassInputDecoration(
                          hintText: 'Port',
                          dense: true,
                        ),
                      )),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    _FilePickerRow(
                      file: _selectedFile,
                      onTap: _pickFile,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: _sending ? 'Sending…' : 'Send payload',
                      icon: Icons.rocket_launch_outlined,
                      loading: _sending,
                      onPressed: _sending ? null : _sendPayload,
                      expand: true,
                    ),
                  ]),
                ),
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    icon: Icons.history_outlined,
                    title: 'Recent Payloads',
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 6),
                        foregroundColor: Bk.danger,
                      ),
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        await PayloadHistoryService.clear();
                        _loadPayloadHistory();
                      },
                      child: const Text('Clear all',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    content: Column(children: [
                      for (int i = 0; i < _history.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                              top: i == 0 ? 0 : AppSpacing.sm),
                          child: _HistoryTile(
                            record: _history[i],
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _ipCtrl.text = _history[i].ip;
                              _portCtrl.text = _history[i].port.toString();
                              setState(() => _selectedFile =
                                  File(_history[i].filePath).existsSync()
                                      ? File(_history[i].filePath)
                                      : null);
                            },
                          ),
                        ),
                    ]),
                  ),
                ],
                if (cp.isConnected) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    icon: Icons.link_outlined,
                    title: 'Connection',
                    content: Column(children: [
                      AppButton(
                        label: 'Disconnect',
                        icon: Icons.link_off_outlined,
                        variant: ButtonVariant.destructive,
                        loading: _disconnecting,
                        onPressed: (_disconnecting || _clearingToken)
                            ? null : _doDisconnect,
                        expand: true,
                      ),
                      if (cp.hasToken) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Clear saved token',
                          icon: Icons.key_off_outlined,
                          variant: ButtonVariant.glass,
                          loading: _clearingToken,
                          onPressed: (!_disconnecting && !_clearingToken)
                              ? _doClearToken
                              : null,
                          expand: true,
                        ),
                      ],
                    ]),
                  ),
                ],
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(children: [
        GlassIconButton(
          icon: Icons.close,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).maybePop();
          },
          size: 38,
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(child: Text('Settings', style: T.display)),
      ]),
    );
  }
}

// ── Section ───────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    this.rows,
    this.content,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<_ToggleRow>? rows;
  final Widget? content;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      style: GlassStyle.raised,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Bk.accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: Bk.accent.withOpacity(0.4)),
              ),
              child: Icon(icon, color: Bk.accent, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(title,
              style: const TextStyle(
                color: Bk.textPri, fontSize: 16,
                fontWeight: FontWeight.w700, letterSpacing: -0.2))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: AppSpacing.md),
          if (rows != null)
            ..._withDividers(rows!),
          if (content != null) content!,
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<_ToggleRow> rows) {
    final out = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i != rows.length - 1) {
        out.add(const Divider(
          color: Bk.glassBorder, height: 1, thickness: 1));
      }
    }
    return out;
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String sub;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
              color: Bk.textPri, fontSize: 14,
              fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(
              color: Bk.textDim, fontSize: 12)),
          ],
        )),
        const SizedBox(width: AppSpacing.md),
        Switch(
          value: value,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          activeColor: Bk.accent,
          inactiveThumbColor: Bk.textDim,
          inactiveTrackColor: Bk.glassSubtle,
        ),
      ]),
    );
  }
}

// ── File picker row ───────────────────────────────────────────────────────

class _FilePickerRow extends StatelessWidget {
  const _FilePickerRow({required this.file, required this.onTap});
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = file?.path.split(Platform.pathSeparator).last;
    return GlassCard(
      onTap: onTap,
      style: GlassStyle.subtle,
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Bk.glassRaised,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: Bk.glassBorderHi),
          ),
          child: const Icon(Icons.insert_drive_file_outlined,
            color: Bk.textSec, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name ?? 'Select payload file',
              style: TextStyle(
                color: name == null ? Bk.textDim : Bk.textPri,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(name == null
                ? 'Tap to browse'
                : '${(file!.statSync().size / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(color: Bk.textDim, fontSize: 11)),
          ],
        )),
        const Icon(Icons.chevron_right, color: Bk.textDim),
      ]),
    );
  }
}

// ── History tile ──────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.onTap});
  final PayloadRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(record.sentAt);
    final timeAgo = age.inDays > 0
        ? '${age.inDays}d ago'
        : age.inHours > 0
            ? '${age.inHours}h ago'
            : age.inMinutes > 0 ? '${age.inMinutes}m ago' : 'just now';

    return GlassCard(
      onTap: onTap,
      style: GlassStyle.subtle,
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(children: [
        const Icon(Icons.rocket_launch_outlined,
          color: Bk.textSec, size: 16),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.fileName,
              style: const TextStyle(
                color: Bk.textPri, fontSize: 13,
                fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${record.ip}:${record.port}',
              style: const TextStyle(
                color: Bk.textDim, fontSize: 11, fontFamily: 'monospace')),
          ],
        )),
        const SizedBox(width: AppSpacing.sm),
        Text(timeAgo, style: const TextStyle(
          color: Bk.textDim, fontSize: 11, letterSpacing: 0.3)),
      ]),
    );
  }
}

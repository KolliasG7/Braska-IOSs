// lib/screens/settings_screen.dart
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

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _ipCtrl   = TextEditingController();
  final _portCtrl = TextEditingController(text: '9023');

  List<PayloadRecord> _history = [];
  File? _selectedFile;
  bool  _sending = false;
  bool  _disconnecting = false;
  bool  _clearingToken = false;
  final _payloadSender = const PayloadSenderService();
  bool _showPayloadSection = true;
  bool _showHistorySection = true;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadPayloadHistory();
    _loadSavedTarget();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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

  Future<void> _injectPayload(String ip, int port, File file) async {
    if (!mounted) return;
    _showSnack('Connecting to $ip:$port…', color: Bk.surface2);
    try {
      await _payloadSender.send(
        ip: ip, port: port, file: file,
        timeout: const Duration(seconds: 10),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      final fileName = file.path.split(Platform.pathSeparator).last;
      _showSnack('Sending $fileName…', color: Bk.surface2, textColor: Bk.textSec);

      await PayloadHistoryService.save(PayloadRecord(
        ip: ip, port: port, fileName: fileName,
        filePath: file.path, sentAt: DateTime.now(),
      ));
      _loadPayloadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _showSnack('✓ Payload sent', color: const Color(0xFF1A3A1A),
          textColor: Colors.greenAccent, bold: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _showSnack('Error: ${ErrorFormatter.userMessage(e)}',
          color: Colors.red.shade900);
    }
  }

  void _showSnack(String msg, {
    Color color = Bk.surface2,
    Color textColor = Bk.white,
    bool bold = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      content: Text(msg, style: TextStyle(
        color: textColor, fontSize: 12,
        fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
      )),
    ));
  }

  Future<void> _sendPayload() async {
    final ip   = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9023;
    if (ip.isEmpty) { _showSnack('Enter a target IP address'); return; }
    if (_selectedFile == null) { _showSnack('Select a payload file first'); return; }
    await _saveTarget(ip, port);
    setState(() => _sending = true);
    await _injectPayload(ip, port, _selectedFile!);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _doDisconnect() async {
    HapticFeedback.mediumImpact();
    setState(() => _disconnecting = true);
    final cp = context.read<ConnectionProvider>();
    // FIX: use disconnectAndForget() so _Root doesn't immediately reconnect
    await cp.disconnectAndForget();
    if (!mounted) return;
    // Pop after state is updated — no race condition
    Navigator.of(context).pop();
  }

  Future<void> _doClearToken() async {
    HapticFeedback.mediumImpact();
    setState(() => _clearingToken = true);
    final cp = context.read<ConnectionProvider>();
    await cp.clearToken();
    if (!mounted) return;
    setState(() => _clearingToken = false);
    _showSnack('Token cleared — you will need to re-authenticate',
        color: Bk.surface2);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();

    return Scaffold(
      backgroundColor: Bk.oled,
      appBar: AppBar(
        backgroundColor: Bk.oled,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
          child: const Icon(Icons.arrow_back_ios_new, color: Bk.textDim, size: 18),
        ),
        title: const Text('SETTINGS', style: TextStyle(
          color: Bk.textPri, fontSize: 13,
          fontWeight: FontWeight.w900, letterSpacing: 2.5,
        )),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Bk.border),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
          children: [

            // ── Display preferences ─────────────────────────────────
            _SectionHeader('DISPLAY'),
            const SizedBox(height: 8),
            _ToggleGroup(children: [
              _ToggleTile(label: 'CPU Graph',           value: cp.showCpuGraph,      onChanged: cp.toggleCpuGraph),
              _ToggleTile(label: 'RAM Graph',           value: cp.showRamGraph,      onChanged: cp.toggleRamGraph),
              _ToggleTile(label: 'Thermal Graph',       value: cp.showThermalGraph,  onChanged: cp.toggleThermalGraph),
              _ToggleTile(label: 'Status Notifications',value: cp.showNotifications, onChanged: cp.toggleNotifications),
              _ToggleTile(label: 'Reduce Motion',       value: cp.reduceMotion,      onChanged: cp.toggleReduceMotion, last: true),
            ]),

            const SizedBox(height: 28),

            // ── Payload injection ────────────────────────────────────
            Row(children: [
              const Expanded(child: _SectionHeader('PAYLOAD INJECTION')),
              _CollapseButton(
                expanded: _showPayloadSection,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showPayloadSection = !_showPayloadSection);
                },
              ),
            ]),
            const SizedBox(height: 8),
            _AnimatedSection(
              visible: _showPayloadSection,
              child: Column(children: [
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: _InputField(controller: _ipCtrl, hint: 'Target IP',
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _InputField(controller: _portCtrl, hint: 'Port',
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly]),
                  ),
                ]),
                const SizedBox(height: 8),
                _FilePicker(
                  file: _selectedFile,
                  onTap: _pickFile,
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  label: 'SEND PAYLOAD',
                  loading: _sending,
                  onTap: _sending ? null : _sendPayload,
                  style: _ActionStyle.primary,
                ),
              ]),
            ),

            // ── History ──────────────────────────────────────────────
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(children: [
                const Expanded(child: _SectionHeader('HISTORY')),
                _CollapseButton(
                  expanded: _showHistorySection,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showHistorySection = !_showHistorySection);
                  },
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await PayloadHistoryService.clear();
                    _loadPayloadHistory();
                  },
                  child: const Text('CLEAR', style: TextStyle(
                    color: Bk.textDim, fontSize: 9, letterSpacing: 1.5)),
                ),
              ]),
              const SizedBox(height: 8),
              _AnimatedSection(
                visible: _showHistorySection,
                child: Column(
                  children: _history.map((r) => _HistoryTile(
                    record: r,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _ipCtrl.text   = r.ip;
                      _portCtrl.text = r.port.toString();
                      setState(() => _selectedFile =
                          File(r.filePath).existsSync() ? File(r.filePath) : null);
                    },
                  )).toList(),
                ),
              ),
            ],

            // ── Connection ───────────────────────────────────────────
            if (cp.isConnected) ...[
              const SizedBox(height: 28),
              const _SectionHeader('CONNECTION'),
              const SizedBox(height: 8),
              // BUG FIX: Two separate buttons — Disconnect vs Clear Token
              _ActionButton(
                label: 'DISCONNECT',
                loading: _disconnecting,
                onTap: (_disconnecting || _clearingToken) ? null : _doDisconnect,
                style: _ActionStyle.danger,
                icon: Icons.link_off_outlined,
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: cp.hasToken ? 'CLEAR SAVED TOKEN' : 'NO TOKEN SAVED',
                loading: _clearingToken,
                onTap: (cp.hasToken && !_disconnecting && !_clearingToken)
                    ? _doClearToken
                    : null,
                style: _ActionStyle.ghost,
                icon: Icons.key_off_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Animated collapsible section ─────────────────────────────────────────

class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedCrossFade(
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    crossFadeState: visible
        ? CrossFadeState.showFirst
        : CrossFadeState.showSecond,
    firstChild: child,
    secondChild: const SizedBox.shrink(),
  );
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(
      color: Bk.textDim, fontSize: 9,
      fontWeight: FontWeight.w700, letterSpacing: 2,
    )),
    const SizedBox(width: 8),
    Expanded(child: Container(height: 1, color: Bk.border)),
  ]);
}

// ── Collapse button ───────────────────────────────────────────────────────

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedRotation(
      turns: expanded ? 0 : -0.5,
      duration: const Duration(milliseconds: 220),
      child: const Icon(Icons.keyboard_arrow_up, color: Bk.textDim, size: 16),
    ),
  );
}

// ── Toggle group wrapper ──────────────────────────────────────────────────

class _ToggleGroup extends StatelessWidget {
  const _ToggleGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Bk.surface1,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Bk.border),
    ),
    child: Column(children: children),
  );
}

// ── Toggle tile ───────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
  });
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label,
          style: const TextStyle(color: Bk.textPri, fontSize: 13))),
        Switch(
          value: value,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          activeColor: Bk.white,
          inactiveThumbColor: Bk.textDim,
          inactiveTrackColor: Bk.surface2,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    ),
    if (!last) Divider(height: 1, thickness: 1, color: Bk.border.withOpacity(0.5),
        indent: 14, endIndent: 14),
  ]);
}

// ── Input field ───────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboard = TextInputType.text,
    this.formatters,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboard;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Bk.surface1,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Bk.border),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
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

// ── File picker row ───────────────────────────────────────────────────────

class _FilePicker extends StatelessWidget {
  const _FilePicker({required this.file, required this.onTap});
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Bk.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: file != null ? Bk.white.withOpacity(0.3) : Bk.border),
      ),
      child: Row(children: [
        Icon(
          file != null ? Icons.description_outlined : Icons.attach_file_outlined,
          color: file != null ? Bk.textSec : Bk.textDim,
          size: 16,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(
          file != null
              ? file!.path.split(Platform.pathSeparator).last
              : 'Select payload file…',
          style: TextStyle(
            color: file != null ? Bk.textPri : Bk.textDim,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        )),
        const Icon(Icons.chevron_right, color: Bk.textDim, size: 16),
      ]),
    ),
  );
}

// ── Action button ─────────────────────────────────────────────────────────

enum _ActionStyle { primary, danger, ghost }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.style,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final _ActionStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !loading;

    Color bg, fg, border;
    switch (style) {
      case _ActionStyle.primary:
        bg     = disabled ? Bk.surface2 : Bk.white;
        fg     = Bk.oled;
        border = Bk.border;
      case _ActionStyle.danger:
        bg     = disabled ? Bk.surface1 : const Color(0xFF1A0808);
        fg     = disabled ? Bk.textDim : Colors.redAccent;
        border = disabled ? Bk.border : Colors.redAccent.withOpacity(0.4);
      case _ActionStyle.ghost:
        bg     = Bk.surface1;
        fg     = disabled ? Bk.textDim : Bk.textSec;
        border = Bk.border;
    }

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: loading
            ? Center(child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  color: style == _ActionStyle.primary ? Bk.oled : fg,
                  strokeWidth: 2,
                ),
              ))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[
                  Icon(icon, color: fg, size: 15),
                  const SizedBox(width: 8),
                ],
                Text(label, style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                )),
              ]),
      ),
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
    final dt = record.sentAt;
    final ts = '${dt.day}/${dt.month}  '
               '${dt.hour.toString().padLeft(2, '0')}:'
               '${dt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                Text(record.fileName, style: const TextStyle(
                  color: Bk.textPri, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${record.ip}:${record.port}  ·  $ts',
                  style: const TextStyle(color: Bk.textDim, fontSize: 10,
                    fontFamily: 'monospace')),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Bk.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('USE', style: TextStyle(
                color: Bk.textDim, fontSize: 8,
                fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

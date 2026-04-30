// lib/screens/settings_screen.dart — Glass settings panel
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/connection_provider.dart';
import '../services/payload_history_service.dart';
import '../services/payload_sender_service.dart';
import '../services/error_formatter.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import 'logs_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipCtrl   = TextEditingController();
  final _portCtrl = TextEditingController(text: '9023');

  List<PayloadRecord> _history = [];
  File? _selectedFile;
  double? _selectedFileSizeKb;
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
    final file = File(result.files.single.path!);
    double? sizeKb;
    try {
      sizeKb = (await file.length()) / 1024;
    } catch (_) {
      sizeKb = null;
    }
    setState(() {
      _selectedFile = file;
      _selectedFileSizeKb = sizeKb;
    });
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

    // Validate IP address format
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ip.isEmpty) {
      _snack('Enter a target IP address', danger: true);
      return;
    }
    if (!ipRegex.hasMatch(ip)) {
      _snack('Invalid IP address format', danger: true);
      return;
    }

    // Validate IP octets
    final octets = ip.split('.');
    for (final octet in octets) {
      final value = int.tryParse(octet);
      if (value == null || value < 0 || value > 255) {
        _snack('Invalid IP address: each octet must be 0-255', danger: true);
        return;
      }
    }

    // Validate port
    if (port <= 0 || port > 65535) {
      _snack('Invalid port: must be between 1 and 65535', danger: true);
      return;
    }

    if (_selectedFile == null) {
      _snack('Select a payload file first', danger: true);
      return;
    }

    // Validate file exists and is not empty
    if (!await _selectedFile!.exists()) {
      _snack('Selected file does not exist', danger: true);
      return;
    }
    if (await _selectedFile!.length() == 0) {
      _snack('Selected file is empty', danger: true);
      return;
    }

    await _saveTarget(ip, port);
    setState(() => _sending = true);
    await _injectPayload(ip, port, _selectedFile!);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _applyHistoryRecord(PayloadRecord rec) async {
    _ipCtrl.text = rec.ip;
    _portCtrl.text = rec.port.toString();
    final file = File(rec.filePath);
    final exists = await file.exists();
    if (!mounted) return;
    if (!exists) {
      setState(() {
        _selectedFile = null;
        _selectedFileSizeKb = null;
      });
      return;
    }
    double? sizeKb;
    try {
      sizeKb = (await file.length()) / 1024;
    } catch (_) {
      sizeKb = null;
    }
    if (!mounted) return;
    setState(() {
      _selectedFile = file;
      _selectedFileSizeKb = sizeKb;
    });
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

  Future<void> _doChangePassword() async {
    HapticFeedback.selectionClick();
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      _snack('Password changed — session kept alive', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCpuGraph = context.select<ConnectionProvider, bool>((p) => p.showCpuGraph);
    final showRamGraph = context.select<ConnectionProvider, bool>((p) => p.showRamGraph);
    final showThermalGraph = context.select<ConnectionProvider, bool>((p) => p.showThermalGraph);
    final showNotifications = context.select<ConnectionProvider, bool>((p) => p.showNotifications);
    final reduceMotion = context.select<ConnectionProvider, bool>((p) => p.reduceMotion);
    final isConnected = context.select<ConnectionProvider, bool>((p) => p.isConnected);
    final hasToken = context.select<ConnectionProvider, bool>((p) => p.hasToken);
    final cp = context.read<ConnectionProvider>();

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
              child: RepaintBoundary(
                child: Column(children: [
                _Section(
                  icon: Icons.visibility_outlined,
                  title: 'Display',
                  rows: [
                    _ToggleRow(
                      label: 'CPU graph',
                      sub: 'Show processor usage sparkline',
                      value: showCpuGraph,
                      onChanged: cp.toggleCpuGraph,
                    ),
                    _ToggleRow(
                      label: 'RAM graph',
                      sub: 'Show memory usage sparkline',
                      value: showRamGraph,
                      onChanged: cp.toggleRamGraph,
                    ),
                    _ToggleRow(
                      label: 'Thermal graph',
                      sub: 'Show temperature sparkline',
                      value: showThermalGraph,
                      onChanged: cp.toggleThermalGraph,
                    ),
                    _ToggleRow(
                      label: 'Status notifications',
                      sub: 'Enable system notifications',
                      value: showNotifications,
                      onChanged: cp.toggleNotifications,
                    ),
                    _ToggleRow(
                      label: 'Reduce motion',
                      sub: 'Minimize animations',
                      value: reduceMotion,
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
                      sizeKb: _selectedFileSizeKb,
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
                              final rec = _history[i];
                              HapticFeedback.selectionClick();
                              _applyHistoryRecord(rec);
                            },
                          ),
                        ),
                    ]),
                  ),
                ],
                if (isConnected) ...[
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
                      if (hasToken) ...[
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
                  if (hasToken) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _Section(
                      icon: Icons.lock_outline,
                      title: 'Security',
                      content: AppButton(
                        label: 'Change password',
                        icon: Icons.key_outlined,
                        variant: ButtonVariant.glass,
                        onPressed: (_disconnecting || _clearingToken)
                            ? null : _doChangePassword,
                        expand: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _Section(
                      icon: Icons.article_outlined,
                      title: 'Diagnostics',
                      content: AppButton(
                        label: 'View daemon logs',
                        icon: Icons.terminal_outlined,
                        variant: ButtonVariant.glass,
                        onPressed: (_disconnecting || _clearingToken)
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).push(
                                  FadeThroughRoute(child: const LogsScreen()),
                                );
                              },
                        expand: true,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.xxl),
                const _AboutFooter(),
              ])),
            )),
          ]),
        ),
      ),
    );
  }
}

// ── About footer ──────────────────────────────────────────────────────────
// Tiny centered block at the bottom of Settings showing the app version and
// build number (pulled from pubspec via package_info_plus) plus a credit
// line. Makes it obvious which build is running when reporting bugs; no
// action, no network, just static identification.

class _AboutFooter extends StatefulWidget {
  const _AboutFooter();

  @override
  State<_AboutFooter> createState() => _AboutFooterState();
}

class _AboutFooterState extends State<_AboutFooter> {
  String? _versionLine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _versionLine = 'v${info.version} · build ${info.buildNumber}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLine = 'version unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(children: [
        Text(
          _versionLine ?? ' ',
          style: const TextStyle(
            color: Bk.textDim,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'by rmux · reworked by KolliasG7',
          style: TextStyle(
            color: Bk.textDim,
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
      ]),
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
        Expanded(
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7DD3FC), // accent
                  Color(0xFFA5B4FC), // violet
                  Color(0xFFF472B6), // pink
                ],
              ).createShader(bounds);
            },
            child: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
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
      style: GlassStyle.normal,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Enhanced icon container with gradient border
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Bk.accent.withValues(alpha: 0.2),
                    Bk.accent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: Bk.accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: Bk.accent, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(title,
              style: const TextStyle(
                color: Bk.textPri, fontSize: 17,
                fontWeight: FontWeight.w800, letterSpacing: -0.2))),
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
              color: Bk.textPri, fontSize: 15,
              fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(
              color: Bk.textDim, fontSize: 12)),
          ],
        )),
        const SizedBox(width: AppSpacing.md),
        // Enhanced toggle switch with better styling
        Container(
          width: 52, height: 28,
          decoration: BoxDecoration(
            color: value ? Bk.accent : Bk.glassSubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value ? Bk.accent : Bk.glassBorder,
              width: 1.5,
            ),
            boxShadow: value ? [
              BoxShadow(
                color: Bk.accent.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ] : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── File picker row ───────────────────────────────────────────────────────

class _FilePickerRow extends StatelessWidget {
  const _FilePickerRow({
    required this.file,
    required this.sizeKb,
    required this.onTap,
  });
  final File? file;
  final double? sizeKb;
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
        // Enhanced file icon container
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Bk.glassRaised,
                Bk.glassDefault,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: Bk.glassBorderHi, width: 1.5),
          ),
          child: Icon(
            name == null ? Icons.insert_drive_file_outlined : Icons.description_outlined,
            color: name == null ? Bk.textDim : Bk.accent,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name ?? 'Select payload file',
              style: TextStyle(
                color: name == null ? Bk.textDim : Bk.textPri,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(name == null
                ? 'Tap to browse'
                : sizeKb == null ? 'File selected' : '${sizeKb!.toStringAsFixed(1)} KB',
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

// ── Change password dialog ────────────────────────────────────────────────
// Three-field password rotation (current / new / confirm). Client-side
// validation is deliberately a thin sanity layer — the backend is the
// source of truth for min length, current-password check, rate-limiting,
// etc. Whatever the server rejects with gets surfaced verbatim so users
// can see exactly why (e.g. "Current password is incorrect.", "New
// password must be at least 4 characters.", "Too many failed attempts.").

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  bool    _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final next    = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'All three fields are required.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'New password and confirmation do not match.');
      return;
    }
    if (next == current) {
      setState(() => _error = 'New password must differ from the current one.');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      await context.read<ConnectionProvider>().rotatePassword(
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ErrorFormatter.userMessage(e);
      });
    }
  }

  InputDecoration _dec(String label, {required VoidCallback onToggle, required bool obscured}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Bk.textSec, fontSize: 13),
      filled: true,
      fillColor: Bk.surface1,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 12),
      suffixIcon: IconButton(
        icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                   color: Bk.textDim, size: 18),
        onPressed: _submitting ? null : onToggle,
        splashRadius: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Bk.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg)),
      titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      title: const Text('Change password',
        style: TextStyle(color: Bk.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: _obscureCurrent,
            enabled: !_submitting,
            autofocus: true,
            style: const TextStyle(color: Bk.textPri, fontSize: 14),
            cursorColor: Bk.accent,
            decoration: _dec('Current password',
              obscured: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent)),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _newCtrl,
            obscureText: _obscureNew,
            enabled: !_submitting,
            style: const TextStyle(color: Bk.textPri, fontSize: 14),
            cursorColor: Bk.accent,
            decoration: _dec('New password',
              obscured: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew)),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            enabled: !_submitting,
            onSubmitted: (_) => _submitting ? null : _submit(),
            style: const TextStyle(color: Bk.textPri, fontSize: 14),
            cursorColor: Bk.accent,
            decoration: _dec('Confirm new password',
              obscured: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
              style: const TextStyle(color: Bk.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel',
            style: TextStyle(color: Bk.textSec)),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Bk.accent))
            : const Text('Change',
                style: TextStyle(color: Bk.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

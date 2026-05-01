// lib/screens/settings_screen.dart — Glass settings panel
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/connection_provider.dart';
import '../services/api_service.dart';
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

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  final _ipCtrl   = TextEditingController();
  final _portCtrl = TextEditingController(text: '9023');

  List<PayloadRecord> _history = [];
  File? _selectedFile;
  double? _selectedFileSizeKb;
  bool  _sending = false;
  bool  _disconnecting = false;
  bool  _clearingToken = false;
  final _payloadSender = const PayloadSenderService();

  late TabController _diagTabController;

  @override
  void initState() {
    super.initState();
    _diagTabController = TabController(length: 4, vsync: this);
    _loadPayloadHistory();
    _loadSavedTarget();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _diagTabController.dispose();
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
    _snack('Connecting to $ip:$port...');
    try {
      await _payloadSender.send(
        ip: ip, port: port, file: file,
        timeout: const Duration(seconds: 10),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      final fileName = file.path.split(Platform.pathSeparator).last;
      _snack('Sending $fileName...');

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
    _snack('Token cleared - re-authenticate to continue');
  }

  Future<void> _doChangePassword() async {
    HapticFeedback.selectionClick();
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      _snack('Password changed - session kept alive', success: true);
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: RepaintBoundary(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 980;

                        final leftChildren = <Widget>[
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
                          if (isConnected) ...[
                            const SizedBox(height: AppSpacing.xl),
                            _DiagnosticsSection(
                              api: cp.api,
                              tabController: _diagTabController,
                              canOpenLogs: !_disconnecting && !_clearingToken,
                            ),
                          ],
                        ];

                        final rightChildren = <Widget>[
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
                                label: _sending ? 'Sending...' : 'Send payload',
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
                            ],
                          ],
                        ];

                        if (!isWide) {
                          return Column(children: [
                            ...leftChildren,
                            const SizedBox(height: AppSpacing.xl),
                            ...rightChildren,
                            const SizedBox(height: AppSpacing.xxl),
                            const _AboutFooter(),
                          ]);
                        }

                        return Column(children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(children: leftChildren)),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(child: Column(children: rightChildren)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          const _AboutFooter(),
                        ]);
                      },
                    ),
                  ),
                ),
              ),
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
      setState(() => _versionLine = 'v${info.version} | build ${info.buildNumber}');
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
          'by rmux | reworked by KolliasG7',
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

// ── Unified Diagnostics section with tabs ─────────────────────────────────────

class _DiagnosticsSection extends StatefulWidget {
  const _DiagnosticsSection({
    required this.api,
    required this.tabController,
    required this.canOpenLogs,
  });
  final ApiService? api;
  final TabController tabController;
  final bool canOpenLogs;

  @override State<_DiagnosticsSection> createState() => _DiagnosticsSectionState();
}

class _DiagnosticsSectionState extends State<_DiagnosticsSection> {
  Map<String, dynamic>? _settings;
  Map<String, dynamic>? _caps;
  Map<String, dynamic>? _diag;
  bool _loadingSettings = true;
  bool _loadingCaps = true;
  bool _loadingDiag = true;
  bool _loadedSettings = false;
  bool _loadedCaps = false;
  bool _loadedDiag = false;
  bool _saving = false;
  String? _errSettings;
  String? _errCaps;
  String? _errDiag;

  final _pollIntervalCtrl = TextEditingController();
  final _fanDebounceCtrl = TextEditingController();
  final _remotePortCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
    _ensureTabLoaded(widget.tabController.index);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    _pollIntervalCtrl.dispose();
    _fanDebounceCtrl.dispose();
    _remotePortCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!widget.tabController.indexIsChanging) {
      _ensureTabLoaded(widget.tabController.index);
    }
  }

  void _ensureTabLoaded(int tabIndex) {
    if (widget.api == null) return;
    if (tabIndex == 0 && !_loadedSettings) _loadSettings();
    if (tabIndex == 1 && !_loadedCaps) _loadCaps();
    if (tabIndex == 2 && !_loadedDiag) _loadDiag();
  }

  Future<void> _loadSettings() async {
    if (widget.api == null) return;
    setState(() { _loadingSettings = true; _errSettings = null; });
    try {
      final s = await widget.api!.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _loadingSettings = false;
        _loadedSettings = true;
        _pollIntervalCtrl.text = (s['poll_interval_ms'] as int? ?? 1000).toString();
        _fanDebounceCtrl.text = (s['fan_debounce_ms'] as int? ?? 2000).toString();
        _remotePortCtrl.text = (s['remote_port'] as int? ?? 9023).toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSettings = false;
        _errSettings = e.toString();
      });
    }
  }

  Future<void> _loadCaps() async {
    if (widget.api == null) return;
    setState(() { _loadingCaps = true; _errCaps = null; });
    try {
      final c = await widget.api!.getCapabilities();
      if (!mounted) return;
      setState(() {
        _caps = c;
        _loadingCaps = false;
        _loadedCaps = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCaps = false;
        _errCaps = e.toString();
      });
    }
  }

  Future<void> _loadDiag() async {
    if (widget.api == null) return;
    setState(() { _loadingDiag = true; _errDiag = null; });
    try {
      final d = await widget.api!.getDiagnostics();
      if (!mounted) return;
      setState(() {
        _diag = d;
        _loadingDiag = false;
        _loadedDiag = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDiag = false;
        _errDiag = e.toString();
      });
    }
  }

  Future<void> _saveSettings() async {
    if (widget.api == null) return;
    setState(() { _saving = true; _errSettings = null; });
    try {
      final pollInterval = int.tryParse(_pollIntervalCtrl.text);
      final fanDebounce = int.tryParse(_fanDebounceCtrl.text);
      final remotePort = int.tryParse(_remotePortCtrl.text);

      if (pollInterval == null || pollInterval < 100) {
        setState(() { _saving = false; _errSettings = 'Poll interval must be at least 100ms'; });
        return;
      }
      if (fanDebounce == null || fanDebounce < 0) {
        setState(() { _saving = false; _errSettings = 'Fan debounce must be non-negative'; });
        return;
      }
      if (remotePort == null || remotePort < 1 || remotePort > 65535) {
        setState(() { _saving = false; _errSettings = 'Port must be between 1 and 65535'; });
        return;
      }

      await widget.api!.updateSettings(
        pollIntervalMs: pollInterval,
        fanDebounceMs: fanDebounce,
        remotePort: remotePort,
      );
      if (!mounted) return;
      await _loadSettings();
      if (!mounted) return;
      setState(() { _saving = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errSettings = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.bug_report_outlined,
      title: 'Diagnostics',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Bk.glassSubtle,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: Bk.glassBorder, width: 1),
            ),
            child: TabBar(
              controller: widget.tabController,
              indicator: BoxDecoration(
                color: Bk.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Bk.accent,
              unselectedLabelColor: Bk.textDim,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
              tabs: const [
                Tab(text: 'Settings'),
                Tab(text: 'Capabilities'),
                Tab(text: 'Diagnostics'),
                Tab(text: 'Logs'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedBuilder(
            animation: widget.tabController.animation!,
            builder: (_, __) {
              final activeIndex = widget.tabController.index;
              _ensureTabLoaded(activeIndex);
              return _buildTab(activeIndex);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return _buildSettingsTab();
      case 1:
        return _buildCapsTab();
      case 2:
        return _buildDiagTab();
      case 3:
        return _buildLogsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSettingsTab() {
    if (_loadingSettings) {
      return const Center(
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: Bk.accent),
        ),
      );
    }

    if (_errSettings != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_errSettings!,
            style: const TextStyle(color: Bk.danger, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _loadSettings,
            child: const Text('Retry',
              style: TextStyle(color: Bk.accent, fontSize: 12)),
          ),
        ],
      );
    }

    final s = _settings!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          _SettingRow(
            label: 'Poll interval',
            value: '${s['poll_interval_ms']} ms',
            sub: 'Telemetry update frequency',
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingRow(
            label: 'Fan debounce',
            value: '${s['fan_debounce_ms']} ms',
            sub: 'Fan control delay',
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingRow(
            label: 'Remote port',
            value: '${s['remote_port']}',
            sub: 'API server port',
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingRow(
            label: 'Remote enabled',
            value: s['remote_enabled'] == true ? 'Yes' : 'No',
            sub: 'Remote API access',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _pollIntervalCtrl,
                style: T.mono,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: glassInputDecoration(
                  hintText: 'Poll interval (ms)',
                  dense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _fanDebounceCtrl,
                style: T.mono,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: glassInputDecoration(
                  hintText: 'Fan debounce (ms)',
                  dense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _remotePortCtrl,
                style: T.mono,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: glassInputDecoration(
                  hintText: 'Port',
                  dense: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _saving ? 'Saving...' : 'Apply settings',
            icon: Icons.save_outlined,
            loading: _saving,
            onPressed: _saving ? null : _saveSettings,
            expand: true,
          ),
      ],
    );
  }

  Widget _buildCapsTab() {
    if (_loadingCaps) {
      return const Center(
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: Bk.accent),
        ),
      );
    }

    if (_errCaps != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_errCaps!,
            style: const TextStyle(color: Bk.danger, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _loadCaps,
            child: const Text('Retry',
              style: TextStyle(color: Bk.accent, fontSize: 12)),
          ),
        ],
      );
    }

    final c = _caps!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          _CapRow(
            label: 'Fan',
            available: _bool(c['fan']?['available']),
            write: _bool(c['fan']?['write']),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CapRow(
            label: 'LED',
            available: _bool(c['led']?['available']),
            write: _bool(c['led']?['write']),
            extra: _bool(c['led']?['thermal_mode']) ? 'Thermal mode' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CapRow(
            label: 'GPU',
            available: _bool(c['gpu']?['available']),
            write: _bool(c['gpu']?['write']),
            extra: _bool(c['gpu']?['supported_hardware']) ? 'Supported hardware' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CapRow(
            label: 'HDMI',
            available: _bool(c['hdmi']?['available']),
            write: _bool(c['hdmi']?['write']),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CapRow(
            label: 'System',
            available: true,
            write: false,
            extra: 'Processes: ${_bool(c['system']?['processes']) ? 'Yes' : 'No'}, '
                   'Power: ${_bool(c['system']?['power']) ? 'Yes' : 'No'}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _CapRow(
            label: 'Files',
            available: _bool(c['files']?['available']),
            write: false,
          ),
      ],
    );
  }

  Widget _buildDiagTab() {
    if (_loadingDiag) {
      return const Center(
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: Bk.accent),
        ),
      );
    }

    if (_errDiag != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_errDiag!,
            style: const TextStyle(color: Bk.danger, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _loadDiag,
            child: const Text('Retry',
              style: TextStyle(color: Bk.accent, fontSize: 12)),
          ),
        ],
      );
    }

    final d = _diag!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          _DiagRow(label: 'Status', value: d['status'] as String? ?? 'Unknown'),
          const SizedBox(height: AppSpacing.sm),
          _DiagRow(label: 'Peer IP', value: d['peer_ip'] as String? ?? 'Unknown'),
          const SizedBox(height: AppSpacing.sm),
          _DiagRow(label: 'Auth required', value: _bool(d['auth_required']) ? 'Yes' : 'No'),
          const SizedBox(height: AppSpacing.sm),
          _DiagRow(label: 'Remote enabled', value: _bool(d['remote_enabled']) ? 'Yes' : 'No'),
          const SizedBox(height: AppSpacing.sm),
          _DiagRow(label: 'Remote port', value: '${d['remote_port'] ?? 'N/A'}'),
          const SizedBox(height: AppSpacing.sm),
          _DiagRow(label: 'Kernel', value: d['kernel'] as String? ?? 'Unavailable'),
          const SizedBox(height: AppSpacing.sm),
          _DiagRow(label: 'Hardware variant', value: d['hardware_variant'] as String? ?? 'Unknown'),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: Bk.glassBorder),
          const SizedBox(height: AppSpacing.md),
          const Text('Component status',
            style: TextStyle(
              color: Bk.textSec, fontSize: 11,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          _CompStatus(
            label: 'Fan',
            available: _bool(d['fan']?['available']),
            message: d['fan']?['message'] as String?,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CompStatus(
            label: 'LED',
            available: _bool(d['led']?['available']),
            message: d['led']?['message'] as String?,
            extra: _bool(d['led']?['thermal_mode_supported']) ? 'Thermal mode supported' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CompStatus(
            label: 'GPU',
            available: _bool(d['gpu']?['available']),
            message: d['gpu']?['message'] as String?,
            warning: d['gpu']?['warning'] as String?,
            extra: _bool(d['gpu']?['supported_hardware']) ? 'Supported hardware' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CompStatus(
            label: 'HDMI',
            available: _bool(d['hdmi']?['available']),
            message: d['hdmi']?['message'] as String?,
          ),
      ],
    );
  }

  Widget _buildLogsTab() {
    return AppButton(
      label: 'View daemon logs',
      icon: Icons.terminal_outlined,
      variant: ButtonVariant.glass,
      onPressed: widget.canOpenLogs
          ? () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                FadeThroughRoute(child: const LogsScreen()),
              );
            }
          : null,
      expand: true,
    );
  }

  bool _bool(dynamic v) => v == true;
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: const TextStyle(
                  color: Bk.textPri, fontSize: 13,
                  fontWeight: FontWeight.w600)),
              Text(sub,
                style: const TextStyle(
                  color: Bk.textDim, fontSize: 10)),
            ],
          ),
        ),
        Text(value,
          style: const TextStyle(
            color: Bk.accent, fontSize: 13,
            fontFamily: 'monospace', fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CapRow extends StatelessWidget {
  const _CapRow({
    required this.label,
    required this.available,
    required this.write,
    this.extra,
  });

  final String label;
  final bool available;
  final bool write;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: available ? Bk.success : Bk.textDim,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: TextStyle(
                  color: available ? Bk.textPri : Bk.textDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
              if (extra != null)
                Text(extra!,
                  style: const TextStyle(
                    color: Bk.textDim, fontSize: 10)),
            ],
          ),
        ),
        if (available)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: write
                  ? Bk.accent.withValues(alpha: 0.15)
                  : Bk.textDim.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: write
                    ? Bk.accent.withValues(alpha: 0.4)
                    : Bk.textDim.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              write ? 'RW' : 'RO',
              style: TextStyle(
                color: write ? Bk.accent : Bk.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label,
            style: const TextStyle(
              color: Bk.textDim, fontSize: 12)),
        ),
        Text(value,
          style: const TextStyle(
            color: Bk.textPri, fontSize: 12,
            fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CompStatus extends StatelessWidget {
  const _CompStatus({
    required this.label,
    required this.available,
    this.message,
    this.warning,
    this.extra,
  });

  final String label;
  final bool available;
  final String? message;
  final String? warning;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: available ? Bk.success : Bk.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      color: available ? Bk.textPri : Bk.textDim,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
                  if (message != null && message!.isNotEmpty)
                    Text(message!,
                      style: const TextStyle(
                        color: Bk.textDim, fontSize: 10)),
                  if (extra != null)
                    Text(extra!,
                      style: const TextStyle(
                        color: Bk.accent, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        if (warning != null && warning!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_outlined,
                  color: Bk.warn, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(warning!,
                    style: const TextStyle(
                      color: Bk.warn, fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

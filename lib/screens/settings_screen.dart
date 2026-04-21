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
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            surfaceTintColor: Colors.transparent,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back_ios_new, 
                  color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Settings', style: TextStyle(
                color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.w700,
              )),
              titlePadding: const EdgeInsets.only(bottom: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF0A0A0A),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Display Preferences Card
                _ModernCard(
                  title: 'Display Preferences',
                  icon: Icons.visibility_outlined,
                  child: Column(
                    children: [
                      _ModernToggleTile(
                        label: 'CPU Graph',
                        subtitle: 'Show CPU usage graph',
                        value: cp.showCpuGraph,
                        onChanged: cp.toggleCpuGraph,
                      ),
                      _ModernToggleTile(
                        label: 'RAM Graph',
                        subtitle: 'Show memory usage graph',
                        value: cp.showRamGraph,
                        onChanged: cp.toggleRamGraph,
                      ),
                      _ModernToggleTile(
                        label: 'Thermal Graph',
                        subtitle: 'Show temperature monitoring',
                        value: cp.showThermalGraph,
                        onChanged: cp.toggleThermalGraph,
                      ),
                      _ModernToggleTile(
                        label: 'Status Notifications',
                        subtitle: 'Enable system notifications',
                        value: cp.showNotifications,
                        onChanged: cp.toggleNotifications,
                      ),
                      _ModernToggleTile(
                        label: 'Reduce Motion',
                        subtitle: 'Minimize animations',
                        value: cp.reduceMotion,
                        onChanged: cp.toggleReduceMotion,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Payload Injection Card
                _ModernCard(
                  title: 'Payload Injection',
                  icon: Icons.send_outlined,
                  action: _ModernExpandButton(
                    expanded: _showPayloadSection,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showPayloadSection = !_showPayloadSection);
                    },
                  ),
                  child: _ModernAnimatedSection(
                    visible: _showPayloadSection,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _ModernInputField(
                                controller: _ipCtrl,
                                hint: 'Target IP Address',
                                icon: Icons.lan_outlined,
                                keyboard: TextInputType.number,
                                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _ModernInputField(
                                controller: _portCtrl,
                                hint: 'Port',
                                icon: Icons.settings_ethernet_outlined,
                                keyboard: TextInputType.number,
                                formatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ModernFilePicker(
                          file: _selectedFile,
                          onTap: _pickFile,
                        ),
                        const SizedBox(height: 20),
                        _ModernActionButton(
                          label: 'Send Payload',
                          loading: _sending,
                          onTap: _sending ? null : _sendPayload,
                          style: _ModernActionStyle.primary,
                          icon: Icons.rocket_launch_outlined,
                        ),
                      ],
                    ),
                  ),
                ),

                // History Card
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _ModernCard(
                    title: 'Recent Payloads',
                    icon: Icons.history_outlined,
                    action: Row(
                      children: [
                        _ModernExpandButton(
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: const Text('Clear All', style: TextStyle(
                              color: Colors.redAccent, fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                          ),
                        ),
                      ],
                    ),
                    child: _ModernAnimatedSection(
                      visible: _showHistorySection,
                      child: Column(
                        children: _history.map((r) => _ModernHistoryTile(
                          record: r,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _ipCtrl.text = r.ip;
                            _portCtrl.text = r.port.toString();
                            setState(() => _selectedFile =
                                File(r.filePath).existsSync() ? File(r.filePath) : null);
                          },
                        )).toList(),
                      ),
                    ),
                  ),
                ],

                // Connection Card
                if (cp.isConnected) ...[
                  const SizedBox(height: 24),
                  _ModernCard(
                    title: 'Connection',
                    icon: Icons.link_outlined,
                    child: Column(
                      children: [
                        _ModernActionButton(
                          label: 'Disconnect',
                          loading: _disconnecting,
                          onTap: (_disconnecting || _clearingToken) ? null : _doDisconnect,
                          style: _ModernActionStyle.danger,
                          icon: Icons.link_off_outlined,
                        ),
                        const SizedBox(height: 12),
                        _ModernActionButton(
                          label: cp.hasToken ? 'Clear Saved Token' : 'No Token Saved',
                          loading: _clearingToken,
                          onTap: (cp.hasToken && !_disconnecting && !_clearingToken)
                              ? _doClearToken
                              : null,
                          style: _ModernActionStyle.ghost,
                          icon: Icons.key_off_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modern Card Component ───────────────────────────────────────────────

class _ModernCard extends StatelessWidget {
  const _ModernCard({
    required this.title,
    required this.child,
    required this.icon,
    this.action,
  });
  
  final String title;
  final Widget child;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Modern Toggle Tile ───────────────────────────────────────────────────

class _ModernToggleTile extends StatelessWidget {
  const _ModernToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });
  
  final String label;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Switch(
                value: value,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                },
                activeColor: const Color(0xFF4CAF50),
                inactiveThumbColor: Colors.white.withOpacity(0.3),
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withOpacity(0.1),
          ),
      ],
    );
  }
}

// ── Modern Input Field ───────────────────────────────────────────────────

class _ModernInputField extends StatelessWidget {
  const _ModernInputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.formatters,
  });
  
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboard;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: formatters,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: Colors.white.withOpacity(0.5),
            size: 20,
          ),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

// ── Modern File Picker ───────────────────────────────────────────────────

class _ModernFilePicker extends StatelessWidget {
  const _ModernFilePicker({
    required this.file,
    required this.onTap,
  });
  
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: file != null 
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null 
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: file != null 
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                file != null ? Icons.description_outlined : Icons.attach_file_outlined,
                color: file != null ? const Color(0xFF4CAF50) : Colors.white.withOpacity(0.6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file != null
                        ? file!.path.split(Platform.pathSeparator).last
                        : 'Select payload file',
                    style: TextStyle(
                      color: file != null ? Colors.white : Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: file != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (file != null)
                    Text(
                      'Ready to send',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modern Action Button ─────────────────────────────────────────────────

enum _ModernActionStyle { primary, danger, ghost }

class _ModernActionButton extends StatelessWidget {
  const _ModernActionButton({
    required this.label,
    required this.onTap,
    required this.style,
    this.loading = false,
    this.icon,
  });
  
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final _ModernActionStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !loading;

    Color bg, fg, border;
    switch (style) {
      case _ModernActionStyle.primary:
        bg = disabled ? Colors.white.withOpacity(0.1) : const Color(0xFF4CAF50);
        fg = Colors.white;
        border = disabled ? Colors.white.withOpacity(0.1) : const Color(0xFF4CAF50);
      case _ModernActionStyle.danger:
        bg = disabled ? Colors.white.withOpacity(0.1) : const Color(0xFFE53935);
        fg = Colors.white;
        border = disabled ? Colors.white.withOpacity(0.1) : const Color(0xFFE53935);
      case _ModernActionStyle.ghost:
        bg = Colors.white.withOpacity(0.05);
        fg = disabled ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.8);
        border = Colors.white.withOpacity(0.1);
    }

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: [
            if (!disabled && style == _ModernActionStyle.primary)
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: loading
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: fg,
                    strokeWidth: 2,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: fg, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Modern History Tile ───────────────────────────────────────────────────

class _ModernHistoryTile extends StatelessWidget {
  const _ModernHistoryTile({
    required this.record,
    required this.onTap,
  });
  
  final PayloadRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dt = record.sentAt;
    final ts = '${dt.day}/${dt.month}  '
               '${dt.hour.toString().padLeft(2, '0')}:'
               '${dt.minute.toString().padLeft(2, '0')}';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.ip}:${record.port}  ·  $ts',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                  ),
                ),
                child: const Text(
                  'USE',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modern Expand Button ──────────────────────────────────────────────────

class _ModernExpandButton extends StatelessWidget {
  const _ModernExpandButton({
    required this.expanded,
    required this.onTap,
  });
  
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: AnimatedRotation(
          turns: expanded ? 0 : -0.5,
          duration: const Duration(milliseconds: 300),
          child: const Icon(
            Icons.keyboard_arrow_up,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ── Modern Animated Section ───────────────────────────────────────────────

class _ModernAnimatedSection extends StatelessWidget {
  const _ModernAnimatedSection({
    required this.visible,
    required this.child,
  });
  
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: visible
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: child,
      secondChild: const SizedBox.shrink(),
    );
  }
}

// ── Legacy Components (kept for compatibility) ───────────────────────────────

class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedCrossFade(
    duration: const Duration(milliseconds: 240),
    crossFadeState: visible
        ? CrossFadeState.showFirst
        : CrossFadeState.showSecond,
    firstChild: child,
    secondChild: const SizedBox.shrink(),
  );
}

// Legacy components kept for compatibility - they are no longer used in the modern UI
// but kept here to prevent any potential compilation errors

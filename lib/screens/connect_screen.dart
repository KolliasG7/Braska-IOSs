// lib/screens/connect_screen.dart — Strawberry Manager landing
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/connection_provider.dart';
import '../services/payload_history_service.dart';
import '../services/payload_sender_service.dart';
import '../services/error_formatter.dart';
import '../theme.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl    = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isTunnel = false;

  String? _lastTunnelUrl;

  List<PayloadRecord> _payloadHistory = [];
  final _payloadSender = const PayloadSenderService();

  late final AnimationController _entranceCtrl;
  late final Animation<double>   _entranceFade;
  late final Animation<Offset>   _entranceSlide;

  @override
  void initState() {
    super.initState();
    final cp = context.read<ConnectionProvider>();
    _ctrl.text = cp.rawInput;
    _isTunnel  = cp.isTunnel;
    // Gentle fade + rise on first appearance. Paired with the root-level
    // zoom-through, this makes the Connect screen settle in instead of
    // just snapping.
    _entranceCtrl = AnimationController(
      vsync: this, duration: AppDurations.med,
    )..forward();
    _entranceFade = CurvedAnimation(
      parent: _entranceCtrl, curve: AppCurves.enter);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.02), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: AppCurves.enter));
    _loadLastTunnel();
    _loadPayloadHistory();
  }

  Future<void> _loadLastTunnel() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('last_tunnel_url');
    if (url != null && mounted) setState(() => _lastTunnelUrl = url);
  }

  Future<void> _loadPayloadHistory() async {
    final history = await PayloadHistoryService.load();
    if (mounted) setState(() => _payloadHistory = history);
  }

  void _onChanged(String v) {
    final t = v.startsWith('https://') || v.startsWith('http://') ||
              v.contains('.trycloudflare.com');
    if (t != _isTunnel) setState(() => _isTunnel = t);
  }

  void _setMode(bool tunnel) {
    if (tunnel == _isTunnel) return;
    setState(() => _isTunnel = tunnel);
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    final cp = context.read<ConnectionProvider>();
    await cp.connect(_ctrl.text.trim());
    if (!mounted) return;
    if (cp.connState == ConnState.needsAuth) _showPasswordDialog();
  }

  Future<void> _showPasswordDialog() async {
    final cp   = context.read<ConnectionProvider>();
    final ctrl = TextEditingController();
    bool  obscure = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Password',
            style: TextStyle(color: Bk.textPri, fontSize: 16,
              fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter Strawberry Manager password.',
              style: TextStyle(color: Bk.textSec, fontSize: 13, height: 1.4)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl,
              obscureText: obscure,
              autofocus: true,
              style: T.mono,
              cursorColor: Bk.accent,
              decoration: glassInputDecoration(
                hintText: 'password',
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                    color: Bk.textDim, size: 18),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
            if (cp.error != null && cp.connState == ConnState.needsAuth) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(cp.error!,
                style: const TextStyle(color: Bk.danger, fontSize: 12)),
            ],
          ]),
          actions: [
            TextButton(
              onPressed: () { cp.disconnect(); Navigator.pop(ctx); },
              child: const Text('Cancel',
                style: TextStyle(color: Bk.textSec))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await cp.login(ctrl.text);
                ctrl.dispose();
              },
              child: const Text('Unlock')),
          ],
        ),
      ),
    );
  }

  void _useTunnelUrl(String url) {
    _ctrl.text = url;
    setState(() => _isTunnel = true);
  }

  Future<void> _resendPayload(PayloadRecord record) async {
    final file = File(record.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      _snack('File not found: ${record.fileName}', danger: true);
      return;
    }
    _injectPayload(record.ip, record.port, file);
  }

  void _snack(String msg, {bool danger = false, bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Bk.surface1,
      content: Text(msg, style: TextStyle(
        color: danger ? Bk.danger : success ? Bk.success : Bk.textPri,
        fontSize: 13)),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConnectionProvider>();
    final connecting = cp.connState == ConnState.connecting;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: FadeTransition(
            opacity: _entranceFade,
            child: SlideTransition(
              position: _entranceSlide,
              child: Form(
            key: _formKey,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(children: [
                const SizedBox(height: 48),
                const _HeroTitle(),
                const SizedBox(height: AppSpacing.lg),
                const _GlassTagline(),
                const SizedBox(height: AppSpacing.xl),

                if (cp.rawInput.isNotEmpty || _lastTunnelUrl != null) ...[
                  _StatusPanel(
                    lastHost: cp.rawInput.isNotEmpty
                        ? cp.rawInput
                        : _lastTunnelUrl!,
                    isTunnel: _isTunnel,
                    ready: cp.hasToken,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  style: GlassStyle.raised,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModeSegmented(
                        isTunnel: _isTunnel,
                        onChanged: _setMode,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _ctrl,
                        onChanged: _onChanged,
                        style: T.mono,
                        cursorColor: Bk.accent,
                        decoration: glassInputDecoration(
                          hintText: _isTunnel
                              ? 'https://xxxx.trycloudflare.com'
                              : '192.168.1.116:8765',
                          prefixIcon: _isTunnel
                              ? Icons.link_outlined
                              : Icons.lan_outlined,
                        ),
                        validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      if (_lastTunnelUrl != null &&
                          _lastTunnelUrl != _ctrl.text) ...[
                        const SizedBox(height: AppSpacing.md),
                        _LastTunnelRow(
                          url: _lastTunnelUrl!,
                          onUse: () => _useTunnelUrl(_lastTunnelUrl!),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                if (cp.error != null)
                  GlassCard(
                    tint: Bk.danger.withValues(alpha: 0.25),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                        color: Bk.danger, size: 18),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(cp.error!,
                        style: const TextStyle(
                          color: Bk.textPri, fontSize: 13, height: 1.4))),
                    ]),
                  ),

                if (cp.error != null)
                  const SizedBox(height: AppSpacing.md),

                AppButton(
                  onPressed: connecting ? null : _connect,
                  loading: connecting,
                  icon: connecting ? null : Icons.rocket_launch_outlined,
                  label: connecting ? 'Connecting…' : 'Connect',
                  expand: true,
                ),

                const SizedBox(height: AppSpacing.md),

                AppButton(
                  variant: ButtonVariant.glass,
                  onPressed: _showPayloadInjector,
                  icon: Icons.rocket_launch_outlined,
                  label: 'Inject Linux Payload',
                  expand: true,
                ),

                if (_payloadHistory.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const StatLabel('RECENT PAYLOADS'),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: Bk.textDim,
                        ),
                        onPressed: () async {
                          await PayloadHistoryService.clear();
                          _loadPayloadHistory();
                        },
                        child: const Text('CLEAR',
                          style: TextStyle(
                            fontSize: 10, letterSpacing: 1.5,
                            fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._payloadHistory.take(5).map((record) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _RecentPayloadTile(
                        record: record,
                        onTap: () => _resendPayload(record),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: Bk.textDim.withValues(alpha: 0.7),
                      fontSize: 11, letterSpacing: 0.5),
                    children: const [
                      TextSpan(text: 'by '),
                      TextSpan(text: 'rmux',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: '  ·  reworked by '),
                      TextSpan(text: 'KolliasG7',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
              ),
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPayloadInjector() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any, allowMultiple: false);
    if (res == null || res.files.single.path == null) return;

    final file = File(res.files.single.path!);

    String ip = '192.168.1.31';
    String port = '9090';
    if (_payloadHistory.isNotEmpty) {
      ip = _payloadHistory.first.ip;
      port = _payloadHistory.first.port.toString();
    }
    final currentInput = _ctrl.text.trim();
    if (currentInput.isNotEmpty && !currentInput.startsWith('http')) {
      ip = currentInput.split(':').first;
    }

    if (!mounted) return;
    final ipCtrl = TextEditingController(text: ip);
    final portCtrl = TextEditingController(text: port);

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Inject payload',
          style: TextStyle(color: Bk.textPri, fontSize: 16,
            fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${res.files.single.name}',
              style: const TextStyle(color: Bk.textSec, fontSize: 12)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ipCtrl,
              style: T.mono,
              cursorColor: Bk.accent,
              decoration: glassInputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.31',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: portCtrl,
              style: T.mono,
              cursorColor: Bk.accent,
              keyboardType: TextInputType.number,
              decoration: glassInputDecoration(
                labelText: 'Port (usually 9020 or 9023)',
                hintText: '9023',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel',
              style: TextStyle(color: Bk.textSec))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              _injectPayload(
                ipCtrl.text.trim(),
                int.tryParse(portCtrl.text.trim()) ?? 9023,
                file,
              );
            },
            child: const Text('Send')),
        ],
      ),
    );

    ipCtrl.dispose();
    portCtrl.dispose();
  }

  Future<void> _injectPayload(String ip, int port, File file) async {
    // Validate IP address format
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
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

    if (!mounted) return;
    _snack('Connecting to $ip:$port…');
    try {
      await _payloadSender.send(
        ip: ip, port: port, file: file,
        timeout: const Duration(seconds: 3),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      final fileName = file.path.split(Platform.pathSeparator).last;
      _snack('Sending $fileName…');

      await PayloadHistoryService.save(PayloadRecord(
        ip: ip, port: port,
        fileName: fileName, filePath: file.path,
        sentAt: DateTime.now(),
      ));
      _loadPayloadHistory();

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _snack('Payload sent successfully', success: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _snack('Error: ${ErrorFormatter.userMessage(e)}', danger: true);
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

/// Centered wordmark used as the top-of-screen identity.
class _HeroTitle extends StatelessWidget {
  const _HeroTitle();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Enhanced title with gradient effect
      ShaderMask(
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
          'Strawberry Manager',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
      const SizedBox(height: 8),
      // Enhanced subtitle with better styling
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Bk.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: Bk.accent.withValues(alpha: 0.3), width: 1),
        ),
        child: const Text(
          'PlayStation 4 · Linux Control',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Bk.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ]);
  }
}

class _GlassTagline extends StatelessWidget {
  const _GlassTagline();

  @override
  Widget build(BuildContext context) {
    return const GlassPill(
      selected: true,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'PlayStation 4 Control Surface',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Bk.textHighlight,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

/// Info card shown above the connect form when the user has a previous
/// session on record. Gives the screen a purposeful top-half.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.lastHost,
    required this.isTunnel,
    required this.ready,
  });

  final String lastHost;
  final bool isTunnel;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final stateColor = ready ? Bk.success : Bk.textSec;
    final stateLabel = ready ? 'Ready' : 'Idle';

    return GlassCard(
      style: GlassStyle.raised,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const StatLabel('STATUS'),
            const Spacer(),
            // Enhanced status badge with glow effect
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                    color: stateColor.withValues(alpha: 0.4), width: 1),
                boxShadow: ready ? [
                  BoxShadow(
                    color: stateColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stateColor,
                    boxShadow: ready ? [
                      BoxShadow(
                        color: stateColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ] : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(stateLabel,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  )),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          const Text('LAST SESSION',
            style: TextStyle(
              color: Bk.textDim, fontSize: 10,
              letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          // Enhanced host display with better styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Bk.glassDefault,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: Bk.glassBorder, width: 1),
            ),
            child: Text(lastHost,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.mono.copyWith(
                color: Bk.textPri,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              )),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(
              isTunnel ? Icons.cloud_outlined : Icons.wifi_outlined,
              color: Bk.textSec, size: 14),
            const SizedBox(width: 4),
            Text(isTunnel ? 'Tunnel' : 'Local',
              style: const TextStyle(
                color: Bk.textSec, fontSize: 12,
                fontWeight: FontWeight.w600)),
            const Text('  ·  ',
              style: TextStyle(color: Bk.textDim, fontSize: 12)),
            Text(ready ? 'Token saved' : 'Tap Connect to sign in',
              style: const TextStyle(
                color: Bk.textSec, fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

class _ModeSegmented extends StatelessWidget {
  const _ModeSegmented({required this.isTunnel, required this.onChanged});
  final bool isTunnel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const pad = 4.0;
    const height = 48.0;
    final reduceMotion = context.watch<ConnectionProvider>().reduceMotion;

    return LayoutBuilder(builder: (ctx, box) {
      final segW = (box.maxWidth - pad * 2) / 2;

      return Container(
        height: height,
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Bk.glassSubtle,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: Bk.glassBorder),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
          // Sliding glass thumb. Uses an eased curve and the accent for a
          // soft glow so it feels like the pill physically moves.
          AnimatedPositioned(
            // Smooth settle: uses a gentler curve to prevent curvature
            // artifacts during the slide animation.
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: isTunnel ? segW : 0,
            top: 0,
            bottom: 0,
            width: segW,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Bk.glassRaised,
                borderRadius: BorderRadius.circular(AppRadii.pill - pad),
                border: Border.all(color: Bk.glassBorderHi),
                boxShadow: [
                  BoxShadow(
                    color: Bk.accent.withValues(alpha: 0.18),
                    blurRadius: 18,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                  const BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(children: [
            Expanded(child: _SegBtn(
              icon: Icons.wifi_outlined,
              label: 'Local',
              selected: !isTunnel,
              onTap: () => onChanged(false),
            )),
            Expanded(child: _SegBtn(
              icon: Icons.cloud_outlined,
              label: 'Tunnel',
              selected: isTunnel,
              onTap: () => onChanged(true),
            )),
          ]),
        ]),
      );
    });
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: selected ? 1 : 0),
              duration: AppDurations.med,
              curve: AppCurves.standard,
              builder: (_, v, __) => Icon(icon,
                size: 16,
                color: Color.lerp(Bk.textDim, Bk.textPri, v)),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: AppDurations.med,
              curve: AppCurves.standard,
              style: TextStyle(
                color: selected ? Bk.textPri : Bk.textDim,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastTunnelRow extends StatelessWidget {
  const _LastTunnelRow({required this.url, required this.onUse});
  final String url;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onUse,
      style: GlassStyle.subtle,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      radius: AppRadii.md,
      child: Row(children: [
        const Icon(Icons.history_outlined,
          color: Bk.textSec, size: 16),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(
          url.replaceAll('https://', ''),
          style: const TextStyle(color: Bk.textPri, fontSize: 12),
          overflow: TextOverflow.ellipsis)),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Bk.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: Bk.accent.withValues(alpha: 0.5)),
          ),
          child: const Text('USE',
            style: TextStyle(
              color: Bk.accent, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ),
      ]),
    );
  }
}

class _RecentPayloadTile extends StatelessWidget {
  const _RecentPayloadTile({required this.record, required this.onTap});
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      radius: AppRadii.md,
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
          color: Bk.textDim, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Bk.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: Bk.accent.withValues(alpha: 0.5)),
          ),
          child: const Text('SEND',
            style: TextStyle(
              color: Bk.accent, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ),
      ]),
    );
  }
}

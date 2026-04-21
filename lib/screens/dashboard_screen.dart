// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../models/telemetry.dart';
import '../services/ws_service.dart';
import '../theme.dart';
import '../widgets/overview_widgets.dart';
import '../widgets/fan_control.dart';
import '../widgets/led_panel.dart';
import 'processes_screen.dart';
import 'terminal_screen.dart';
import 'power_screen.dart';
import 'files_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  int _prevTab = 0;

  // Subtle entrance animation
  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Widget _buildTabContent(TelemetryFrame? frame, ConnectionProvider cp) {
    return switch (_tab) {
      0 => _OverviewTab(frame: frame),
      1 => _ControlTab(frame: frame, api: cp.api),
      2 => ProcessesScreen(api: cp.api!),
      3 => const TerminalScreen(),
      4 => FilesScreen(api: cp.api!),
      _ => PowerScreen(api: cp.api!),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cp     = context.watch<ConnectionProvider>();
    final frame  = cp.frame;
    final cpu    = frame?.cpu?.percent ?? 0;
    final animMs = cp.reduceMotion ? 1 : 260;

    return FadeTransition(
      opacity: _entranceFade,
      child: SlideTransition(
        position: _entranceSlide,
        child: Scaffold(
          backgroundColor: Bk.oled,
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              _TopBar(
                frame: frame,
                ws: cp.ws,
                onSettings: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context,
                    _SlideUpRoute(child: const SettingsScreen()));
                },
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: animMs),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final isForward = _tab >= _prevTab;
                    final beginX = isForward ? 0.04 : -0.04;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(beginX, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_tab),
                    child: _buildTabContent(frame, cp),
                  ),
                ),
              ),
            ]),
          ),
          bottomNavigationBar: _Nav(
            selected: _tab,
            reduceMotion: cp.reduceMotion,
            onTap: (i) {
              if (i == _tab) return;
              HapticFeedback.selectionClick();
              setState(() { _prevTab = _tab; _tab = i; });
            },
            hasCpuAlert: cpu > 80,
          ),
        ),
      ),
    );
  }
}

// ── Slide-up page route ────────────────────────────────────────────────────

class _SlideUpRoute<T> extends PageRouteBuilder<T> {
  _SlideUpRoute({required Widget child})
    : super(
        pageBuilder: (_, __, ___) => child,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, secAnim, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(position: slide, child: child),
          );
        },
      );
}

// ── 6-tab nav bar ──────────────────────────────────────────────────────────

class _Nav extends StatelessWidget {
  const _Nav({
    required this.selected,
    required this.onTap,
    required this.hasCpuAlert,
    required this.reduceMotion,
  });
  final int selected;
  final void Function(int) onTap;
  final bool hasCpuAlert;
  final bool reduceMotion;

  static const _tabs = [
    (icon: Icons.monitor_heart_outlined, label: 'MONITOR', badge: false),
    (icon: Icons.tune_outlined,          label: 'CONTROL', badge: false),
    (icon: Icons.memory_outlined,        label: 'PROC',    badge: true),
    (icon: Icons.terminal_outlined,      label: 'SHELL',   badge: false),
    (icon: Icons.folder_outlined,        label: 'FILES',   badge: false),
    (icon: Icons.power_settings_new,     label: 'POWER',   badge: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Bk.surface1,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Bk.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final sel = i == selected;
              return _NavItem(
                icon: tab.icon,
                label: tab.label,
                badge: tab.badge && hasCpuAlert,
                selected: sel,
                reduceMotion: reduceMotion,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool badge, selected, reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = reduceMotion ? 1 : 200;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: selected
            ? BoxDecoration(
                color: Bk.white,
                borderRadius: BorderRadius.circular(18),
              )
            : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Badge(
            isLabelVisible: badge,
            backgroundColor: selected ? Bk.oled : Bk.white,
            smallSize: 5,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: reduceMotion ? 1 : 200),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                icon,
                key: ValueKey(selected),
                color: selected ? Bk.oled : Bk.textDim,
                size: selected ? 18 : 17,
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: Duration(milliseconds: ms),
            style: TextStyle(
              color: selected ? Bk.oled : Bk.textDim,
              fontSize: 7,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
              letterSpacing: 0.8,
            ),
            child: Text(label),
          ),
        ]),
      ),
    );
  }

}

// ── Top bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.frame, required this.ws, required this.onSettings});
  final TelemetryFrame? frame;
  final WsService? ws;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final temp = frame?.fan?.apuTempC ?? 0;
    final cpu  = frame?.cpu?.percent  ?? 0;
    final rpm  = frame?.fan?.rpm      ?? 0;
    final tempHot = temp >= 88;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      child: Row(children: [
        // App name + uptime
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('STRAWBERRY', style: TextStyle(
            color: Bk.textPri, fontSize: 17,
            fontWeight: FontWeight.w900, letterSpacing: 2)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: frame != null
                ? Text(
                    key: const ValueKey('uptime'),
                    'MANAGER  ·  ${frame!.uptimeFormatted}',
                    style: const TextStyle(
                      color: Bk.textDim, fontSize: 9, letterSpacing: 1.5),
                  )
                : const Text(
                    key: ValueKey('connecting'),
                    'MANAGER',
                    style: TextStyle(
                      color: Bk.textDim, fontSize: 9, letterSpacing: 1.5),
                  ),
          ),
        ]),
        const Spacer(),

        // Live stat chips
        if (frame != null) ...[
          _Chip(Icons.thermostat_outlined, '${temp.toStringAsFixed(0)}°',
              tempHot ? Bk.white : Bk.textSec),
          const SizedBox(width: 8),
          _Chip(Icons.memory_outlined, '${cpu.toStringAsFixed(0)}%', Bk.textSec),
          const SizedBox(width: 8),
          _Chip(Icons.air_outlined, rpm == 0 ? 'idle' : '$rpm', Bk.textSec),
          const SizedBox(width: 14),
        ],

        // WS status dot
        StreamBuilder<WsState>(
          stream: ws?.state,
          builder: (_, snap) {
            final s = snap.data ?? WsState.disconnected;
            return _StatusDot(
              color: s == WsState.connected   ? Bk.white
                   : s == WsState.connecting  ? Bk.textSec
                   : Bk.border,
              pulse: s == WsState.connected,
            );
          },
        ),

        const SizedBox(width: 12),
        GestureDetector(
          onTap: onSettings,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.settings_outlined, color: Bk.textDim, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.val, this.color);
  final IconData icon; final String val; final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color.withOpacity(0.6), size: 11),
      const SizedBox(width: 3),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: Text(
          val,
          key: ValueKey<String>(val),
          style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;
  @override State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final opacity = widget.pulse
          ? 0.45 + _c.value * 0.55
          : 1.0;
      return Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(opacity),
          boxShadow: widget.pulse
              ? [BoxShadow(
                  color: widget.color.withOpacity(0.4 * _c.value),
                  blurRadius: 6, spreadRadius: 1)]
              : null,
        ),
      );
    },
  );
}

// ── Overview tab ───────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.frame});
  final TelemetryFrame? frame;

  @override
  Widget build(BuildContext context) {
    if (frame == null) return const _Wait();
    if (frame!.isError) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(child: Text(frame!.error!,
        style: const TextStyle(color: Bk.textSec, fontSize: 12)))));

    final cp = context.watch<ConnectionProvider>();

    final cards = <Widget>[
      if (frame!.cpu != null)
        CpuCard(cpu: frame!.cpu!, cpuHistory: cp.cpuHistory, showGraph: cp.showCpuGraph),
      if (frame!.ram != null)
        RamCard(ram: frame!.ram!, swap: frame!.swap, ramHistory: cp.ramHistory, showGraph: cp.showRamGraph),
      if (frame!.fan != null)
        ThermalCard(fan: frame!.fan!, tempHistory: cp.tempHistory, fanHistory: cp.fanHistory, showGraph: cp.showThermalGraph),
      if (frame!.net.isNotEmpty) NetworkCard(netList: frame!.net),
      if (frame!.disk.isNotEmpty) DiskCard(disks: frame!.disk),
      IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: UptimeChip(uptime: frame!.uptimeFormatted)),
          if (frame!.tunnel != null) ...[
            const SizedBox(width: 10),
            Expanded(child: _TunnelChip(t: frame!.tunnel!)),
          ],
        ],
      )),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
      child: Column(
        children: List.generate(cards.length * 2 - 1, (index) {
          if (index.isOdd) return const SizedBox(height: 10);
          final i = index ~/ 2;
          return _Anim(delay: Duration(milliseconds: 50 * i), child: cards[i]);
        }),
      ),
    );
  }
}

class _TunnelChip extends StatelessWidget {
  const _TunnelChip({required this.t});
  final TunnelStatus t;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Icon(t.isRunning ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        color: Bk.white, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StatLabel(t.isRunning ? 'TUNNEL ON' : 'TUNNEL OFF'),
          if (t.url != null)
            Text(t.url!.replaceAll('https://', ''),
              style: const TextStyle(color: Bk.textSec, fontSize: 9),
              overflow: TextOverflow.ellipsis),
        ])),
    ]),
  );
}

class _ControlTab extends StatelessWidget {
  const _ControlTab({required this.frame, required this.api});
  final TelemetryFrame? frame;
  final dynamic api;

  @override
  Widget build(BuildContext context) {
    if (api == null) return const _Wait();
    final cards = <Widget>[
      if (frame?.fan != null)
        FanControlCard(api: api, currentThreshold: frame!.fan!.thresholdC),
      LedPanelCard(api: api),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
      child: Column(
        children: List.generate(cards.length * 2 - 1, (index) {
          if (index.isOdd) return const SizedBox(height: 10);
          final i = index ~/ 2;
          return _Anim(delay: Duration(milliseconds: 50 * i), child: cards[i]);
        }),
      ),
    );
  }
}

// ── Waiting spinner ────────────────────────────────────────────────────────

class _Wait extends StatelessWidget {
  const _Wait();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(
          color: Bk.white, strokeWidth: 1.5)),
      const SizedBox(height: 16),
      const Text('AWAITING TELEMETRY', style: TextStyle(
        color: Bk.textDim, fontSize: 9, letterSpacing: 3)),
    ]),
  );
}

// ── Staggered card animation ───────────────────────────────────────────────

class _Anim extends StatefulWidget {
  const _Anim({required this.child, required this.delay});
  final Widget child;
  final Duration delay;
  @override State<_Anim> createState() => _AnimState();
}

class _AnimState extends State<_Anim> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _c     = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade,
          child: SlideTransition(position: _slide, child: widget.child));
}

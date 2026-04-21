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

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  int _prevTab = 0;

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
    final cp    = context.watch<ConnectionProvider>();
    final frame = cp.frame;
    final cpu   = frame?.cpu?.percent ?? 0;
    final animMs = cp.reduceMotion ? 1 : 260;
    final iconAnimMs = cp.reduceMotion ? 1 : 220;

    return Scaffold(
      backgroundColor: Bk.oled,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _TopBar(
            frame: frame, ws: cp.ws,
            onSettings: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: animMs),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final isForward = _tab >= _prevTab;
                final beginX = isForward ? 0.05 : -0.05;
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
        selected:    _tab,
        reduceMotion: cp.reduceMotion,
        onTap:       (i) {
          if (i == _tab) return;
          HapticFeedback.selectionClick();
          setState(() {
            _prevTab = _tab;
            _tab = i;
          });
        },
        hasCpuAlert: cpu > 80,
      ),
    );
  }
}

// ── 6-tab nav ─────────────────────────────────────────────────────────────

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
    (icon: Icons.monitor_heart_outlined,  label: 'MONITOR', badge: false),
    (icon: Icons.tune_outlined,           label: 'CONTROL', badge: false),
    (icon: Icons.memory_outlined,         label: 'PROC',    badge: true),
    (icon: Icons.terminal_outlined,       label: 'SHELL',   badge: false),
    (icon: Icons.folder_outlined,         label: 'FILES',   badge: false),
    (icon: Icons.power_settings_new,      label: 'POWER',   badge: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
      child: Container(
        decoration: BoxDecoration(
          color: Bk.oled,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Bk.border, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final sel = i == selected;
              final col = sel ? Bk.oled : Bk.textDim;
              final iconAnimMs = reduceMotion ? 1 : 220;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: reduceMotion ? 1 : 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  decoration: sel ? BoxDecoration(
                    color: Bk.white,
                    borderRadius: BorderRadius.circular(18),
                  ) : null,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Badge(
                      isLabelVisible: tab.badge && hasCpuAlert,
                      backgroundColor: Bk.white,
                      smallSize: 6,
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: iconAnimMs),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.12),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('icon-$i-$sel'),
                          duration: Duration(milliseconds: reduceMotion ? 1 : 190),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(
                            begin: sel ? 0.9 : 1.08,
                            end: sel ? 1.08 : 1,
                          ),
                          builder: (_, scale, __) => Transform.scale(
                            scale: scale,
                            child: Icon(
                              tab.icon,
                              color: col,
                              size: sel ? 19 : 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: Duration(milliseconds: reduceMotion ? 1 : 180),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: col,
                        fontSize: 7,
                        fontWeight: sel ? FontWeight.w900 : FontWeight.w500,
                        letterSpacing: 1,
                      ),
                      child: Text(tab.label),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.frame, required this.ws, required this.onSettings});
  final TelemetryFrame? frame;
  final WsService? ws;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final temp = frame?.fan?.apuTempC ?? 0;
    final cpu  = frame?.cpu?.percent  ?? 0;
    final rpm  = frame?.fan?.rpm ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('STRAWBERRY', style: TextStyle(
            color: Bk.textPri, fontSize: 16,
            fontWeight: FontWeight.w900, letterSpacing: 2.5)),
          if (frame != null)
            Text('MANAGER  ·  ${frame!.uptimeFormatted}', style: const TextStyle(
              color: Bk.textDim, fontSize: 9, letterSpacing: 1.5)),
        ]),
        const Spacer(),
        if (frame != null) ...[
          _Chip(
            Icons.thermostat_outlined,
            '${temp.toStringAsFixed(0)}°',
            temp >= 88 ? Bk.white : Bk.textSec,
          ),
          const SizedBox(width: 6),
          _Chip(Icons.memory_outlined, '${cpu.toStringAsFixed(0)}%', Bk.textSec),
          const SizedBox(width: 6),
          _Chip(Icons.air_outlined, rpm == 0 ? 'idle' : '$rpm', Bk.textSec),
          const SizedBox(width: 12),
        ],
        StreamBuilder<WsState>(
          stream: ws?.state,
          builder: (_, snap) {
            final s = snap.data ?? WsState.disconnected;
            return _Dot(s == WsState.connected ? Bk.white
              : s == WsState.connecting ? Bk.textSec : Bk.border);
          },
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onSettings,
          child: const Semantics(
            label: 'Open settings',
            button: true,
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
  @override Widget build(BuildContext context) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color.withOpacity(0.7), size: 11),
      const SizedBox(width: 3),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
        child: Text(
          val,
          key: ValueKey<String>(val),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ]);
}

class _Dot extends StatefulWidget {
  const _Dot(this.color);
  final Color color;
  @override State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(width: 7, height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: widget.color.withOpacity(0.4 + _c.value * 0.6))));
  @override void dispose() { _c.dispose(); super.dispose(); }
}

// ── Overview / Control tabs (same as before) ──────────────────────────────

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
      if (frame!.cpu != null)      CpuCard(cpu: frame!.cpu!, cpuHistory: cp.cpuHistory, showGraph: cp.showCpuGraph),
      if (frame!.ram != null)      RamCard(ram: frame!.ram!, swap: frame!.swap, ramHistory: cp.ramHistory, showGraph: cp.showRamGraph),
      if (frame!.fan != null)      ThermalCard(fan: frame!.fan!, tempHistory: cp.tempHistory, fanHistory: cp.fanHistory, showGraph: cp.showThermalGraph),
      if (frame!.net.isNotEmpty)   NetworkCard(netList: frame!.net),
      if (frame!.disk.isNotEmpty)  DiskCard(disks: frame!.disk),
      IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: UptimeChip(uptime: frame!.uptimeFormatted)),
          if (frame!.tunnel != null) ...[
            const SizedBox(width: 12),
            Expanded(child: _TunnelChip(t: frame!.tunnel!)),
          ],
        ],
      )),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
      child: Column(children: [
        for (int i = 0; i < cards.length; i++) ...[
          _Anim(delay: Duration(milliseconds: 60 * i), child: cards[i]),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class _TunnelChip extends StatelessWidget {
  const _TunnelChip({required this.t});
  final TunnelStatus t;
  @override Widget build(BuildContext context) => GlassCard(
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
  final TelemetryFrame? frame; final dynamic api;
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
      child: Column(children: [
        for (int i = 0; i < cards.length; i++) ...[
          _Anim(delay: Duration(milliseconds: 60 * i), child: cards[i]),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class _Wait extends StatelessWidget {
  const _Wait();
  @override Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 26, height: 26,
        child: CircularProgressIndicator(color: Bk.white, strokeWidth: 2)),
      SizedBox(height: 14),
      Text('AWAITING TELEMETRY',
        style: TextStyle(color: Bk.textDim, fontSize: 9, letterSpacing: 3)),
    ]),
  );
}

class _Anim extends StatefulWidget {
  const _Anim({required this.child, required this.delay});
  final Widget child; final Duration delay;
  @override State<_Anim> createState() => _AnimState();
}
class _AnimState extends State<_Anim> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;
  @override void initState() {
    super.initState();
    _c     = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => FadeTransition(
    opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
}

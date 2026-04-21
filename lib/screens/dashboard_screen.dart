// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../models/telemetry.dart';
import '../models/process_info.dart';
import '../services/ws_service.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/overview_widgets.dart';
import '../widgets/fan_control.dart';
import '../widgets/led_panel.dart';
import '../widgets/power_controls.dart';
import 'processes_screen.dart';
import 'terminal_screen.dart';
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

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: AppDurations.med,
    )..forward();
    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: AppCurves.enter);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: AppCurves.enter));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Widget _tabBody(TelemetryFrame? frame, ConnectionProvider cp) {
    return switch (_tab) {
      0 => _MonitorTab(frame: frame, api: cp.api),
      1 => _ControlTab(frame: frame, api: cp.api),
      2 => const TerminalScreen(embedded: true),
      _ => FilesScreen(api: cp.api!, embedded: true),
    };
  }

  void _openSettings() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      SlideUpRoute(child: const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp     = context.watch<ConnectionProvider>();
    final frame  = cp.frame;
    final cpu    = frame?.cpu?.percent ?? 0;
    final reduceMotion = cp.reduceMotion;

    return AppBackground(
      child: FadeTransition(
        opacity: _entranceFade,
        child: SlideTransition(
          position: _entranceSlide,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(
                    frame: frame,
                    ws: cp.ws,
                    onSettings: _openSettings,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      // The old 520ms slow + 0.08 slide made every tab tap
                      // feel like it stuttered. iOS segmented content swaps
                      // in ~220ms; match that and keep the slide subtle.
                      duration: reduceMotion
                          ? Duration.zero
                          : AppDurations.fast,
                      reverseDuration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      switchInCurve: AppCurves.enter,
                      switchOutCurve: AppCurves.exit,
                      // Put the incoming child on top so the outgoing one
                      // fades out underneath without ghosting the gradient.
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      transitionBuilder: (child, animation) {
                        final isForward = _tab >= _prevTab;
                        final beginX = isForward ? 0.03 : -0.03;
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(beginX, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: AppCurves.enter,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_tab),
                        child: _tabBody(frame, cp),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: GlassBottomNav(
                reduceMotion: reduceMotion,
                selectedIndex: _tab,
                onTap: (i) {
                  setState(() { _prevTab = _tab; _tab = i; });
                },
                destinations: [
                  NavDestination(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Monitor',
                    badge: cpu > 80,
                  ),
                  const NavDestination(
                    icon: Icons.tune_outlined,
                    label: 'Control',
                  ),
                  const NavDestination(
                    icon: Icons.terminal_outlined,
                    label: 'Shell',
                  ),
                  const NavDestination(
                    icon: Icons.folder_outlined,
                    label: 'Files',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Slide-up page route (shared export) ────────────────────────────────────

class SlideUpRoute<T> extends PageRouteBuilder<T> {
  SlideUpRoute({required Widget child})
    : super(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => child,
        transitionDuration: AppDurations.med,
        reverseTransitionDuration: AppDurations.fast,
        transitionsBuilder: (_, anim, __, child) {
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

// ── Top bar (header w/ title, live chips, status, settings) ───────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.frame,
    required this.ws,
    required this.onSettings,
  });
  final TelemetryFrame? frame;
  final WsService? ws;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Strawberry', style: TextStyle(
                  color: Bk.textPri, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.2,
                )),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: AppDurations.med,
                  child: Text(
                    frame == null
                        ? 'Connecting…'
                        : 'Uptime ${frame!.uptimeFormatted}',
                    key: ValueKey(frame == null ? 'wait' : 'ok'),
                    style: const TextStyle(color: Bk.textSec, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          _ConnStatus(ws: ws),
          const SizedBox(width: AppSpacing.sm),
          GlassIconButton(
            icon: Icons.settings_outlined,
            onPressed: onSettings,
            size: 40,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _ConnStatus extends StatelessWidget {
  const _ConnStatus({required this.ws});
  final WsService? ws;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WsState>(
      stream: ws?.state,
      builder: (_, snap) {
        final s = snap.data ?? WsState.disconnected;
        final (color, label) = switch (s) {
          WsState.connected    => (Bk.success,  'LIVE'),
          WsState.connecting   => (Bk.warn,     'CONNECTING'),
          WsState.disconnected => (Bk.textDim,  'OFFLINE'),
        };
        return GlassPill(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(color: color, pulse: s == WsState.connected),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: color, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.2,
            )),
          ]),
        );
      },
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;
  @override State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final opacity = widget.pulse ? 0.55 + _c.value * 0.45 : 1.0;
      return Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(opacity),
          boxShadow: widget.pulse ? [
            BoxShadow(
              color: widget.color.withOpacity(0.6 * _c.value),
              blurRadius: 6, spreadRadius: 1),
          ] : null,
        ),
      );
    },
  );
}

// ── Monitor tab (Overview) ─────────────────────────────────────────────────

class _MonitorTab extends StatelessWidget {
  const _MonitorTab({required this.frame, required this.api});
  final TelemetryFrame? frame;
  final ApiService? api;

  @override
  Widget build(BuildContext context) {
    if (frame == null) return const _Wait();
    if (frame!.isError) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: _ErrorCard(message: frame!.error!),
      );
    }

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
      if (api != null) TopProcessesCard(api: api!),
      IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: UptimeChip(uptime: frame!.uptimeFormatted)),
          if (frame!.tunnel != null) ...[
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _TunnelChip(t: frame!.tunnel!)),
          ],
        ],
      )),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 120),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => cards[i],
    );
  }
}

class _TunnelChip extends StatelessWidget {
  const _TunnelChip({required this.t});
  final TunnelStatus t;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    child: Row(children: [
      Icon(
        t.isRunning ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        color: t.isRunning ? Bk.success : Bk.textDim,
        size: 16,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StatLabel(t.isRunning ? 'TUNNEL ON' : 'TUNNEL OFF'),
          if (t.url != null) ...[
            const SizedBox(height: 2),
            Text(t.url!.replaceAll('https://', ''),
              style: const TextStyle(color: Bk.textSec, fontSize: 10),
              overflow: TextOverflow.ellipsis),
          ],
        ])),
    ]),
  );
}

// ── Control tab (Power + Fan + LED) ────────────────────────────────────────

class _ControlTab extends StatelessWidget {
  const _ControlTab({required this.frame, required this.api});
  final TelemetryFrame? frame;
  final ApiService? api;

  @override
  Widget build(BuildContext context) {
    if (api == null) return const _Wait();
    final cards = <Widget>[
      PowerControlsCard(api: api!),
      if (frame?.fan != null)
        FanControlCard(api: api!, currentThreshold: frame!.fan!.thresholdC),
      LedPanelCard(api: api!),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 120),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => cards[i],
    );
  }
}

// ── Top Processes card (monitor drill-in) ──────────────────────────────────

class TopProcessesCard extends StatefulWidget {
  const TopProcessesCard({super.key, required this.api});
  final ApiService api;
  @override State<TopProcessesCard> createState() => _TopProcessesCardState();
}

class _TopProcessesCardState extends State<TopProcessesCard> {
  List<ProcessInfo> _procs = const [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.api.getProcesses(limit: 5, sortBy: 'cpu');
      if (!mounted) return;
      setState(() { _procs = p; _loading = false; _err = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Row(children: [
              const StatLabel('TOP PROCESSES'),
              const Spacer(),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context,
                    SlideUpRoute(child: ProcessesScreen(api: widget.api)));
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Bk.accent,
                ),
                child: const Text('SEE ALL',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Bk.accent)),
              ),
            )
          else if (_err != null)
            Padding(
              padding: const EdgeInsets.only(
                  right: AppSpacing.md, bottom: AppSpacing.sm),
              child: Text(_err!, style: const TextStyle(
                color: Bk.danger, fontSize: 11)),
            )
          else
            ...List.generate(_procs.length, (i) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _TopProcRow(p: _procs[i]),
            )),
        ],
      ),
    );
  }
}

class _TopProcRow extends StatelessWidget {
  const _TopProcRow({required this.p});
  final ProcessInfo p;

  @override
  Widget build(BuildContext context) {
    final cpuColor = p.cpuPct > 50 ? Bk.warn
                   : p.cpuPct > 20 ? Bk.accent : Bk.textSec;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(
          width: 48,
          child: Text('${p.pid}', style: const TextStyle(
            color: Bk.textDim, fontSize: 11, fontFamily: 'monospace')),
        ),
        Expanded(
          child: Text(p.name, style: const TextStyle(
            color: Bk.textPri, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        SizedBox(
          width: 52,
          child: Text(
            p.cpuPct > 0 ? '${p.cpuPct.toStringAsFixed(1)}%' : '—',
            style: TextStyle(
              color: cpuColor, fontSize: 12,
              fontWeight: FontWeight.w700, fontFamily: 'monospace'),
            textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 54,
          child: Text('${p.memRssMb.toStringAsFixed(0)}M',
            style: const TextStyle(
              color: Bk.textSec, fontSize: 12, fontFamily: 'monospace'),
            textAlign: TextAlign.right),
        ),
      ]),
    );
  }
}

// ── Placeholders ───────────────────────────────────────────────────────────

class _Wait extends StatelessWidget {
  const _Wait();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: const [
      SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(
          color: Bk.accent, strokeWidth: 2)),
      SizedBox(height: AppSpacing.lg),
      Text('AWAITING TELEMETRY', style: TextStyle(
        color: Bk.textDim, fontSize: 10, letterSpacing: 2.5)),
    ]),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => GlassCard(
    tint: Bk.danger.withOpacity(0.18),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline, color: Bk.danger, size: 18),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Text(message, style: const TextStyle(
        color: Bk.textSec, fontSize: 12, height: 1.4))),
    ]),
  );
}

// The previous `_StaggerIn` helper cross-fade-slid every card on every tab
// swap, which compounded with the tab transition itself and made the app
// feel like it was constantly re-introducing itself. The dashboard's
// single top-level entrance already covers first mount; individual card
// entrances on tab swap weren't adding signal, only latency.

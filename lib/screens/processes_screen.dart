// lib/screens/processes_screen.dart — process drilldown from Monitor tab
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/process_info.dart';
import '../providers/connection_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key, required this.api});
  final ApiService api;
  @override State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen>
    with WidgetsBindingObserver {
  List<ProcessInfo> _procs = [];
  String _sort = 'cpu';
  bool _loading = true;
  String? _err;
  Timer? _timer;
  String _filter = '';
  DateTime? _lastUpdated;
  DateTime? _lastSuccess;
  // Prevents overlapping `_refresh` calls when the server is slow: the
  // 3 s poller or a pull-to-refresh can otherwise fire a second request
  // before the first one returns, producing out-of-order state updates
  // and doubling the bandwidth cost on flaky links.
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    _timer ??= Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _refresh();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  Future<void> _refresh() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final p = await widget.api.getProcesses(limit: 60, sortBy: _sort);
      if (!mounted) return;
      setState(() {
        _procs = p;
        _loading = false;
        _err = null;
        _lastUpdated = DateTime.now();
        _lastSuccess = _lastUpdated;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } finally {
      _inFlight = false;
    }
  }

  List<ProcessInfo> get _filtered {
    if (_filter.isEmpty) return _procs;
    final q = _filter.toLowerCase();
    return _procs.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.user.toLowerCase().contains(q) ||
      p.pid.toString().contains(q)).toList();
  }

  Future<void> _kill(ProcessInfo p, String sig) async {
    try {
      await widget.api.killProcess(p.pid, signal: sig);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e',
          style: const TextStyle(color: Bk.textPri)),
        backgroundColor: Bk.danger.withValues(alpha:0.9),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showActions(ProcessInfo p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GlassSheet(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('PID ${p.pid}  ·  ${p.name}',
            style: const TextStyle(color: Bk.textPri, fontSize: 15,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(p.cmdline,
            style: const TextStyle(color: Bk.textDim, fontSize: 11),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(child: _SigBtn('SIGTERM', Bk.warn,
              () { Navigator.pop(context); _kill(p, 'SIGTERM'); })),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _SigBtn('SIGKILL', Bk.danger,
              () { Navigator.pop(context); _kill(p, 'SIGKILL'); })),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _SigBtn('SIGSTOP', Bk.textSec,
              () { Navigator.pop(context); _kill(p, 'SIGSTOP'); })),
          ]),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
              style: TextStyle(color: Bk.textDim, fontSize: 13))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<ConnectionProvider>().reduceMotion;
    final procs = _filtered;
    final stale = _lastSuccess != null &&
        DateTime.now().difference(_lastSuccess!).inSeconds > 15;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(children: [
            _Header(
              count: procs.length,
              sort: _sort,
              onSortChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _sort = v);
                _refresh();
              },
              onRefresh: _refresh,
              updatedLabel: _lastUpdated == null
                  ? 'Never updated'
                  : stale
                      ? 'Stale (${DateTime.now().difference(_lastUpdated!).inSeconds}s ago)'
                      : 'Updated ${DateTime.now().difference(_lastUpdated!).inSeconds}s ago',
              updatedColor: stale ? Bk.warn : Bk.textDim,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
              child: TextField(
                onChanged: (v) => setState(() => _filter = v),
                style: const TextStyle(color: Bk.textPri, fontSize: 14),
                cursorColor: Bk.accent,
                decoration: glassInputDecoration(
                  hintText: 'Filter by name, user, PID…',
                  prefixIcon: Icons.search_outlined,
                  dense: true,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl + AppSpacing.xs),
              child: Row(children: [
                SizedBox(width: 52, child: Text('PID', style: T.label)),
                Expanded(flex: 3, child: Text('NAME', style: T.label)),
                SizedBox(width: 52, child: Text('CPU%',
                  style: T.label, textAlign: TextAlign.right)),
                SizedBox(width: 58, child: Text('MEM',
                  style: T.label, textAlign: TextAlign.right)),
              ]),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: Bk.accent,
                backgroundColor: Bk.surface1,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduceMotion ? 1 : 220),
                  switchInCurve: AppCurves.enter,
                  switchOutCurve: AppCurves.exit,
                  child: _loading
                      ? const _ProcSkeleton(key: ValueKey('loading'))
                      : _err != null
                          ? Center(
                              key: const ValueKey('error'),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Text(
                                  _err!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Bk.danger, fontSize: 12),
                                ),
                              ),
                            )
                          : ListView.separated(
                              key: const ValueKey('list'),
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                              itemCount: procs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (_, i) => _ProcRow(
                                p: procs[i],
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showActions(procs[i]);
                                },
                              ),
                            ),
                ),
              ),
            ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.sort,
    required this.onSortChanged,
    required this.onRefresh,
    required this.updatedLabel,
    required this.updatedColor,
  });
  final int count;
  final String sort;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onRefresh;
  final String updatedLabel;
  final Color updatedColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(children: [
        GlassIconButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: () => Navigator.of(context).maybePop(),
          size: 38,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Processes',
                style: TextStyle(
                  color: Bk.textPri, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Bk.accent.withValues(alpha:0.18),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: Bk.accent.withValues(alpha:0.4)),
                ),
                child: Text('$count',
                  style: const TextStyle(
                    color: Bk.accent, fontSize: 11,
                    fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(updatedLabel,
              style: TextStyle(
                color: updatedColor, fontSize: 11, letterSpacing: 0.2)),
          ],
        )),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<String>(
          tooltip: 'Sort',
          color: Bk.surface1,
          icon: const Icon(Icons.sort_outlined, color: Bk.textSec),
          onSelected: onSortChanged,
          itemBuilder: (_) => [
            for (final s in ['cpu', 'mem', 'pid', 'name'])
              PopupMenuItem(value: s, child: Text(s.toUpperCase(),
                style: TextStyle(
                  color: sort == s ? Bk.accent : Bk.textSec,
                  fontSize: 12, letterSpacing: 1.5,
                  fontWeight: FontWeight.w700))),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh_outlined,
            color: Bk.textSec, size: 20),
          onPressed: onRefresh,
        ),
      ]),
    );
  }
}

class _ProcRow extends StatelessWidget {
  const _ProcRow({required this.p, required this.onTap});
  final ProcessInfo p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      style: GlassStyle.subtle,
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 10),
      child: Row(children: [
        SizedBox(width: 52,
          child: Text('${p.pid}',
            style: const TextStyle(color: Bk.textDim, fontSize: 12,
              fontFamily: 'monospace'))),
        Expanded(flex: 3, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name,
              style: const TextStyle(color: Bk.textPri, fontSize: 13,
                fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            if (p.user.isNotEmpty)
              Text(p.user,
                style: const TextStyle(color: Bk.textDim, fontSize: 10)),
          ])),
        SizedBox(width: 52,
          child: Text(
            p.cpuPct > 0 ? '${p.cpuPct.toStringAsFixed(1)}%' : '—',
            style: TextStyle(
              color: p.cpuPct > 50 ? Bk.warn
                   : p.cpuPct > 20 ? Bk.accent : Bk.textSec,
              fontSize: 12, fontWeight: FontWeight.w700,
              fontFamily: 'monospace'),
            textAlign: TextAlign.right)),
        SizedBox(width: 58,
          child: Text(
            '${p.memRssMb.toStringAsFixed(1)}M',
            style: TextStyle(
              color: p.memRssMb > 500 ? Bk.warn : Bk.textSec,
              fontSize: 12, fontFamily: 'monospace'),
            textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _SigBtn extends StatelessWidget {
  const _SigBtn(this.label, this.color, this.onTap);
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color.withValues(alpha:0.14),
      foregroundColor: color,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: color.withValues(alpha:0.38))),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    child: Text(label,
      style: const TextStyle(fontSize: 11, letterSpacing: 1.5,
        fontWeight: FontWeight.w800)),
  );
}

class _ProcSkeleton extends StatelessWidget {
  const _ProcSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      itemCount: 10,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, __) => const GlassCard(
        style: GlassStyle.subtle,
        radius: AppRadii.md,
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 14),
        child: Row(children: [
          _Skel(width: 48, height: 10),
          SizedBox(width: 10),
          Expanded(child: _Skel(width: double.infinity, height: 12)),
          SizedBox(width: 10),
          _Skel(width: 40, height: 10),
          SizedBox(width: 10),
          _Skel(width: 50, height: 10),
        ]),
      ),
    );
  }
}

class _Skel extends StatelessWidget {
  const _Skel({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Bk.glassSubtle,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

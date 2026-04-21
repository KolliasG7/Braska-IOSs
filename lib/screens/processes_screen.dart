// lib/screens/processes_screen.dart
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

class _ProcessesScreenState extends State<ProcessesScreen> with WidgetsBindingObserver {
  List<ProcessInfo> _procs = [];
  String _sort = 'cpu';
  bool _loading = true;
  String? _err;
  Timer? _timer;
  String _filter = '';
  DateTime? _lastUpdated;
  DateTime? _lastSuccess;

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
        content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
        backgroundColor: Bk.red,
      ));
    }
  }

  void _showActions(ProcessInfo p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Bk.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('PID ${p.pid}  ·  ${p.name}',
            style: const TextStyle(color: Bk.textPri, fontSize: 14,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(p.cmdline,
            style: const TextStyle(color: Bk.textDim, fontSize: 10),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _ActionBtn('SIGTERM', Bk.amber,
              () { Navigator.pop(context); _kill(p, 'SIGTERM'); })),
            const SizedBox(width: 10),
            Expanded(child: _ActionBtn('SIGKILL', Bk.red,
              () { Navigator.pop(context); _kill(p, 'SIGKILL'); })),
            const SizedBox(width: 10),
            Expanded(child: _ActionBtn('SIGSTOP', Bk.textSec,
              () { Navigator.pop(context); _kill(p, 'SIGSTOP'); })),
          ]),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL',
              style: TextStyle(color: Bk.textDim, letterSpacing: 2, fontSize: 11))),
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
    return Scaffold(
      backgroundColor: Bk.oled,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Text('PROCESSES'),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Bk.cyanGlow,
              borderRadius: BorderRadius.circular(10)),
            child: Text('${procs.length}',
              style: const TextStyle(color: Bk.cyan, fontSize: 10,
                fontWeight: FontWeight.w800)),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_outlined, color: Bk.textSec),
            color: Bk.surface1,
            onSelected: (v) {
              HapticFeedback.selectionClick();
              setState(() => _sort = v);
              _refresh();
            },
            itemBuilder: (_) => [
              for (final s in ['cpu', 'mem', 'pid', 'name'])
                PopupMenuItem(value: s, child: Text(s.toUpperCase(),
                  style: TextStyle(
                    color: _sort == s ? Bk.cyan : Bk.textSec,
                    fontSize: 11, letterSpacing: 1.5))),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 18),
            tooltip: 'Refresh processes',
            onPressed: _refresh),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _lastUpdated == null
                  ? 'Never updated'
                  : stale
                      ? 'Stale (${DateTime.now().difference(_lastUpdated!).inSeconds}s ago)'
                      : 'Updated ${DateTime.now().difference(_lastUpdated!).inSeconds}s ago',
              style: TextStyle(
                color: stale ? Bk.amber : Bk.textDim,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v),
            style: const TextStyle(color: Bk.textPri, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Filter by name, user, PID…',
              hintStyle: const TextStyle(color: Bk.textDim, fontSize: 12),
              prefixIcon: const Icon(Icons.search_outlined,
                color: Bk.textDim, size: 18),
              filled: true, fillColor: Bk.surface1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Bk.border)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Bk.border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Bk.cyan, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        // Headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: const [
            SizedBox(width: 52, child: Text('PID',
              style: TextStyle(color: Bk.textDim, fontSize: 9, letterSpacing: 1.5))),
            Expanded(flex: 3, child: Text('NAME',
              style: TextStyle(color: Bk.textDim, fontSize: 9, letterSpacing: 1.5))),
            SizedBox(width: 52, child: Text('CPU%',
              style: TextStyle(color: Bk.textDim, fontSize: 9, letterSpacing: 1.5),
              textAlign: TextAlign.right)),
            SizedBox(width: 58, child: Text('MEM',
              style: TextStyle(color: Bk.textDim, fontSize: 9, letterSpacing: 1.5),
              textAlign: TextAlign.right)),
          ]),
        ),
        const Divider(color: Bk.border, height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: Bk.white,
            backgroundColor: Bk.surface1,
            child: AnimatedSwitcher(
            duration: Duration(milliseconds: reduceMotion ? 1 : 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _loading
                ? const _ProcSkeleton(key: ValueKey('loading'))
                : _err != null
                    ? Center(
                        key: const ValueKey('error'),
                        child: Text(
                          _err!,
                          style: const TextStyle(color: Bk.red, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('list'),
                        itemCount: procs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Bk.border, height: 1),
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
    );
  }
}

class _ProcSkeleton extends StatelessWidget {
  const _ProcSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _SkelBox(width: 48, height: 10),
            SizedBox(width: 10),
            Expanded(child: _SkelBox(width: double.infinity, height: 12)),
            SizedBox(width: 10),
            _SkelBox(width: 40, height: 10),
            SizedBox(width: 10),
            _SkelBox(width: 50, height: 10),
          ],
        ),
      ),
    );
  }
}

class _SkelBox extends StatelessWidget {
  const _SkelBox({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Bk.surface1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Bk.border),
      ),
    );
  }
}

class _ProcRow extends StatelessWidget {
  const _ProcRow({required this.p, required this.onTap});
  final ProcessInfo p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(children: [
        SizedBox(width: 52,
          child: Text('${p.pid}',
            style: const TextStyle(color: Bk.textDim, fontSize: 11,
              fontFamily: 'monospace'))),
        Expanded(flex: 3, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name,
              style: const TextStyle(color: Bk.textPri, fontSize: 12,
                fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            if (p.user.isNotEmpty)
              Text(p.user,
                style: const TextStyle(color: Bk.textDim, fontSize: 9)),
          ])),
        SizedBox(width: 52,
          child: Text(
            p.cpuPct > 0 ? '${p.cpuPct.toStringAsFixed(1)}%' : '—',
            style: TextStyle(
              color: p.cpuPct > 50 ? Bk.amber
                   : p.cpuPct > 20 ? Bk.cyan : Bk.textSec,
              fontSize: 11, fontWeight: FontWeight.w700,
              fontFamily: 'monospace'),
            textAlign: TextAlign.right)),
        SizedBox(width: 58,
          child: Text(
            '${p.memRssMb.toStringAsFixed(1)}M',
            style: TextStyle(
              color: p.memRssMb > 500 ? Bk.amber : Bk.textSec,
              fontSize: 11, fontFamily: 'monospace'),
            textAlign: TextAlign.right)),
      ]),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(this.label, this.color, this.onTap);
  final String label; final Color color; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color.withOpacity(0.12),
      foregroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.35))),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    child: Text(label,
      style: const TextStyle(fontSize: 10, letterSpacing: 1.5,
        fontWeight: FontWeight.w800)),
  );
}

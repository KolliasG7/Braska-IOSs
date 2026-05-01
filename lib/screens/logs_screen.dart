// lib/screens/logs_screen.dart — live-ish systemd journal viewer
//
// Pushes from Settings → Diagnostics → View logs. Fetches the last N
// lines of `journalctl -u strawberry-manager` over GET /api/system/logs,
// renders them as a monospace scroll view, and lets the user change the
// line-count / priority filter and pull-to-refresh. Kept deliberately
// simple: not a tailing subscription, just a snapshot on demand, because
// the daemon's log volume is low and a WS stream would be overkill for
// an in-app "what's wrong on my PS4" tool.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/error_formatter.dart';
import '../theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  static const _lineOptions = <int>[100, 500, 1000, 2000];
  static const _priorityOptions = <_PriorityOption>[
    _PriorityOption(null, 'All'),
    _PriorityOption('3', 'Errors'),     // err
    _PriorityOption('4', 'Warnings+'),  // warning
    _PriorityOption('6', 'Info+'),      // info
    _PriorityOption('7', 'Debug'),      // debug
  ];

  int _lines = 500;
  String? _priority;
  List<String> _entries = const [];
  bool _loading = true;
  String? _err;
  DateTime? _lastUpdated;
  // Overlap guard: when a fetch is already running, new calls to
  // _load() set _pendingReload instead of firing a second HTTP
  // request. The finally-block drains the pending flag by issuing
  // exactly one more fetch with whatever the most recent _lines /
  // _priority values are — so rapid chip taps always end with a
  // request that matches the currently-selected filter, and
  // pull-to-refresh never silently no-ops.
  bool _inFlight = false;
  bool _pendingReload = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_inFlight) {
      _pendingReload = true;
      return;
    }
    _inFlight = true;
    if (mounted) setState(() { _loading = true; _err = null; });
    try {
      final api = context.read<ConnectionProvider>().api;
      if (api == null) {
        throw StateError('Not connected.');
      }
      final data = await api.fetchLogs(lines: _lines, priority: _priority);
      final raw = (data['lines'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _entries = raw.whereType<String>().toList(growable: false);
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = ErrorFormatter.userMessage(e);
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } finally {
      _inFlight = false;
      // Drain one queued request if any filter changed / pull-to-
      // refresh was requested while we were busy. We don't chain
      // further than one extra hop: coalescing multiple queued
      // requests into the single re-fetch is the whole point, and
      // the current _lines/_priority fields are already the latest
      // values the user wanted.
      if (_pendingReload && mounted) {
        _pendingReload = false;
        // Intentionally unawaited: this is a fire-and-forget drain
        // from inside our own finally-block. The awaiting caller
        // (usually RefreshIndicator) only needs its in-flight
        // Future to complete for its spinner to dismiss.
        unawaited(_load());
      }
    }
  }

  void _setLines(int n) {
    if (n == _lines) return;
    HapticFeedback.selectionClick();
    setState(() => _lines = n);
    _load();
  }

  void _setPriority(String? p) {
    if (p == _priority) return;
    HapticFeedback.selectionClick();
    setState(() => _priority = p);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Daemon logs'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_outlined),
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm,
                  AppSpacing.lg, AppSpacing.sm),
                child: _FilterBar(
                  lines: _lines,
                  priority: _priority,
                  lineOptions: _lineOptions,
                  priorityOptions: _priorityOptions,
                  onLines: _setLines,
                  onPriority: _setPriority,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _body(),
                ),
              ),
              if (_lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 4, AppSpacing.lg, AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_entries.length} entries · updated '
                      '${_hhmmss(_lastUpdated!)}',
                      style: T.caption.copyWith(color: Bk.textDim),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_err != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.error_outline, color: Bk.danger, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Couldn\u2019t load logs',
                      style: T.title.copyWith(color: Bk.danger)),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(_err!, style: T.mono.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (_entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Text('No log entries for this filter.',
              style: T.body.copyWith(color: Bk.textDim)),
          ),
        ],
      );
    }
    // One glass card with a monospace column. SelectableText so the user
    // can long-press to copy a specific line when something weird shows
    // up and they want to paste it into a bug report.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              _entries.join('\n'),
              style: T.mono.copyWith(fontSize: 11, height: 1.35),
            ),
          ),
        ),
      ],
    );
  }

  static String _hhmmss(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';
}

class _PriorityOption {
  const _PriorityOption(this.code, this.label);
  final String? code;
  final String  label;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.lines,
    required this.priority,
    required this.lineOptions,
    required this.priorityOptions,
    required this.onLines,
    required this.onPriority,
  });

  final int                     lines;
  final String?                 priority;
  final List<int>               lineOptions;
  final List<_PriorityOption>   priorityOptions;
  final ValueChanged<int>       onLines;
  final ValueChanged<String?>   onPriority;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lines', style: T.caption.copyWith(color: Bk.textDim)),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final n in lineOptions)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text('$n'),
                  selected: n == lines,
                  onSelected: (_) => onLines(n),
                ),
              ),
          ]),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Priority', style: T.caption.copyWith(color: Bk.textDim)),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final p in priorityOptions)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(p.label),
                  selected: p.code == priority,
                  onSelected: (_) => onPriority(p.code),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

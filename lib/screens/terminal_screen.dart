// lib/screens/terminal_screen.dart — Real PTY terminal
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/terminal_service.dart';
import '../theme.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, this.embedded = false});

  /// When true, no Scaffold/background is rendered — the screen assumes it
  /// is stacked inside the DashboardScreen shell.
  final bool embedded;

  @override State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  TerminalService? _term;
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  final _lines      = <String>[];
  StreamSubscription? _outSub;
  StreamSubscription? _stateSub;
  bool _connected = false;
  bool _initFailed = false;
  String _partial = '';

  /// Send a raw byte sequence to the pty and keep focus on the input so
  /// the iOS soft keyboard stays up while the user chains accessory keys.
  void _sendRaw(String bytes) {
    if (!_connected || _term == null) return;
    HapticFeedback.selectionClick();
    _term!.sendInput(bytes);
    if (!_inputFocus.hasFocus) _inputFocus.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cp = context.read<ConnectionProvider>();
    if (cp.api == null) {
      _initFailed = true;
      return;
    }
    _term = TerminalService(cp.api!.baseUrl, token: cp.token);
    _outSub   = _term!.output.listen(_onOutput);
    _stateSub = _term!.state.listen((s) {
      if (mounted) setState(() => _connected = s == TermState.connected);
    });
    _term!.connect();
  }

  void _onOutput(String text) {
    final clean = text
        .replaceAll(RegExp(r'\x1B\][^\x07]*\x07'), '')
        .replaceAll(RegExp(r'\x1B\][^\x1B]*\x1B\\'), '')
        .replaceAll(RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    setState(() {
      _partial += clean;
      final parts = _partial.split('\n');
      _partial = parts.last;
      for (int i = 0; i < parts.length - 1; i++) {
        if (parts[i].isNotEmpty || _lines.isNotEmpty) _lines.add(parts[i]);
      }
      if (_lines.length > 1000) _lines.removeRange(0, _lines.length - 1000);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendLine(String text) {
    if (text.isEmpty) {
      _term?.sendInput('\n');
      return;
    }
    _term?.sendInput('$text\n');
    _inputCtrl.clear();
  }

  void _clear() {
    HapticFeedback.selectionClick();
    setState(() { _lines.clear(); _partial = ''; });
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return _ConnectionError(embedded: widget.embedded);
    }

    final body = Column(children: [
      _Header(
        connected: _connected,
        onClear: _clear,
        embedded: widget.embedded,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: (_lines.isEmpty && _partial.isEmpty)
                ? _IdlePrompt(connected: _connected)
                : ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _lines.length + (_partial.isNotEmpty ? 1 : 0),
                    itemBuilder: (_, i) {
                      final text = i < _lines.length ? _lines[i] : _partial;
                      return Text(text, style: T.mono);
                    },
                  ),
          ),
        ),
      ),
      // Keyboard accessory bar — only rendered while the iOS soft keyboard
      // is actually on screen (viewInsets.bottom > 0) so it doesn't steal
      // vertical space when the terminal is idle. Chips send raw pty
      // sequences so users get Tab/Esc/arrows/Ctrl-C-D-Z without a
      // hardware keyboard.
      if (MediaQuery.of(context).viewInsets.bottom > 0)
        _ShellKeyboardBar(
          enabled: _connected,
          onSend: _sendRaw,
        ),
      Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg,
          widget.embedded
              ? MediaQuery.of(context).viewInsets.bottom + 100
              : MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: _InputRow(
          controller: _inputCtrl,
          focusNode: _inputFocus,
          connected: _connected,
          onSubmit: _sendLine,
        ),
      ),
    ]);

    if (widget.embedded) return body;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: body),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_term != null && _term!.currentState != TermState.connected) {
        _term!.connect();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _outSub?.cancel();
    _stateSub?.cancel();
    _term?.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }
}

class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            r'$ ',
            style: T.mono.copyWith(
              color: Bk.accent.withOpacity(0.55),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            connected
                ? 'session idle · type a command to begin'
                : 'connecting…',
            style: T.mono.copyWith(
              color: Bk.textSec.withOpacity(0.55),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.embedded});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      _Header(
        connected: false,
        onClear: () {},
        embedded: embedded,
      ),
      const Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: GlassCard(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: Text(
                'Unable to connect: API not available',
                style: TextStyle(color: Bk.danger, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    ]);

    if (embedded) return body;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: body),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.connected,
    required this.onClear,
    required this.embedded,
  });
  final bool connected;
  final VoidCallback onClear;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final (color, label) = connected
        ? (Bk.success, 'LIVE')
        : (Bk.warn, 'CONNECTING');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
      child: Row(children: [
        if (!embedded) ...[
          GlassIconButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        // No per-tab H1: the bottom nav already tells you where you are,
        // and two H1s ("Shell"/"Files") rendered through each other is
        // the ghost-text artifact that killed the old cross-fade.
        GlassPill(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              color: color, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ]),
        ),
        const Spacer(),
        GlassIconButton(
          icon: Icons.cleaning_services_outlined,
          onPressed: onClear,
          tooltip: 'Clear terminal',
        ),
      ]),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.focusNode,
    required this.connected,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool connected;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 6),
      radius: AppRadii.pill,
      child: Row(children: [
        const Text(r'$', style: TextStyle(
          color: Bk.accent, fontSize: 14,
          fontFamily: 'monospace', fontWeight: FontWeight.w900)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: connected,
          style: const TextStyle(
            color: Bk.textPri, fontFamily: 'monospace', fontSize: 13),
          cursorColor: Bk.accent,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'command…',
            hintStyle: TextStyle(color: Bk.textDim, fontSize: 12),
            isDense: true,
          ),
          onSubmitted: onSubmit,
          textInputAction: TextInputAction.send,
        )),
        Semantics(
          label: 'Send command',
          button: true,
          child: IconButton(
            onPressed: connected ? () => onSubmit(controller.text) : null,
            icon: Icon(Icons.send_rounded,
              color: connected ? Bk.accent : Bk.textDim, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ── Shell keyboard accessory bar ──────────────────────────────────────────
// Thin horizontally-scrollable strip above the input field that renders
// while the iOS soft keyboard is visible. Each chip writes a raw byte
// sequence straight to the pty stream, since iOS's soft keyboard omits
// Tab/Esc/Ctrl/arrows. Disabled chips are rendered muted but never
// consume taps so they don't accidentally dismiss the keyboard.

class _ShellKeyboardBar extends StatelessWidget {
  const _ShellKeyboardBar({
    required this.enabled,
    required this.onSend,
  });
  final bool enabled;
  final void Function(String bytes) onSend;

  @override
  Widget build(BuildContext context) {
    // (label, byte sequence, optional narrow-width flag)
    final keys = <(String, String, bool)>[
      ('Tab',   '\t',       false),
      ('Esc',   '\x1b',     false),
      ('Ctrl+C','\x03',     false),
      ('Ctrl+D','\x04',     false),
      ('Ctrl+Z','\x1a',     false),
      ('\u2191','\x1b[A',   true),
      ('\u2193','\x1b[B',   true),
      ('\u2190','\x1b[D',   true),
      ('\u2192','\x1b[C',   true),
    ];
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
      decoration: BoxDecoration(
        color: Bk.surface1.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Bk.glassBorder),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 4),
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (label, bytes, narrow) = keys[i];
          return _KbChip(
            label: label,
            narrow: narrow,
            enabled: enabled,
            onTap: () => onSend(bytes),
          );
        },
      ),
    );
  }
}

class _KbChip extends StatelessWidget {
  const _KbChip({
    required this.label,
    required this.narrow,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool narrow;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: BoxConstraints(minWidth: narrow ? 36 : 48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Bk.glassDefault.withOpacity(0.6),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: Bk.glassBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? Bk.textPri : Bk.textDim,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

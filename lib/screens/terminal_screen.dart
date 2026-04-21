// lib/screens/terminal_screen.dart — Real PTY terminal
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/terminal_service.dart';
import '../theme.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> with WidgetsBindingObserver {
  late TerminalService _term;
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _buffer     = StringBuffer();
  final _lines      = <String>[];
  StreamSubscription? _outSub;
  StreamSubscription? _stateSub;
  bool _connected   = false;

  // Pending partial line
  String _partial = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cp = context.read<ConnectionProvider>();
    _term = TerminalService(cp.api!.baseUrl, token: cp.token);
    _outSub   = _term.output.listen(_onOutput);
    _stateSub = _term.state.listen((s) {
      if (mounted) setState(() => _connected = s == TermState.connected);
    });
    _term.connect();
  }

  void _onOutput(String text) {
    // Strip ANSI escape codes for simple rendering
    final clean = text.replaceAll(RegExp(r'\x1B\][^\x07]*\x07'), '')
                       .replaceAll(RegExp(r'\x1B\][^\x1B]*\x1B\\'), '')
                       .replaceAll(RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]'), '')
                       .replaceAll('\r\n', '\n')
                       .replaceAll('\r', '\n');

    setState(() {
      _partial += clean;
      // Split on newlines, keep partial last line
      final parts = _partial.split('\n');
      _partial = parts.last;
      for (int i = 0; i < parts.length - 1; i++) {
        if (parts[i].isNotEmpty || _lines.isNotEmpty) {
          _lines.add(parts[i]);
        }
      }
      // Cap buffer
      if (_lines.length > 1000) _lines.removeRange(0, _lines.length - 1000);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut);
      }
    });
  }

  void _sendLine(String text) {
    if (text.isEmpty) {
      _term.sendInput('\n');
      return;
    }
    _term.sendInput('$text\n');
    _inputCtrl.clear();
  }

  void _sendCtrl(String key) {
    // Ctrl+C = 0x03, Ctrl+D = 0x04, Ctrl+L = 0x0C, Tab = 0x09
    final map = {'C': '\x03', 'D': '\x04', 'L': '\x0C', 'Z': '\x1A'};
    final s = map[key];
    if (s != null) _term.sendInput(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bk.oled,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Text('SHELL'),
          const SizedBox(width: 10),
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connected ? Bk.white : Bk.textDim,
            ),
          ),
          const SizedBox(width: 6),
          Text(_connected ? 'LIVE' : 'CONNECTING…',
            style: TextStyle(
              color: _connected ? Bk.textSec : Bk.textDim,
              fontSize: 9, letterSpacing: 2)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined, size: 16),
            onPressed: () => setState(() { _lines.clear(); _partial = ''; }),
            tooltip: 'Clear terminal'),
        ],
      ),
      body: Column(children: [

        // Terminal output
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF020305),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Bk.border),
            ),
            child: ListView.builder(
              controller: _scrollCtrl,
              itemCount: _lines.length + (_partial.isNotEmpty ? 1 : 0),
              itemBuilder: (_, i) {
                final text = i < _lines.length ? _lines[i] : _partial;
                return Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Input row
        Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10,
            MediaQuery.of(context).viewInsets.bottom + 110),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Bk.surface1,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Bk.border),
              ),
              child: const Text(r'$',
                style: TextStyle(
                  color: Bk.white, fontSize: 14,
                  fontFamily: 'monospace', fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _inputCtrl,
              enabled: _connected,
              style: const TextStyle(
                color: Bk.textPri, fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'command…',
                hintStyle: TextStyle(color: Bk.textDim, fontSize: 12),
                isDense: true,
              ),
              onSubmitted: _sendLine,
              textInputAction: TextInputAction.send,
            )),
            Semantics(
              label: 'Send command',
              button: true,
              child: GestureDetector(
                onTap: () => _sendLine(_inputCtrl.text),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.send_rounded,
                    color: _connected ? Bk.white : Bk.textDim, size: 18)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_term.currentState != TermState.connected) {
        _term.connect();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _outSub?.cancel();
    _stateSub?.cancel();
    _term.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

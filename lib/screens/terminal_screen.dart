// lib/screens/terminal_screen.dart - Real terminal emulator via xterm
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';
import '../providers/connection_provider.dart';
import '../services/terminal_service.dart';
import '../theme.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, this.embedded = false});

  /// When true, no Scaffold/background is rendered - screen is hosted inside
  /// Dashboard shell.
  final bool embedded;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  TerminalService? _term;
  late Terminal _uiTerminal;
  final _uiController = TerminalController();
  final _terminalFocus = FocusNode();

  StreamSubscription? _outSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _errorSub;

  bool _connected = false;
  bool _initFailed = false;
  String? _lastError;
  String _hostLabel = 'host';
  bool _showReconnectBanner = false;

  double _fontSize = 13;
  double _terminalOpacity = 1;
  TerminalCursorType _cursorType = TerminalCursorType.block;
  String _themePreset = 'midnight';

  bool _ctrlSticky = false;
  bool _altSticky = false;

  bool get _isMobileTarget {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _initUiTerminal() {
    _uiTerminal = Terminal(maxLines: _isMobileTarget ? 2500 : 8000);
    _uiTerminal.onOutput = (data) {
      _term?.sendInput(data);
    };
    _uiTerminal.onResize = (w, h, _, __) {
      _term?.sendResize(w, h);
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTerminalPrefs();
    _initUiTerminal();

    final cp = context.read<ConnectionProvider>();
    if (cp.api == null) {
      _initFailed = true;
      return;
    }

    _term = TerminalService(cp.api!.baseUrl, token: cp.token);
    _hostLabel = _extractHost(cp.api!.baseUrl);
    _outSub = _term!.output.listen((data) {
      _uiTerminal.write(data);
    });
    _stateSub = _term!.state.listen((s) {
      if (!mounted) return;
      setState(() {
        _connected = s == TermState.connected;
        _showReconnectBanner =
            s == TermState.disconnected && (_lastError?.isNotEmpty ?? false);
      });
    });
    _errorSub = _term!.errors.listen((msg) {
      if (!mounted) return;
      setState(() => _lastError = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });

    _term!.connect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _terminalFocus.requestFocus();
    });
  }

  void _sendBytes(String data) {
    if (!_connected) return;
    _term?.sendInput(data);
    _terminalFocus.requestFocus();
  }

  String _extractHost(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host.isNotEmpty ? uri.host : baseUrl;
    } catch (_) {
      return baseUrl;
    }
  }

  Future<void> _loadTerminalPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSize = p.getDouble('term.fontSize') ?? 13;
      _terminalOpacity = p.getDouble('term.opacity') ?? 1;
      _themePreset = p.getString('term.theme') ?? 'midnight';
      final cursor = p.getString('term.cursor') ?? 'block';
      _cursorType = _cursorFromString(cursor);
    });
  }

  Future<void> _saveTerminalPrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('term.fontSize', _fontSize);
    await p.setDouble('term.opacity', _terminalOpacity);
    await p.setString('term.theme', _themePreset);
    await p.setString('term.cursor', _cursorToString(_cursorType));
  }

  TerminalCursorType _cursorFromString(String value) {
    switch (value) {
      case 'underline':
        return TerminalCursorType.underline;
      case 'verticalBar':
        return TerminalCursorType.verticalBar;
      default:
        return TerminalCursorType.block;
    }
  }

  String _cursorToString(TerminalCursorType value) {
    switch (value) {
      case TerminalCursorType.underline:
        return 'underline';
      case TerminalCursorType.verticalBar:
        return 'verticalBar';
      case TerminalCursorType.block:
        return 'block';
    }
  }

  void _switchToZsh() {
    if (!_connected) return;
    _sendBytes(
      r'if command -v zsh >/dev/null 2>&1; then exec env -u PS1 TERM=xterm-256color COLORTERM=truecolor SHELL="$(command -v zsh)" zsh -il; else echo "zsh not found"; fi'
      '\n',
    );
  }

  void _reloadZshRc() {
    if (!_connected) return;
    _sendBytes(
      r'if [ -n "$ZSH_VERSION" ] && [ -f ~/.zshrc ]; then source ~/.zshrc; else echo "zshrc not available"; fi'
      '\n',
    );
  }

  Future<void> _pasteFromClipboard() async {
    if (!_connected) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _sendBytes(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pasted from clipboard'),
        duration: Duration(milliseconds: 900),
      ));
    }
  }

  Future<void> _copySelection() async {
    final selection = _uiController.selection;
    if (selection == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No selection to copy'),
        duration: Duration(milliseconds: 900),
      ));
      return;
    }
    final text = _uiTerminal.buffer.getText(selection);
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _uiController.clearSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Copied selection'),
      duration: Duration(milliseconds: 900),
    ));
  }

  String _applyStickyModifiers(String ch) {
    var out = ch;
    if (_ctrlSticky && ch.isNotEmpty) {
      final code = ch.toUpperCase().codeUnitAt(0);
      if (code >= 64 && code <= 95) {
        out = String.fromCharCode(code - 64);
      }
      _ctrlSticky = false;
    }
    if (_altSticky) {
      out = '\x1b$out';
      _altSticky = false;
    }
    return out;
  }

  void _sendKey(String bytes) {
    _sendBytes(_applyStickyModifiers(bytes));
    if (mounted) setState(() {});
  }

  Future<void> _openMobileKeyMenu() async {
    if (!_isMobileTarget) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return GlassSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terminal Shortcuts',
                style: TextStyle(
                  color: Bk.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ToggleChip(
                    label: 'Ctrl',
                    active: _ctrlSticky,
                    onTap: () {
                      setState(() => _ctrlSticky = !_ctrlSticky);
                      setSheetState(() {});
                    },
                  ),
                  _ToggleChip(
                    label: 'Alt',
                    active: _altSticky,
                    onTap: () {
                      setState(() => _altSticky = !_altSticky);
                      setSheetState(() {});
                    },
                  ),
                  _ShortcutChip(label: 'Tab', bytes: '\t', onSend: _sendKey),
                  _ShortcutChip(label: 'Esc', bytes: '\x1b', onSend: _sendKey),
                  _ShortcutChip(label: 'Ctrl+C', bytes: '\x03', onSend: _sendKey),
                  _ShortcutChip(label: 'Ctrl+D', bytes: '\x04', onSend: _sendKey),
                  _ShortcutChip(label: 'Ctrl+Z', bytes: '\x1a', onSend: _sendKey),
                  _ShortcutChip(label: 'Ctrl+L', bytes: '\x0c', onSend: _sendKey),
                  _ShortcutChip(label: 'Up', bytes: '\x1b[A', onSend: _sendKey),
                  _ShortcutChip(label: 'Down', bytes: '\x1b[B', onSend: _sendKey),
                  _ShortcutChip(label: 'Left', bytes: '\x1b[D', onSend: _sendKey),
                  _ShortcutChip(label: 'Right', bytes: '\x1b[C', onSend: _sendKey),
                  _ActionChip(label: 'Switch to zsh', onTap: _switchToZsh),
                  _ActionChip(label: 'Reload zshrc', onTap: _reloadZshRc),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Desktop: Ctrl+C interrupt, Ctrl+V paste, Ctrl+Shift+C copy selection.',
                style: TextStyle(color: Bk.textDim, fontSize: 11),
              ),
            ],
          ),
        );
      }),
    );
    _terminalFocus.requestFocus();
  }

  TerminalTheme _currentTheme() {
    switch (_themePreset) {
      case 'amber':
        return const TerminalTheme(
          cursor: Color(0xFFFFD166),
          selection: Color(0x55F59E0B),
          foreground: Color(0xFFF8EED1),
          background: Color(0xFF14110F),
          black: Color(0xFF1B1B1B),
          red: Color(0xFFFF6B6B),
          green: Color(0xFF95E06C),
          yellow: Color(0xFFFFD166),
          blue: Color(0xFF6EC6FF),
          magenta: Color(0xFFC792EA),
          cyan: Color(0xFF5DE4C7),
          white: Color(0xFFF8EED1),
          brightBlack: Color(0xFF6B7280),
          brightRed: Color(0xFFFF8787),
          brightGreen: Color(0xFFB4F38A),
          brightYellow: Color(0xFFFFE08A),
          brightBlue: Color(0xFF9BD6FF),
          brightMagenta: Color(0xFFD7AAFF),
          brightCyan: Color(0xFF88F0DB),
          brightWhite: Color(0xFFFFFFFF),
          searchHitBackground: Color(0x55F59E0B),
          searchHitBackgroundCurrent: Color(0x88F59E0B),
          searchHitForeground: Color(0xFFF8EED1),
        );
      case 'matrix':
        return const TerminalTheme(
          cursor: Color(0xFF4ADE80),
          selection: Color(0x5534D399),
          foreground: Color(0xFFA7F3D0),
          background: Color(0xFF041108),
          black: Color(0xFF041108),
          red: Color(0xFF4ADE80),
          green: Color(0xFF4ADE80),
          yellow: Color(0xFF86EFAC),
          blue: Color(0xFF34D399),
          magenta: Color(0xFF6EE7B7),
          cyan: Color(0xFFA7F3D0),
          white: Color(0xFFA7F3D0),
          brightBlack: Color(0xFF14532D),
          brightRed: Color(0xFF86EFAC),
          brightGreen: Color(0xFFBBF7D0),
          brightYellow: Color(0xFFD9F99D),
          brightBlue: Color(0xFF6EE7B7),
          brightMagenta: Color(0xFF6EE7B7),
          brightCyan: Color(0xFFA7F3D0),
          brightWhite: Color(0xFFE5FFF1),
          searchHitBackground: Color(0x5534D399),
          searchHitBackgroundCurrent: Color(0x8834D399),
          searchHitForeground: Color(0xFFE5FFF1),
        );
      case 'midnight':
      default:
        return const TerminalTheme(
          cursor: Color(0xFF6EE7B7),
          selection: Color(0x5538BDF8),
          foreground: Color(0xFFE5E7EB),
          background: Color(0xFF0A0F1D),
          black: Color(0xFF111827),
          red: Color(0xFFEF4444),
          green: Color(0xFF22C55E),
          yellow: Color(0xFFF59E0B),
          blue: Color(0xFF60A5FA),
          magenta: Color(0xFFB794F4),
          cyan: Color(0xFF22D3EE),
          white: Color(0xFFE5E7EB),
          brightBlack: Color(0xFF4B5563),
          brightRed: Color(0xFFF87171),
          brightGreen: Color(0xFF4ADE80),
          brightYellow: Color(0xFFFBBF24),
          brightBlue: Color(0xFF93C5FD),
          brightMagenta: Color(0xFFD8B4FE),
          brightCyan: Color(0xFF67E8F9),
          brightWhite: Color(0xFFFFFFFF),
          searchHitBackground: Color(0x55F59E0B),
          searchHitBackgroundCurrent: Color(0x88F59E0B),
          searchHitForeground: Color(0xFFE5E7EB),
        );
    }
  }

  Future<void> _openTerminalSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 760),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF121826),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: const Color(0xFF2A3448)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: const Color(0xFF67D2FF),
                  inactiveTrackColor: const Color(0xFF2B3852),
                  thumbColor: const Color(0xFFE6F7FF),
                  overlayColor: const Color(0x3367D2FF),
                  trackHeight: 4,
                ),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Terminal Settings',
                  style: TextStyle(
                      color: Bk.textPri,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tune look and readability',
                  style: TextStyle(color: Bk.textDim, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.md),
                _SettingCard(
                  title: 'Typography',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Font size ${_fontSize.toStringAsFixed(0)}',
                          style: const TextStyle(color: Bk.textPri)),
                      Slider(
                        value: _fontSize,
                        min: 11,
                        max: 18,
                        divisions: 7,
                        onChanged: (v) {
                          setState(() => _fontSize = v);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SettingCard(
                  title: 'Display',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Opacity ${(_terminalOpacity * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Bk.textPri)),
                      Slider(
                        value: _terminalOpacity,
                        min: 0.8,
                        max: 1,
                        divisions: 4,
                        onChanged: (v) {
                          setState(() => _terminalOpacity = v);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text('Cursor',
                          style: TextStyle(
                              color: Bk.textSec,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _SettingOption(
                            label: 'Block',
                            active: _cursorType == TerminalCursorType.block,
                            onTap: () {
                              setState(
                                  () => _cursorType = TerminalCursorType.block);
                              setSheetState(() {});
                            }),
                        _SettingOption(
                            label: 'Beam',
                            active:
                                _cursorType == TerminalCursorType.verticalBar,
                            onTap: () {
                              setState(() =>
                                  _cursorType = TerminalCursorType.verticalBar);
                              setSheetState(() {});
                            }),
                        _SettingOption(
                            label: 'Underline',
                            active: _cursorType == TerminalCursorType.underline,
                            onTap: () {
                              setState(() =>
                                  _cursorType = TerminalCursorType.underline);
                              setSheetState(() {});
                            }),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SettingCard(
                  title: 'Theme',
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    _SettingOption(
                        label: 'Midnight',
                        active: _themePreset == 'midnight',
                        onTap: () {
                          setState(() => _themePreset = 'midnight');
                          setSheetState(() {});
                        }),
                    _SettingOption(
                        label: 'Amber',
                        active: _themePreset == 'amber',
                        onTap: () {
                          setState(() => _themePreset = 'amber');
                          setSheetState(() {});
                        }),
                    _SettingOption(
                        label: 'Matrix',
                        active: _themePreset == 'matrix',
                        onTap: () {
                          setState(() => _themePreset = 'matrix');
                          setSheetState(() {});
                        }),
                  ]),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF8FCFFF))),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF67C5EB),
                        foregroundColor: const Color(0xFF052231),
                      ),
                      onPressed: () async {
                        await _saveTerminalPrefs();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                )
              ],
                ),
              ),
            ),
          ),
        );
      }),
    );
    _terminalFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return _ConnectionError(embedded: widget.embedded);
    }

    final w = MediaQuery.of(context).size.width;
    final compact = w < 900;
    final sidePad = compact ? AppSpacing.md : AppSpacing.lg;
    final liveFont = compact ? (_fontSize - 1).clamp(11, 18) : _fontSize;

    final body = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
          _pasteFromClipboard();
        },
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): () => _sendBytes('\x03'),
        const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): () {
          _copySelection();
        },
      },
      child: Column(children: [
      _Header(
        connected: _connected,
        onPaste: _pasteFromClipboard,
        onCopy: _copySelection,
        onSettings: _openTerminalSettings,
        onKeys: _openMobileKeyMenu,
        showKeys: _isMobileTarget,
        embedded: widget.embedded,
        hostLabel: _hostLabel,
        shellLabel: _themePreset,
      ),
      if (_showReconnectBanner)
        _ReconnectBanner(
          error: _lastError ?? 'Connection lost',
          onRetry: () => _term?.connect(),
        ),
      Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, AppSpacing.sm),
          child: _TerminalWindowFrame(
            connected: _connected,
            opacity: _terminalOpacity,
            child: !_connected && _lastError != null
                ? _IdlePrompt(connected: _connected, error: _lastError)
                : GestureDetector(
                    onLongPress: _copySelection,
                    child: TerminalView(
                      _uiTerminal,
                      controller: _uiController,
                      focusNode: _terminalFocus,
                      autofocus: true,
                      onTapUp: (_, __) => _terminalFocus.requestFocus(),
                      backgroundOpacity: _terminalOpacity,
                      deleteDetection: true,
                      readOnly: !_connected,
                      cursorType: _cursorType,
                      hardwareKeyboardOnly: !_isMobileTarget,
                      keyboardType: TextInputType.multiline,
                      textStyle: TerminalStyle(
                        fontSize: liveFont.toDouble(),
                        fontFamily: 'monospace',
                      ),
                      theme: _currentTheme(),
                    ),
                  ),
          ),
        ),
      ),
      if (_isMobileTarget && MediaQuery.of(context).viewInsets.bottom > 0)
        _ShellKeyboardBar(
          enabled: _connected,
          ctrlSticky: _ctrlSticky,
          altSticky: _altSticky,
          onToggleCtrl: () => setState(() => _ctrlSticky = !_ctrlSticky),
          onToggleAlt: () => setState(() => _altSticky = !_altSticky),
          onSend: _sendKey,
        ),
      SizedBox(
        height: widget.embedded
            ? MediaQuery.of(context).viewInsets.bottom + 100
            : MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
    ]),
    );

    if (widget.embedded) return body;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: body,
            ),
          ),
        ),
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
    _errorSub?.cancel();
    _term?.dispose();
    _terminalFocus.dispose();
    super.dispose();
  }
}

class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt({required this.connected, this.error});
  final bool connected;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            r'$ ',
            style: T.mono.copyWith(
              color: Bk.accent.withValues(alpha: 0.55),
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Text(
              connected ? 'session idle - type a command to begin' : (error ?? 'connecting...'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.mono.copyWith(
                color: connected ? Bk.textSec.withValues(alpha: 0.55) : Bk.warn,
                fontStyle: FontStyle.italic,
              ),
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
        onPaste: () {},
        onCopy: () {},
        onSettings: () {},
        onKeys: () {},
        showKeys: false,
        embedded: embedded,
        hostLabel: '-',
        shellLabel: '-',
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
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalWindowFrame extends StatelessWidget {
  const _TerminalWindowFrame({
    required this.connected,
    required this.opacity,
    required this.child,
  });

  final bool connected;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withValues(alpha: opacity.clamp(0.8, 1.0)),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: connected
              ? const Color(0xFF6EE7B7).withValues(alpha: 0.25)
              : const Color(0xFF94A3B8).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg - 1),
        child: Column(
          children: [
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.98),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF334155).withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  _dot(const Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  _dot(const Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  _dot(const Color(0xFF22C55E)),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    connected ? 'Terminal Session' : 'Terminal (offline)',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.connected,
    required this.onPaste,
    required this.onCopy,
    required this.onSettings,
    required this.onKeys,
    required this.showKeys,
    required this.embedded,
    required this.hostLabel,
    required this.shellLabel,
  });
  final bool connected;
  final VoidCallback onPaste;
  final VoidCallback onCopy;
  final VoidCallback onSettings;
  final VoidCallback onKeys;
  final bool showKeys;
  final bool embedded;
  final String hostLabel;
  final String shellLabel;

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
        GlassPill(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ContextPill(
          text: '$hostLabel | $shellLabel',
          connected: connected,
        ),
        const Spacer(),
        GlassIconButton(
          icon: Icons.copy_all_outlined,
          onPressed: connected ? onCopy : null,
          tooltip: 'Copy selected',
        ),
        const SizedBox(width: AppSpacing.sm),
        GlassIconButton(
          icon: Icons.content_paste_outlined,
          onPressed: connected ? onPaste : null,
          tooltip: 'Paste',
        ),
        const SizedBox(width: AppSpacing.sm),
        GlassIconButton(
          icon: Icons.tune,
          onPressed: onSettings,
          tooltip: 'Terminal settings',
        ),
        if (showKeys) ...[
          const SizedBox(width: AppSpacing.sm),
          GlassIconButton(
            icon: Icons.keyboard_command_key_outlined,
            onPressed: connected ? onKeys : null,
            tooltip: 'Shortcuts',
          ),
        ],
      ]),
    );
  }
}

class _ShellKeyboardBar extends StatelessWidget {
  const _ShellKeyboardBar({
    required this.enabled,
    required this.ctrlSticky,
    required this.altSticky,
    required this.onToggleCtrl,
    required this.onToggleAlt,
    required this.onSend,
  });
  final bool enabled;
  final bool ctrlSticky;
  final bool altSticky;
  final VoidCallback onToggleCtrl;
  final VoidCallback onToggleAlt;
  final void Function(String bytes) onSend;

  @override
  Widget build(BuildContext context) {
    final keys = <(String, String, bool)>[
      ('Tab', '\t', false),
      ('Esc', '\x1b', false),
      ('Ctrl+C', '\x03', false),
      ('Ctrl+D', '\x04', false),
      ('Ctrl+Z', '\x1a', false),
      ('Up', '\x1b[A', true),
      ('Down', '\x1b[B', true),
      ('Left', '\x1b[D', true),
      ('Right', '\x1b[C', true),
    ];
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
      decoration: BoxDecoration(
        color: Bk.surface1.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Bk.glassBorder),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        itemCount: keys.length + 2,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _ToggleKeyChip(
              label: 'Ctrl',
              active: ctrlSticky,
              enabled: enabled,
              onTap: onToggleCtrl,
            );
          }
          if (i == 1) {
            return _ToggleKeyChip(
              label: 'Alt',
              active: altSticky,
              enabled: enabled,
              onTap: onToggleAlt,
            );
          }
          final (label, bytes, narrow) = keys[i - 2];
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

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFFCA5A5), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            error,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry'))
      ]),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.text, required this.connected});

  final String text;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Bk.surface1.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: connected ? Bk.success.withValues(alpha: 0.25) : Bk.glassBorder,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Bk.textSec,
          fontSize: 10,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2232),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: const Color(0xFF2F3A50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Bk.textSec,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SettingOption extends StatelessWidget {
  const _SettingOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Bk.accent.withValues(alpha: 0.22)
              : const Color(0xFF1B2236).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: active ? Bk.accent : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Bk.accent : Bk.textPri,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Bk.accent.withValues(alpha: 0.2)
              : Bk.glassSubtle.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: active ? Bk.accent : Bk.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Bk.accent : Bk.textPri,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ToggleKeyChip extends StatelessWidget {
  const _ToggleKeyChip({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 46),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active
                ? Bk.accent.withValues(alpha: 0.22)
                : Bk.glassDefault.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: active ? Bk.accent : Bk.glassBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Bk.accent : Bk.textPri,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.label,
    required this.bytes,
    required this.onSend,
  });

  final String label;
  final String bytes;
  final void Function(String bytes) onSend;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: () {
        HapticFeedback.selectionClick();
        onSend(bytes);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Bk.glassSubtle,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: Bk.glassBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Bk.textPri,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Bk.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: Bk.accent.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Bk.accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
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
              color: Bk.glassDefault.withValues(alpha: 0.6),
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

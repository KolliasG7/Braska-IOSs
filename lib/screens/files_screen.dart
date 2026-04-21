// lib/screens/files_screen.dart — File browser, upload, download
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.api, this.embedded = false});
  final ApiService api;

  /// When true, rendered without its own Scaffold/background (inside dashboard).
  final bool embedded;

  @override State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _path = '/';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _err;
  final List<String> _history = ['/'];
  DateTime? _lastUpdated;
  DateTime? _lastSuccess;
  // Guards against overlapping _load calls when the user pulls to refresh
  // while a prior listing is still in flight, or when _navigate/_load fire
  // in quick succession on a slow link.
  bool _loadInFlight = false;

  @override void initState() { super.initState(); _load('/'); }

  Future<void> _load(String path) async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    setState(() { _loading = true; _err = null; });
    try {
      final data = await widget.api.listFiles(path);
      if (!mounted) return;
      setState(() {
        _path = data['path'] as String;
        _items = List<Map<String, dynamic>>.from(data['items'] as List);
        _loading = false;
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
      _loadInFlight = false;
    }
  }

  void _navigate(String path) {
    // History must only advance if the load will actually run; otherwise
    // a rapid tap on a slow link would push a phantom entry while _load
    // silently returned, leaving Back to pop to the wrong directory.
    if (_loadInFlight) return;
    HapticFeedback.selectionClick();
    _history.add(path);
    _load(path);
  }

  void _goBack() {
    if (_loadInFlight) return;
    if (_history.length > 1) {
      HapticFeedback.selectionClick();
      _history.removeLast();
      _load(_history.last);
    }
  }

  Future<void> _download(Map<String, dynamic> item) async {
    final path = item['path'] as String;
    final name = item['name'] as String;
    if (!mounted) return;

    _snack('Downloading $name…');
    try {
      final bytes = await widget.api.downloadFile(path);
      final out = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file',
        fileName: name,
        bytes: bytes,
      );
      if (out == null) {
        if (mounted) _snack('Download cancelled');
        return;
      }
      if (!mounted) return;
      _snack('Saved: $out', success: true);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final name = file.name;
    _snack('Uploading $name…');
    try {
      final resp = await widget.api.uploadFile(
        bytes: file.bytes!, filename: name, destDir: _path);
      if (!mounted) return;
      _snack('Uploaded to ${resp['path']}', success: true);
      _load(_path);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    }
  }

  /// Show a confirm dialog; returns true if the user confirms delete.
  /// Kept separate from the actual delete so `Dismissible.confirmDismiss`
  /// can invoke it directly and only commit the slide-out on approval.
  Future<bool> _confirmDelete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${item['name']}?',
          style: const TextStyle(color: Bk.textPri)),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Bk.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Bk.textSec))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
              style: TextStyle(color: Bk.danger, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Perform the actual delete call and refresh the list. Errors are
  /// surfaced via snackbar; the row stays hidden because the Dismissible
  /// already committed, and the refresh will either remove it (success)
  /// or restore it (failure).
  Future<void> _performDelete(Map<String, dynamic> item) async {
    try {
      await widget.api.deleteFile(item['path'] as String);
      _load(_path);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
      _load(_path);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Bk.textPri, fontSize: 12)),
      backgroundColor: Bk.surface1,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}K';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)}M';
    return '${(bytes / 1073741824).toStringAsFixed(1)}G';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<ConnectionProvider>().reduceMotion;
    final stale = _lastSuccess != null &&
        DateTime.now().difference(_lastSuccess!).inSeconds > 30;

    final body = Stack(children: [
      Column(children: [
        _Header(
          path: _path,
          canGoBack: _history.length > 1,
          onBack: _goBack,
          stale: stale,
          onRefresh: () => _load(_path),
          embedded: widget.embedded,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(_path),
            color: Bk.accent,
            backgroundColor: Bk.surface1,
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : AppDurations.fast,
              switchInCurve: AppCurves.enter,
              switchOutCurve: AppCurves.exit,
              child: _loading
                  ? const _FileSkeleton(key: ValueKey('loading'))
                  : _err != null
                      ? Center(
                          key: const ValueKey('error'),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Text(_err!,
                              style: const TextStyle(
                                color: Bk.danger, fontSize: 12)),
                          ),
                        )
                      : _items.isEmpty
                          ? const _EmptyDir(key: ValueKey('empty'))
                          : _FileList(
                              key: const ValueKey('list'),
                              items: _items,
                              bottomPad: widget.embedded ? 120 : 32,
                              fmtSize: _fmtSize,
                              onTap: (i) {
                                if (i['is_dir'] == true) {
                                  _navigate(i['path'] as String);
                                }
                              },
                              onDownload: (i) {
                                if (i['is_dir'] != true) _download(i);
                              },
                              onConfirmDelete: _confirmDelete,
                              onPerformDelete: _performDelete,
                            ),
            ),
          ),
        ),
      ]),
      Positioned(
        right: AppSpacing.xl,
        bottom: widget.embedded ? 110 : AppSpacing.xl,
        child: _UploadFab(onTap: _upload),
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
}

class _Header extends StatelessWidget {
  const _Header({
    required this.path,
    required this.canGoBack,
    required this.onBack,
    required this.stale,
    required this.onRefresh,
    required this.embedded,
  });
  final String path;
  final bool canGoBack, stale, embedded;
  final VoidCallback onBack, onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (!embedded) ...[
            GlassIconButton(
              icon: Icons.arrow_back_ios_new,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          // No per-tab H1: the bottom nav already identifies the section,
          // and per-tab H1s were ghosting through each other during the
          // cross-fade. Stretch the breadcrumb row to fill the space.
          const Spacer(),
          GlassIconButton(
            icon: Icons.refresh_outlined,
            onPressed: onRefresh,
            tooltip: 'Refresh',
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        GlassCard(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 8),
          radius: AppRadii.md,
          child: Row(children: [
            if (canGoBack)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new,
                  size: 14, color: Bk.textSec),
              ),
            if (canGoBack) const SizedBox(width: 4),
            Expanded(child: Text(path,
              style: const TextStyle(
                color: Bk.textPri, fontSize: 12, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
            if (stale) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.history, size: 14, color: Bk.warn),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({
    super.key,
    required this.items,
    required this.bottomPad,
    required this.onTap,
    required this.onDownload,
    required this.onConfirmDelete,
    required this.onPerformDelete,
    required this.fmtSize,
  });
  final List<Map<String, dynamic>> items;
  final double bottomPad;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(Map<String, dynamic>) onDownload;
  final Future<bool> Function(Map<String, dynamic>) onConfirmDelete;
  final Future<void> Function(Map<String, dynamic>) onPerformDelete;
  final String Function(int) fmtSize;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, bottomPad),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final item = items[i];
        // Use the server path as the key so the Dismissible is stable across
        // refreshes (names can repeat across directories).
        final rowKey = ValueKey<String>('row:${item['path']}');
        return Dismissible(
          key: rowKey,
          direction: DismissDirection.endToStart,
          // Require the user to swipe past ~40% before we commit, matching
          // the feel of iOS Mail/Files.
          dismissThresholds: const {DismissDirection.endToStart: 0.4},
          background: const SizedBox.shrink(),
          secondaryBackground: _SwipeDeleteBg(),
          confirmDismiss: (_) async {
            HapticFeedback.mediumImpact();
            final ok = await onConfirmDelete(item);
            if (ok) HapticFeedback.heavyImpact();
            return ok;
          },
          onDismissed: (_) => onPerformDelete(item),
          child: _FileRow(
            item: item,
            onTap: () => onTap(item),
            onDownload: item['is_dir'] == true
                ? null : () => onDownload(item),
            fmtSize: fmtSize,
          ),
        );
      },
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.item,
    required this.onTap,
    this.onDownload,
    required this.fmtSize,
  });
  final Map<String, dynamic> item;
  final VoidCallback? onTap, onDownload;
  final String Function(int) fmtSize;

  @override
  Widget build(BuildContext context) {
    final isDir = item['is_dir'] as bool? ?? false;
    final name = item['name'] as String;
    final size = item['size'] as int? ?? 0;
    final mode = item['mode'] as String? ?? '';
    final errMsg = item['error'] as String?;

    return GlassCard(
      onTap: onTap,
      style: GlassStyle.subtle,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: (isDir ? Bk.accent : Bk.textSec).withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            isDir ? Icons.folder_outlined : _fileIcon(name),
            color: isDir ? Bk.accent : Bk.textSec,
            size: 18,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(
              color: errMsg != null ? Bk.textDim : Bk.textPri,
              fontSize: 13, fontFamily: 'monospace',
              fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Row(children: [
              if (!isDir)
                Text(fmtSize(size), style: const TextStyle(
                  color: Bk.textDim, fontSize: 11)),
              if (mode.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(mode, style: const TextStyle(
                  color: Bk.textDim, fontSize: 11, fontFamily: 'monospace')),
              ],
              if (errMsg != null) ...[
                const SizedBox(width: 6),
                Expanded(child: Text(errMsg, style: const TextStyle(
                  color: Bk.danger, fontSize: 10),
                  overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ],
        )),
        if (onDownload != null)
          IconButton(
            icon: const Icon(Icons.download_outlined,
              size: 18, color: Bk.textSec),
            onPressed: onDownload,
            tooltip: 'Download',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        // Delete lives on swipe-left now (iOS-native). No trailing button.
      ]),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'txt' || 'md' || 'log' => Icons.description_outlined,
      'zip' || 'gz' || 'tar' || 'xz' || 'bz2' => Icons.archive_outlined,
      'py' || 'c' || 'h' || 'dart' || 'rs' || 'sh' => Icons.code_outlined,
      'mp4' || 'mkv' || 'avi' => Icons.movie_outlined,
      'mp3' || 'flac' || 'ogg' => Icons.audio_file_outlined,
      'jpg' || 'jpeg' || 'png' || 'gif' => Icons.image_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

class _FileSkeleton extends StatelessWidget {
  const _FileSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GlassCard(
          style: GlassStyle.subtle,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: const [
            _SkelBox(width: 34, height: 34),
            SizedBox(width: 12),
            Expanded(child: _SkelBox(width: double.infinity, height: 12)),
            SizedBox(width: 12),
            _SkelBox(width: 50, height: 10),
          ]),
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
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Bk.glassDefault,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class _UploadFab extends StatelessWidget {
  const _UploadFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: GlassPill(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          tint: Bk.accent,
          selected: true,
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.upload_outlined, size: 18, color: Bk.accent),
            SizedBox(width: 8),
            Text('Upload', style: TextStyle(
              color: Bk.accent, fontSize: 13,
              fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ── Swipe-to-delete background ────────────────────────────────────────────
// Shown under a file row as the user swipes it left. Mirrors the native iOS
// Mail/Files pattern: red pill revealing a trash icon + "Delete" label on
// the trailing edge.

class _SwipeDeleteBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: Bk.danger.withOpacity(0.85),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.delete_outline, size: 20, color: Colors.white),
        SizedBox(width: 8),
        Text('Delete',
          style: TextStyle(
            color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      ]),
    );
  }
}

// ── Empty directory state ─────────────────────────────────────────────────
// Replaces the bare "Empty directory" text with a centered icon + title +
// hint so blank directories feel intentional rather than broken.

class _EmptyDir extends StatelessWidget {
  const _EmptyDir({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      // ListView wraps the page so RefreshIndicator still works on an empty
      // directory (pull-to-refresh needs a scrollable child).
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Bk.accent.withOpacity(0.08),
                      border: Border.all(
                        color: Bk.accent.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: const Icon(
                      Icons.folder_open_outlined,
                      size: 34, color: Bk.accent),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Empty directory',
                    style: TextStyle(
                      color: Bk.textPri, fontSize: 15,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Tap Upload to add a file',
                    style: TextStyle(
                      color: Bk.textDim, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

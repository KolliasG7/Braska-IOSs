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

  @override void initState() { super.initState(); _load('/'); }

  Future<void> _load(String path) async {
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
    }
  }

  void _navigate(String path) {
    HapticFeedback.selectionClick();
    _history.add(path);
    _load(path);
  }

  void _goBack() {
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

  Future<void> _delete(Map<String, dynamic> item) async {
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
    if (confirmed != true) return;

    try {
      await widget.api.deleteFile(item['path'] as String);
      _load(_path);
    } catch (e) {
      _snack('Error: $e');
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
                          ? const Center(
                              key: ValueKey('empty'),
                              child: Text('Empty directory',
                                style: TextStyle(
                                  color: Bk.textDim, fontSize: 13)),
                            )
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
                              onDelete: _delete,
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
          const Text('Files', style: TextStyle(
            color: Bk.textPri, fontSize: 22,
            fontWeight: FontWeight.w800, letterSpacing: -0.2)),
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
    required this.onDelete,
    required this.fmtSize,
  });
  final List<Map<String, dynamic>> items;
  final double bottomPad;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(Map<String, dynamic>) onDownload;
  final void Function(Map<String, dynamic>) onDelete;
  final String Function(int) fmtSize;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, bottomPad),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _FileRow(
        item: items[i],
        onTap: () => onTap(items[i]),
        onDownload: items[i]['is_dir'] == true
            ? null : () => onDownload(items[i]),
        onDelete: () => onDelete(items[i]),
        fmtSize: fmtSize,
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.onDownload,
    required this.fmtSize,
  });
  final Map<String, dynamic> item;
  final VoidCallback? onTap, onDownload, onDelete;
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
        IconButton(
          icon: const Icon(Icons.delete_outline,
            size: 18, color: Bk.textSec),
          onPressed: onDelete,
          tooltip: 'Delete',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
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

// lib/screens/files_screen.dart — File browser, upload, download
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.api});
  final ApiService api;
  @override State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _path    = '/';
  List<Map<String, dynamic>> _items = [];
  bool    _loading  = true;
  String? _err;
  List<String> _history = ['/'];
  DateTime? _lastUpdated;
  DateTime? _lastSuccess;

  @override void initState() { super.initState(); _load('/'); }

  Future<void> _load(String path) async {
    setState(() { _loading = true; _err = null; });
    try {
      final data = await widget.api.listFiles(path);
      if (!mounted) return;
      setState(() {
        _path    = data['path'] as String;
        _items   = List<Map<String, dynamic>>.from(data['items'] as List);
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

    _showSnack('Downloading $name…');
    try {
      final bytes = await widget.api.downloadFile(path);

      // Ask user where to save the file and natively write to it via SAF
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save payload/file',
        fileName: name,
        bytes: bytes,
      );

      if (outputFile == null) {
        if (mounted) _showSnack('Download cancelled');
        return; 
      }

      if (!mounted) return;
      // Note: FilePicker automatically writes the bytes via native channels if passed.
      // outputFile will contain the path/URI where it was written.
      _showSnack('✓ Saved: $outputFile', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final name = file.name;
    _showSnack('Uploading $name…');
    try {
      final resp = await widget.api.uploadFile(
        bytes: file.bytes!,
        filename: name,
        destDir: _path,
      );
      if (!mounted) return;
      _showSnack('✓ Uploaded to ${resp['path']}', success: true);
      _load(_path);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Bk.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Bk.border)),
        title: const Text('DELETE', style: TextStyle(
          color: Bk.textPri, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
        content: Text('Delete ${item['name']}?',
          style: const TextStyle(color: Bk.textSec, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Bk.textDim))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Bk.white, fontWeight: FontWeight.w900))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.deleteFile(item['path'] as String);
      _load(_path);
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Bk.textPri, fontSize: 12)),
      backgroundColor: Bk.surface2,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024)        return '${bytes}B';
    if (bytes < 1048576)     return '${(bytes/1024).toStringAsFixed(1)}K';
    if (bytes < 1073741824)  return '${(bytes/1048576).toStringAsFixed(1)}M';
    return '${(bytes/1073741824).toStringAsFixed(1)}G';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<ConnectionProvider>().reduceMotion;
    final stale = _lastSuccess != null &&
        DateTime.now().difference(_lastSuccess!).inSeconds > 30;
    return Scaffold(
      backgroundColor: Bk.oled,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          if (_history.length > 1)
            GestureDetector(
              onTap: _goBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.arrow_back_ios_new, size: 16, color: Bk.textSec))),
          Expanded(child: Text(
            _path,
            style: const TextStyle(
              color: Bk.textSec, fontSize: 11,
              fontFamily: 'monospace', letterSpacing: 0),
            overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_outlined, size: 20),
            onPressed: _upload,
            tooltip: 'Upload to current folder'),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 18),
            tooltip: 'Refresh files',
            onPressed: () => _load(_path)),
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
      body: RefreshIndicator(
        onRefresh: () => _load(_path),
        color: Bk.white,
        backgroundColor: Bk.surface1,
        child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduceMotion ? 1 : 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _loading
            ? const _FileSkeleton(key: ValueKey('loading'))
            : _err != null
                ? Center(
                    key: const ValueKey('error'),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _err!,
                        style: const TextStyle(color: Bk.textSec, fontSize: 12),
                      ),
                    ),
                  )
                : _items.isEmpty
                    ? const Center(
                        key: ValueKey('empty'),
                        child: Text(
                          'Empty directory',
                          style: TextStyle(color: Bk.textDim, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('list'),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Bk.border, height: 1),
                        itemBuilder: (_, i) => _FileRow(
                          item: _items[i],
                          onTap: () {
                            if (_items[i]['is_dir'] == true) {
                              _navigate(_items[i]['path'] as String);
                            }
                          },
                          onDownload: _items[i]['is_dir'] != true
                              ? () => _download(_items[i])
                              : null,
                          onDelete: () => _delete(_items[i]),
                          fmtSize: _fmtSize,
                        ),
                      ),
        ),
      ),
    );
  }
}

class _FileSkeleton extends StatelessWidget {
  const _FileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _SkelBox(width: 16, height: 16),
            SizedBox(width: 12),
            Expanded(child: _SkelBox(width: double.infinity, height: 12)),
            SizedBox(width: 10),
            _SkelBox(width: 18, height: 18),
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

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.item, required this.onTap,
    required this.onDelete, this.onDownload,
    required this.fmtSize,
  });
  final Map<String, dynamic> item;
  final VoidCallback? onTap, onDownload, onDelete;
  final String Function(int) fmtSize;

  @override
  Widget build(BuildContext context) {
    final isDir  = item['is_dir'] as bool? ?? false;
    final name   = item['name']   as String;
    final size   = item['size']   as int? ?? 0;
    final mode   = item['mode']   as String? ?? '';
    final errMsg = item['error']  as String?;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          Icon(
            isDir ? Icons.folder_outlined : _fileIcon(name),
            color: isDir ? Bk.white : Bk.textSec,
            size: 18),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(
                color: errMsg != null ? Bk.textDim : Bk.textPri,
                fontSize: 13, fontFamily: 'monospace',
                fontWeight: FontWeight.w600)),
              Row(children: [
                if (!isDir)
                  Text(fmtSize(size), style: const TextStyle(
                    color: Bk.textDim, fontSize: 10)),
                if (mode.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(mode, style: const TextStyle(
                    color: Bk.textDim, fontSize: 10, fontFamily: 'monospace')),
                ],
                if (errMsg != null) ...[
                  const SizedBox(width: 6),
                  Text(errMsg, style: const TextStyle(
                    color: Bk.textDim, fontSize: 9)),
                ],
              ]),
            ],
          )),
          // Download button (files only)
          if (onDownload != null)
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 18, color: Bk.textDim),
              onPressed: onDownload,
              tooltip: 'Download file',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints()),
          const SizedBox(width: 4),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17, color: Bk.textDim),
            onPressed: onDelete,
            tooltip: 'Delete item',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints()),
        ]),
      ),
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

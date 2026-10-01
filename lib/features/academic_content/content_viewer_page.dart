// lib/features/academic_content/content_viewer_page.dart
// Renders an uploaded file in-app: images (pinch-zoom), PDFs (pdfx),
// video (chewie/video_player), Word documents (.docx, via DocxParser),
// and EPUB electronic books (.epub, via EpubParser).
// Provides text selection/copying, visible Save for Offline action,
// and local persistence.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';
import '../../core/docx_parser.dart';
import '../../core/epub_parser.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';

enum ViewableFileKind { image, pdf, video, docx, epub }

/// Maps a file's extension to a kind this viewer can render, or null if
/// it should fall back to opening externally.
ViewableFileKind? viewableKindFor(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp'};
  const pdfExts = {'pdf'};
  const videoExts = {'mp4', 'mov', 'avi', 'm4v'};
  const docxExts = {'docx'};
  const epubExts = {'epub'};
  if (imageExts.contains(ext)) return ViewableFileKind.image;
  if (pdfExts.contains(ext)) return ViewableFileKind.pdf;
  if (videoExts.contains(ext)) return ViewableFileKind.video;
  if (docxExts.contains(ext)) return ViewableFileKind.docx;
  if (epubExts.contains(ext)) return ViewableFileKind.epub;
  return null;
}

class ContentViewerPage extends StatelessWidget {
  final String fileUrl;
  final String title;
  final ViewableFileKind kind;

  /// Both required to track/resume reading position (Home "Continue Reading")
  final String? contentId;
  final String? userId;

  /// Path to a device-local copy from AcademicContentRepository's offline download
  final String? localFilePath;

  const ContentViewerPage({
    super.key,
    required this.fileUrl,
    required this.title,
    required this.kind,
    this.contentId,
    this.userId,
    this.localFilePath,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: kind == ViewableFileKind.video ? Colors.black : ac.bg,
      appBar: AppBar(
        title: Text(
          title,
          style: AppText.title.copyWith(
            color: kind == ViewableFileKind.video ? Colors.white : ac.txt,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: kind == ViewableFileKind.video ? Colors.black : ac.bg,
        iconTheme: IconThemeData(
          color: kind == ViewableFileKind.video ? Colors.white : ac.txt,
        ),
        actions: [
          _ViewerSaveOfflineAction(
            contentId: contentId,
            fileUrl: fileUrl,
            title: title,
            localFilePath: localFilePath,
          ),
        ],
      ),
      body: SelectionArea(
        child: switch (kind) {
          ViewableFileKind.image => _ImageViewer(url: fileUrl, localFilePath: localFilePath),
          ViewableFileKind.pdf => _PdfViewer(
              url: fileUrl,
              localFilePath: localFilePath,
              contentId: contentId,
              userId: userId,
            ),
          ViewableFileKind.video => _VideoViewer(url: fileUrl, localFilePath: localFilePath),
          ViewableFileKind.docx => _DocxViewer(
              url: fileUrl,
              localFilePath: localFilePath,
              contentId: contentId,
            ),
          ViewableFileKind.epub => _EpubViewer(
              url: fileUrl,
              localFilePath: localFilePath,
              contentId: contentId,
            ),
        },
      ),
    );
  }
}

class _ViewerSaveOfflineAction extends StatefulWidget {
  final String? contentId;
  final String fileUrl;
  final String title;
  final String? localFilePath;

  const _ViewerSaveOfflineAction({
    required this.contentId,
    required this.fileUrl,
    required this.title,
    this.localFilePath,
  });

  @override
  State<_ViewerSaveOfflineAction> createState() => _ViewerSaveOfflineActionState();
}

class _ViewerSaveOfflineActionState extends State<_ViewerSaveOfflineAction> {
  bool _isSaved = false;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    if (widget.localFilePath != null) {
      if (mounted) setState(() => _isSaved = true);
      return;
    }
    final contentId = widget.contentId;
    if (contentId != null) {
      final path = await AcademicContentRepository.instance.offlineFilePath(contentId);
      if (mounted && path != null) {
        setState(() => _isSaved = true);
      }
    }
  }

  Future<void> _saveOffline() async {
    final contentId = widget.contentId;
    if (contentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This resource is streamed directly and cannot be saved offline.')),
      );
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0;
    });

    try {
      await AcademicContentRepository.instance.ensureLocalCopy(
        contentId: contentId,
        fileUrl: widget.fileUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        setState(() {
          _isSaved = true;
          _downloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved for offline use. Accessible anytime in Offline section.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save offline: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (_downloading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _progress > 0 ? _progress : null,
              color: ac.primary,
            ),
          ),
        ),
      );
    }

    if (_isSaved) {
      return IconButton(
        icon: Icon(Icons.check_circle_rounded, color: ac.grn),
        tooltip: 'Saved for offline',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This document is saved locally and available offline.')),
          );
        },
      );
    }

    return IconButton(
      icon: Icon(Icons.download_rounded, color: ac.txt2),
      tooltip: 'Save for offline',
      onPressed: _saveOffline,
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String url;
  final String? localFilePath;
  const _ImageViewer({required this.url, this.localFilePath});

  @override
  Widget build(BuildContext context) {
    final path = localFilePath;
    final image = (path != null)
        ? Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(child: Text('Could not load this image.')),
          )
        : Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) => const Center(
              child: Text('Could not load this image.'),
            ),
          );
    return InteractiveViewer(minScale: 0.5, maxScale: 4, child: Center(child: image));
  }
}

class _PdfViewer extends StatefulWidget {
  final String url;
  final String? localFilePath;
  final String? contentId;
  final String? userId;
  const _PdfViewer({required this.url, this.localFilePath, this.contentId, this.userId});

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  late final Future<(int, String?)> _readyFuture = _prepare();
  double _downloadProgress = 0;

  Future<(int, String?)> _prepare() async {
    final contentId = widget.contentId;
    final userId = widget.userId;

    final initialPageFuture = (contentId != null && userId != null)
        ? AcademicContentRepository.instance.savedReadPage(contentId: contentId, userId: userId)
        : Future.value(1);

    final Future<String?> pathFuture;
    if (widget.localFilePath != null) {
      pathFuture = Future.value(widget.localFilePath);
    } else if (contentId != null) {
      pathFuture = AcademicContentRepository.instance.ensureLocalCopy(
        contentId: contentId,
        fileUrl: widget.url,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
    } else {
      pathFuture = Future.value(null);
    }

    final page = await initialPageFuture;
    final path = await pathFuture;
    return (page, path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(int, String?)>(
      future: _readyFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not open this PDF: ${snap.error}', textAlign: TextAlign.center),
            ),
          );
        }
        if (!snap.hasData) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                value: _downloadProgress > 0 ? _downloadProgress : null,
              ),
              if (_downloadProgress > 0) ...[
                const SizedBox(height: 12),
                Text('${(_downloadProgress * 100).round()}%'),
              ],
            ]),
          );
        }
        final (page, path) = snap.data!;
        return _PdfViewerBody(
          url: widget.url,
          localFilePath: path,
          initialPage: page,
          contentId: widget.contentId,
          userId: widget.userId,
        );
      },
    );
  }
}

class _PdfViewerBody extends StatefulWidget {
  final String url;
  final String? localFilePath;
  final int initialPage;
  final String? contentId;
  final String? userId;
  const _PdfViewerBody({
    required this.url,
    this.localFilePath,
    required this.initialPage,
    this.contentId,
    this.userId,
  });

  @override
  State<_PdfViewerBody> createState() => _PdfViewerBodyState();
}

class _PdfViewerBodyState extends State<_PdfViewerBody> {
  late final PdfControllerPinch _controller;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: widget.localFilePath != null
          ? PdfDocument.openFile(widget.localFilePath!)
          : PdfDocument.openData(_fetchBytes(widget.url)),
      initialPage: widget.initialPage,
    );
  }

  Future<Uint8List> _fetchBytes(String url) async {
    final resp = await http.get(Uri.parse(url));
    return resp.bodyBytes;
  }

  void _onPageChanged(int page) {
    final contentId = widget.contentId;
    final userId = widget.userId;
    if (contentId == null || userId == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () {
      final total = _controller.pagesCount ?? page;
      AcademicContentRepository.instance.recordReadPosition(
        contentId: contentId,
        userId: userId,
        page: page,
        totalPages: total,
      );
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewPinch(
      controller: _controller,
      onPageChanged: _onPageChanged,
      onDocumentError: (error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not open this PDF: $error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _VideoViewer extends StatefulWidget {
  final String url;
  final String? localFilePath;
  const _VideoViewer({required this.url, this.localFilePath});

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late final VideoPlayerController _videoCtrl;
  ChewieController? _chewieCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final path = widget.localFilePath;
    _videoCtrl = path != null
        ? VideoPlayerController.file(File(path))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _videoCtrl.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _chewieCtrl = ChewieController(
          videoPlayerController: _videoCtrl,
          autoPlay: true,
          looping: false,
        );
      });
    }).catchError((e) {
      if (mounted) setState(() => _error = 'Could not play this video.');
    });
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.white)));
    }
    if (_chewieCtrl == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(child: Chewie(controller: _chewieCtrl!));
  }
}

class _DocxViewer extends StatefulWidget {
  final String url;
  final String? localFilePath;
  final String? contentId;
  const _DocxViewer({required this.url, this.localFilePath, this.contentId});

  @override
  State<_DocxViewer> createState() => _DocxViewerState();
}

class _DocxViewerState extends State<_DocxViewer> {
  quill.QuillController? _controller;
  List<String> _warnings = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var path = widget.localFilePath;
      final contentId = widget.contentId;
      if (path == null && contentId != null) {
        path = await AcademicContentRepository.instance.ensureLocalCopy(
          contentId: contentId,
          fileUrl: widget.url,
        );
      }
      Uint8List bytes;
      if (path != null) {
        bytes = await File(path).readAsBytes();
      } else {
        final resp = await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 30));
        if (resp.statusCode >= 400) throw Exception('Server returned ${resp.statusCode}');
        bytes = resp.bodyBytes;
      }
      final parsed = await compute(DocxParser.parse, bytes);
      final doc = quill.Document.fromJson(jsonDecode(parsed.deltaJson));
      if (!mounted) return;
      setState(() {
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        _warnings = parsed.warnings;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open this document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final ac = AppColors.of(context);
    return Column(children: [
      if (_warnings.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: ac.goldBg,
          child: Text(_warnings.join(' '), style: AppText.caption.copyWith(color: ac.gold)),
        ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            quill.QuillEditor.basic(
              controller: controller,
              config: const quill.QuillEditorConfig(
                showCursor: false,
                autoFocus: false,
                placeholder: '',
                enableInteractiveSelection: true,
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _EpubViewer extends StatefulWidget {
  final String url;
  final String? localFilePath;
  final String? contentId;
  const _EpubViewer({required this.url, this.localFilePath, this.contentId});

  @override
  State<_EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<_EpubViewer> {
  EpubDocument? _doc;
  int _chapterIndex = 0;
  String? _error;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var path = widget.localFilePath;
      final contentId = widget.contentId;
      if (path == null && contentId != null) {
        path = await AcademicContentRepository.instance.ensureLocalCopy(
          contentId: contentId,
          fileUrl: widget.url,
        );
      }
      Uint8List bytes;
      if (path != null) {
        bytes = await File(path).readAsBytes();
      } else {
        final resp = await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 30));
        if (resp.statusCode >= 400) throw Exception('Server returned ${resp.statusCode}');
        bytes = resp.bodyBytes;
      }
      final parsed = await compute(EpubParser.parse, bytes);
      if (!mounted) return;
      setState(() {
        _doc = parsed;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open this EPUB: $e');
    }
  }

  void _showTableOfContents(BuildContext context) {
    final doc = _doc;
    if (doc == null) return;
    final ac = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Table of Contents', style: AppText.title.copyWith(fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: doc.chapters.length,
                itemBuilder: (ctx, i) {
                  final ch = doc.chapters[i];
                  final isCurrent = i == _chapterIndex;
                  return ListTile(
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCurrent ? ac.primary : ac.surf2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: AppText.caption.copyWith(
                          color: isCurrent ? Colors.white : ac.txt2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      ch.title,
                      style: AppText.bodySm.copyWith(
                        color: isCurrent ? ac.primary : ac.txt,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setState(() => _chapterIndex = i);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final doc = _doc;
    if (doc == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (doc.chapters.isEmpty) {
      return const Center(child: Text('This book contains no readable chapters.'));
    }

    final ac = AppColors.of(context);
    final chapter = doc.chapters[_chapterIndex.clamp(0, doc.chapters.length - 1)];

    return Column(
      children: [
        // Reader toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: ac.surf2,
            border: Border(bottom: BorderSide(color: ac.bdr)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.list_rounded),
                tooltip: 'Table of Contents',
                onPressed: () => _showTableOfContents(context),
              ),
              Expanded(
                child: Text(
                  chapter.title,
                  style: AppText.title.copyWith(fontSize: 13, color: ac.txt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.text_decrease_rounded, size: 18),
                tooltip: 'Decrease font size',
                onPressed: _fontSize > 12 ? () => setState(() => _fontSize -= 1.5) : null,
              ),
              IconButton(
                icon: const Icon(Icons.text_increase_rounded, size: 22),
                tooltip: 'Increase font size',
                onPressed: _fontSize < 28 ? () => setState(() => _fontSize += 1.5) : null,
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy chapter text',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: chapter.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chapter text copied to clipboard.')),
                  );
                },
              ),
            ],
          ),
        ),
        // Chapter content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SelectableText(
              chapter.content,
              style: AppText.body.copyWith(
                fontSize: _fontSize,
                height: 1.6,
                color: ac.txt,
              ),
            ),
          ),
        ),
        // Chapter pagination bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: ac.surf,
            border: Border(top: BorderSide(color: ac.bdr)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _chapterIndex > 0
                    ? () => setState(() => _chapterIndex--)
                    : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Previous'),
              ),
              Text(
                '${_chapterIndex + 1} of ${doc.chapters.length}',
                style: AppText.caption.copyWith(color: ac.muted),
              ),
              TextButton.icon(
                onPressed: _chapterIndex < doc.chapters.length - 1
                    ? () => setState(() => _chapterIndex++)
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

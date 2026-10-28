// lib/features/academic_content/content_viewer_page.dart
// Renders an uploaded file in-app: images (pinch-zoom), PDFs (pdfx),
// video (chewie/video_player), and Word documents (.docx, via the same
// DocxParser the Course composer's importer uses, rendered read-only in
// Quill). Other office formats and archives have no practical in-app
// renderer, so those still fall back to the external-app flow the
// caller already has.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';
import '../../core/docx_parser.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';

enum ViewableFileKind { image, pdf, video, docx }

/// Maps a file's extension to a kind this viewer can render, or null if
/// it should fall back to opening externally.
ViewableFileKind? viewableKindFor(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp'};
  const pdfExts = {'pdf'};
  const videoExts = {'mp4', 'mov', 'avi', 'm4v'};
  const docxExts = {'docx'};
  if (imageExts.contains(ext)) return ViewableFileKind.image;
  if (pdfExts.contains(ext)) return ViewableFileKind.pdf;
  if (videoExts.contains(ext)) return ViewableFileKind.video;
  if (docxExts.contains(ext)) return ViewableFileKind.docx;
  return null;
}

class ContentViewerPage extends StatelessWidget {
  final String fileUrl;
  final String title;
  final ViewableFileKind kind;

  /// Both required to track/resume reading position (Home "Continue
  /// Reading") — null for callers that don't have a persisted content
  /// item and/or signed-in user, in which case position tracking is
  /// simply skipped rather than guessed at.
  final String? contentId;
  final String? userId;

  /// Path to a device-local copy from AcademicContentRepository's offline
  /// download (see content_details_page's "Save for offline"). When set,
  /// every viewer kind (image/pdf/video/docx) reads from disk instead of
  /// the network — no loading spinner, no re-download on repeat opens.
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
        title: Text(title, style: AppText.title.copyWith(
            color: kind == ViewableFileKind.video ? Colors.white : ac.txt),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: kind == ViewableFileKind.video ? Colors.black : ac.bg,
        iconTheme: IconThemeData(
            color: kind == ViewableFileKind.video ? Colors.white : ac.txt),
      ),
      body: switch (kind) {
        ViewableFileKind.image => _ImageViewer(url: fileUrl, localFilePath: localFilePath),
        ViewableFileKind.pdf => _PdfViewer(
            url: fileUrl, localFilePath: localFilePath, contentId: contentId, userId: userId),
        ViewableFileKind.video => _VideoViewer(url: fileUrl, localFilePath: localFilePath),
        ViewableFileKind.docx => _DocxViewer(url: fileUrl, localFilePath: localFilePath, contentId: contentId),
      },
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
        // Offline copy first — no network round trip, and no loading
        // spinner needed since the file is already on disk.
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

/// Resolves everything needed before the actual PDF viewer can be built:
/// the saved page position AND a real local file to open pdfx against.
///
/// Previously this only awaited the saved-page lookup, then handed
/// PdfControllerPinch either a local path or `PdfDocument.openData
/// (_fetchBytes(url))` -- a single blocking `http.get()` that buffers
/// the ENTIRE PDF into memory before pdfx renders even page 1, with NO
/// caching at all: reopening the exact same book a minute later
/// re-downloaded it from scratch every time. That was the actual
/// bottleneck behind "PDFs/books take forever to open" -- not a
/// timeout, not the renderer, the download strategy itself.
///
/// Now: resolve the saved page AND a cached local copy (via
/// AcademicContentRepository.ensureLocalCopy -- instant if this exact
/// file was ever opened or explicitly saved before, streamed-to-disk
/// with real progress otherwise) concurrently rather than sequentially,
/// and always open pdfx from a local file. First open of a never-seen
/// file still has to download once; every open after that is instant.
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

    // Both kicked off before either is awaited, so the Firestore read
    // and the file download/cache-check happen in parallel, not
    // back-to-back.
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
      // No contentId to cache against (caller has no persisted content
      // item) -- fall back to letting pdfx read the URL directly rather
      // than buffering it here too.
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
          url: widget.url, localFilePath: path, initialPage: page,
          contentId: widget.contentId, userId: widget.userId,
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
    required this.url, this.localFilePath, required this.initialPage, this.contentId, this.userId,
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
      // By the time this widget exists, _PdfViewerState has already
      // resolved a real local file whenever a contentId was available
      // to cache against (see that class's doc comment) -- openData's
      // whole-file network fetch is now only reached for the rare
      // caller with no contentId at all.
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

  /// Debounced so flicking through pages quickly doesn't fire a write per
  /// page — only the page the reader actually settles on is persisted.
  void _onPageChanged(int page) {
    final contentId = widget.contentId;
    final userId = widget.userId;
    if (contentId == null || userId == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () {
      final total = _controller.pagesCount ?? page;
      AcademicContentRepository.instance.recordReadPosition(
        contentId: contentId, userId: userId, page: page, totalPages: total,
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
    // Offline copy first (no network round trip, no buffering) — network
    // streaming fallback otherwise, same pattern as the PDF viewer.
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
      // Offline/cached copy first. Same fix as the PDF viewer: an
      // explicit localFilePath wins outright, otherwise auto-cache via
      // ensureLocalCopy when a contentId exists (instant on repeat
      // opens) instead of always re-downloading the whole document with
      // a plain http.get() -- only falls through to that raw fetch when
      // there's no contentId to cache against at all.
      var path = widget.localFilePath;
      final contentId = widget.contentId;
      if (path == null && contentId != null) {
        path = await AcademicContentRepository.instance.ensureLocalCopy(
          contentId: contentId, fileUrl: widget.url,
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
      // Zip-decode + XML-parse is CPU-bound — same reason the Course
      // composer's .docx importer runs this via compute() rather than
      // blocking the UI isolate.
      final parsed = await compute(DocxParser.parse, bytes);
      final doc = quill.Document.fromJson(jsonDecode(parsed.deltaJson));
      if (!mounted) return;
      setState(() {
        _controller = quill.QuillController(
            document: doc, selection: const TextSelection.collapsed(offset: 0), readOnly: true);
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
                showCursor: false, autoFocus: false, placeholder: '',
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

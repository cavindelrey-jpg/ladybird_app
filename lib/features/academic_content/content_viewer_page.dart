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
import 'dart:typed_data';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';
import '../../core/docx_parser.dart';
import '../../core/epub_parser.dart';
import '../../repositories/academic_content_repository.dart';
import '../../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';

enum ViewableFileKind { image, pdf, video, docx, webText, epub }

/// Maps a file's extension to a kind this viewer can render, or null if
/// it should fall back to opening externally.
ViewableFileKind? viewableKindFor(String url) {
  final clean = url.split('?').first.split('#').first.toLowerCase();
  const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp'};
  const pdfExts = {'pdf'};
  const videoExts = {'mp4', 'mov', 'avi', 'm4v'};
  const docxExts = {'docx'};
  const epubExts = {'epub'};
  const textExts = {'txt', 'html', 'htm', 'md'};

  final ext = clean.contains('.') ? clean.split('.').last : '';
  if (imageExts.contains(ext)) return ViewableFileKind.image;
  if (pdfExts.contains(ext)) return ViewableFileKind.pdf;
  if (videoExts.contains(ext)) return ViewableFileKind.video;
  if (docxExts.contains(ext)) return ViewableFileKind.docx;
  if (epubExts.contains(ext)) return ViewableFileKind.epub;
  if (textExts.contains(ext)) return ViewableFileKind.webText;

  // Project Gutenberg links (e.g. https://www.gutenberg.org/ebooks/1342)
  if (url.toLowerCase().contains('gutenberg.org')) {
    return ViewableFileKind.webText;
  }

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
      backgroundColor: kind == ViewableFileKind.video
          ? Colors.black
          : (kind == ViewableFileKind.epub ? Colors.transparent : ac.bg),
      appBar: kind == ViewableFileKind.epub
          ? null
          : AppBar(
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
            url: fileUrl, localFilePath: localFilePath, contentId: contentId, userId: userId, title: title),
        ViewableFileKind.video => _VideoViewer(url: fileUrl, localFilePath: localFilePath),
        ViewableFileKind.docx => _DocxViewer(url: fileUrl, localFilePath: localFilePath, contentId: contentId),
        ViewableFileKind.webText => _WebTextViewer(
            url: fileUrl, title: title, contentId: contentId, userId: userId, localFilePath: localFilePath),
        ViewableFileKind.epub => _EpubViewer(
            url: fileUrl, title: title, contentId: contentId, userId: userId, localFilePath: localFilePath),
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
  final String title;
  final String? localFilePath;
  final String? contentId;
  final String? userId;
  const _PdfViewer({required this.url, required this.title, this.localFilePath, this.contentId, this.userId});

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
          url: widget.url, title: widget.title, localFilePath: path, initialPage: page,
          contentId: widget.contentId, userId: widget.userId,
        );
      },
    );
  }
}

class _PdfViewerBody extends StatefulWidget {
  final String url;
  final String title;
  final String? localFilePath;
  final int initialPage;
  final String? contentId;
  final String? userId;
  const _PdfViewerBody({
    required this.url, required this.title, this.localFilePath, required this.initialPage, this.contentId, this.userId,
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
      AuthService.instance.setContinueReading(
        userId, itemId: contentId, title: widget.title, page: page, totalPages: total,
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

class _WebTextViewer extends StatefulWidget {
  final String url;
  final String title;
  final String? contentId;
  final String? userId;
  final String? localFilePath;

  const _WebTextViewer({
    required this.url,
    required this.title,
    this.contentId,
    this.userId,
    this.localFilePath,
  });

  @override
  State<_WebTextViewer> createState() => _WebTextViewerState();
}

class _WebTextViewerState extends State<_WebTextViewer> {
  String? _text;
  bool _loading = true;
  String? _error;
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final contentId = widget.contentId;
    final userId = widget.userId;
    if (contentId == null || userId == null || !_scrollCtrl.hasClients) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () {
      final max = _scrollCtrl.position.maxScrollExtent;
      final current = _scrollCtrl.position.pixels;
      final totalEst = max > 0 ? (max / 800).ceil() : 1;
      final pageEst = max > 0 ? ((current / max) * totalEst).clamp(1, totalEst).round() : 1;
      AcademicContentRepository.instance.recordReadPosition(
        contentId: contentId, userId: userId, page: pageEst, totalPages: totalEst,
      );
      AuthService.instance.setContinueReading(
        userId, itemId: contentId, title: widget.title, page: pageEst, totalPages: totalEst,
      );
    });
  }

  Future<void> _load() async {
    try {
      String resolvedUrl = widget.url;
      if (resolvedUrl.contains('gutenberg.org/ebooks/')) {
        final match = RegExp(r'gutenberg\.org/ebooks/(\d+)').firstMatch(resolvedUrl);
        if (match != null) {
          final id = match.group(1);
          resolvedUrl = 'https://www.gutenberg.org/files/$id/$id-0.txt';
        }
      }

      String raw;
      if (widget.localFilePath != null) {
        raw = await File(widget.localFilePath!).readAsString();
      } else {
        var resp = await http.get(Uri.parse(resolvedUrl)).timeout(const Duration(seconds: 20));
        if (resp.statusCode != 200 && widget.url.contains('gutenberg.org')) {
          final match = RegExp(r'gutenberg\.org/ebooks/(\d+)').firstMatch(widget.url);
          if (match != null) {
            final id = match.group(1);
            final fallbackUrl = 'https://www.gutenberg.org/cache/epub/$id/pg$id.txt';
            resp = await http.get(Uri.parse(fallbackUrl)).timeout(const Duration(seconds: 20));
          }
        }
        if (resp.statusCode != 200) {
          throw Exception('Server returned ${resp.statusCode}');
        }
        raw = resp.body;
      }

      if (raw.contains('<!DOCTYPE') || raw.contains('<html') || raw.contains('<p>')) {
        raw = raw
            .replaceAll(RegExp(r'<style[^>]*>.*?</style>', multiLine: true, dotAll: true), '')
            .replaceAll(RegExp(r'<script[^>]*>.*?</script>', multiLine: true, dotAll: true), '')
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();
      }

      if (mounted) {
        setState(() {
          _text = raw;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load text reader: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: ac.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: ac.txt)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: ac.bg,
      child: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SelectableText(
            _text ?? '',
            style: GoogleFonts.merriweather(
              fontSize: 16,
              height: 1.7,
              color: ac.txt,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EPUB VIEWER (P2)
// ════════════════════════════════════════════════════════════════════════════

enum EpubReaderTheme {
  sepia,
  light,
  night,
  black,
  system,
}

enum EpubFontFamily {
  serif,
  sans,
  mono,
}

class _EpubSearchResult {
  final int chapterIndex;
  final String chapterTitle;
  final String snippet;

  const _EpubSearchResult({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.snippet,
  });
}

class _EpubViewer extends StatefulWidget {
  final String url;
  final String title;
  final String? contentId;
  final String? userId;
  final String? localFilePath;

  const _EpubViewer({
    required this.url,
    required this.title,
    this.contentId,
    this.userId,
    this.localFilePath,
  });

  @override
  State<_EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<_EpubViewer> {
  EpubDocument? _doc;
  int _currentChapter = 0;
  double _fontSize = 17.0;
  double _lineHeight = 1.7;
  EpubReaderTheme _readerTheme = EpubReaderTheme.sepia;
  EpubFontFamily _fontFamily = EpubFontFamily.serif;
  bool _loading = true;
  String? _error;

  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<_EpubSearchResult> _searchResults = [];
  bool _searchPerformed = false;

  final ScrollController _scrollCtrl = ScrollController();
  double _scrollProgress = 0.0;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final current = _scrollCtrl.position.pixels;
    final p = (current / maxScroll).clamp(0.0, 1.0);
    if ((p - _scrollProgress).abs() > 0.02) {
      setState(() => _scrollProgress = p);
    }
  }

  Color _getBgColor(AppColors ac) => switch (_readerTheme) {
        EpubReaderTheme.system => ac.bg,
        EpubReaderTheme.light => const Color(0xFFFFFFFF),
        EpubReaderTheme.sepia => const Color(0xFFFBF0D9),
        EpubReaderTheme.night => const Color(0xFF202225),
        EpubReaderTheme.black => const Color(0xFF000000),
      };

  Color _getTextColor(AppColors ac) => switch (_readerTheme) {
        EpubReaderTheme.system => ac.txt,
        EpubReaderTheme.light => const Color(0xFF1A1A1A),
        EpubReaderTheme.sepia => const Color(0xFF4A3728),
        EpubReaderTheme.night => const Color(0xFFE2E4E8),
        EpubReaderTheme.black => const Color(0xFFDCDCDC),
      };

  Color _getBarColor(AppColors ac) => switch (_readerTheme) {
        EpubReaderTheme.system => ac.surf,
        EpubReaderTheme.light => const Color(0xFFF5F6F8),
        EpubReaderTheme.sepia => const Color(0xFFF3E7CA),
        EpubReaderTheme.night => const Color(0xFF181A1C),
        EpubReaderTheme.black => const Color(0xFF111111),
      };

  Color _getBorderColor(AppColors ac) => switch (_readerTheme) {
        EpubReaderTheme.system => ac.bdr,
        EpubReaderTheme.light => const Color(0xFFE4E7EC),
        EpubReaderTheme.sepia => const Color(0xFFE5D5B3),
        EpubReaderTheme.night => const Color(0xFF2E3236),
        EpubReaderTheme.black => const Color(0xFF222222),
      };

  Color _getSecondaryTextColor(AppColors ac) => switch (_readerTheme) {
        EpubReaderTheme.system => ac.txt2,
        EpubReaderTheme.light => const Color(0xFF667085),
        EpubReaderTheme.sepia => const Color(0xFF7A6553),
        EpubReaderTheme.night => const Color(0xFF9AA2AB),
        EpubReaderTheme.black => const Color(0xFF888888),
      };

  Color _getAccentColor(AppColors ac) => switch (_readerTheme) {
        EpubReaderTheme.sepia => const Color(0xFFB45309),
        _ => ac.primary,
      };

  TextStyle _getTextStyle({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle fontStyle = FontStyle.normal,
    TextDecoration decoration = TextDecoration.none,
    double? height,
  }) {
    final base = TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      height: height,
    );
    return switch (_fontFamily) {
      EpubFontFamily.serif => GoogleFonts.merriweather(textStyle: base),
      EpubFontFamily.sans => GoogleFonts.inter(textStyle: base),
      EpubFontFamily.mono => GoogleFonts.firaCode(textStyle: base),
    };
  }

  Future<void> _load() async {
    try {
      Uint8List bytes;
      if (widget.localFilePath != null && File(widget.localFilePath!).existsSync()) {
        bytes = await File(widget.localFilePath!).readAsBytes();
      } else if (widget.url.startsWith('/') || widget.url.startsWith('file:')) {
        final path = widget.url.startsWith('file:') ? Uri.parse(widget.url).toFilePath() : widget.url;
        bytes = await File(path).readAsBytes();
      } else if (widget.contentId != null) {
        final path = await AcademicContentRepository.instance.ensureLocalCopy(
          contentId: widget.contentId!,
          fileUrl: widget.url,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
        bytes = await File(path).readAsBytes();
      } else {
        final resp = await http.get(Uri.parse(widget.url)).timeout(const Duration(minutes: 3));
        if (resp.statusCode != 200) {
          throw Exception('Server returned HTTP ${resp.statusCode}');
        }
        bytes = resp.bodyBytes;
      }

      final doc = EpubParser.parse(bytes);
      if (doc.chapters.isEmpty) {
        throw const FormatException('This EPUB contains no readable chapters.');
      }

      int startChapter = 0;
      final contentId = widget.contentId;
      final userId = widget.userId;
      if (contentId != null && userId != null) {
        try {
          final saved = await AcademicContentRepository.instance.savedReadPage(contentId: contentId, userId: userId);
          if (saved > 0 && saved <= doc.chapters.length) {
            startChapter = saved - 1;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _doc = doc;
          _currentChapter = startChapter;
          _loading = false;
        });
        _recordProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load EPUB reader: $e';
          _loading = false;
        });
      }
    }
  }

  void _recordProgress() {
    final doc = _doc;
    final contentId = widget.contentId;
    final userId = widget.userId;
    if (doc == null || contentId == null || userId == null) return;

    final page = _currentChapter + 1;
    final total = doc.chapters.length;
    AcademicContentRepository.instance.recordReadPosition(
      contentId: contentId,
      userId: userId,
      page: page,
      totalPages: total,
    );
    AuthService.instance.setContinueReading(
      userId,
      itemId: contentId,
      title: widget.title,
      page: page,
      totalPages: total,
    );
  }

  void _changeChapter(int newIndex) {
    if (_doc == null || newIndex < 0 || newIndex >= _doc!.chapters.length) return;
    setState(() {
      _currentChapter = newIndex;
      _scrollProgress = 0.0;
    });
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
    _recordProgress();
  }

  void _executeSearch(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.length < 2 || _doc == null) {
      setState(() {
        _searchResults = [];
        _searchPerformed = clean.isNotEmpty;
      });
      return;
    }

    final results = <_EpubSearchResult>[];
    for (var i = 0; i < _doc!.chapters.length; i++) {
      final ch = _doc!.chapters[i];
      final plain = ch.content.toLowerCase();
      var startIdx = 0;
      var matchesInChapter = 0;
      while ((startIdx = plain.indexOf(clean, startIdx)) != -1 && matchesInChapter < 3) {
        final snippetStart = (startIdx - 35).clamp(0, ch.content.length);
        final snippetEnd = (startIdx + clean.length + 45).clamp(0, ch.content.length);
        final snippet = '…${ch.content.substring(snippetStart, snippetEnd).replaceAll('\n', ' ').trim()}…';
        results.add(_EpubSearchResult(
          chapterIndex: i,
          chapterTitle: ch.title,
          snippet: snippet,
        ));
        startIdx += clean.length;
        matchesInChapter++;
      }
      if (results.length >= 25) break;
    }

    setState(() {
      _searchResults = results;
      _searchPerformed = true;
    });
  }

  void _showAppearanceSheet(BuildContext context, AppColors ac) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _getBarColor(ac),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final txtColor = _getTextColor(ac);
          final secColor = _getSecondaryTextColor(ac);
          final bdrColor = _getBorderColor(ac);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: secColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Reader Settings', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: txtColor)),
                  const SizedBox(height: 18),

                  // Theme Selector
                  Text('BACKGROUND & THEME', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: secColor, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildThemeChip(EpubReaderTheme.sepia, 'Sepia', const Color(0xFFFBF0D9), const Color(0xFF4A3728), setSheetState),
                      const SizedBox(width: 8),
                      _buildThemeChip(EpubReaderTheme.light, 'Light', const Color(0xFFFFFFFF), const Color(0xFF1A1A1A), setSheetState),
                      const SizedBox(width: 8),
                      _buildThemeChip(EpubReaderTheme.night, 'Dark', const Color(0xFF202225), const Color(0xFFE2E4E8), setSheetState),
                      const SizedBox(width: 8),
                      _buildThemeChip(EpubReaderTheme.black, 'OLED', const Color(0xFF000000), const Color(0xFFDCDCDC), setSheetState),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Font Family Selector
                  Text('TYPOGRAPHY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: secColor, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildFontChip(EpubFontFamily.serif, 'Serif', 'Merriweather', setSheetState, txtColor, bdrColor),
                      const SizedBox(width: 8),
                      _buildFontChip(EpubFontFamily.sans, 'Sans', 'Inter', setSheetState, txtColor, bdrColor),
                      const SizedBox(width: 8),
                      _buildFontChip(EpubFontFamily.mono, 'Mono', 'Fira Code', setSheetState, txtColor, bdrColor),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Font Size & Line Spacing
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FONT SIZE (${_fontSize.toInt()}pt)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: secColor, letterSpacing: 0.8)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(40, 38),
                                    padding: EdgeInsets.zero,
                                    side: BorderSide(color: bdrColor),
                                  ),
                                  onPressed: _fontSize > 13
                                      ? () {
                                          setState(() => _fontSize -= 1);
                                          setSheetState(() {});
                                        }
                                      : null,
                                  child: Icon(Icons.remove, size: 18, color: txtColor),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(40, 38),
                                    padding: EdgeInsets.zero,
                                    side: BorderSide(color: bdrColor),
                                  ),
                                  onPressed: _fontSize < 28
                                      ? () {
                                          setState(() => _fontSize += 1);
                                          setSheetState(() {});
                                        }
                                      : null,
                                  child: Icon(Icons.add, size: 18, color: txtColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LINE SPACING', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: secColor, letterSpacing: 0.8)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildHeightChip(1.5, 'Normal', setSheetState, txtColor, bdrColor),
                                const SizedBox(width: 8),
                                _buildHeightChip(1.8, 'Relaxed', setSheetState, txtColor, bdrColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeChip(EpubReaderTheme theme, String label, Color bg, Color fg, StateSetter setSheetState) {
    final isSelected = _readerTheme == theme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _readerTheme = theme);
          setSheetState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0x33888888),
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: fg),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontChip(EpubFontFamily f, String label, String sampleFont, StateSetter setSheetState, Color txt, Color bdr) {
    final isSelected = _fontFamily == f;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.12) : Colors.transparent,
          side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : bdr, width: isSelected ? 2 : 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          setState(() => _fontFamily = f);
          setSheetState(() {});
        },
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : txt,
          ),
        ),
      ),
    );
  }

  Widget _buildHeightChip(double h, String label, StateSetter setSheetState, Color txt, Color bdr) {
    final isSelected = (_lineHeight - h).abs() < 0.05;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          backgroundColor: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.12) : Colors.transparent,
          side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : bdr, width: isSelected ? 2 : 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setState(() => _lineHeight = h);
          setSheetState(() {});
        },
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : txt,
          ),
        ),
      ),
    );
  }

  void _showChapterDrawer(BuildContext context, AppColors ac) {
    if (_doc == null) return;
    final txtColor = _getTextColor(ac);
    final secColor = _getSecondaryTextColor(ac);
    final bdrColor = _getBorderColor(ac);
    final barColor = _getBarColor(ac);

    String filter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: barColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final chapters = _doc!.chapters.where((c) {
            if (filter.isEmpty) return true;
            return c.title.toLowerCase().contains(filter.toLowerCase());
          }).toList();

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: _getAccentColor(ac), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Table of Contents', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: txtColor)),
                              Text('${_doc!.chapters.length} sections • ${_doc!.author}', style: GoogleFonts.inter(fontSize: 12, color: secColor)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: secColor),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextField(
                      style: TextStyle(color: txtColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search chapters…',
                        hintStyle: TextStyle(color: secColor, fontSize: 13),
                        prefixIcon: Icon(Icons.search, size: 18, color: secColor),
                        filled: true,
                        fillColor: _getBgColor(ac),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: bdrColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: bdrColor)),
                      ),
                      onChanged: (val) => setModalState(() => filter = val.trim()),
                    ),
                  ),
                  Divider(height: 1, color: bdrColor),
                  Expanded(
                    child: ListView.separated(
                      itemCount: chapters.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: bdrColor.withValues(alpha: 0.5)),
                      itemBuilder: (_, i) {
                        final ch = chapters[i];
                        final origIdx = _doc!.chapters.indexOf(ch);
                        final isCurrent = origIdx == _currentChapter;

                        return ListTile(
                          selected: isCurrent,
                          selectedTileColor: _getAccentColor(ac).withValues(alpha: 0.12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: CircleAvatar(
                            radius: 13,
                            backgroundColor: isCurrent ? _getAccentColor(ac) : bdrColor.withValues(alpha: 0.5),
                            child: Text(
                              '${origIdx + 1}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCurrent ? Colors.white : txtColor),
                            ),
                          ),
                          title: Text(
                            ch.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCurrent ? _getAccentColor(ac) : txtColor,
                            ),
                          ),
                          subtitle: ch.wordCount > 0
                              ? Text(
                                  '~${(ch.wordCount / 200).ceil()} min read (${ch.wordCount} words)',
                                  style: TextStyle(fontSize: 11, color: secColor),
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _changeChapter(origIdx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageZoomDialog(BuildContext context, Uint8List imageBytes, String alt) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            if (alt.isNotEmpty)
              Positioned(
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    alt,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    if (_loading) {
      return Container(
        color: _getBgColor(ac),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: _getAccentColor(ac),
                value: _downloadProgress > 0 && _downloadProgress < 1 ? _downloadProgress : null,
              ),
              const SizedBox(height: 16),
              Text(
                _downloadProgress > 0 && _downloadProgress < 1
                    ? 'Downloading book (${(_downloadProgress * 100).round()}%)…'
                    : 'Opening EPUB reader…',
                style: TextStyle(color: _getSecondaryTextColor(ac), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _doc == null) {
      return Container(
        color: _getBgColor(ac),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: _getTextColor(ac)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: ac.red),
                      const SizedBox(height: 12),
                      Text(_error ?? 'Could not open EPUB', textAlign: TextAlign.center, style: TextStyle(color: _getTextColor(ac))),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _load();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final chapter = _doc!.chapters[_currentChapter];
    final totalChapters = _doc!.chapters.length;
    final bgColor = _getBgColor(ac);
    final txtColor = _getTextColor(ac);
    final secColor = _getSecondaryTextColor(ac);
    final barColor = _getBarColor(ac);
    final bdrColor = _getBorderColor(ac);
    final accent = _getAccentColor(ac);

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Reader Header
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: barColor,
                border: Border(bottom: BorderSide(color: bdrColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, size: 22, color: txtColor),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted_rounded, size: 21),
                    tooltip: 'Table of Contents',
                    color: txtColor,
                    onPressed: () => _showChapterDrawer(context, ac),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: txtColor),
                        ),
                        Text(
                          '${_doc!.title} • ${((_currentChapter + 1) / totalChapters * 100).round()}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11, color: secColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isSearching ? Icons.search_off_rounded : Icons.search_rounded, size: 21, color: txtColor),
                    tooltip: 'Search Book',
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchResults = [];
                          _searchCtrl.clear();
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 21),
                    tooltip: 'Reader Appearance',
                    color: txtColor,
                    onPressed: () => _showAppearanceSheet(context, ac),
                  ),
                ],
              ),
            ),
          ),

          // Thin reading progress indicator
          LinearProgressIndicator(
            value: ((_currentChapter + _scrollProgress) / totalChapters).clamp(0.0, 1.0),
            backgroundColor: barColor,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
            minHeight: 2.5,
          ),

          // Search Panel (when active)
          if (_isSearching)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(color: barColor, border: Border(bottom: BorderSide(color: bdrColor))),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: txtColor, fontSize: 13.5),
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search across this book…',
                      hintStyle: TextStyle(color: secColor, fontSize: 13),
                      prefixIcon: Icon(Icons.search, size: 18, color: secColor),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              color: secColor,
                              onPressed: () {
                                _searchCtrl.clear();
                                _executeSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: bgColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: bdrColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: bdrColor)),
                    ),
                    onSubmitted: _executeSearch,
                    onChanged: _executeSearch,
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      margin: const EdgeInsets.only(top: 8),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: bdrColor.withValues(alpha: 0.5)),
                        itemBuilder: (ctx, idx) {
                          final res = _searchResults[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            title: Text(res.chapterTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: accent)),
                            subtitle: Text(res.snippet, style: TextStyle(fontSize: 11.5, color: txtColor)),
                            onTap: () {
                              setState(() => _isSearching = false);
                              _changeChapter(res.chapterIndex);
                            },
                          );
                        },
                      ),
                    )
                  else if (_searchPerformed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('No matches found for "${_searchCtrl.text}"', style: TextStyle(fontSize: 12, color: secColor)),
                    ),
                ],
              ),
            ),

          // Chapter Reading Content
          Expanded(
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 740),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chapter Title
                          Text(
                            chapter.title,
                            style: _getTextStyle(
                              fontSize: _fontSize + 7,
                              fontWeight: FontWeight.bold,
                              color: txtColor,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Render Blocks
                          if (chapter.blocks.isNotEmpty)
                            ...chapter.blocks.map((block) => _buildBlockWidget(block, ac))
                          else
                            SelectableText(
                              chapter.content,
                              style: _getTextStyle(
                                fontSize: _fontSize,
                                height: _lineHeight,
                                color: txtColor,
                              ),
                            ),

                          const SizedBox(height: 48),

                          // End of Chapter Transition Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: bdrColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.bookmark_added_rounded, color: accent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Completed Section ${_currentChapter + 1} of $totalChapters',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: txtColor),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_currentChapter < totalChapters - 1) ...[
                                  Text(
                                    'Next: ${_doc!.chapters[_currentChapter + 1].title}',
                                    style: TextStyle(fontSize: 12, color: secColor),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: () => _changeChapter(_currentChapter + 1),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                    label: const Text('Read Next Chapter'),
                                  ),
                                ] else ...[
                                  Text(
                                    '🎉 Congratulations! You have reached the final chapter of ${_doc!.title}.',
                                    style: TextStyle(fontSize: 13, color: txtColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Navigation Bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: barColor,
                border: Border(top: BorderSide(color: bdrColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentChapter > 0 ? () => _changeChapter(_currentChapter - 1) : null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: bdrColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: Icon(Icons.chevron_left_rounded, size: 18, color: _currentChapter > 0 ? txtColor : secColor),
                    label: Text('Prev', style: TextStyle(color: _currentChapter > 0 ? txtColor : secColor, fontSize: 12)),
                  ),
                  Text(
                    'Section ${_currentChapter + 1} of $totalChapters • ${((_scrollProgress) * 100).toInt()}%',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: secColor),
                  ),
                  ElevatedButton.icon(
                    onPressed: _currentChapter < totalChapters - 1 ? () => _changeChapter(_currentChapter + 1) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Next', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockWidget(EpubBlock block, AppColors ac) {
    final txtColor = _getTextColor(ac);
    final bdrColor = _getBorderColor(ac);
    final accent = _getAccentColor(ac);
    final secColor = _getSecondaryTextColor(ac);

    switch (block) {
      case EpubHeadingBlock h:
        final headingSize = switch (h.level) {
          1 => _fontSize + 6,
          2 => _fontSize + 4,
          3 => _fontSize + 2,
          _ => _fontSize + 1,
        };
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: SelectableText(
            h.text,
            style: _getTextStyle(
              fontSize: headingSize,
              fontWeight: FontWeight.bold,
              color: txtColor,
              height: 1.35,
            ),
          ),
        );

      case EpubParagraphBlock p:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SelectableText.rich(
            TextSpan(
              children: p.spans.map((s) {
                return TextSpan(
                  text: s.text,
                  style: _getTextStyle(
                    fontSize: _fontSize,
                    height: _lineHeight,
                    color: txtColor,
                    fontWeight: s.isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: s.isItalic ? FontStyle.italic : FontStyle.normal,
                    decoration: s.isUnderline ? TextDecoration.underline : TextDecoration.none,
                  ),
                );
              }).toList(),
            ),
          ),
        );

      case EpubBlockquoteBlock b:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(width: 3.5, color: accent)),
            color: bdrColor.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          ),
          child: SelectableText(
            b.text,
            style: _getTextStyle(
              fontSize: _fontSize - 0.5,
              height: _lineHeight,
              fontStyle: FontStyle.italic,
              color: txtColor,
            ),
          ),
        );

      case EpubCodeBlock c:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _readerTheme == EpubReaderTheme.sepia ? const Color(0xFFF0E4C5) : bdrColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bdrColor),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              c.code,
              style: GoogleFonts.firaCode(fontSize: _fontSize - 2, height: 1.45, color: txtColor),
            ),
          ),
        );

      case EpubTableBlock tbl:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: bdrColor),
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                if (tbl.headers.isNotEmpty)
                  TableRow(
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.1)),
                    children: tbl.headers
                        .map((hdr) => Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(hdr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: _fontSize - 1, color: txtColor)),
                            ))
                        .toList(),
                  ),
                ...tbl.rows.map((row) => TableRow(
                      children: row
                          .map((cell) => Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(cell, style: TextStyle(fontSize: _fontSize - 1, color: txtColor)),
                              ))
                          .toList(),
                    )),
              ],
            ),
          ),
        );

      case EpubImageBlock img:
        if (img.imageBytes == null || img.imageBytes!.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => _showImageZoomDialog(context, img.imageBytes!, img.alt),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  img.imageBytes!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(16),
                    color: bdrColor.withValues(alpha: 0.15),
                    child: Text('Image unavailable (${img.alt})', style: TextStyle(fontSize: 12, color: secColor)),
                  ),
                ),
              ),
            ),
          ),
        );

      case EpubListBlock list:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(list.items.length, (idx) {
              final prefix = list.isOrdered ? '${idx + 1}. ' : '• ';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prefix, style: TextStyle(fontWeight: FontWeight.bold, fontSize: _fontSize, color: txtColor)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SelectableText(
                        list.items[idx],
                        style: _getTextStyle(fontSize: _fontSize, height: _lineHeight, color: txtColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );

      case EpubDividerBlock():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: bdrColor, thickness: 1),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

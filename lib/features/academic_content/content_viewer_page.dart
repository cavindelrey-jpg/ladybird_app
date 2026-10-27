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
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../core/docx_parser.dart';
import '../../core/epub_parser.dart';
import '../../core/result.dart';
import '../../models/academic_content.dart';
import '../../models/app_user.dart';
import '../../models/entitlement.dart';
import '../../config/branding.dart';
import '../../repositories/academic_content_repository.dart';
import '../../repositories/xp_repository.dart';
import '../../widgets/paper_unlock_sheet.dart';
import '../../widgets/premium_unlock_sheet.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/application_shell.dart';
import '../../widgets/widgets.dart' show showToast;
import '../../widgets/web_embed/web_embed.dart';
import 'content_delete_dialog.dart';
import 'content_details_page.dart';
import 'content_edit_page.dart';
import 'library_home_page.dart';

import '../../widgets/skeleton_spinner.dart';
enum ViewableFileKind { image, pdf, video, docx, pptx, epub, txt }

/// Maps a file's extension to a kind this viewer can render, or null if
/// it should fall back to opening externally.
ViewableFileKind? viewableKindFor(String url) {
  final path = Uri.tryParse(url)?.path ?? url.split('?').first;
  final lastSegment = path.split('/').last;
  final ext = lastSegment.contains('.') ? lastSegment.split('.').last.toLowerCase() : '';
  const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
  const pdfExts = {'pdf'};
  const videoExts = {'mp4', 'mov', 'avi', 'm4v', 'webm', 'mkv'};
  const docxExts = {'docx'};
  const pptxExts = {'pptx', 'ppt', 'doc', 'xls', 'xlsx'};
  const epubExts = {'epub'};
  const txtExts = {'txt', 'md', 'csv', 'json', 'log'};
  if (imageExts.contains(ext)) return ViewableFileKind.image;
  if (pdfExts.contains(ext)) return ViewableFileKind.pdf;
  if (videoExts.contains(ext)) return ViewableFileKind.video;
  if (docxExts.contains(ext)) return ViewableFileKind.docx;
  if (pptxExts.contains(ext)) return ViewableFileKind.pptx;
  if (epubExts.contains(ext)) return ViewableFileKind.epub;
  if (txtExts.contains(ext)) return ViewableFileKind.txt;
  return null;
}

class ContentViewerPage extends StatefulWidget {
  final AcademicContent? content;
  final AppUser? user;
  final String fileUrl;
  final String title;
  final ViewableFileKind kind;

  /// Both required to track/resume reading position (Home "Continue Reading")
  final String? contentId;
  final String? userId;

  /// Path to a device-local copy from AcademicContentRepository's offline download
  final String? localFilePath;

  ContentViewerPage({
    super.key,
    this.content,
    this.user,
    String? fileUrl,
    String? title,
    ViewableFileKind? kind,
    String? contentId,
    String? userId,
    this.localFilePath,
  })  : fileUrl = fileUrl ?? content?.fileUrl ?? '',
        title = title ?? content?.title ?? 'Document Viewer',
        kind = kind ??
            viewableKindFor(fileUrl ?? content?.fileUrl ?? '') ??
            (content?.contentType == ContentType.video
                ? ViewableFileKind.video
                : ViewableFileKind.pdf),
        contentId = contentId ?? content?.id,
        userId = userId ?? user?.id;

  @override
  State<ContentViewerPage> createState() => _ContentViewerPageState();
}

class _ContentViewerPageState extends State<ContentViewerPage> {
  String? _resolvedLocalPath;
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _resolvedLocalPath = widget.localFilePath;
    _initDocumentSession();
  }

  Future<void> _initDocumentSession() async {
    final cid = widget.contentId;
    if (cid == null || cid.isEmpty) return;

    if (!_tracked) {
      _tracked = true;
      unawaited(AcademicContentRepository.instance.incrementViews(cid));
      unawaited(AcademicContentRepository.instance.incrementDownloads(cid));
      final uid = widget.userId ?? widget.user?.id ?? '';
      if (uid.isNotEmpty) {
        unawaited(AcademicContentRepository.instance.recordView(cid, uid));
      }
    }

    if (!kIsWeb && _resolvedLocalPath == null) {
      try {
        final p = await AcademicContentRepository.instance.offlineFilePath(cid);
        if (mounted && p != null) {
          setState(() => _resolvedLocalPath = p);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cid = widget.contentId;
    final currentUser = widget.user ?? AppUser.guest();

    if (widget.content != null) {
      return _buildShellWithContent(context, ac, widget.content!, currentUser);
    }

    if (cid != null && cid.isNotEmpty) {
      return StreamBuilder<AcademicContent?>(
        stream: AcademicContentRepository.instance.watchOne(cid),
        builder: (context, snap) {
          return _buildShellWithContent(context, ac, snap.data, currentUser);
        },
      );
    }

    return _buildShellWithContent(context, ac, null, currentUser);
  }

  Widget _buildShellWithContent(
    BuildContext context,
    AppColors ac,
    AcademicContent? item,
    AppUser currentUser,
  ) {
    final fileUrl = widget.fileUrl.isNotEmpty
        ? widget.fileUrl
        : (item?.fileUrl ?? '');
    final title = widget.title.isNotEmpty
        ? widget.title
        : (item?.title ?? 'Document Viewer');
    final kind = widget.kind;
    final contentId = widget.contentId ?? item?.id;
    final userId = widget.userId ?? (currentUser.id.isNotEmpty ? currentUser.id : null);
    final localPath = _resolvedLocalPath;
    final isPastPaper = item?.contentType == ContentType.pastPaper;
    final isViewOnly = item?.isViewOnly ?? isPastPaper;
    final canEdit = item != null &&
        !isViewOnly &&
        !currentUser.isGuest &&
        (currentUser.canUploadContent || item.uploadedBy == currentUser.id);

    final innerViewer = switch (kind) {
      ViewableFileKind.image =>
        _ImageViewer(url: fileUrl, localFilePath: localPath),
      ViewableFileKind.pdf => _PdfViewer(
          url: fileUrl,
          localFilePath: localPath,
          contentId: contentId,
          userId: userId,
          isViewOnly: isViewOnly,
        ),
      ViewableFileKind.video =>
        _VideoViewer(url: fileUrl, localFilePath: localPath),
      ViewableFileKind.docx => _DocxViewer(
          url: fileUrl,
          localFilePath: localPath,
          contentId: contentId,
          isViewOnly: isViewOnly,
        ),
      ViewableFileKind.pptx => _ExternalDocFallback(fileUrl: fileUrl),
      ViewableFileKind.epub => _EpubViewer(
          url: fileUrl,
          localFilePath: localPath,
          contentId: contentId,
          isViewOnly: isViewOnly,
        ),
      ViewableFileKind.txt => _TextViewer(
          url: fileUrl,
          localFilePath: localPath,
          contentId: contentId,
          isViewOnly: isViewOnly,
        ),
    };

    final viewerBody = (kIsWeb &&
            (kind == ViewableFileKind.pdf || kind == ViewableFileKind.pptx))
        ? _WebDocBody(fileUrl: fileUrl, kind: kind)
        : (isViewOnly ? innerViewer : SelectionArea(child: innerViewer));

    final isGatedType = item != null &&
        (item.contentType == ContentType.pastPaper ||
            item.contentType == ContentType.note ||
            item.contentType == ContentType.book);
    final needsUnlockCheck = isGatedType &&
        !currentUser.isSilver &&
        !currentUser.isGold &&
        Branding.current.xpEconomyEnabled;

    final effectiveViewerBody = needsUnlockCheck
        ? StreamBuilder<bool>(
            stream: XpRepository.instance.watchIsContentUnlocked(
              currentUser,
              contentId: item.id,
              contentType: item.contentType,
            ),
            builder: (context, snap) {
              final isUnlocked = snap.data ?? false;
              if (isUnlocked) return viewerBody;
              final cost = XpRepository.costForContentType(item.contentType);
              return Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: ac.surf,
                    borderRadius: BorderRadius.circular(Rad.lg),
                    border: Border.all(color: ac.bdr),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(color: ac.goldBg, shape: BoxShape.circle),
                        child: Icon(Icons.lock_rounded, color: ac.gold, size: 30),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${item.contentType.label} Locked',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: ac.txt),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This resource is gated for Bronze members. Unlock with XP or upgrade to Silver for unlimited access.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => showContentUnlockSheet(
                            context,
                            user: currentUser,
                            contentId: item.id,
                            contentTitle: item.title,
                            contentType: item.contentType,
                          ),
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: Text('Unlock with $cost XP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ac.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: ac.surf,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl)),
                            ),
                            builder: (_) => PremiumUnlockSheet(
                              userId: currentUser.id,
                              initialTier: EntitlementTier.silver,
                              onUnlockSuccess: () {},
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Upgrade to Silver / Gold'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        : viewerBody;

    return ApplicationShell(
      user: currentUser,
      currentTitle: title,
      subtitle: item != null
          ? [
              if (item.subject.isNotEmpty) item.subject,
              if (item.level.isNotEmpty) item.level,
              item.contentType.label,
            ].join(' • ')
          : null,
      currentDestination: isPastPaper
          ? AppNavDestination.pastQuestions
          : AppNavDestination.academicLibrary,
      breadcrumbs: [
        ShellBreadcrumb(
          label: isPastPaper ? 'Past Questions' : 'Academic Library',
          icon: isPastPaper
              ? Icons.description_rounded
              : Icons.folder_copy_rounded,
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => LibraryHomePage(
                user: currentUser,
                navDestination: isPastPaper
                    ? AppNavDestination.pastQuestions
                    : AppNavDestination.academicLibrary,
              ),
            ),
          ),
        ),
        if (item != null && item.subject.isNotEmpty)
          ShellBreadcrumb(label: item.subject),
        ShellBreadcrumb(label: title),
      ],
      headerActions: [
        if (isViewOnly)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: ac.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Rad.sm),
              border: Border.all(color: ac.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: ac.primary),
                const SizedBox(width: 5),
                Text('Protected Read-Only',
                    style: AppText.caption.copyWith(
                      color: ac.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    )),
              ],
            ),
          ),
        if (!isViewOnly && item != null && !currentUser.isGuest && currentUser.id.isNotEmpty)
          StreamBuilder<bool>(
            stream: AcademicContentRepository.instance
                .watchIsSaved(item.id, currentUser.id),
            builder: (context, savedSnap) {
              final saved = savedSnap.data ?? false;
              return IconButton(
                icon: Icon(
                  saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: saved ? ac.gold : ac.txt2,
                  size: 20,
                ),
                tooltip: saved ? 'Saved in Library' : 'Save / Bookmark',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await AcademicContentRepository.instance
                      .toggleSave(item.id, currentUser.id);
                  if (!saved && (item.fileUrl ?? '').isNotEmpty && !kIsWeb) {
                    unawaited(
                      AcademicContentRepository.instance.downloadForOffline(item),
                    );
                  }
                },
              );
            },
          ),
        if (item != null)
          IconButton(
            icon: Icon(Icons.info_outline_rounded, size: 20, color: ac.txt2),
            tooltip: 'Document Details',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ContentDetailsPage(
                    contentId: item.id,
                    user: currentUser,
                  ),
                ),
              );
            },
          ),
        if (canEdit) ...[
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: ac.txt2),
            tooltip: 'Edit Metadata',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ContentEditPage(content: item, user: currentUser),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: ac.red),
            tooltip: 'Delete Document',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ContentDeleteDialog(
                  content: item,
                  onDeleted: () => Navigator.of(context).maybePop(),
                ),
              );
            },
          ),
        ],
        if (!isViewOnly && fileUrl.isNotEmpty)
          IconButton(
            icon: Icon(Icons.open_in_new_rounded, size: 20, color: ac.txt2),
            tooltip: 'Open externally / in browser',
            onPressed: () async {
              final uri = Uri.tryParse(fileUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        if (!kIsWeb)
          _ViewerSaveOfflineAction(
            contentId: contentId,
            fileUrl: fileUrl,
            title: title,
            localFilePath: localPath,
          ),
      ],
      contextualPanel: item != null
          ? BookDetailsContextualPanel(
              content: item,
              user: currentUser,
            )
          : LibraryContextualPanel(
              user: currentUser,
              isPastQuestions: isPastPaper,
            ),
      child: Container(
        color: kind == ViewableFileKind.video ? Colors.black : ac.bg,
        child: effectiveViewerBody,
      ),
    );
  }
}

// Web document body: renders the file inside a browser iframe. PDFs load
// inline; Office files go through the Office Online embed viewer. A toolbar
// row offers "Open in new tab" as a guaranteed fallback.
class _WebDocBody extends StatelessWidget {
  final String fileUrl;
  final ViewableFileKind kind;
  const _WebDocBody({required this.fileUrl, required this.kind});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final embedUrl = kind == ViewableFileKind.pdf ? fileUrl : officeViewerUrl(fileUrl);
    return Column(
      children: [
        Container(
          color: ac.surf,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Icon(
              kind == ViewableFileKind.pptx
                  ? Icons.slideshow_rounded
                  : kind == ViewableFileKind.docx
                      ? Icons.description_rounded
                      : Icons.picture_as_pdf_rounded,
              size: 18, color: ac.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(
              kind == ViewableFileKind.pptx ? 'Presentation' : kind == ViewableFileKind.docx ? 'Document' : 'PDF',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.txt2))),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(embedUrl), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open in new tab'),
            ),
          ]),
        ),
        Divider(height: 1, color: ac.bdr),
        Expanded(child: WebDocEmbed(url: embedUrl)),
      ],
    );
  }
}

// Non-web fallback for presentations (no in-app renderer on mobile): opens
// the Office Online viewer in the device browser.
class _ExternalDocFallback extends StatelessWidget {
  final String fileUrl;
  const _ExternalDocFallback({required this.fileUrl});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.slideshow_rounded, size: 52, color: ac.muted),
          const SizedBox(height: 14),
          Text('Presentation', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 6),
          Text('Open this presentation in your browser to view all slides.',
              textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => launchUrl(Uri.parse(officeViewerUrl(fileUrl)), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open presentation'),
          ),
        ]),
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
    if (contentId != null && await AcademicContentRepository.instance.isSavedForOffline(contentId)) {
      if (mounted) setState(() => _isSaved = true);
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

    final res = await AcademicContentRepository.instance.saveForOffline(
      contentId: contentId,
      fileUrl: widget.fileUrl,
      title: widget.title,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _isSaved = res is Success<void>;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res is Failure<void>
          ? res.message
          : 'Saved for offline. Find it under Library → Available Offline.'),
    ));
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
            child: SkeletonSpinner(
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
                progress == null ? child : const Center(child: SkeletonSpinner()),
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
  final bool isViewOnly;
  const _PdfViewer({
    required this.url,
    this.localFilePath,
    this.contentId,
    this.userId,
    this.isViewOnly = false,
  });

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  late final Future<(int, String?)> _readyFuture = _prepare();
  double _downloadProgress = 0;

  Future<(int, String?)> _prepare() async {
    final contentId = widget.contentId;
    final userId = widget.userId;

    int page = 1;
    if (contentId != null && userId != null) {
      try {
        page = await AcademicContentRepository.instance
            .savedReadPage(contentId: contentId, userId: userId);
      } catch (_) {}
    }

    String? path = widget.localFilePath;
    if (path == null && contentId != null && !kIsWeb) {
      try {
        path = await AcademicContentRepository.instance.ensureLocalCopy(
          contentId: contentId,
          fileUrl: widget.url,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      } catch (_) {
        path = null;
      }
    }

    return (page, path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(int, String?)>(
      future: _readyFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return _PdfViewerBodyState.friendlyError(snap.error!);
        }
        if (!snap.hasData) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SkeletonSpinner(
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
          isViewOnly: widget.isViewOnly,
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
  final bool isViewOnly;
  const _PdfViewerBody({
    required this.url,
    this.localFilePath,
    required this.initialPage,
    this.contentId,
    this.userId,
    this.isViewOnly = false,
  });

  @override
  State<_PdfViewerBody> createState() => _PdfViewerBodyState();
}

class _PdfViewerBodyState extends State<_PdfViewerBody> {
  // pdfrx (PDFium) instead of pdfx: pdfx rasterised each page to an image,
  // so "select text -> copy -> share" was impossible on any PDF even
  // though this file's header promised it. pdfrx keeps the text layer.
  final _controller = PdfViewerController();
  Timer? _saveDebounce;
  PdfTextSelection? _selection;

  void _onPageChanged(int? page) {
    final contentId = widget.contentId;
    final userId = widget.userId;
    if (page == null || contentId == null || userId == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () {
      final total = _controller.isReady ? _controller.pageCount : page;
      AcademicContentRepository.instance.recordReadPosition(
        contentId: contentId,
        userId: userId,
        page: page,
        totalPages: total,
      );
    });
  }

  Future<String> _selectedText() async => (await _selection?.getSelectedText())?.trim() ?? '';

  Future<void> _copySelection() async {
    final text = await _selectedText();
    if (text.isEmpty || !mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showToast(context, 'Copied ${text.length} characters');
  }

  Future<void> _shareSelection() async {
    final text = await _selectedText();
    if (text.isEmpty) return;
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) showToast(context, 'Sharing isn\'t available here — copied instead.');
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Widget _error(BuildContext context, Object error) => friendlyError(error);

  /// Never show raw exception text to a student.
  static Widget friendlyError(Object error) {
    final offline = error is SocketException || error.toString().contains('SocketException') ||
        error.toString().contains('ClientException');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          offline
              ? 'This document isn\'t saved on your device and you\'re offline. Connect to open it — and tap "Save for offline" to read it without internet next time.'
              : 'This PDF couldn\'t be opened. The file may be damaged or no longer available.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = PdfViewerParams(
      backgroundColor: AppColors.of(context).surf3,
      onPageChanged: _onPageChanged,
      errorBannerBuilder: (context, error, stack, ref) => _error(context, error),
      textSelectionParams: PdfTextSelectionParams(
        onTextSelectionChange: (sel) {
          if (!mounted) return;
          setState(() => _selection = sel.hasSelectedText ? sel : null);
        },
      ),
    );
    final viewer = widget.localFilePath != null
        ? PdfViewer.file(widget.localFilePath!, controller: _controller, params: params, initialPageNumber: widget.initialPage)
        : PdfViewer.uri(Uri.parse(widget.url), controller: _controller, params: params, initialPageNumber: widget.initialPage);
    final ac = AppColors.of(context);
    return Stack(children: [
      Positioned.fill(child: viewer),
      if (_selection != null && !widget.isViewOnly)
        Positioned(
          left: 16, right: 16, bottom: 16,
          child: SafeArea(
            child: Material(
              elevation: 6,
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                TextButton.icon(onPressed: _copySelection, icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Copy')),
                TextButton.icon(onPressed: _shareSelection, icon: const Icon(Icons.share_rounded, size: 18), label: const Text('Share')),
                TextButton.icon(
                  onPressed: () => _controller.textSelectionDelegate.clearTextSelection(),
                  icon: const Icon(Icons.close_rounded, size: 18), label: const Text('Clear')),
              ]),
            ),
          ),
        ),
    ]);
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
      return const Center(child: SkeletonSpinner(color: Colors.white));
    }
    return Center(child: Chewie(controller: _chewieCtrl!));
  }
}

class _DocxViewer extends StatefulWidget {
  final String url;
  final String? localFilePath;
  final String? contentId;
  final bool isViewOnly;
  const _DocxViewer({
    required this.url,
    this.localFilePath,
    this.contentId,
    this.isViewOnly = false,
  });

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
      if (path == null && contentId != null && !kIsWeb) {
        try {
          path = await AcademicContentRepository.instance.ensureLocalCopy(
            contentId: contentId,
            fileUrl: widget.url,
          );
        } catch (_) {
          path = null;
        }
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
      if (mounted) setState(() => _error = _friendlyLoadError(e, 'document'));
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
      return const Center(child: SkeletonSpinner());
    }
    final ac = AppColors.of(context);
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: ac.surf2,
          border: Border(bottom: BorderSide(color: ac.bdr)),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 16, color: ac.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.isViewOnly ? 'Protected Document' : 'Word Document · Select text or tap Copy',
                style: AppText.caption.copyWith(color: ac.txt2, fontWeight: FontWeight.w600),
              ),
            ),
            if (!widget.isViewOnly)
              TextButton.icon(
                onPressed: () {
                  final text = controller.document.toPlainText().trim();
                  Clipboard.setData(ClipboardData(text: text));
                  showToast(context, 'Document text copied to clipboard.');
                },
                icon: Icon(Icons.copy_rounded, size: 16, color: ac.primary),
                label: Text('Copy All', style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
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
  final bool isViewOnly;
  const _EpubViewer({
    required this.url,
    this.localFilePath,
    this.contentId,
    this.isViewOnly = false,
  });

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
      if (path == null && contentId != null && !kIsWeb) {
        try {
          path = await AcademicContentRepository.instance.ensureLocalCopy(
            contentId: contentId,
            fileUrl: widget.url,
          );
        } catch (_) {
          path = null;
        }
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
      if (mounted) setState(() => _error = _friendlyLoadError(e, 'book'));
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
      return const Center(child: SkeletonSpinner());
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
              if (!widget.isViewOnly)
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
            child: widget.isViewOnly
                ? Text(
                    chapter.content,
                    style: AppText.body.copyWith(
                      fontSize: _fontSize,
                      height: 1.6,
                      color: ac.txt,
                    ),
                  )
                : SelectableText(
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


class _TextViewer extends StatefulWidget {
  final String url;
  final String? localFilePath;
  final String? contentId;
  final bool isViewOnly;
  const _TextViewer({
    required this.url,
    this.localFilePath,
    this.contentId,
    this.isViewOnly = false,
  });

  @override
  State<_TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<_TextViewer> {
  String? _text;
  String? _error;
  double _fontSize = 15.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var path = widget.localFilePath;
      final contentId = widget.contentId;
      if (path == null && contentId != null && !kIsWeb) {
        try {
          path = await AcademicContentRepository.instance.ensureLocalCopy(
            contentId: contentId,
            fileUrl: widget.url,
          );
        } catch (_) {
          path = null;
        }
      }
      Uint8List bytes;
      if (path != null) {
        bytes = await File(path).readAsBytes();
      } else {
        final resp = await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 30));
        if (resp.statusCode >= 400) throw Exception('Server returned ${resp.statusCode}');
        bytes = resp.bodyBytes;
      }
      final decoded = utf8.decode(bytes, allowMalformed: true);
      if (!mounted) return;
      setState(() => _text = decoded);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyLoadError(e, 'file'));
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
    final text = _text;
    if (text == null) {
      return const Center(child: SkeletonSpinner());
    }
    final ac = AppColors.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: ac.surf2,
            border: Border(bottom: BorderSide(color: ac.bdr)),
          ),
          child: Row(
            children: [
              Icon(Icons.article_outlined, size: 16, color: ac.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isViewOnly ? 'Protected Text Document' : 'Text Document · Select text or tap Copy All',
                  style: AppText.caption.copyWith(color: ac.txt2, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.text_decrease_rounded, size: 18),
                tooltip: 'Decrease font size',
                onPressed: _fontSize > 11 ? () => setState(() => _fontSize -= 1.5) : null,
              ),
              IconButton(
                icon: const Icon(Icons.text_increase_rounded, size: 22),
                tooltip: 'Increase font size',
                onPressed: _fontSize < 26 ? () => setState(() => _fontSize += 1.5) : null,
              ),
              if (!widget.isViewOnly)
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    showToast(context, 'Text copied to clipboard.');
                  },
                  icon: Icon(Icons.copy_rounded, size: 16, color: ac.primary),
                  label: Text('Copy All', style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: widget.isViewOnly
                  ? Text(
                      text,
                      style: AppText.body.copyWith(
                        fontSize: _fontSize,
                        height: 1.65,
                        color: ac.txt,
                      ),
                    )
                  : SelectableText(
                      text,
                      style: AppText.body.copyWith(
                        fontSize: _fontSize,
                        height: 1.65,
                        color: ac.txt,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

String _friendlyLoadError(Object e, String what) {
  final msg = e.toString();
  if (e is SocketException || e is TimeoutException || msg.contains('ClientException') || msg.contains('SocketException')) {
    return 'This $what isn\'t saved on your device and you\'re offline. Connect to open it — '
        'and tap "Save for offline" to read it without internet next time.';
  }
  return 'This $what couldn\'t be opened. The file may be damaged or no longer available.';
}

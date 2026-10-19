// lib/features/academic_content/content_details_page.dart
// Shows full details of a content item. Tracks views. Supports download.
//
// Design pass: named AppText scale, reading-appropriate line-height on
// the description, haptic on download.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'content_edit_page.dart';
import 'content_delete_dialog.dart';
import 'content_viewer_page.dart';
import '../../widgets/widgets.dart';
class ContentDetailsPage extends StatefulWidget {
  final String contentId;
  final AppUser user;

  const ContentDetailsPage({
    super.key,
    required this.contentId,
    required this.user,
  });

  @override
  State<ContentDetailsPage> createState() => _ContentDetailsPageState();
}

class _ContentDetailsPageState extends State<ContentDetailsPage> {
  bool _viewTracked = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AcademicContent?>(
      stream: AcademicContentRepository.instance.watchOne(widget.contentId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return ApplicationShell(
            user: widget.user,
            currentTitle: 'Loading Content…',
            currentDestination: AppNavDestination.academicLibrary,
            showBackButton: true,
            onBack: () => Navigator.of(context).maybePop(),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final item = snap.data;
        if (item == null) {
          return ApplicationShell(
            user: widget.user,
            currentTitle: 'Content Not Found',
            currentDestination: AppNavDestination.academicLibrary,
            showBackButton: true,
            onBack: () => Navigator.of(context).maybePop(),
            child: const Center(child: Text('Content no longer exists.')),
          );
        }

        // Track view once per page open. Deferred to a post-frame callback
        // rather than fired directly here -- this whole block runs inside
        // StreamBuilder's builder, which build() invokes, and the
        // framework can call build() during layout; committing a database
        // write as a direct side effect of that is what the guard alone
        // doesn't prevent (only re-firing does).
        if (!_viewTracked) {
          _viewTracked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AcademicContentRepository.instance.incrementViews(item.id);
            AcademicContentRepository.instance.recordView(item.id, widget.user.id);
          });
        }

        final canEdit = widget.user.canUploadContent ||
            item.uploadedBy == widget.user.id;

        final ac = AppColors.of(context);
        return ApplicationShell(
          user: widget.user,
          currentTitle: item.title,
          subtitle: item.contentType.label,
          currentDestination: (item.contentType == ContentType.pastPaper || item.subject.toLowerCase().contains('past'))
              ? AppNavDestination.pastQuestions
              : AppNavDestination.academicLibrary,
          showBackButton: true,
          onBack: () => Navigator.of(context).maybePop(),
          contextualPanel: _ContentDetailsRightPanel(
            item: item,
            user: widget.user,
            canEdit: canEdit,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                if (item.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderThumbnail(type: item.contentType),
                      ),
                    ),
                  )
                else
                  _PlaceholderThumbnail(type: item.contentType),
                const SizedBox(height: 20),

                // Type badge + classification (subject/level/exam/year)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _TypeBadge(type: item.contentType),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: ac.bluBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(item.subject,
                        style: AppText.subtitle.copyWith(fontSize: 11, color: ac.blu)),
                  ),
                  if (item.level.isNotEmpty && item.level != 'All Levels')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: ac.grnBg, borderRadius: BorderRadius.circular(20)),
                      child: Text(item.level,
                          style: AppText.subtitle.copyWith(fontSize: 11, color: ac.grn)),
                    ),
                  if (item.examBoard.isNotEmpty && item.examBoard != 'N/A')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(20)),
                      child: Text(item.year != null ? '${item.examBoard} ${item.year}' : item.examBoard,
                          style: AppText.subtitle.copyWith(fontSize: 11, color: ac.gold)),
                    ),
                ]),
                const SizedBox(height: 14),

                // Title
                Text(item.title, style: AppText.h1),
                const SizedBox(height: 12),

                // Stats row
                Row(children: [
                  _Stat(icon: Icons.visibility_outlined, value: '${item.views} views'),
                  const SizedBox(width: 16),
                  _Stat(icon: Icons.download_outlined, value: '${item.downloads} downloads'),
                  const SizedBox(width: 16),
                  _Stat(icon: Icons.calendar_today_outlined, value: _formatDate(item.uploadDate)),
                ]),
                const SizedBox(height: 20),

                // Description
                if (item.description.isNotEmpty) ...[
                  Text('Description', style: AppText.title.copyWith(fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(item.description, style: AppText.body.copyWith(fontSize: 14)),
                  const SizedBox(height: 20),
                ],

                // Tags
                if (item.tags.isNotEmpty) ...[
                  Text('Tags', style: AppText.title.copyWith(fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: item.tags.map((t) => _Tag(label: t)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Download button
                if (item.fileUrl != null)
                  _DownloadButton(item: item, user: widget.user),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _PlaceholderThumbnail extends StatelessWidget {
  final ContentType type;
  const _PlaceholderThumbnail({required this.type});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ac.surf2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(type.emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        Text(type.label, style: AppText.bodySm),
      ]),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ContentType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(20)),
      child: Text('${type.emoji} ${type.label}',
          style: AppText.subtitle.copyWith(fontSize: 11, color: ac.pur)),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: ac.muted),
      const SizedBox(width: 4),
      Text(value, style: AppText.caption.copyWith(fontSize: 12)),
    ]);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ac.surf2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.bdr),
      ),
      child: Text('#$label', style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2)),
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final AcademicContent item;
  final AppUser user;
  const _DownloadButton({required this.item, required this.user});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _loading = false;

  bool get _isPastPaper => widget.item.contentType == ContentType.pastPaper;
  ViewableFileKind? get _viewableKind => viewableKindFor(widget.item.fileUrl!);

  Future<void> _openFile() async {
    // Images, PDFs, video, and .docx render in-app instead of handing off
    // to whatever external app the OS picks. Other office formats and
    // archives have no practical in-app renderer, so those still open
    // externally.
    final kind = _viewableKind;
    if (kind != null) {
      await AcademicContentRepository.instance.incrementDownloads(widget.item.id);
      final localPath = await AcademicContentRepository.instance.offlineFilePath(widget.item.id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ContentViewerPage(
          fileUrl: widget.item.fileUrl!,
          localFilePath: localPath,
          title: widget.item.title,
          kind: kind,
          contentId: widget.item.id,
          userId: widget.user.id,
        ),
      ));
      return;
    }
    final uri = Uri.tryParse(widget.item.fileUrl!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await AcademicContentRepository.instance.incrementDownloads(widget.item.id);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file.')),
      );
    }
  }

  Future<void> _download() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    // Past papers are freely accessible in Green Hills (no XP economy).

    try {
      await _openFile();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _download,
        style: ElevatedButton.styleFrom(
          backgroundColor: ac.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(_isPastPaper
                ? Icons.bolt_rounded
                : (_viewableKind != null ? Icons.visibility_rounded : Icons.download_rounded)),
        label: Text(
            _loading
                ? 'Opening…'
                : (_isPastPaper ? 'Unlock / Open' : (_viewableKind != null ? 'View' : 'Download')),
            style: AppText.button.copyWith(fontSize: 15)),
      ),
    );
  }
}

class _ContentDetailsRightPanel extends StatelessWidget {
  final AcademicContent item;
  final AppUser user;
  final bool canEdit;

  const _ContentDetailsRightPanel({
    required this.item,
    required this.user,
    required this.canEdit,
  });

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final fileUrl = item.fileUrl;
    final viewable = fileUrl != null && viewableKindFor(fileUrl) != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFE5A93C)),
                  const SizedBox(width: 8),
                  Text('DOCUMENT OVERVIEW',
                      style: AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.title,
                style: AppText.title.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _TypeBadge(type: item.contentType),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: ac.bluBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(item.subject,
                        style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: ac.blu)),
                  ),
                  if (item.level.isNotEmpty && item.level != 'All Levels')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ac.grnBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(item.level,
                          style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: ac.grn)),
                    ),
                  if (item.examBoard.isNotEmpty && item.examBoard != 'N/A')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(item.year != null ? '${item.examBoard} ${item.year}' : item.examBoard,
                          style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: ac.gold)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              _metaRow(ac, Icons.calendar_today_outlined, 'Uploaded', _formatDate(item.uploadDate)),
              const SizedBox(height: 6),
              _metaRow(ac, Icons.visibility_outlined, 'Views', '${item.views}'),
              const SizedBox(height: 6),
              _metaRow(ac, Icons.download_outlined, 'Downloads', '${item.downloads}'),
              if (item.fileSizeBytes != null && item.fileSizeBytes! > 0) ...[
                const SizedBox(height: 6),
                _metaRow(ac, Icons.description_outlined, 'File Size', '${(item.fileSizeBytes! / 1024).toStringAsFixed(1)} KB'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFE5A93C)),
                  const SizedBox(width: 8),
                  Text('QUICK ACTIONS',
                      style: AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt)),
                ],
              ),
              const SizedBox(height: 12),
              if (viewable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final kind = viewableKindFor(fileUrl);
                        if (kind != null) {
                          await AcademicContentRepository.instance.incrementDownloads(item.id);
                          final localPath = await AcademicContentRepository.instance.offlineFilePath(item.id);
                          if (!context.mounted) return;
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ContentViewerPage(
                              fileUrl: fileUrl,
                              localFilePath: localPath,
                              title: item.title,
                              kind: kind,
                              contentId: item.id,
                              userId: user.id,
                            ),
                          ));
                        }
                      },
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('Open Reader'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A93C),
                        foregroundColor: const Color(0xFF081630),
                      ),
                    ),
                  ),
                ),
              StreamBuilder<bool>(
                stream: AcademicContentRepository.instance.watchIsSaved(item.id, user.id),
                builder: (context, savedSnap) {
                  final saved = savedSnap.data ?? false;
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final wasSaved = saved;
                        await AcademicContentRepository.instance.toggleSave(item.id, user.id);
                        if (wasSaved) {
                          await AcademicContentRepository.instance.removeOfflineFile(item.id);
                        } else if ((item.fileUrl ?? '').isNotEmpty) {
                          if (context.mounted) {
                            showToast(context, 'Downloading for offline…');
                          }
                          final res = await AcademicContentRepository.instance.downloadForOffline(item);
                          if (!context.mounted) return;
                          showToast(context,
                              res is Failure<String> ? res.message : 'Saved — available offline in your Library.',
                              isError: res is Failure<String>);
                        }
                      },
                      icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 18, color: saved ? ac.grn : ac.txt),
                      label: Text(saved ? 'Saved Offline' : 'Save for Offline',
                          style: TextStyle(color: saved ? ac.grn : ac.txt)),
                    ),
                  );
                },
              ),
              if (canEdit) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ContentEditPage(content: item, user: user)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Resource'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => ContentDeleteDialog(
                        content: item,
                        onDeleted: () => Navigator.pop(context),
                      ),
                    ),
                    icon: Icon(Icons.delete_outline, size: 18, color: ac.red),
                    label: Text('Delete Resource', style: TextStyle(color: ac.red)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaRow(AppColors ac, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: ac.muted),
        const SizedBox(width: 6),
        Text(label, style: AppText.caption.copyWith(color: ac.muted, fontSize: 12)),
        const Spacer(),
        Text(value, style: AppText.caption.copyWith(color: ac.txt, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}


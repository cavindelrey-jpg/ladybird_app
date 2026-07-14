// lib/features/academic_content/content_details_page.dart
// Shows full details of a content item. Tracks views. Supports download.
//
// Design pass: named AppText scale, reading-appropriate line-height on
// the description, haptic on download.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../repositories/xp_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/paper_unlock_sheet.dart';
import 'content_edit_page.dart';
import 'content_delete_dialog.dart';
import 'content_viewer_page.dart';

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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final item = snap.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Content no longer exists.')),
          );
        }

        // Track view once per page open
        if (!_viewTracked) {
          _viewTracked = true;
          AcademicContentRepository.instance.incrementViews(item.id);
          AcademicContentRepository.instance.recordView(item.id, widget.user.id);
        }

        final canEdit = widget.user.canUploadContent ||
            item.uploadedBy == widget.user.id;

        return Scaffold(
          backgroundColor: C.bg,
          appBar: AppBar(
            title: Text(item.contentType.label, style: AppText.title),
            actions: [
              StreamBuilder<bool>(
                stream: AcademicContentRepository.instance.watchIsSaved(item.id, widget.user.id),
                builder: (context, savedSnap) {
                  final saved = savedSnap.data ?? false;
                  return IconButton(
                    icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: saved ? C.grn : C.txt2),
                    tooltip: saved ? 'Saved' : 'Save for offline',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      AcademicContentRepository.instance.toggleSave(item.id, widget.user.id);
                    },
                  );
                },
              ),
              if (canEdit) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ContentEditPage(content: item, user: widget.user),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: C.red),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ContentDeleteDialog(
                      content: item,
                      onDeleted: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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

                // Type badge + subject
                Row(children: [
                  _TypeBadge(type: item.contentType),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: C.blub, borderRadius: BorderRadius.circular(20)),
                    child: Text(item.subject,
                        style: AppText.subtitle.copyWith(fontSize: 11, color: C.blu)),
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
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: C.surf2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.bdr),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: C.purb, borderRadius: BorderRadius.circular(20)),
      child: Text('${type.emoji} ${type.label}',
          style: AppText.subtitle.copyWith(fontSize: 11, color: C.pur)),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: C.muted),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: C.surf2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.bdr),
      ),
      child: Text('#$label', style: AppText.caption.copyWith(fontSize: 11, color: C.txt2)),
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
    // Images, PDFs, and video render in-app instead of handing off to
    // whatever external app the OS picks. Office documents/archives have
    // no practical in-app renderer, so those still open externally.
    final kind = _viewableKind;
    if (kind != null) {
      await AcademicContentRepository.instance.incrementDownloads(widget.item.id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ContentViewerPage(
          fileUrl: widget.item.fileUrl!,
          title: widget.item.title,
          kind: kind,
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

    // Past papers specifically are gated behind the XP/Premium unlock
    // economy — everything else in the Library stays freely accessible.
    if (_isPastPaper) {
      final unlocked = await XpRepository.instance.isPaperUnlocked(widget.user, widget.item.id);
      if (!unlocked) {
        if (mounted) setState(() => _loading = false);
        if (!mounted) return;
        final nowUnlocked = await showPaperUnlockSheet(
          context, user: widget.user, paperId: widget.item.id, paperTitle: widget.item.title,
        );
        if (!nowUnlocked) return; // user backed out — don't open the file
        if (mounted) setState(() => _loading = true);
      }
    }

    await _openFile();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _download,
        style: ElevatedButton.styleFrom(
          backgroundColor: C.primary,
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

// lib/features/academic_content/content_details_page.dart
// Shows full details of a content item. Tracks views. Supports download.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_theme.dart';
import 'content_edit_page.dart';
import 'content_delete_dialog.dart';

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
        }

        final canEdit = widget.user.canUploadContent ||
            item.uploadedBy == widget.user.id;

        return Scaffold(
          backgroundColor: C.bg,
          appBar: AppBar(
            title: Text(item.contentType.label,
                style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
            actions: [
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.blub,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(item.subject,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: C.blu)),
                  ),
                ]),
                const SizedBox(height: 14),

                // Title
                Text(item.title,
                    style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: C.txt)),
                const SizedBox(height: 12),

                // Stats row
                Row(children: [
                  _Stat(icon: Icons.visibility_outlined,
                      value: '${item.views} views'),
                  const SizedBox(width: 16),
                  _Stat(icon: Icons.download_outlined,
                      value: '${item.downloads} downloads'),
                  const SizedBox(width: 16),
                  _Stat(icon: Icons.calendar_today_outlined,
                      value: _formatDate(item.uploadDate)),
                ]),
                const SizedBox(height: 20),

                // Description
                if (item.description.isNotEmpty) ...[
                  Text('Description',
                      style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.txt)),
                  const SizedBox(height: 8),
                  Text(item.description,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: C.txt2, height: 1.6)),
                  const SizedBox(height: 20),
                ],

                // Tags
                if (item.tags.isNotEmpty) ...[
                  Text('Tags',
                      style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: C.txt)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: item.tags
                        .map((t) => _Tag(label: t))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Download button
                if (item.fileUrl != null)
                  _DownloadButton(item: item),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
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
        Text(type.label,
            style: GoogleFonts.inter(fontSize: 14, color: C.txt2)),
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
      decoration: BoxDecoration(
        color: C.purb,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('${type.emoji} ${type.label}',
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: C.pur)),
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
      Text(value,
          style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
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
      child: Text('#$label',
          style: GoogleFonts.inter(fontSize: 11, color: C.txt2)),
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final AcademicContent item;
  const _DownloadButton({required this.item});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _loading = false;

  Future<void> _download() async {
    setState(() => _loading = true);
    final uri = Uri.tryParse(widget.item.fileUrl!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await AcademicContentRepository.instance
          .incrementDownloads(widget.item.id);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file.')),
        );
      }
    }
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.download_rounded),
        label: Text(_loading ? 'Opening…' : 'Download',
            style: GoogleFonts.sora(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

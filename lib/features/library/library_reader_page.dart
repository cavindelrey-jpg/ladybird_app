// lib/features/library/library_reader_page.dart
// NOT a full PDF/document renderer — that's a bigger feature (needs a PDF
// viewer package) and is out of scope for this pass. This is a real,
// minimal page-position tracker: it opens the item's download link and
// lets the person record which page they're on, so Home's "Continue
// Reading" card reflects an actual position instead of a fabricated one.
// Flag if/when you want a true in-app paginated reader.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/library_item.dart';
import '../../services/auth_service.dart';

class LibraryReaderPage extends StatefulWidget {
  final AppUser user;
  final LibraryItem item;
  const LibraryReaderPage({super.key, required this.user, required this.item});

  @override
  State<LibraryReaderPage> createState() => _LibraryReaderPageState();
}

class _LibraryReaderPageState extends State<LibraryReaderPage> {
  late int _page = widget.user.continueReadingItemId == widget.item.id
      ? widget.user.continueReadingPage
      : 1;
  bool _saving = false;

  Future<void> _persist() async {
    setState(() => _saving = true);
    await AuthService.instance.setContinueReading(
      widget.user.id,
      itemId: widget.item.id,
      title: widget.item.title,
      page: _page,
      totalPages: widget.item.totalPages,
    );
    if (mounted) setState(() => _saving = false);
  }

  void _changePage(int delta) {
    final max = widget.item.totalPages;
    final next = _page + delta;
    if (next < 1) return;
    if (max != null && next > max) return;
    setState(() => _page = next);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.item.totalPages;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          if (widget.item.downloadUrl != null)
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(widget.item.downloadUrl!),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open document'),
            ),
          const SizedBox(height: 24),
          Text('You\'re on page', style: GoogleFonts.inter(fontSize: 13, color: C.txt2)),
          const SizedBox(height: 6),
          Text(total != null ? '$_page of $total' : '$_page',
              style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w800, color: C.txt)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filled(
              onPressed: _page > 1 ? () => _changePage(-1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            const SizedBox(width: 20),
            IconButton.filled(
              onPressed: (total == null || _page < total) ? () => _changePage(1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
          const SizedBox(height: 12),
          if (_saving)
            Text('Saving…', style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
        ]),
      ),
    );
  }
}

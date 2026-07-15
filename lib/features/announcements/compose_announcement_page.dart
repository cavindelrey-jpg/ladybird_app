// lib/features/announcements/compose_announcement_page.dart
// Full-page announcement composer for Teachers and Admins.
// Supports title, body, urgency flag, and optional image URL attachment.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/announcement_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ComposeAnnouncementPage extends StatefulWidget {
  final AppUser user;
  const ComposeAnnouncementPage({super.key, required this.user});

  @override
  State<ComposeAnnouncementPage> createState() => _ComposeAnnouncementPageState();
}

class _ComposeAnnouncementPageState extends State<ComposeAnnouncementPage> {
  final _titleCtrl   = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  final _imageCtrl   = TextEditingController();
  bool _urgent = false;
  bool _loading = false;
  String _category = 'General';

  static const _categories = ['General', 'Academic', 'Sports', 'Club', 'Emergency'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, 'Please enter a title.');
      return;
    }
    setState(() => _loading = true);

    final tag = _urgent ? '🔴 Urgent' : '📢 $_category';
    final ann = Announcement(
      id: '',
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      tag: tag,
      authorName: widget.user.name,
      authorId: widget.user.id,
      date: DateTime.now(),
      urgent: _urgent,
      schoolId: widget.user.schoolId,
    );

    final result = await AnnouncementRepository.instance.post(ann);
    setState(() => _loading = false);
    if (!mounted) return;

    if (result is Success) {
      showToast(context, '📢 Announcement published!');
      Navigator.pop(context);
    } else {
      showToast(context, '❌ ${(result as Failure).message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('New Announcement',
          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _publish,
              child: Text('Publish',
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700,
                  color: C.primary)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Urgency toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _urgent ? C.redb : C.surf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _urgent ? C.red.withValues(alpha: 0.4) : C.bdr),
            ),
            child: Row(children: [
              Icon(_urgent ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                color: _urgent ? C.red : C.muted, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mark as Urgent',
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _urgent ? C.red : C.txt)),
                Text('Urgent notices appear highlighted for all users.',
                  style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
              ])),
              Switch(
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
                activeThumbColor: C.red,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Category
          if (!_urgent) ...[
            Text('Category',
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final sel = _category == _categories[i];
                  return GestureDetector(
                    onTap: () => setState(() => _category = _categories[i]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? C.primary : C.surf,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? C.primary : C.bdr),
                      ),
                      child: Text(_categories[i],
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : C.txt2)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Title
          Text('Title *',
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            maxLength: 120,
            decoration: const InputDecoration(
              hintText: 'e.g. Chemistry Lab Cancelled Tomorrow',
            ),
          ),
          const SizedBox(height: 16),

          // Body
          Text('Message',
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Full announcement text…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Optional image URL
          Text('Image URL (optional)',
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _imageCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://…',
              prefixIcon: Icon(Icons.image_outlined),
            ),
          ),
          const SizedBox(height: 32),

          PrimaryBtn(label: '📢 Publish Announcement', loading: _loading, onTap: _publish),
        ]),
      ),
    );
  }
}

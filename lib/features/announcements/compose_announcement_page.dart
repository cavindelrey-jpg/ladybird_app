// lib/features/announcements/compose_announcement_page.dart
// Full-page announcement composer for Teachers and Admins.
// Supports title, body, urgency flag, and an optional photo attached
// straight from the device -- item 12 of the architecture brief: the old
// "Image URL" text field wasn't even wired into the Announcement it
// built (filling it in silently did nothing). Pick -> upload -> preview
// -> publish, same shape as every other image attachment in this app
// (hero slides, article thumbnails).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models.dart';
import '../../repositories/announcement_repository.dart';
import '../../core/result.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class ComposeAnnouncementPage extends StatefulWidget {
  final AppUser user;
  const ComposeAnnouncementPage({super.key, required this.user});

  @override
  State<ComposeAnnouncementPage> createState() => _ComposeAnnouncementPageState();
}

class _ComposeAnnouncementPageState extends State<ComposeAnnouncementPage> {
  final _titleCtrl   = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  File? _pickedImage;
  bool _urgent = false;
  bool _loading = false;
  bool _uploadingImage = false;
  String _category = 'General';

  static const _categories = ['General', 'Academic', 'Sports', 'Group', 'Emergency'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, 'Please enter a title.');
      return;
    }
    setState(() => _loading = true);

    final repo = AnnouncementRepository.instance;
    // A real id is needed BEFORE the image upload so the file can be
    // keyed to it (and so publish still works cleanly with no photo
    // attached, in which case the empty-id add() path below is used).
    final id = _pickedImage != null ? repo.newId() : '';
    String? imageUrl;
    if (_pickedImage != null) {
      setState(() => _uploadingImage = true);
      final uploadResult = await repo.uploadImage(id: id, imageFile: _pickedImage!);
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      switch (uploadResult) {
        case Success(:final value): imageUrl = value;
        case Failure(:final message):
          setState(() => _loading = false);
          showToast(context, '❌ $message');
          return;
      }
    }

    final tag = _urgent ? '🔴 Urgent' : '📢 $_category';
    final ann = Announcement(
      id: id,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      tag: tag,
      authorName: widget.user.name,
      authorId: widget.user.id,
      date: DateTime.now(),
      urgent: _urgent,
      schoolId: widget.user.schoolId,
      imageUrl: imageUrl,
    );

    final result = await repo.post(ann);
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
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
                  color: ac.primary)),
            ),
        ],
      ),
      body: AppBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Urgency toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _urgent ? ac.redBg : ac.surf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _urgent ? ac.red.withValues(alpha: 0.4) : ac.bdr),
            ),
            child: Row(children: [
              Icon(_urgent ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                color: _urgent ? ac.red : ac.muted, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mark as Urgent',
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _urgent ? ac.red : ac.txt)),
                Text('Urgent notices appear highlighted for all users.',
                  style: GoogleFonts.inter(fontSize: 11, color: ac.muted)),
              ])),
              Switch(
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
                activeThumbColor: ac.red,
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
                        color: sel ? ac.primary : ac.surf,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? ac.primary : ac.bdr),
                      ),
                      child: Text(_categories[i],
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : ac.txt2)),
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

          // Optional photo, picked straight from the device
          Text('Photo (optional)',
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_pickedImage != null)
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_pickedImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 6, right: 6,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    onPressed: () => setState(() => _pickedImage = null),
                  ),
                ),
              ),
              if (_uploadingImage)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ),
            ])
          else
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Add a photo from your device'),
            ),
          const SizedBox(height: 32),

          PrimaryBtn(label: '📢 Publish Announcement', loading: _loading, onTap: _publish),
        ]),
      ),
      ),
    );
  }
}

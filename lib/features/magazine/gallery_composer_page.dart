// lib/features/magazine/gallery_composer_page.dart
// "Student Gallery" post composer — multi-image pick + caption.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/magazine_gallery_post.dart';
import '../../repositories/magazine_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class GalleryComposerPage extends StatefulWidget {
  final AppUser user;
  const GalleryComposerPage({super.key, required this.user});

  @override
  State<GalleryComposerPage> createState() => _GalleryComposerPageState();
}

class _GalleryComposerPageState extends State<GalleryComposerPage> {
  final _captionCtrl = TextEditingController();
  final List<File> _images = [];
  bool _posting = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _submit() async {
    if (_images.isEmpty) {
      showToast(context, 'Add at least one photo.');
      return;
    }
    setState(() => _posting = true);
    final repo = MagazineRepository.instance;
    final createResult = await repo.createGalleryPost(MagazineGalleryPost(
      id: '', authorId: widget.user.id, authorName: widget.user.name,
      authorPhotoUrl: widget.user.photoUrl, caption: _captionCtrl.text.trim(),
      imageUrls: const [], createdAt: DateTime.now(),
    ));
    if (createResult is! Success<String>) {
      if (mounted) {
        setState(() => _posting = false);
        showToast(context, (createResult as Failure).message, isError: true);
      }
      return;
    }
    final postId = createResult.value;
    final urls = <String>[];
    for (var i = 0; i < _images.length; i++) {
      final uploadResult = await repo.uploadGalleryImage(postId: postId, index: i, file: _images[i]);
      if (uploadResult is Success<String>) urls.add(uploadResult.value);
    }
    if (urls.isNotEmpty) {
      await repo.setGalleryImages(postId, urls);
    }
    if (!mounted) return;
    setState(() => _posting = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(backgroundColor: ac.bg, elevation: 0, iconTheme: IconThemeData(color: ac.txt),
          title: Text('Share Photos', style: AppText.title),
          actions: [
            TextButton(
              onPressed: _posting ? null : _submit,
              child: _posting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Post', style: AppText.button.copyWith(color: ac.primary)),
            ),
          ]),
      body: AppBackground(child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _captionCtrl, maxLines: 3,
              decoration: const InputDecoration(hintText: 'Say something about these photos…', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ..._images.map((f) => ClipRRect(
              borderRadius: BorderRadius.circular(Rad.sm),
              child: Image.file(f, width: 90, height: 90, fit: BoxFit.cover),
            )),
            InkWell(
              onTap: _pickImages,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
                child: Icon(Icons.add_photo_alternate_outlined, color: ac.muted),
              ),
            ),
          ]),
        ]),
      ))),
    );
  }
}

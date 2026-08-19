// lib/features/magazine/video_composer_page.dart
// "Latest Videos" post composer — video pick + optional thumbnail + title.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/magazine_video_post.dart';
import '../../repositories/magazine_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class VideoComposerPage extends StatefulWidget {
  final AppUser user;
  const VideoComposerPage({super.key, required this.user});

  @override
  State<VideoComposerPage> createState() => _VideoComposerPageState();
}

class _VideoComposerPageState extends State<VideoComposerPage> {
  final _titleCtrl = TextEditingController();
  File? _video;
  File? _thumbnail;
  bool _posting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 10));
    if (picked != null) setState(() => _video = File(picked.path));
  }

  Future<void> _pickThumbnail() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _thumbnail = File(picked.path));
  }

  Future<void> _submit() async {
    if (_video == null) {
      showToast(context, 'Pick a video first.');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, 'Give the video a title.');
      return;
    }
    setState(() => _posting = true);
    final repo = MagazineRepository.instance;
    final createResult = await repo.createVideoPost(MagazineVideoPost(
      id: '', authorId: widget.user.id, authorName: widget.user.name,
      authorPhotoUrl: widget.user.photoUrl, title: _titleCtrl.text.trim(),
      videoUrl: '', createdAt: DateTime.now(),
    ));
    if (createResult is! Success<String>) {
      if (mounted) {
        setState(() => _posting = false);
        showToast(context, (createResult as Failure).message, isError: true);
      }
      return;
    }
    final postId = createResult.value;
    final videoUpload = await repo.uploadVideoFile(postId: postId, file: _video!);
    if (videoUpload is! Success<String>) {
      if (mounted) {
        setState(() => _posting = false);
        showToast(context, (videoUpload as Failure).message, isError: true);
      }
      return;
    }
    String? thumbnailUrl;
    if (_thumbnail != null) {
      final thumbUpload = await repo.uploadVideoThumbnail(postId: postId, file: _thumbnail!);
      if (thumbUpload is Success<String>) thumbnailUrl = thumbUpload.value;
    }
    await repo.setVideoUrls(postId, videoUrl: videoUpload.value, thumbnailUrl: thumbnailUrl);
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
          title: Text('Share a Video', style: AppText.title),
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
          TextField(controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Video title', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickVideo,
            child: Container(
              width: double.infinity, height: 120,
              decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_video != null ? Icons.check_circle_rounded : Icons.videocam_outlined,
                    color: _video != null ? ac.grn : ac.muted, size: 28),
                const SizedBox(height: 6),
                Text(_video != null ? 'Video selected' : 'Tap to pick a video', style: AppText.bodySm),
              ])),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickThumbnail,
            child: Container(
              width: 120, height: 80,
              decoration: BoxDecoration(
                color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr),
                image: _thumbnail != null ? DecorationImage(image: FileImage(_thumbnail!), fit: BoxFit.cover) : null,
              ),
              child: _thumbnail == null
                  ? Icon(Icons.add_photo_alternate_outlined, color: ac.muted)
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text('Thumbnail (optional)', style: AppText.caption),
        ]),
      ))),
    );
  }
}

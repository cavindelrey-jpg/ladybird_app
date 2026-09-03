// lib/features/courses_marketplace/curriculum_icon_editor.dart
// Shared "pick an image, upload it, set it as this Level/Subject/Topic
// tile's thumbnail" flow. [onChanged] is called after a successful edit
// so the caller (a one-shot Future.wait load, not a live stream) can
// refetch curriculumIconsOnce() and show the new thumbnail immediately.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/result.dart';
import '../../repositories/public_course_repository.dart';
import '../../widgets/widgets.dart';

Future<void> editCurriculumThumbnail(
  BuildContext context, {
  required String iconKey,
  required VoidCallback onChanged,
}) async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
  if (picked == null || !context.mounted) return;
  final repo = PublicCourseRepository.instance;
  final upload = await repo.uploadCurriculumNodeImage(key: iconKey, imageFile: File(picked.path));
  if (upload is Failure) {
    if (context.mounted) showToast(context, (upload as Failure).message);
    return;
  }
  await repo.setCurriculumIcon(iconKey, imageUrl: (upload as Success<String>).value);
  onChanged();
}

Future<void> removeCurriculumThumbnail(
  BuildContext context, {
  required String iconKey,
  required String emoji,
  required VoidCallback onChanged,
}) async {
  await PublicCourseRepository.instance.setCurriculumIcon(iconKey, emoji: emoji);
  onChanged();
}

// lib/features/academic_content/folder_thumbnail_editor.dart
// Shared "pick an image, upload it, set it as this folder's thumbnail"
// flow, used from both the Academia Library home page's root folder tiles
// and the File Explorer's own folder tiles. Every folder view is backed
// by a realtime stream (watchRootFolders/watchChildFolders), so the new
// thumbnail appears immediately with no manual refresh needed.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/result.dart';
import '../../models/library_folder.dart';
import '../../repositories/library_folder_repository.dart';
import '../../widgets/widgets.dart';

Future<void> editFolderThumbnail(BuildContext context, LibraryFolder folder) async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
  if (picked == null || !context.mounted) return;
  final upload = await LibraryFolderRepository.instance
      .uploadFolderImage(folderId: folder.id, imageFile: File(picked.path));
  if (upload is Failure) {
    if (context.mounted) showToast(context, (upload as Failure).message);
    return;
  }
  final result = await LibraryFolderRepository.instance
      .setFolderImage(folder.id, (upload as Success<String>).value);
  if (context.mounted && result is Failure) showToast(context, (result as Failure).message);
}

Future<void> removeFolderThumbnail(BuildContext context, LibraryFolder folder) async {
  final result = await LibraryFolderRepository.instance.setFolderImage(folder.id, '');
  if (context.mounted && result is Failure) showToast(context, (result as Failure).message);
}

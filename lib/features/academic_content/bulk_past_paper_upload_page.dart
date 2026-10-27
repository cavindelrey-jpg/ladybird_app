// lib/features/academic_content/bulk_past_paper_upload_page.dart
// Backward-compatible wrapper delegating to BulkContentUploadPage.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import 'bulk_content_upload_page.dart';

export 'bulk_content_upload_page.dart';

class BulkPastPaperUploadPage extends StatelessWidget {
  final AppUser user;
  final String? folderId;
  const BulkPastPaperUploadPage({super.key, required this.user, this.folderId});

  @override
  Widget build(BuildContext context) {
    return BulkContentUploadPage(
      user: user,
      folderId: folderId,
      initialCategory: ContentType.pastPaper,
    );
  }
}

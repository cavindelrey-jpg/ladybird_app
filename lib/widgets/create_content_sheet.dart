// lib/widgets/create_content_sheet.dart
// Architecture brief item 14: several pages used to have a permanent
// "Create X" card sitting at the top of the interface at all times
// (Courses' _createCourseCta, Magazine's _writeCta with Article/Photos/
// Video actions) -- removed from those pages and consolidated here, a
// single bottom sheet reachable from HomeShell's global "+" FAB (item
// 14: "expose content creation through the + button... plus menu can
// expose: Add quiz, Add article, Add past paper, Add PDF, Add image").
// Every destination below is a real, already-existing composer page --
// nothing new was invented, this only changes how they're reached.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../features/courses_marketplace/course_composer_page.dart';
import '../features/magazine/article_composer_page.dart';
import '../features/magazine/gallery_composer_page.dart';
import '../features/magazine/video_composer_page.dart';
import '../features/testing/test_composer_page.dart';
import '../features/academic_content/content_upload_page.dart';
import '../features/academic_content/bulk_past_paper_upload_page.dart';
import '../features/clubs/create_club_page.dart';

class _CreateOption {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final WidgetBuilder pageBuilder;
  const _CreateOption({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.pageBuilder,
  });
}

/// Only meant to be called for a signed-in, non-guest user -- the "+"
/// FAB that opens this only exists on HomeShell, which never renders for
/// a guest (see app_router.dart's _AppUserGate/_GuestShell split).
Future<void> showCreateContentSheet(BuildContext context, AppUser user) async {
  final options = <_CreateOption>[
    _CreateOption(
      icon: Icons.article_rounded, label: 'Article', subtitle: 'Write and publish a Magazine post',
      color: Colors.indigo,
      pageBuilder: (_) => ArticleComposerPage(user: user),
    ),
    _CreateOption(
      icon: Icons.photo_library_rounded, label: 'Photos', subtitle: 'Share a photo gallery post',
      color: Colors.teal,
      pageBuilder: (_) => GalleryComposerPage(user: user),
    ),
    _CreateOption(
      icon: Icons.videocam_rounded, label: 'Video', subtitle: 'Share a video post',
      color: Colors.deepOrange,
      pageBuilder: (_) => VideoComposerPage(user: user),
    ),
    _CreateOption(
      icon: Icons.groups_rounded, label: 'Group / Club', subtitle: 'Start a new study circle or student club',
      color: Colors.green,
      pageBuilder: (_) => CreateClubPage(user: user),
    ),
    _CreateOption(
      icon: Icons.school_rounded, label: 'Course', subtitle: 'Create an Academia Course',
      color: Colors.blue,
      pageBuilder: (_) => CourseComposerPage(user: user),
    ),
    if (user.hasMinRole(UserRole.lecturer)) ...[
      _CreateOption(
        icon: Icons.quiz_rounded, label: 'Quiz', subtitle: 'MCQ, Structured, or Essay questions',
        color: Colors.purple,
        pageBuilder: (_) => TestComposerPage(author: user),
      ),
      _CreateOption(
        icon: Icons.upload_file_rounded, label: 'Library Content', subtitle: 'PDF, image, past paper, book, or video',
        color: Colors.green,
        pageBuilder: (_) => ContentUploadPage(user: user),
      ),
      _CreateOption(
        icon: Icons.drive_folder_upload_rounded, label: 'Mass Upload Past Papers', subtitle: 'Batch upload multiple PDFs with auto-parsed metadata',
        color: Colors.amber,
        pageBuilder: (_) => BulkPastPaperUploadPage(user: user),
      ),
    ],
  ];

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final ac = AppColors.of(sheetContext);
      return Container(
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
        ),
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 12,
          bottom: 16 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: ac.bdr, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Create', style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
          const SizedBox(height: 12),
          ...options.map((o) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: o.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(Rad.sm)),
                  child: Icon(o.icon, color: o.color, size: 22),
                ),
                title: Text(o.label, style: AppText.subtitle.copyWith(fontSize: 14, color: ac.txt)),
                subtitle: Text(o.subtitle, style: AppText.caption.copyWith(fontSize: 11.5, color: ac.txt2)),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: o.pageBuilder));
                },
              )),
        ]),
      );
    },
  );
}

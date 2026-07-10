// lib/features/courses_marketplace/course_creator_profile_page.dart
// A course creator's published (and, on your own profile, draft) courses.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'course_reader_page.dart';
import 'course_composer_page.dart';

class CourseCreatorProfilePage extends StatelessWidget {
  final String creatorId;
  final AppUser? currentUser;
  const CourseCreatorProfilePage({super.key, required this.creatorId, this.currentUser});

  bool get _isOwnProfile => currentUser?.id == creatorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text(_isOwnProfile ? 'Your Courses' : 'Creator Profile', style: AppText.title),
      ),
      body: StreamBuilder<List<PublicCourse>>(
        stream: PublicCourseRepository.instance.watchByCreator(creatorId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          var courses = snap.data ?? const <PublicCourse>[];
          if (!_isOwnProfile) courses = courses.where((c) => c.published).toList();
          if (courses.isEmpty) {
            return EmptyState(
              icon: Icons.school_outlined,
              title: _isOwnProfile ? "You haven't published a course yet" : 'No published courses yet',
              subtitle: _isOwnProfile ? 'Tap Create Course on the Courses tab to start.' : null,
            );
          }
          final headerName = courses.first.creatorName;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                UserAvatar(initials: headerName.isEmpty ? '?' : headerName[0].toUpperCase(),
                    radius: 26, photoUrl: courses.first.creatorPhotoUrl),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(headerName, style: AppText.h2),
                  Text('${courses.length} course${courses.length == 1 ? '' : 's'}', style: AppText.bodySm),
                ]),
              ]),
              const SizedBox(height: 20),
              ...courses.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ACard(
                  onTap: () {
                    if (c.published || _isOwnProfile) {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CourseReaderPage(course: c, currentUser: currentUser)));
                    }
                  },
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(c.title, style: AppText.title.copyWith(fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (!c.published)
                            const Padding(padding: EdgeInsets.only(left: 8),
                                child: StatusBadge(label: 'DRAFT', color: C.org, bg: C.orgb)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.star_rounded, size: 13, color: C.gold),
                          const SizedBox(width: 2),
                          Text(c.avgRating > 0 ? c.avgRating.toStringAsFixed(1) : '—', style: AppText.caption),
                          const SizedBox(width: 10),
                          const Icon(Icons.people_alt_outlined, size: 13, color: C.muted),
                          const SizedBox(width: 3),
                          Text('${c.enrolledCount}', style: AppText.caption),
                        ]),
                      ]),
                    ),
                    if (_isOwnProfile)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: C.txt2),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CourseComposerPage(user: currentUser!, existing: c))),
                      ),
                  ]),
                ),
              )),
            ],
          );
        },
      ),
    );
  }
}

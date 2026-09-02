// lib/features/courses_marketplace/course_search_page.dart
// Full-text search across all published courses — the search bar shown on
// Courses Home opens here rather than filtering the home screen itself,
// since Recommended/Recent Reads are discovery, not the searchable catalog.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'course_lessons_page.dart';

class CourseSearchPage extends StatefulWidget {
  final AppUser? user;
  const CourseSearchPage({super.key, this.user});

  @override
  State<CourseSearchPage> createState() => _CourseSearchPageState();
}

class _CourseSearchPageState extends State<CourseSearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          style: AppText.bodySm.copyWith(color: ac.txt),
          decoration: InputDecoration(
            hintText: 'Search courses, topics, subjects…',
            hintStyle: AppText.bodySm.copyWith(color: ac.muted),
            border: InputBorder.none,
          ),
        ),
      ),
      body: AppBackground(child: StreamBuilder<List<PublicCourse>>(
        stream: PublicCourseRepository.instance.watchLatest(limit: 200),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const ShimmerBlock(width: double.infinity, height: 72),
            );
          }
          var courses = snap.data ?? const <PublicCourse>[];
          if (_query.isNotEmpty) {
            final q = _query.toLowerCase();
            courses = courses.where((c) =>
                c.title.toLowerCase().contains(q) ||
                c.description.toLowerCase().contains(q) ||
                c.category.toLowerCase().contains(q) ||
                c.topic.toLowerCase().contains(q)).toList();
          }
          if (_query.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Start typing to search courses, topics, and subjects.',
                    textAlign: TextAlign.center, style: AppText.bodySm.copyWith(color: ac.txt2)),
              ),
            );
          }
          if (courses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No courses match "$_query".', style: AppText.bodySm.copyWith(color: ac.txt2)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final course = courses[i];
              final meta = [course.level, course.category, course.topic].where((s) => s.isNotEmpty).join(' • ');
              return Material(
                color: ac.surf,
                borderRadius: BorderRadius.circular(Rad.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.md),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CourseLessonsPage(course: course, currentUser: widget.user)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 48, height: 48,
                          child: (course.coverImageUrl ?? '').isNotEmpty
                              ? Image.network(course.coverImageUrl!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: ac.primaryBg))
                              : Container(color: ac.primaryBg, child: Icon(Icons.menu_book_rounded, color: ac.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(course.title, style: AppText.title.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (meta.isNotEmpty)
                            Text(meta, style: AppText.caption.copyWith(fontSize: 11)),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      )),
    );
  }
}

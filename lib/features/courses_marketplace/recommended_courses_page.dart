// lib/features/courses_marketplace/recommended_courses_page.dart
// "See all" for Academia Courses' Recommended for You rail — same real
// recommendation pool, just a longer, browsable grid instead of a
// 5-card slide.

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

class RecommendedCoursesPage extends StatelessWidget {
  final AppUser? user;
  const RecommendedCoursesPage({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Recommended for You', style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
      ),
      body: AppBackground(child: FutureBuilder<List<PublicCourse>>(
        future: PublicCourseRepository.instance.recommendedForUser(user?.id, limit: 30),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
              itemCount: 6,
              itemBuilder: (_, __) => const ShimmerBlock(),
            );
          }
          final courses = snap.data ?? const <PublicCourse>[];
          if (courses.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Nothing to recommend yet',
              subtitle: 'Check back once there are more courses.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
            itemCount: courses.length,
            itemBuilder: (context, i) => _Card(
              course: courses[i],
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CourseLessonsPage(course: courses[i], currentUser: user)));
              },
            ),
          );
        },
      )),
    );
  }
}

class _Card extends StatelessWidget {
  final PublicCourse course;
  final VoidCallback onTap;
  const _Card({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: (course.coverImageUrl ?? '').isNotEmpty
                  ? Image.network(course.coverImageUrl!, fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder(ac))
                  : _placeholder(ac),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (course.category.isNotEmpty) StatusBadge(label: course.category, color: ac.primary),
                const SizedBox(height: 6),
                Text(course.title, style: AppText.title.copyWith(fontSize: 12, color: ac.txt), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(AppColors ac) => Container(color: ac.navy, child: Icon(Icons.school_rounded, color: ac.gold, size: 28));
}

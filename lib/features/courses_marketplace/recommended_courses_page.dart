// lib/features/courses_marketplace/recommended_courses_page.dart
// "See all" for Academia Courses' Recommended for You rail — same real
// recommendation pool, just a longer, browsable grid instead of a
// 5-card slide.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'course_lessons_page.dart';
import 'course_search_page.dart';

class RecommendedCoursesPage extends StatelessWidget {
  final AppUser? user;
  const RecommendedCoursesPage({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final effectiveUser = user ?? AuthService.instance.lastKnownUser;

    return ApplicationShell(
      user: effectiveUser,
      currentTitle: 'Recommended Courses',
      subtitle: 'Curated curriculum recommendations tailored to your studies',
      currentDestination: AppNavDestination.academicCourses,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      contextualPanel: _RecommendedCoursesRightPanel(user: effectiveUser),
      child: FutureBuilder<List<PublicCourse>>(
        future: PublicCourseRepository.instance.recommendedForUser(effectiveUser?.id, limit: 30),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: 6,
                  itemBuilder: (_, __) => const ShimmerBlock(),
                );
              },
            );
          }
          final courses = snap.data ?? const <PublicCourse>[];
          if (courses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Nothing to recommend yet',
                  subtitle: 'Check back once more courses are published to the catalog.',
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: courses.length,
                itemBuilder: (context, i) => _Card(
                  course: courses[i],
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CourseLessonsPage(
                        course: courses[i],
                        currentUser: effectiveUser,
                      ),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: (course.coverImageUrl ?? '').isNotEmpty
                    ? Image.network(
                        course.coverImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _placeholder(ac),
                      )
                    : _placeholder(ac),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (course.category.isNotEmpty)
                      StatusBadge(label: course.category, color: ac.primary),
                    const SizedBox(height: 6),
                    Text(
                      course.title,
                      style: AppText.title.copyWith(fontSize: 13, color: ac.txt),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (course.level.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        course.level,
                        style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(AppColors ac) => Container(
        color: ac.navy,
        child: Center(
          child: Icon(Icons.school_rounded, color: ac.gold, size: 28),
        ),
      );
}

class _RecommendedCoursesRightPanel extends StatelessWidget {
  final AppUser? user;
  const _RecommendedCoursesRightPanel({this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: ac.gold),
                  const SizedBox(width: 8),
                  Text(
                    'Curated Selection',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'These recommendations are matched to your curriculum profile, active topics, and overall learning progression.',
                style: AppText.caption.copyWith(color: ac.txt2, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: ac.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Explore the Catalog',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Looking for a specific subject, exam revision course, or syllabus topic?',
                style: AppText.caption.copyWith(color: ac.txt2, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SecondaryBtn(
                  label: 'Search Catalog',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CourseSearchPage(user: user),
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tips_and_updates_outlined, size: 18, color: ac.muted),
                  const SizedBox(width: 8),
                  Text(
                    'Study Tips',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '• Enroll in 2-3 focused courses per term.\n'
                '• Download lessons for seamless offline revision.\n'
                '• Complete embedded test questions to consolidate XP.',
                style: AppText.caption.copyWith(color: ac.txt2, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

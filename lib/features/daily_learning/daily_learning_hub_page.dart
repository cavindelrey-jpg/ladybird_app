// lib/features/daily_learning/daily_learning_hub_page.dart
// Entry point for Home's "Challenge" Quick Access tile. Lists every
// Daily Learning course (today: just Etymology) as a simple card grid --
// adding a second subject later means adding one entry to
// data/etymology_course.dart's dailyLearningCourses list, nothing here
// changes.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/daily_learning.dart';
import '../../repositories/daily_learning_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'daily_learning_course_page.dart';

class DailyLearningHubPage extends StatelessWidget {
  final AppUser user;
  const DailyLearningHubPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final courses = DailyLearningRepository.instance.courses;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        title: Text('Daily Challenge', style: AppText.h2.copyWith(color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('A short lesson and quiz every day -- pick a course to continue.',
              style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.4)),
          const SizedBox(height: 16),
          for (final course in courses) _CourseCard(user: user, course: course),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final AppUser user;
  final DailyLearningCourse course;
  const _CourseCard({required this.user, required this.course});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final radius = BorderRadius.circular(Rad.md);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ac.surf,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DailyLearningCoursePage(user: user, course: course))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                borderRadius: radius, border: Border.all(color: ac.bdr)),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: ac.orgBg, shape: BoxShape.circle),
                child: Icon(Icons.local_fire_department_rounded, color: ac.org, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(course.title, style: GoogleFonts.sora(
                      fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt)),
                  const SizedBox(height: 4),
                  Text(course.description, style: GoogleFonts.inter(fontSize: 12, color: ac.txt2, height: 1.3)),
                  const SizedBox(height: 6),
                  Text('${course.lessons.length} lessons', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: ac.primary)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: ac.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

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
import '../../models/daily_learning_streak.dart';
import '../../models/xp_transaction.dart';
import '../../repositories/daily_learning_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'daily_learning_course_page.dart';

class DailyLearningHubPage extends StatelessWidget {
  final AppUser user;
  const DailyLearningHubPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final courses = DailyLearningRepository.instance.courses;

    return ApplicationShell(
      user: user,
      currentTitle: 'Daily Challenge',
      subtitle: 'Short daily lessons and micro-quizzes',
      currentDestination: AppNavDestination.academicCourses,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      contextualPanel: _buildHubContextualPanel(context, ac, courses),
      child: ListView(
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

  Widget _buildHubContextualPanel(BuildContext context, AppColors ac, List<DailyLearningCourse> courses) {
    final totalLessons = courses.fold<int>(0, (sum, c) => sum + c.lessons.length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Streak Card
        Text('Daily Learning Streak', style: AppText.title.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<DailyLearningStreak?>(
          stream: DailyLearningRepository.instance.watchStreak(user.id),
          builder: (context, snap) {
            final streak = snap.data;
            final current = streak?.currentStreak ?? 0;
            final longest = streak?.longestStreak ?? 0;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ac.surf2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ac.bdr),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: ac.org, size: 36),
                      const SizedBox(width: 8),
                      Text(
                        '$current Days',
                        style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: ac.txt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Current Streak', style: TextStyle(fontSize: 11, color: ac.txt2)),
                          const SizedBox(height: 2),
                          Text('$current days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Container(width: 1, height: 24, color: ac.bdr),
                      Column(
                        children: [
                          Text('Best Streak', style: TextStyle(fontSize: 11, color: ac.txt2)),
                          const SizedBox(height: 2),
                          Text('$longest days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Courses Overview Card
        Text('Curriculum Overview', style: AppText.title.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            children: [
              _metricRow(ac, 'Active Daily Courses', '${courses.length}', Icons.auto_stories_rounded),
              const Divider(height: 16),
              _metricRow(ac, 'Total Micro-Lessons', '$totalLessons', Icons.quiz_rounded),
              const Divider(height: 16),
              _metricRow(ac, 'Daily XP Rate', '+${XpSource.dailyLearning.baseXp} XP / correct', Icons.stars_rounded),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tips Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.military_tech_rounded, size: 18, color: ac.gold),
                  const SizedBox(width: 8),
                  Text('Milestone Rewards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ac.txt)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Completing lessons every day triggers streak milestone bonuses every 7 days (up to +200 bonus XP). Keep your streak alive to maximize your rank on the leaderboard!',
                style: TextStyle(fontSize: 12, color: ac.txt2, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricRow(AppColors ac, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ac.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: ac.txt2))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
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

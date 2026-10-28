// lib/features/daily_learning/daily_learning_course_page.dart
// Duolingo-style lesson path for one Daily Learning course: lessons
// unlock in order (a lesson is open once the one before it is
// completed), each node shows locked/available/completed state. Real
// progress via DailyLearningRepository.watchProgress -- never a
// fabricated "streak" or completion percentage.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/daily_learning.dart';
import '../../repositories/daily_learning_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'daily_learning_lesson_page.dart';

class DailyLearningCoursePage extends StatelessWidget {
  final AppUser user;
  final DailyLearningCourse course;
  const DailyLearningCoursePage({super.key, required this.user, required this.course});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isGuest = user.isGuest;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        title: Text(course.title, style: AppText.h2.copyWith(color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: false
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_outline_rounded, size: 48, color: ac.muted),
                  const SizedBox(height: 16),
                  Text('Sign in to start ${course.title}',
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
                ]),
              ),
            )
          : StreamBuilder<Set<String>>(
              stream: DailyLearningRepository.instance.watchProgress(user.id, course.id),
              builder: (context, snap) {
                final completed = snap.data ?? const <String>{};
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('${completed.length} of ${course.lessons.length} lessons complete',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.txt2)),
                    const SizedBox(height: 16),
                    for (var i = 0; i < course.lessons.length; i++)
                      _LessonNode(
                        user: user,
                        course: course,
                        lesson: course.lessons[i],
                        index: i,
                        isCompleted: completed.contains(course.lessons[i].id),
                        isUnlocked: i == 0 || completed.contains(course.lessons[i - 1].id),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _LessonNode extends StatelessWidget {
  final AppUser user;
  final DailyLearningCourse course;
  final DailyLearningLesson lesson;
  final int index;
  final bool isCompleted;
  final bool isUnlocked;
  const _LessonNode({
    required this.user, required this.course, required this.lesson,
    required this.index, required this.isCompleted, required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final radius = BorderRadius.circular(Rad.md);
    final nodeColor = isCompleted ? ac.grn : (isUnlocked ? ac.primary : ac.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ac.surf,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            if (!isUnlocked) {
              showToast(context, 'Complete the previous lesson to unlock this one.');
              return;
            }
            HapticFeedback.selectionClick();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DailyLearningLessonPage(user: user, course: course, lesson: lesson)));
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: ac.bdr)),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: nodeColor.withValues(alpha: .15), shape: BoxShape.circle),
                child: Icon(
                  isCompleted ? Icons.check_rounded : (isUnlocked ? Icons.play_arrow_rounded : Icons.lock_outline_rounded),
                  color: nodeColor, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Lesson ${index + 1}', style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
                  Text(lesson.title, style: GoogleFonts.sora(
                      fontSize: 13.5, fontWeight: FontWeight.w700,
                      color: isUnlocked ? ac.txt : ac.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

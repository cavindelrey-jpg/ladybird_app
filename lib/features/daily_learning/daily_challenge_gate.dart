import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_user.dart';
import '../../models/daily_learning.dart';
import '../../models/daily_learning_streak.dart';
import '../../repositories/daily_learning_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'daily_learning_lesson_page.dart';

class DailyChallengeGate extends StatefulWidget {
  final AppUser user;
  final Widget child;
  const DailyChallengeGate({super.key, required this.user, required this.child});

  @override
  State<DailyChallengeGate> createState() => _DailyChallengeGateState();
}

class _DailyChallengeGateState extends State<DailyChallengeGate> {
  bool _checked = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkDailyChallenge();
  }

  Future<void> _checkDailyChallenge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      final lastDismissed = prefs.getString('daily_challenge_dismissed_${widget.user.id}');
      if (lastDismissed == todayStr) {
        if (mounted) setState(() => _checked = true);
        return;
      }

      final streakStream = DailyLearningRepository.instance.watchStreak(widget.user.id);
      final streak = await streakStream.first;
      
      final lastCompleted = streak?.lastCompletedDate;
      if (lastCompleted != null && lastCompleted.year == now.year && lastCompleted.month == now.month && lastCompleted.day == now.day) {
        // Completed today
        if (mounted) setState(() => _checked = true);
        return;
      }
    } catch (e) {
      // If table doesn't exist yet or offline, fail open to avoid boot loop
      debugPrint('DailyChallengeGate error: $e');
    }

    // Show the modal! (or fail open if errored, but we can't show modal without data, so if we errored, _getPendingChallenge will probably also error and we handle it there).
    if (mounted) setState(() => _checked = true);
  }

  void _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    await prefs.setString('daily_challenge_dismissed_${widget.user.id}', todayStr);
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    // If they already did it today or dismissed it, show the real app
    if (_dismissed) return widget.child;

    return FutureBuilder(
      future: _getPendingChallenge(),
      builder: (context, AsyncSnapshot<_PendingChallenge?> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final pending = snap.data;
        if (pending == null) {
          return widget.child;
        }

        return _DailyChallengeOverlay(
          user: widget.user,
          course: pending.course,
          lesson: pending.lesson,
          streak: pending.streak,
          onDismiss: _dismiss,
        );
      },
    );
  }

  Future<_PendingChallenge?> _getPendingChallenge() async {
    try {
      final streak = await DailyLearningRepository.instance.watchStreak(widget.user.id).first;
      final now = DateTime.now();
      if (streak?.lastCompletedDate != null && 
          streak!.lastCompletedDate!.year == now.year && 
          streak.lastCompletedDate!.month == now.month && 
          streak.lastCompletedDate!.day == now.day) {
        return null;
      }

      final courses = DailyLearningRepository.instance.courses;
      if (courses.isEmpty) return null;

      DailyLearningCourse? targetCourse;
      DailyLearningLesson? nextLesson;

      for (final course in courses) {
        final progressRecord = await DailyLearningRepository.instance.watchProgress(widget.user.id, course.id).first;
        final completed = progressRecord.$1;
        for (final l in course.lessons) {
          if (!completed.contains(l.id)) {
            targetCourse = course;
            nextLesson = l;
            break;
          }
        }
        if (nextLesson != null) {
          break;
        }
      }
      
      if (targetCourse == null || nextLesson == null) {
        return null; // All done
      }
      
      return _PendingChallenge(course: targetCourse, lesson: nextLesson, streak: streak);
    } catch (e) {
      debugPrint('DailyChallengeGate error: $e');
      return null;
    }
  }
}

class _PendingChallenge {
  final DailyLearningCourse course;
  final DailyLearningLesson lesson;
  final DailyLearningStreak? streak;
  _PendingChallenge({required this.course, required this.lesson, this.streak});
}

class _DailyChallengeOverlay extends StatelessWidget {
  final AppUser user;
  final DailyLearningCourse course;
  final DailyLearningLesson lesson;
  final DailyLearningStreak? streak;
  final VoidCallback onDismiss;

  const _DailyChallengeOverlay({
    required this.user,
    required this.course,
    required this.lesson,
    this.streak,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final currentStreak = streak?.currentStreak ?? 0;

    return Scaffold(
      backgroundColor: ac.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ac.txt2),
                    onPressed: onDismiss,
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Icon(Icons.local_fire_department_rounded, size: 80, color: currentStreak > 0 ? Colors.orange : ac.muted),
              ),
              const SizedBox(height: 16),
              Text(
                currentStreak > 0 ? '$currentStreak Day Streak!' : 'Start Your Streak!',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w800, color: ac.txt),
              ),
              const SizedBox(height: 16),
              Text(
                'Ready for today\'s intellectual challenge?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: ac.txt2, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ac.surf,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: Shad.sm,
                ),
                child: Column(
                  children: [
                    Text(course.title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.primary)),
                    const SizedBox(height: 8),
                    Text(lesson.title, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: ac.txt), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryBtn(
                label: 'Start Challenge',
                onTap: () {
                  onDismiss(); // Mark as dismissed so when we pop back, we go to HomeShell
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DailyLearningLessonPage(
                      user: user,
                      course: course,
                      lesson: lesson,
                    ),
                  ));
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onDismiss,
                child: Text('Not now', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ac.txt2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

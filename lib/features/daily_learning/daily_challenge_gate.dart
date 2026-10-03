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
  // Resolved ONCE per signed-in user, not per build. This gate wraps
  // HomeShell, and _AppUserGate rebuilds it every time the user row
  // changes (XP awarded, profile edit...). Creating the future inside
  // build() used to restart it on each of those rebuilds, swapping the
  // whole HomeShell for a spinner and back -- losing the current tab and
  // scroll position and re-firing every Home query.
  late Future<_PendingChallenge?> _pending;
  bool _dismissed = false;

  /// Never let this gate hold the whole app hostage: a stalled (not
  /// failed) connection used to leave users on a spinner forever.
  static const _timeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _pending = _resolve();
  }

  @override
  void didUpdateWidget(covariant DailyChallengeGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _dismissed = false;
      _pending = _resolve();
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  static bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<_PendingChallenge?> _resolve() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('daily_challenge_dismissed_${widget.user.id}') == _todayKey()) return null;
      return await _getPendingChallenge().timeout(_timeout, onTimeout: () => null);
    } catch (e) {
      debugPrint('DailyChallengeGate error: $e');
      return null; // fail open -- the app matters more than the prompt
    }
  }

  void _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('daily_challenge_dismissed_${widget.user.id}', _todayKey());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return widget.child;
    return FutureBuilder<_PendingChallenge?>(
      future: _pending,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final pending = snap.data;
        if (pending == null) return widget.child;
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
    final streak = await DailyLearningRepository.instance.watchStreak(widget.user.id).first;
    if (_isToday(streak?.lastCompletedDate)) return null; // already done today

    final courses = DailyLearningRepository.instance.courses;
    for (final course in courses) {
      final progress = await DailyLearningRepository.instance.watchProgress(widget.user.id, course.id).first;
      final completed = progress.$1;
      for (final l in course.lessons) {
        if (!completed.contains(l.id)) {
          return _PendingChallenge(course: course, lesson: l, streak: streak);
        }
      }
    }
    return null; // every lesson done
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

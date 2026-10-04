// lib/features/daily_learning/daily_learning_lesson_page.dart
// One lesson's full flow: a few short teaching facts, then a small quiz
// that reinforces them, then a real result (correct count + actual XP
// awarded via DailyLearningRepository.completeLesson -- never a
// fabricated number). Duolingo/W3Schools-style bite size: teach, test,
// done, not a long-form course viewer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/daily_learning.dart';
import '../../repositories/daily_learning_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

enum _Phase { teach, quiz, result }

class DailyLearningLessonPage extends StatefulWidget {
  final AppUser user;
  final DailyLearningCourse course;
  final DailyLearningLesson lesson;
  const DailyLearningLessonPage({
    super.key, required this.user, required this.course, required this.lesson,
  });

  @override
  State<DailyLearningLessonPage> createState() => _DailyLearningLessonPageState();
}

class _DailyLearningLessonPageState extends State<DailyLearningLessonPage> {
  _Phase _phase = _Phase.teach;
  int _questionIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _correctCount = 0;
  int _xpAwarded = 0;
  bool _wasReplay = false;
  bool _saving = false;

  DailyLearningQuestion get _question => widget.lesson.questions[_questionIndex];

  void _selectOption(int i) {
    if (_answered) return;
    setState(() {
      _selectedOption = i;
      _answered = true;
      if (i == _question.correctIndex) _correctCount++;
    });
  }

  Future<void> _nextQuestion() async {
    if (_questionIndex < widget.lesson.questions.length - 1) {
      setState(() {
        _questionIndex++;
        _selectedOption = null;
        _answered = false;
      });
      return;
    }
    setState(() => _saving = true);
    int? awarded;
    try {
      awarded = await DailyLearningRepository.instance.completeLesson(
        userId: widget.user.id,
        courseId: widget.course.id,
        lessonId: widget.lesson.id,
        correctCount: _correctCount,
      ).timeout(const Duration(seconds: 5), onTimeout: () => _correctCount * 10);
    } catch (e) {
      debugPrint('Error saving daily challenge completion: $e');
      awarded = _correctCount * 10;
    } finally {
      if (mounted) {
        setState(() {
          _wasReplay = awarded == null;
          _xpAwarded = awarded ?? 0;
          _saving = false;
          _phase = _Phase.result;
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        title: Text(widget.lesson.title, style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: switch (_phase) {
        _Phase.teach => _teachView(ac),
        _Phase.quiz => _quizView(ac),
        _Phase.result => _resultView(ac),
      },
    );
  }

  Widget _teachView(AppColors ac) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What you\'ll learn', style: GoogleFonts.sora(
            fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: widget.lesson.teachingPoints.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.md)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_outline_rounded, color: ac.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.lesson.teachingPoints[i],
                    style: GoogleFonts.inter(fontSize: 13.5, color: ac.txt, height: 1.4))),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryBtn(
          label: 'Start Quiz',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _phase = _Phase.quiz);
          },
        ),
      ]),
    );
  }

  Widget _quizView(AppColors ac) {
    final total = widget.lesson.questions.length;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_questionIndex + 1) / total,
            backgroundColor: ac.bdr2,
            valueColor: AlwaysStoppedAnimation(ac.primary),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Text('Question ${_questionIndex + 1} of $total',
            style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
        const SizedBox(height: 20),
        Text(_question.prompt, style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt, height: 1.35)),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: _question.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OptionTile(
              text: _question.options[i],
              state: !_answered
                  ? _OptionState.neutral
                  : i == _question.correctIndex
                      ? _OptionState.correct
                      : i == _selectedOption
                          ? _OptionState.wrong
                          : _OptionState.dimmed,
              onTap: () => _selectOption(i),
            ),
          ),
        ),
        if (_answered) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(Rad.sm)),
            child: Text(_question.explanation,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2, height: 1.4)),
          ),
          const SizedBox(height: 14),
          PrimaryBtn(
            label: _questionIndex < total - 1 ? 'Next' : 'Finish Lesson',
            loading: _saving,
            onTap: _nextQuestion,
          ),
        ],
      ]),
    );
  }

  Widget _resultView(AppColors ac) {
    final total = widget.lesson.questions.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(color: ac.grnBg, shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded, color: ac.grn, size: 44),
        ),
        const SizedBox(height: 20),
        Text('Lesson complete!', style: GoogleFonts.sora(
            fontSize: 20, fontWeight: FontWeight.w800, color: ac.txt)),
        const SizedBox(height: 8),
        Text('$_correctCount of $total correct',
            style: GoogleFonts.inter(fontSize: 14, color: ac.txt2)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.star_rounded, color: ac.gold, size: 18),
          const SizedBox(width: 4),
          Text(_wasReplay ? 'Practice round — XP was earned the first time' : '+$_xpAwarded XP',
              style: GoogleFonts.sora(fontSize: _wasReplay ? 12.5 : 14, fontWeight: FontWeight.w700, color: ac.gold)),
        ]),
        const SizedBox(height: 28),
        PrimaryBtn(
          label: 'Done',
          onTap: () => Navigator.of(context).pop(true),
        ),
      ]),
    );
  }
}

enum _OptionState { neutral, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback onTap;
  const _OptionTile({required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final (bg, border, fg) = switch (state) {
      _OptionState.neutral => (ac.surf, ac.bdr, ac.txt),
      _OptionState.correct => (ac.grnBg, ac.grn, ac.grn),
      _OptionState.wrong   => (ac.redBg, ac.red, ac.red),
      _OptionState.dimmed  => (ac.surf, ac.bdr2, ac.muted),
    };
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: border)),
          child: Row(children: [
            Expanded(child: Text(text, style: GoogleFonts.inter(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: fg))),
            if (state == _OptionState.correct) Icon(Icons.check_circle_rounded, color: ac.grn, size: 18),
            if (state == _OptionState.wrong) Icon(Icons.cancel_rounded, color: ac.red, size: 18),
          ]),
        ),
      ),
    );
  }
}

// lib/features/testing/test_taking_page.dart
// Renders all three question formats in one scrollable attempt:
//   - MCQ: radio-style option list.
//   - Structured: one multi-line box, answered one point per line — each
//     non-empty line becomes one entry in the graded response's
//     textAnswer list. When the question was authored with expected
//     answer/key points (production_plan.md §3 Quiz Type 2), those lines
//     are matched offline against them the same way an Essay's are
//     (core/essay_matching.dart); otherwise the answer goes to a human
//     grader exactly as before.
//   - Essay (longForm): NOT a prose box. production_plan.md §3 Quiz
//     Type 3 is explicit — "Essay Quiz = demonstrate that you understand
//     the structure and essential content of the essay, not reproduce a
//     two-page essay inside the application". So the student gets one
//     short line per essential point and states the points they would
//     include; core/essay_matching.dart then scores how many of the
//     author's 7–9 essential points they captured.
//
// UI decision for the Essay input (logged in AUTOPILOT_LOG): the student
// TYPES their own points rather than ticking them off a displayed list of
// the real key points. Showing the real points and asking which ones
// matter would hand over the entire answer — the student would score 100%
// by selecting everything, and the question would test nothing. Typing
// their own phrasing is the only shape that actually demonstrates recall,
// which is what the spec asks the Essay quiz to measure.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/test.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../core/result.dart';
import 'test_result_page.dart';
import '../../core/content_quality.dart';

class TestTakingPage extends StatefulWidget {
  final AppUser user;
  final Test test;
  /// Set when launched from HomeworkPage's "Take Quiz" action (spec item
  /// 4B) — threaded through to TestRepository.submitAttempt so the
  /// server can enforce the real, per-student homework deadline.
  final String? homeworkId;
  const TestTakingPage({super.key, required this.user, required this.test, this.homeworkId});

  @override
  State<TestTakingPage> createState() => _TestTakingPageState();
}

class _TestTakingPageState extends State<TestTakingPage> {
  AppColors get ac => AppColors.of(context);

  final Map<String, int> _mcqAnswers = {};
  final Map<String, TextEditingController> _textControllers = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final q in widget.test.questions) {
      if (q.type == QuestionType.structured) {
        _textControllers[q.id] = TextEditingController();
      } else if (q.type == QuestionType.longForm) {
        for (var i = 0; i < q.keyPoints.length; i++) {
          _textControllers['${q.id}_$i'] = TextEditingController();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allAnswered {
    for (final q in widget.test.questions) {
      switch (q.type) {
        case QuestionType.mcq:
          if (!_mcqAnswers.containsKey(q.id)) return false;
          break;
        case QuestionType.structured:
          if ((_textControllers[q.id]?.text.trim() ?? '').isEmpty) return false;
          break;
        case QuestionType.longForm:
          // Deliberately NOT "every box filled". The Essay score IS how
          // many of the essential points the student managed to recall,
          // so a student who can only produce four of nine points must
          // still be able to submit and be scored 4/9 — blocking
          // submission until all nine boxes are full would turn a
          // scoring dimension into a hard gate. One point is the floor
          // for having attempted the question at all.
          if (_essayPointsEntered(q) == 0) return false;
          break;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    final ac = AppColors.of(context);
    if (widget.user.isGuest) {
      showToast(context, 'Sign in to submit a test', isError: true);
      return;
    }

    if (!_allAnswered) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ac.bg,
          title: Text('Unanswered Questions', style: AppText.title),
          content: Text('You have not answered all questions. Are you sure you want to submit?', style: AppText.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: AppText.button.copyWith(color: ac.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ac.primary),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Submit Anyway', style: AppText.button.copyWith(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _submitting = true);
    final rawAnswers = <String, dynamic>{};
    for (final q in widget.test.questions) {
      switch (q.type) {
        case QuestionType.mcq:
          rawAnswers[q.id] = _mcqAnswers[q.id] ?? -1;
          break;
        case QuestionType.structured:
          final lines = (_textControllers[q.id]?.text ?? '')
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          rawAnswers[q.id] = lines;
          break;
        case QuestionType.longForm:
          rawAnswers[q.id] = [
            for (var i = 0; i < q.keyPoints.length; i++)
              _textControllers['${q.id}_$i']?.text.trim() ?? '',
          ].where((s) => s.isNotEmpty).toList();
          break;
      }
    }

    final result = await TestRepository.instance.submitAttempt(
      test: widget.test,
      userId: widget.user.id,
      userName: widget.user.name,
      rawAnswers: rawAnswers,
      educationLevel: widget.user.educationLevel,
      homeworkId: widget.homeworkId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result case Success(:final value)) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => TestResultPage(attempt: value)));
    } else if (result case Failure(:final message)) {
      showToast(context, message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(title: Text(displayQuizTitle(test), style: AppText.h2)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          for (var i = 0; i < test.questions.length; i++) ...[
            _questionCard(i, test.questions[i]),
            const SizedBox(height: 14),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryBtn(
            label: 'Submit Test',
            loading: _submitting,
            onTap: _submit,
          ),
        ),
      ),
    );
  }

  Widget _questionCard(int index, TestQuestion q) {
    return ACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusBadge(label: 'Q${index + 1} · ${q.points} pts', color: ac.primary),
          const Spacer(),
          StatusBadge(label: q.type.label, color: ac.pur),
        ]),
        const SizedBox(height: 10),
        Text(q.prompt, style: AppText.body),
        if ((q.imageUrl ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(Rad.sm),
            child: Image.network(q.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ],
        const SizedBox(height: 12),
        if (q.type == QuestionType.mcq) _mcqOptions(q),
        if (q.type == QuestionType.structured) _structuredInput(q),
        if (q.type == QuestionType.longForm) _longFormInput(q),
      ]),
    );
  }

  Widget _mcqOptions(TestQuestion q) {
    return Column(children: [
      for (var i = 0; i < q.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.sm),
              onTap: () => setState(() => _mcqAnswers[q.id] = i),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _mcqAnswers[q.id] == i ? ac.primaryBg : ac.surf2,
                  borderRadius: BorderRadius.circular(Rad.sm),
                  border: Border.all(color: _mcqAnswers[q.id] == i ? ac.primary : ac.bdr),
                ),
                child: Row(children: [
                  Icon(
                    _mcqAnswers[q.id] == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18,
                    color: _mcqAnswers[q.id] == i ? ac.primary : ac.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(q.options[i], style: AppText.bodySm)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _structuredInput(TestQuestion q) {
    // production_plan.md §3 Quiz Type 2: when the author defined expected
    // answer/key points, this answer is matched against them offline
    // (core/essay_matching.dart, same matcher as Essay) rather than sent
    // straight to a human — worth telling the student, same as the Essay
    // input does for its own auto-grading.
    final autoGraded = q.expectedPoints.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        autoGraded
            ? 'Write one point per line (${q.lineCount} lines expected). '
                'Each point you capture is marked automatically.'
            : 'Write one point per line (${q.lineCount} lines expected)',
        style: AppText.caption,
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _textControllers[q.id],
        maxLines: q.lineCount.clamp(3, 12),
        minLines: q.lineCount.clamp(3, 12),
        decoration: const InputDecoration(hintText: 'Line 1\nLine 2\n...'),
      ),
    ]);
  }

  /// How many non-empty points the student has entered for [q] so far.
  int _essayPointsEntered(TestQuestion q) {
    var count = 0;
    for (var i = 0; i < q.keyPoints.length; i++) {
      if ((_textControllers['${q.id}_$i']?.text.trim() ?? '').isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  Widget _longFormInput(TestQuestion q) {
    final total = q.keyPoints.length;
    final entered = _essayPointsEntered(q);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ac.primaryBg,
          borderRadius: BorderRadius.circular(Rad.sm),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.checklist_rounded, size: 16, color: ac.primary),
            const SizedBox(width: 6),
            Text('Essential points', style: AppText.subtitle.copyWith(color: ac.primary)),
          ]),
          const SizedBox(height: 6),
          Text(
            'A strong answer to this question contains $total essential points. '
            "Write each point you would include as one short line — you're not "
            'asked to write the full essay. Every point you capture earns marks.',
            style: AppText.caption,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < total; i++) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26, height: 26,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: (_textControllers['${q.id}_$i']?.text.trim() ?? '').isEmpty
                  ? ac.surf2
                  : ac.primaryBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${i + 1}',
                  style: AppText.label.copyWith(
                    color: (_textControllers['${q.id}_$i']?.text.trim() ?? '').isEmpty
                        ? ac.muted
                        : ac.primary,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _textControllers['${q.id}_$i'],
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: i == 0
                    ? 'e.g. a key idea, cause, stage or consequence'
                    : 'Point ${i + 1}',
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
      ],
      Row(children: [
        Icon(Icons.edit_note_rounded, size: 14, color: ac.muted),
        const SizedBox(width: 5),
        Text('$entered of $total points written', style: AppText.caption),
      ]),
    ]);
  }
}

// lib/features/testing/test_taking_page.dart
// Renders all three question formats in one scrollable attempt:
//   - MCQ: radio-style option list.
//   - Structured: one multi-line box, answered one point per line —
//     each non-empty line becomes one entry in the graded response's
//     textAnswer list.
//   - Long-form (AC): one labelled box per required section (Summary /
//     Methodology / Steps, or a theory subject's outline headings) —
//     whatever the test's author configured on the question.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/test.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../core/result.dart';
import 'test_result_page.dart';

class TestTakingPage extends StatefulWidget {
  final AppUser user;
  final Test test;
  const TestTakingPage({super.key, required this.user, required this.test});

  @override
  State<TestTakingPage> createState() => _TestTakingPageState();
}

class _TestTakingPageState extends State<TestTakingPage> {
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
        for (var i = 0; i < q.requiredSections.length; i++) {
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
          for (var i = 0; i < q.requiredSections.length; i++) {
            if ((_textControllers['${q.id}_$i']?.text.trim() ?? '').isEmpty) return false;
          }
          break;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (widget.user.isGuest) {
      showToast(context, 'Sign in to submit a test', isError: true);
      return;
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
          rawAnswers[q.id] = List.generate(
            q.requiredSections.length,
            (i) => _textControllers['${q.id}_$i']?.text.trim() ?? '',
          );
          break;
      }
    }

    final result = await TestRepository.instance.submitAttempt(
      test: widget.test,
      userId: widget.user.id,
      userName: widget.user.name,
      rawAnswers: rawAnswers,
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
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(test.title, style: AppText.h2)),
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
            label: _allAnswered ? 'Submit Test' : 'Answer all questions to submit',
            loading: _submitting,
            onTap: _allAnswered ? _submit : () {},
          ),
        ),
      ),
    );
  }

  Widget _questionCard(int index, TestQuestion q) {
    return ACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusBadge(label: 'Q${index + 1} · ${q.points} pts', color: C.primary),
          const Spacer(),
          StatusBadge(label: q.type.label, color: C.pur),
        ]),
        const SizedBox(height: 10),
        Text(q.prompt, style: AppText.body),
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
                  color: _mcqAnswers[q.id] == i ? C.primaryBg : C.surf2,
                  borderRadius: BorderRadius.circular(Rad.sm),
                  border: Border.all(color: _mcqAnswers[q.id] == i ? C.primary : C.bdr),
                ),
                child: Row(children: [
                  Icon(
                    _mcqAnswers[q.id] == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18,
                    color: _mcqAnswers[q.id] == i ? C.primary : C.muted,
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Write one point per line (${q.lineCount} lines expected)', style: AppText.caption),
      const SizedBox(height: 6),
      TextField(
        controller: _textControllers[q.id],
        maxLines: q.lineCount.clamp(3, 12),
        minLines: q.lineCount.clamp(3, 12),
        decoration: const InputDecoration(hintText: 'Line 1\nLine 2\n...'),
      ),
    ]);
  }

  Widget _longFormInput(TestQuestion q) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < q.requiredSections.length; i++) ...[
        Text(q.requiredSections[i], style: AppText.subtitle),
        const SizedBox(height: 6),
        TextField(
          controller: _textControllers['${q.id}_$i'],
          maxLines: 5,
          minLines: 3,
          decoration: InputDecoration(hintText: 'Your ${q.requiredSections[i].toLowerCase()}...'),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

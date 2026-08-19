// lib/features/testing/grading_page.dart
// Manual grading queue. Gated by AppUser.hasMinRole(UserRole.lecturer) at
// the call site (see AppDrawer) — Firestore rules should mirror this gate
// for the `testAttempts` collection; that rules update is still pending
// (see TestRepository's file-level honest scope note).
//
// Two quite different jobs land here, split by whether the response
// carries QuestionResponse.keyPointOutcomes rather than by QuestionType —
// a Structured answer authored with expected points (production_plan.md
// §3 Quiz Type 2) is graded exactly the SAME way an Essay is, not
// differently just because of its type:
//   - No key point outcomes (a plain Structured answer with no expected
//     points authored, or the old shape): a human reads the text and
//     types a score, as before.
//   - Has key point outcomes (Essay, always — or Structured, when the
//     author defined expected points): these were already auto-scored
//     against their essential/expected points at submit time
//     (core/essay_matching.dart), and only arrive here when the matcher
//     was explicitly UNDECIDED about one or more points. So the grader is
//     not scoring the answer from scratch — they see each point next to
//     the student's own wording, with the confident calls already made,
//     and just settle the flagged ones. The score is then derived from
//     the ticked points rather than typed, so the stored outcomes and the
//     stored score can never disagree.
//
// This is also the seam a future AI grader would plug into: whatever
// eventually generates a suggested score would call
// TestRepository.gradeResponse() exactly the way this page's "Save
// Grade" button does — no repository or model change needed.

import 'package:flutter/material.dart';
import '../../core/essay_matching.dart';
import '../../models/app_user.dart';
import '../../models/test.dart' show QuestionTypeExt;
import '../../models/test_attempt.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../core/result.dart';

class GradingPage extends StatelessWidget {
  final AppUser grader;
  final String? subjectFilter;
  const GradingPage({super.key, required this.grader, this.subjectFilter});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(title: Text('Grading Queue', style: AppText.h2)),
      body: StreamBuilder<List<TestAttempt>>(
        stream: TestRepository.instance.watchPendingGradingQueue(subject: subjectFilter),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(padding: const EdgeInsets.all(16), children: const [
              ShimmerCard(height: 80), ShimmerCard(height: 80),
            ]);
          }
          final attempts = snap.data ?? [];
          if (attempts.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Nothing to grade',
              subtitle: 'Every submitted structured/long-form answer has been reviewed.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: attempts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final a = attempts[i];
              final pendingCount = a.responses.where((r) => !r.graded).length;
              return ACard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _AttemptGradingDetailPage(attempt: a))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.testTitle, style: AppText.title),
                      const SizedBox(height: 3),
                      Text('${a.userName} · ${a.subject}', style: AppText.caption),
                    ]),
                  ),
                  StatusBadge(label: '$pendingCount pending', color: ac.org),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _AttemptGradingDetailPage extends StatefulWidget {
  final TestAttempt attempt;
  const _AttemptGradingDetailPage({required this.attempt});

  @override
  State<_AttemptGradingDetailPage> createState() => _AttemptGradingDetailPageState();
}

class _AttemptGradingDetailPageState extends State<_AttemptGradingDetailPage> {
  AppColors get ac => AppColors.of(context);

  final Map<String, TextEditingController> _pointsCtrl = {};
  final Map<String, TextEditingController> _feedbackCtrl = {};
  final Set<String> _saving = {};
  final Set<String> _justGraded = {};

  /// Per key-point response (Essay, or Structured authored with expected
  /// points): which key point ids the grader currently counts as
  /// captured. Seeded from the matcher's own confident calls, so the
  /// grader starts from the auto-result and only adjusts.
  final Map<String, Set<String>> _pointsCaptured = {};

  TextEditingController _points(String qId, int max) =>
      _pointsCtrl.putIfAbsent(qId, () => TextEditingController(text: max.toString()));
  TextEditingController _feedback(String qId) =>
      _feedbackCtrl.putIfAbsent(qId, () => TextEditingController());

  Set<String> _captured(QuestionResponse r) => _pointsCaptured.putIfAbsent(
        r.questionId,
        () => r.keyPointOutcomes
            .where((o) => o.counted)
            .map((o) => o.keyPointId)
            .toSet(),
      );

  Future<void> _save(QuestionResponse r) async {
    final usesKeyPoints = r.keyPointOutcomes.isNotEmpty;
    int points;
    if (usesKeyPoints) {
      // Derived from the ticked key points, never typed — see
      // TestRepository.gradeResponse's note on why.
      points = _captured(r).length;
    } else {
      final text = _points(r.questionId, r.maxPoints).text.trim();
      final parsed = int.tryParse(text);
      if (parsed == null || parsed < 0 || parsed > r.maxPoints) {
        showToast(context, 'Enter a score between 0 and ${r.maxPoints}', isError: true);
        return;
      }
      points = parsed;
    }
    setState(() => _saving.add(r.questionId));
    final result = await TestRepository.instance.gradeResponse(
      attemptId: widget.attempt.id,
      questionId: r.questionId,
      pointsAwarded: points,
      feedback: _feedback(r.questionId).text.trim().isEmpty ? null : _feedback(r.questionId).text.trim(),
      capturedKeyPointIds: usesKeyPoints ? _captured(r).toList() : null,
    );
    if (!mounted) return;
    setState(() {
      _saving.remove(r.questionId);
      if (result is Success) _justGraded.add(r.questionId);
    });
    if (result case Failure(:final message)) {
      showToast(context, message, isError: true);
    } else {
      showToast(context, 'Grade saved');
    }
  }

  @override
  void dispose() {
    for (final c in _pointsCtrl.values) { c.dispose(); }
    for (final c in _feedbackCtrl.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attempt;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(title: Text('${a.userName} · ${a.testTitle}', style: AppText.h2)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final r in a.responses) ...[
            _responseGradingCard(r),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _responseGradingCard(QuestionResponse r) {
    final alreadyGraded = r.graded || _justGraded.contains(r.questionId);
    final usesKeyPoints = r.keyPointOutcomes.isNotEmpty;
    return ACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusBadge(label: r.type.label, color: ac.pur),
          const Spacer(),
          if (usesKeyPoints && !alreadyGraded)
            StatusBadge(
              label: '${r.uncertainOutcomes.length} to settle',
              color: ac.org,
            ),
          if (alreadyGraded) StatusBadge(label: 'Graded', color: ac.grn),
        ]),
        const SizedBox(height: 10),
        if (usesKeyPoints)
          _keyPointReview(r, alreadyGraded)
        else ...[
          for (final line in r.textAnswer) ...[
            Text('• $line', style: AppText.bodySm),
            const SizedBox(height: 4),
          ],
          if (r.textAnswer.isEmpty)
            Text('(No answer submitted)', style: AppText.caption),
        ],
        const SizedBox(height: 12),
        if (!alreadyGraded) ...[
          Row(children: [
            if (!usesKeyPoints) ...[
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _points(r.questionId, r.maxPoints),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Points (/${r.maxPoints})'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: TextField(
                controller: _feedback(r.questionId),
                decoration: const InputDecoration(labelText: 'Feedback (optional)'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          PrimaryBtn(
            label: usesKeyPoints
                ? 'Save Grade · ${_captured(r).length}/${r.maxPoints} points captured'
                : 'Save Grade',
            loading: _saving.contains(r.questionId),
            onTap: () => _save(r),
          ),
        ] else ...[
          Text('${r.pointsAwarded}/${r.maxPoints} pts · +${r.xpEarned} XP', style: AppText.bodySm),
          if (r.feedback != null && r.feedback!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.feedback!, style: AppText.caption),
          ],
        ],
      ]),
    );
  }

  /// Every essential/expected key point, paired with what the student
  /// actually wrote for it and the matcher's own verdict. Used for both
  /// Essay and a Structured question graded against expected points. The
  /// grader can retick any of them; the ones the matcher flagged as
  /// uncertain are called out so it's obvious where a decision is
  /// genuinely needed.
  Widget _keyPointReview(QuestionResponse r, bool alreadyGraded) {
    final captured = _captured(r);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'The student wrote ${r.textAnswer.length} point'
        '${r.textAnswer.length == 1 ? '' : 's'}. Each essential point below '
        'is shown with the closest thing they wrote.',
        style: AppText.caption,
      ),
      const SizedBox(height: 10),
      for (final o in r.keyPointOutcomes) ...[
        _keyPointRow(r, o, captured, alreadyGraded),
        const SizedBox(height: 8),
      ],
    ]);
  }

  Widget _keyPointRow(
    QuestionResponse r,
    KeyPointOutcome o,
    Set<String> captured,
    bool alreadyGraded,
  ) {
    final isTicked = alreadyGraded ? o.counted : captured.contains(o.keyPointId);
    final needsCall = o.verdict == KeyPointVerdict.uncertain && o.humanDecision == null;
    final accent = needsCall ? ac.org : (isTicked ? ac.grn : ac.muted);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: needsCall && !alreadyGraded ? ac.orgBg : ac.surf2,
        borderRadius: BorderRadius.circular(Rad.sm),
        border: Border.all(color: needsCall && !alreadyGraded ? ac.org : ac.bdr),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (alreadyGraded)
          Icon(isTicked ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 20, color: accent)
        else
          SizedBox(
            width: 24, height: 24,
            child: Checkbox(
              value: isTicked,
              onChanged: (v) => setState(() {
                if (v == true) {
                  captured.add(o.keyPointId);
                } else {
                  captured.remove(o.keyPointId);
                }
              }),
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.keyPointText, style: AppText.bodySm),
            const SizedBox(height: 4),
            if (o.studentText.isNotEmpty)
              Text('Student wrote: "${o.studentText}"', style: AppText.caption)
            else
              Text('Nothing the student wrote matched this point',
                  style: AppText.caption),
            const SizedBox(height: 4),
            Row(children: [
              StatusBadge(label: o.verdict.label, color: accent),
              const SizedBox(width: 8),
              Text('match ${(o.score * 100).round()}%', style: AppText.caption),
            ]),
          ]),
        ),
      ]),
    );
  }
}

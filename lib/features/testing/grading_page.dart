// lib/features/testing/grading_page.dart
// Manual grading queue for structured/long-form answers. Gated by
// AppUser.hasMinRole(UserRole.lecturer) at the call site (see
// TestsSubjectPickerPage) — Firestore rules should mirror this gate for
// the `testAttempts` collection; that rules update is still pending (see
// TestRepository's file-level honest scope note).
//
// This is also the seam a future AI grader would plug into: whatever
// eventually generates a suggested score would call
// TestRepository.gradeResponse() exactly the way this page's "Save
// Grade" button does — no repository or model change needed.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/test.dart' show QuestionTypeExt;
import '../../models/test_attempt.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../core/result.dart';

class GradingPage extends StatelessWidget {
  final AppUser grader;
  final String? subjectFilter;
  const GradingPage({super.key, required this.grader, this.subjectFilter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
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
                  StatusBadge(label: '$pendingCount pending', color: C.org),
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
  final Map<String, TextEditingController> _pointsCtrl = {};
  final Map<String, TextEditingController> _feedbackCtrl = {};
  final Set<String> _saving = {};
  final Set<String> _justGraded = {};

  TextEditingController _points(String qId, int max) =>
      _pointsCtrl.putIfAbsent(qId, () => TextEditingController(text: max.toString()));
  TextEditingController _feedback(String qId) =>
      _feedbackCtrl.putIfAbsent(qId, () => TextEditingController());

  Future<void> _save(QuestionResponse r) async {
    final text = _points(r.questionId, r.maxPoints).text.trim();
    final points = int.tryParse(text);
    if (points == null || points < 0 || points > r.maxPoints) {
      showToast(context, 'Enter a score between 0 and ${r.maxPoints}', isError: true);
      return;
    }
    setState(() => _saving.add(r.questionId));
    final result = await TestRepository.instance.gradeResponse(
      attemptId: widget.attempt.id,
      questionId: r.questionId,
      pointsAwarded: points,
      feedback: _feedback(r.questionId).text.trim().isEmpty ? null : _feedback(r.questionId).text.trim(),
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
      backgroundColor: C.bg,
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
    return ACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusBadge(label: r.type.label, color: C.pur),
          const Spacer(),
          if (alreadyGraded) const StatusBadge(label: 'Graded', color: C.grn),
        ]),
        const SizedBox(height: 10),
        for (final line in r.textAnswer) ...[
          Text('• $line', style: AppText.bodySm),
          const SizedBox(height: 4),
        ],
        if (r.textAnswer.isEmpty)
          Text('(No answer submitted)', style: AppText.caption),
        const SizedBox(height: 12),
        if (!alreadyGraded) ...[
          Row(children: [
            SizedBox(
              width: 90,
              child: TextField(
                controller: _points(r.questionId, r.maxPoints),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Points (/${r.maxPoints})'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _feedback(r.questionId),
                decoration: const InputDecoration(labelText: 'Feedback (optional)'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          PrimaryBtn(
            label: 'Save Grade',
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
}

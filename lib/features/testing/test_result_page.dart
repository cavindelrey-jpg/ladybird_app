// lib/features/testing/test_result_page.dart
// Shown right after submission. If the test had any structured/long-form
// questions, this is an HONEST partial result — it shows what's graded
// so far (usually just the MCQ portion) and says plainly that the rest
// is awaiting review, rather than faking a final score.

import 'package:flutter/material.dart';
import '../../models/test.dart';
import '../../models/test_attempt.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class TestResultPage extends StatelessWidget {
  final TestAttempt attempt;
  const TestResultPage({super.key, required this.attempt});

  Color _scoreColor(double pct) {
    if (pct >= 80) return C.grn;
    if (pct >= 60) return C.gold;
    if (pct >= 40) return C.org;
    return C.red;
  }

  @override
  Widget build(BuildContext context) {
    final graded = attempt.responses.where((r) => r.graded).toList();
    final pending = attempt.responses.where((r) => !r.graded).toList();
    final gradedPoints = graded.fold(0, (s, r) => s + (r.pointsAwarded ?? 0));
    final gradedMax = graded.fold(0, (s, r) => s + r.maxPoints);
    final scorePct = gradedMax == 0 ? 0.0 : (gradedPoints / gradedMax * 100);
    final color = _scoreColor(scorePct);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(attempt.testTitle, style: AppText.h2)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ACard(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Container(
                width: 84, height: 84,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .12)),
                child: Center(
                  child: Text('${scorePct.round()}%',
                      style: AppText.display.copyWith(fontSize: 26, color: color)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                pending.isEmpty ? 'Test complete' : 'Auto-graded portion complete',
                style: AppText.title,
              ),
              const SizedBox(height: 4),
              Text('$gradedPoints / $gradedMax points graded so far', style: AppText.caption),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: C.goldp, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt_rounded, color: C.gold, size: 18),
                  const SizedBox(width: 6),
                  Text('+${attempt.totalXpAwarded} XP so far',
                      style: AppText.bodySm.copyWith(color: C.gold, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            ACard(
              color: C.orgb,
              child: Row(children: [
                const Icon(Icons.hourglass_top_rounded, color: C.org),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${pending.length} answer${pending.length == 1 ? '' : 's'} still awaiting review. '
                    'You\'ll earn more XP once ${pending.length == 1 ? 'it is' : 'they are'} graded.',
                    style: AppText.bodySm.copyWith(color: C.org),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          SectionHeader(title: 'Question Breakdown'),
          const SizedBox(height: 10),
          for (final r in attempt.responses) ...[
            _responseTile(r),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          SecondaryBtn(label: 'Done', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _responseTile(QuestionResponse r) {
    return ACard(
      child: Row(children: [
        Icon(
          !r.graded
              ? Icons.hourglass_empty_rounded
              : (r.pointsAwarded == r.maxPoints ? Icons.check_circle_rounded : Icons.info_rounded),
          color: !r.graded ? C.muted : (r.pointsAwarded == r.maxPoints ? C.grn : C.gold),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.type.label, style: AppText.subtitle),
            const SizedBox(height: 2),
            Text(
              !r.graded
                  ? 'Awaiting review'
                  : '${r.pointsAwarded}/${r.maxPoints} pts · +${r.xpEarned} XP',
              style: AppText.caption,
            ),
            if (r.feedback != null && r.feedback!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.feedback!, style: AppText.bodySm),
            ],
          ]),
        ),
      ]),
    );
  }
}

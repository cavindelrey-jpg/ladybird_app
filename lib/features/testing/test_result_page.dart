// lib/features/testing/test_result_page.dart
// Shown right after submission. If the test had any structured/long-form
// questions, this is an HONEST partial result — it shows what's graded
// so far (usually just the MCQ portion) and says plainly that the rest
// is awaiting review, rather than faking a final score.

import 'package:flutter/material.dart';
import '../../core/essay_matching.dart';
import '../../models/test.dart';
import '../../models/test_attempt.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

class TestResultPage extends StatelessWidget {
  final TestAttempt attempt;
  const TestResultPage({super.key, required this.attempt});

  Color _scoreColor(AppColors ac, double pct) {
    if (pct >= 80) return ac.grn;
    if (pct >= 60) return ac.gold;
    if (pct >= 40) return ac.org;
    return ac.red;
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final graded = attempt.responses.where((r) => r.graded).toList();
    final pending = attempt.responses.where((r) => !r.graded).toList();
    final gradedPoints = graded.fold(0, (s, r) => s + (r.pointsAwarded ?? 0));
    final gradedMax = graded.fold(0, (s, r) => s + r.maxPoints);
    final scorePct = gradedMax == 0 ? 0.0 : (gradedPoints / gradedMax * 100);
    final color = _scoreColor(ac, scorePct);

    return Scaffold(
      backgroundColor: ac.bg,
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
                decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, color: ac.gold, size: 18),
                  const SizedBox(width: 6),
                  Text('+${attempt.totalXpAwarded} XP so far',
                      style: AppText.bodySm.copyWith(color: ac.gold, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            ACard(
              color: ac.orgBg,
              child: Row(children: [
                Icon(Icons.hourglass_top_rounded, color: ac.org),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${pending.length} answer${pending.length == 1 ? '' : 's'} still awaiting review. '
                    'You\'ll earn more XP once ${pending.length == 1 ? 'it is' : 'they are'} graded.',
                    style: AppText.bodySm.copyWith(color: ac.org),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          SectionHeader(title: 'Question Breakdown'),
          const SizedBox(height: 10),
          for (final r in attempt.responses) ...[
            _responseTile(ac, r),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          SecondaryBtn(label: 'Done', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _responseTile(AppColors ac, QuestionResponse r) {
    // Essay always uses key points; a Structured question does too when
    // authored with expected points (production_plan.md §3 Quiz Type 2) —
    // graded and displayed the same way either way.
    final usesKeyPoints = r.keyPointOutcomes.isNotEmpty;
    final pointsLabel =
        r.type == QuestionType.longForm ? 'essential points' : 'expected points';
    return ACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            !r.graded
                ? Icons.hourglass_empty_rounded
                : (r.pointsAwarded == r.maxPoints ? Icons.check_circle_rounded : Icons.info_rounded),
            color: !r.graded ? ac.muted : (r.pointsAwarded == r.maxPoints ? ac.grn : ac.gold),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.type.label, style: AppText.subtitle),
              const SizedBox(height: 2),
              Text(
                !r.graded
                    ? (usesKeyPoints
                        ? '${r.uncertainOutcomes.length} point'
                            '${r.uncertainOutcomes.length == 1 ? '' : 's'} awaiting review'
                        : 'Awaiting review')
                    : (usesKeyPoints
                        ? 'Captured ${r.pointsAwarded} of ${r.maxPoints} $pointsLabel · +${r.xpEarned} XP'
                        : '${r.pointsAwarded}/${r.maxPoints} pts · +${r.xpEarned} XP'),
                style: AppText.caption,
              ),
              if (r.feedback != null && r.feedback!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.feedback!, style: AppText.bodySm),
              ],
            ]),
          ),
        ]),
        // The single most useful thing an essay/structured-with-expected-
        // points attempt can tell a student is WHICH points they missed —
        // that's the revision list. Showing it is the whole "demonstrate
        // you understand the essential/expected content" idea closing the
        // loop.
        if (usesKeyPoints) ...[
          const SizedBox(height: 10),
          for (final o in r.keyPointOutcomes) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                o.counted
                    ? Icons.check_rounded
                    : (o.verdict == KeyPointVerdict.uncertain && o.humanDecision == null
                        ? Icons.hourglass_empty_rounded
                        : Icons.close_rounded),
                size: 15,
                color: o.counted
                    ? ac.grn
                    : (o.verdict == KeyPointVerdict.uncertain && o.humanDecision == null
                        ? ac.org
                        : ac.red),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(o.keyPointText, style: AppText.caption)),
            ]),
            const SizedBox(height: 6),
          ],
        ],
      ]),
    );
  }
}

// lib/features/testing/tests_list_page.dart
// Bottom tier of the browse tree — the live list of published quizzes
// inside one Category > Subject > Topic. Each card shows the quiz's own
// thumbnail (a real photo if set, otherwise a generated letter-avatar —
// see HierarchyAvatar) plus its real question count, difficulty, and
// total points — no fabricated "estimated time" or fake completion
// stats. [category]/[topic] are optional so this page still works for
// callers that reach it without going through the tree tiers (e.g. chat's
// "share a quiz" picker reuses TestRepository.watchTestsBySubject
// directly, not this page — but keeping the filters optional here too
// means this page isn't hard-locked to always being opened from
// TestsTopicPickerPage).

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/test.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'test_taking_page.dart';
import '../../core/content_quality.dart';

class TestsListPage extends StatelessWidget {
  final AppUser user;
  final String subject;
  final String? category;
  final String? topic;
  const TestsListPage({
    super.key, required this.user, required this.subject, this.category, this.topic,
  });

  Color _difficultyColor(AppColors ac, TestDifficulty d) {
    switch (d) {
      case TestDifficulty.easy:   return ac.grn;
      case TestDifficulty.medium: return ac.gold;
      case TestDifficulty.hard:   return ac.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(title: Text(topic ?? subject, style: AppText.h2)),
      body: StreamBuilder<List<Test>>(
        stream: TestRepository.instance.watchTestsBySubject(
            subject, institutionId: user.schoolId, category: category, topic: topic),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(padding: const EdgeInsets.all(16), children: const [
              ShimmerCard(height: 90), ShimmerCard(height: 90),
            ]);
          }
          if (snap.hasError) {
            return ErrorView(message: snap.error.toString());
          }
          final tests = snap.data ?? [];
          if (tests.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No tests here yet',
              subtitle: 'Check back once a test is published for this subject.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final test = tests[i];
              final color = _difficultyColor(ac, test.difficulty);
              return ACard(
                onTap: user.isGuest
                    ? () => showToast(context, 'Sign in to take a test', isError: true)
                    : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TestTakingPage(user: user, test: test))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    HierarchyAvatar(label: displayQuizTitle(test), imageUrl: test.thumbnailUrl ?? '', size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: Text(displayQuizTitle(test), style: AppText.title)),
                    StatusBadge(label: test.difficulty.label, color: color),
                  ]),
                  if (test.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(test.description, style: AppText.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.help_outline_rounded, size: 14, color: ac.muted),
                    const SizedBox(width: 4),
                    Text('${test.questionCount} question${test.questionCount == 1 ? '' : 's'}', style: AppText.caption),
                    const SizedBox(width: 14),
                    Icon(Icons.grade_outlined, size: 14, color: ac.muted),
                    const SizedBox(width: 4),
                    Text('${test.totalPossiblePoints} pts', style: AppText.caption),
                    if (test.hasManualGrading) ...[
                      const SizedBox(width: 14),
                      Icon(Icons.rate_review_outlined, size: 14, color: ac.muted),
                      const SizedBox(width: 4),
                      Text('Some answers reviewed manually', style: AppText.caption),
                    ],
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

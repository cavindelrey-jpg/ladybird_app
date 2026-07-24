// lib/features/testing/tests_list_page.dart
// Live list of published tests for one subject. Each card shows the
// test's real question count, difficulty, and total points — no
// fabricated "estimated time" or fake completion stats.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/test.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'test_taking_page.dart';

class TestsListPage extends StatelessWidget {
  final AppUser user;
  final String subject;
  const TestsListPage({super.key, required this.user, required this.subject});

  Color _difficultyColor(TestDifficulty d) {
    switch (d) {
      case TestDifficulty.easy:   return C.grn;
      case TestDifficulty.medium: return C.gold;
      case TestDifficulty.hard:   return C.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(subject, style: AppText.h2)),
      body: StreamBuilder<List<Test>>(
        stream: TestRepository.instance.watchTestsBySubject(subject, institutionId: user.schoolId),
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
              final color = _difficultyColor(test.difficulty);
              return ACard(
                onTap: user.isGuest
                    ? () => showToast(context, 'Sign in to take a test', isError: true)
                    : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TestTakingPage(user: user, test: test))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(test.title, style: AppText.title)),
                    StatusBadge(label: test.difficulty.label, color: color),
                  ]),
                  if (test.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(test.description, style: AppText.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.help_outline_rounded, size: 14, color: C.muted),
                    const SizedBox(width: 4),
                    Text('${test.questionCount} question${test.questionCount == 1 ? '' : 's'}', style: AppText.caption),
                    const SizedBox(width: 14),
                    const Icon(Icons.grade_outlined, size: 14, color: C.muted),
                    const SizedBox(width: 4),
                    Text('${test.totalPossiblePoints} pts', style: AppText.caption),
                    if (test.hasManualGrading) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.rate_review_outlined, size: 14, color: C.muted),
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

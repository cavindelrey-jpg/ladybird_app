// lib/features/testing/tests_subject_picker_page.dart
// Entry point for the Testing & Quiz system — a subject grid, each tile
// showing the REAL number of published tests for that subject (computed
// from actual `tests` documents, never a placeholder count). Wired from
// Home's "Quizzes" Quick Access tile, which used to open a ComingSoonPage.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'tests_list_page.dart';
import 'xp_dashboard_page.dart';

class TestsSubjectPickerPage extends StatefulWidget {
  final AppUser user;
  const TestsSubjectPickerPage({super.key, required this.user});

  @override
  State<TestsSubjectPickerPage> createState() => _TestsSubjectPickerPageState();
}

class _TestsSubjectPickerPageState extends State<TestsSubjectPickerPage> {
  AppColors get ac => AppColors.of(context);

  Future<Map<String, int>>? _counts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _counts = TestRepository.instance.subjectTestCountsOnce());
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = widget.user.isGuest;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Tests & Quizzes', style: AppText.h2),
        actions: [
          if (!isGuest)
            IconButton(
              icon: Icon(Icons.bolt_rounded, color: ac.gold),
              tooltip: 'XP Dashboard',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => XpDashboardPage(user: widget.user))),
            ),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _counts,
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView(padding: const EdgeInsets.all(16), children: const [
              ShimmerCard(height: 72), ShimmerCard(height: 72), ShimmerCard(height: 72),
            ]);
          }
          final counts = snap.data!;
          if (counts.isEmpty) {
            return EmptyState(
              icon: Icons.quiz_rounded,
              title: 'No tests published yet',
              subtitle: 'Once a lecturer or admin publishes a subject test, it will show up here.',
              actionLabel: 'Refresh',
              onAction: _load,
            );
          }
          final subjects = counts.keys.toList()..sort();
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final subject = subjects[i];
                final count = counts[subject] ?? 0;
                return ACard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TestsListPage(user: widget.user, subject: subject),
                  )),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.sm)),
                      child: Icon(Icons.menu_book_rounded, color: ac.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(subject, style: AppText.title),
                        const SizedBox(height: 3),
                        Text('$count test${count == 1 ? '' : 's'} available', style: AppText.caption),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: ac.muted),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// lib/features/testing/tests_subject_picker_page.dart
// Entry point for the Testing & Quiz system — a subject grid, each tile
// showing the REAL number of published tests for that subject (computed
// from actual `tests` documents, never a placeholder count). Wired from
// Home's "Quizzes" Quick Access tile, which used to open a ComingSoonPage.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/test.dart';
import '../../repositories/test_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'test_taking_page.dart';
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

  /// production_plan.md §5/§7B — "Quizzes → recommends relevant Quizzes",
  /// the one recommendation surface RecommendationRepository didn't cover
  /// yet. Same favorite-subject-first, usage-weighted, honest-fallback
  /// shape as the Library/Courses/Magazine rails elsewhere in the app —
  /// see RecommendationRepository.forQuizzes.
  Future<List<Test>>? _recommended;

  bool get _showRecommended =>
      !widget.user.isGuest && widget.user.favoriteSubjects.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _counts = TestRepository.instance.subjectTestCountsOnce();
      _recommended = _showRecommended ? _loadRecommended() : null;
    });
  }

  Future<List<Test>> _loadRecommended() async {
    final usage =
        await TestRepository.instance.subjectCompletionCountsOnce(widget.user.id);
    return RecommendationRepository.instance.forQuizzes(
      favoriteSubjects: widget.user.favoriteSubjects,
      subjectUsageCounts: usage,
      institutionId: widget.user.schoolId,
    );
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_showRecommended) ...[
                  _recommendedRail(context),
                  const SizedBox(height: 20),
                ],
                for (final subject in subjects) ...[
                  _subjectCard(context, subject, counts[subject] ?? 0),
                  if (subject != subjects.last) const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// production_plan.md §5/§7B — favorite-subject-driven quiz picks.
  /// Hidden entirely (not shown empty) when there's nothing real to show,
  /// same convention as the Library/Courses/Magazine rails.
  Widget _recommendedRail(BuildContext context) {
    return FutureBuilder<List<Test>>(
      future: _recommended,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 92,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final tests = snap.data ?? const <Test>[];
        if (tests.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recommended for You', style: AppText.h2.copyWith(fontSize: 15)),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tests.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final t = tests[i];
                return SizedBox(
                  width: 200,
                  child: ACard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TestTakingPage(user: widget.user, test: t))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.subject, style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(t.title, style: AppText.title.copyWith(fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Text('${t.questionCount} question${t.questionCount == 1 ? '' : 's'}',
                          style: AppText.caption),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }

  Widget _subjectCard(BuildContext context, String subject, int count) {
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
  }
}

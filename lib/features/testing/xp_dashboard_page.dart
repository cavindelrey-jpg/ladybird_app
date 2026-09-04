// lib/features/testing/xp_dashboard_page.dart
// Everything on this page is a live stream from a real source — nothing
// here is computed once and cached as a static number:
//   - XP balance/lifetime      -> XpRepository.watchBalance()
//   - Level + progress bar     -> core/xp_rules.dart, derived from lifetime XP
//   - Streak + week dots       -> AuthService.currentAppUserStream()
//     (the ACTUALLY-wired streak system — see PATCH_NOTES for why this
//     dashboard reads streakDays/weekActivityDates from AppUser rather
//     than the separate, unwired StreakRepository/activityDays system
//     that already existed in the codebase before this patch)
//   - Test history             -> TestRepository.watchAttemptHistory()
//   - XP earning history       -> XpRepository.watchHistory()

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/test_attempt.dart';
import '../../models/xp_transaction.dart';
import '../../repositories/xp_repository.dart';
import '../../repositories/test_repository.dart';
import '../../services/auth_service.dart';
import '../../core/xp_rules.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'test_result_page.dart';
import 'leaderboard_page.dart';

class XpDashboardPage extends StatelessWidget {
  final AppUser user;
  const XpDashboardPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('XP Dashboard', style: AppText.h2),
        actions: [
          IconButton(
            icon: Icon(Icons.leaderboard_rounded, color: ac.txt),
            tooltip: 'Leaderboard',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LeaderboardPage(user: user)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _levelCard(),
          const SizedBox(height: 14),
          _streakCard(),
          const SizedBox(height: 24),
          SectionHeader(title: 'Test History'),
          const SizedBox(height: 10),
          _testHistory(context),
          const SizedBox(height: 24),
          SectionHeader(title: 'XP Earning History'),
          const SizedBox(height: 10),
          _xpHistory(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _levelCard() {
    return StreamBuilder<(int, int)>(
      stream: XpRepository.instance.watchBalance(user.id),
      builder: (context, snap) {
        final ac = AppColors.of(context);
        final balance = snap.data?.$1 ?? 0;
        final lifetime = snap.data?.$2 ?? 0;
        final level = levelForXp(lifetime);
        final progress = levelProgress(lifetime);
        final pct = progress.span == 0 ? 1.0 : (progress.into / progress.span).clamp(0.0, 1.0);
        return GradientCard(
          colors: [ac.navy, ac.navy2],
          height: 170,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: ac.gold, borderRadius: BorderRadius.circular(20)),
                  child: Text('Level $level',
                      style: AppText.label.copyWith(color: ac.navy, fontSize: 12)),
                ),
                const Spacer(),
                Icon(Icons.bolt_rounded, color: ac.gold, size: 20),
                const SizedBox(width: 4),
                Text('$balance spendable',
                    style: AppText.bodySm.copyWith(color: Colors.white70)),
              ]),
              const SizedBox(height: 14),
              Text('$lifetime Total XP',
                  style: AppText.display.copyWith(color: Colors.white, fontSize: 24)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 8,
                  backgroundColor: Colors.white24, color: ac.gold,
                ),
              ),
              const SizedBox(height: 6),
              Text('${progress.into} / ${progress.span} XP to Level ${level + 1}',
                  style: AppText.caption.copyWith(color: Colors.white70)),
            ]),
          ),
        );
      },
    );
  }

  Widget _streakCard() {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.currentAppUserStream(),
      initialData: user,
      builder: (context, snap) {
        final ac = AppColors.of(context);
        final u = snap.data ?? user;
        final now = DateTime.now();
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final activity = u.weekActivityDates.toSet();
        final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        return ACard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.local_fire_department_rounded, color: ac.org, size: 22),
              const SizedBox(width: 8),
              Text('${u.streakDays} day streak', style: AppText.title),
            ]),
            const SizedBox(height: 4),
            Text(
              streakMilestoneBonusXp(u.streakDays + 1) > 0
                  ? 'Tomorrow is a milestone day — bonus XP awaits.'
                  : 'Come back tomorrow to keep it going.',
              style: AppText.caption,
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              final key = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final done = activity.contains(key);
              return Column(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? ac.org : ac.surf3,
                    border: Border.all(color: done ? ac.org : ac.bdr),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(labels[i], style: AppText.caption),
              ]);
            })),
          ]),
        );
      },
    );
  }

  Widget _testHistory(BuildContext context) {
    return StreamBuilder<List<TestAttempt>>(
      stream: TestRepository.instance.watchAttemptHistory(user.id, limit: 10),
      builder: (context, snap) {
        final ac = AppColors.of(context);
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerCard(height: 70);
        }
        final attempts = snap.data ?? [];
        if (attempts.isEmpty) {
          return const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No tests taken yet',
            subtitle: 'Your test attempts and scores will show up here.',
          );
        }
        return Column(children: [
          for (final a in attempts) ...[
            ACard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TestResultPage(attempt: a))),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: a.fullyGraded ? ac.grnBg : ac.orgBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${a.scorePercent.round()}%',
                        style: AppText.caption.copyWith(
                            fontWeight: FontWeight.w800,
                            color: a.fullyGraded ? ac.grn : ac.org, fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.testTitle, style: AppText.title),
                    Text('${a.subject} · +${a.totalXpAwarded} XP', style: AppText.caption),
                  ]),
                ),
                if (!a.fullyGraded) StatusBadge(label: 'Pending', color: ac.org),
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ]);
      },
    );
  }

  Widget _xpHistory() {
    return StreamBuilder<List<XpTransaction>>(
      stream: XpRepository.instance.watchHistory(user.id, limit: 20),
      builder: (context, snap) {
        final ac = AppColors.of(context);
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerCard(height: 70);
        }
        final txns = snap.data ?? [];
        if (txns.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No XP earned yet',
            subtitle: 'Take a test, publish an article, or come back daily to start earning.',
          );
        }
        return Column(children: [
          for (final t in txns) ...[
            ACard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(
                  t.type == XpTransactionType.earn ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                  color: t.type == XpTransactionType.earn ? ac.grn : ac.red,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(t.source.label, style: AppText.bodySm)),
                Text(
                  '${t.type == XpTransactionType.earn ? '+' : '-'}${t.amount} XP',
                  style: AppText.subtitle.copyWith(
                      color: t.type == XpTransactionType.earn ? ac.grn : ac.red),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ]);
      },
    );
  }
}

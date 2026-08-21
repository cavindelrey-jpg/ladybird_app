// lib/widgets/xp_widgets.dart
// Reusable XP UI pieces. No quiz screen exists yet to actually call
// showXpEarnedToast() from — it's built and ready, but its real caller
// (grading a submitted answer) doesn't exist in this codebase. Same for
// XpCapProgressBar, which is meant to live inside a quiz session screen
// that hasn't been built.

import 'package:flutter/material.dart';
import '../models/xp_transaction.dart';
import '../repositories/xp_repository.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

/// Small persistent XP balance pill — drop into any header's action row
/// alongside the existing notification bell / avatar pattern.
class XpBalanceBadge extends StatelessWidget {
  final String userId;
  final VoidCallback? onTap;
  const XpBalanceBadge({super.key, required this.userId, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<(int, int)>(
      stream: XpRepository.instance.watchBalance(userId),
      builder: (context, snap) {
        final balance = snap.data?.$1 ?? 0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [ac.goldBg, Color(0xFFF5E5B8)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ac.gold.withValues(alpha: .35), width: 1),
                boxShadow: [BoxShadow(color: ac.gold.withValues(alpha: .18),
                    blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt_rounded, size: 14, color: ac.gold),
                const SizedBox(width: 3),
                Text('$balance', style: AppText.label.copyWith(
                    fontSize: 11.5, fontWeight: FontWeight.w800, color: ac.gold, letterSpacing: 0)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// Progress toward the daily 200 XP cap — for a quiz session screen.
class XpCapProgressBar extends StatelessWidget {
  final String userId;
  const XpCapProgressBar({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<int>(
      stream: XpRepository.instance.watchXpEarnedToday(userId),
      builder: (context, snap) {
        final earned = (snap.data ?? 0).clamp(0, kDailyXpCap);
        final capped = earned >= kDailyXpCap;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Daily XP', style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$earned / $kDailyXpCap', style: AppText.caption.copyWith(
                fontSize: 11, color: capped ? ac.org : ac.muted)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: earned / kDailyXpCap,
              minHeight: 6,
              backgroundColor: ac.bdr,
              color: capped ? ac.org : ac.gold,
            ),
          ),
          if (capped) ...[
            const SizedBox(height: 4),
            Text('Daily cap reached — more XP tomorrow.', style: AppText.caption.copyWith(fontSize: 10.5, color: ac.org)),
          ],
        ]);
      },
    );
  }
}

/// Call this right after awardXp() succeeds, from wherever a quiz answer
/// eventually gets graded, to show a brief "+10 XP" confirmation.
void showXpEarnedToast(BuildContext context, {required int amount, required XpSource source}) {
  final ac = AppColors.of(context);
  if (amount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ac.org,
      content: Text('Daily XP cap reached — no XP awarded this time.',
          style: AppText.bodySm.copyWith(color: Colors.white)),
    ));
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: ac.navy,
    content: Row(children: [
      Icon(Icons.bolt_rounded, color: ac.gold, size: 18),
      const SizedBox(width: 8),
      Text('+$amount XP · ${source.label}', style: AppText.bodySm.copyWith(
          color: Colors.white, fontWeight: FontWeight.w700)),
    ]),
    duration: const Duration(seconds: 2),
  ));
}

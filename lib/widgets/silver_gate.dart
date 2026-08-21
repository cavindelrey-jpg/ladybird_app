// lib/widgets/silver_gate.dart
// The "properly designed access/upgrade screen" shown whenever an
// account without an active Premium Silver (or Gold) entitlement reaches
// an official-school feature gated in core/feature_access.dart — School
// Connect, Marks, the school's own Class/Exam Timetable, or School
// Connect's Announcements/Calendar/Requests. Never redirect a locked
// destination to a blank page or a silent pop: this is a full, real
// screen, same standard the codebase already holds itself to for
// widgets/coming_soon_page.dart and school_management_page.dart's own
// _AccessDenied.
//
// A signed-out Guest gets a distinct "sign in first" copy instead of the
// paywall — mirrors the distinction FeatureAccess.reasonBlocked already
// makes between the "authenticated" and "silver" access levels, since a
// Guest's actual blocker is authentication, not entitlement.

import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/entitlement.dart';
import '../core/feature_access.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import 'widgets.dart';
import 'app_background.dart';
import 'premium_unlock_sheet.dart';

class SilverLockedPage extends StatelessWidget {
  final AppUser user;
  final AppFeature feature;

  /// AppBar title — the destination name as the person tapped it
  /// ("Marks", "Class Timetable", "School Connect").
  final String title;
  final IconData icon;

  /// One concrete sentence on what's actually behind this specific gate
  /// — not a generic "upgrade to unlock more" line.
  final String description;

  const SilverLockedPage({
    super.key,
    required this.user,
    required this.feature,
    required this.title,
    required this.icon,
    required this.description,
  });

  static const _silverIncludes = [
    'School Connect — requests, notices & the school calendar',
    'Official marks & report cards',
    "Your school's Class & Exam Timetable",
  ];

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final signedIn = !user.isGuest;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(title, style: AppText.title),
      ),
      body: AppBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(children: [
          IconBadge(icon: icon, color: ac.gold, size: 76, iconSize: 34),
          const SizedBox(height: 20),
          Text(
            signedIn ? 'Premium Silver required' : 'Sign in required',
            style: AppText.h2.copyWith(fontSize: 19),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            signedIn
                ? description
                : 'Sign in to your account, then upgrade to Premium Silver, '
                  'to use $title.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Premium Silver also includes',
                  style: AppText.label.copyWith(letterSpacing: .4)),
              const SizedBox(height: 10),
              for (final line in _silverIncludes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: ac.grn),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: AppText.bodySm)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 24),
          if (signedIn) ...[
            PrimaryBtn(
              label: 'Upgrade to Premium Silver',
              icon: Icons.workspace_premium_rounded,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: ac.surf,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
                builder: (_) => PremiumUnlockSheet(
                  userId: user.id,
                  initialTier: EntitlementTier.silver,
                  onUnlockSuccess: () {},
                ),
              ),
            ),
            const SizedBox(height: 10),
            SecondaryBtn(
              label: 'Not now',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ] else
            PrimaryBtn(
              label: 'Go back and sign in',
              onTap: () => Navigator.of(context).maybePop(),
            ),
        ]),
      )),
    );
  }
}

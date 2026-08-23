// lib/features/onboarding/account_choice_screen.dart
// Reached from the Home dashboard's "Join Free" / "Create Free Account" CTAs.
// The account/entitlement system's three tiers (core/feature_access.dart):
//   1. Individual     — free identity, no payment.
//   2. Premium Silver — direct payment (MoMo/Orange Money) or an Academia
//                       vendor voucher. Every premium feature except Video
//                       Courses.
//   3. Premium Gold   — same two funding paths, full access including
//                       Video Courses.
// A voucher received from a vendor is redeemed from Profile after signing
// in (features/entitlements/redeem_voucher_page.dart) — it needs an
// existing account, so it isn't offered as a fourth choice here.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../config/branding.dart';
import '../../models/entitlement.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'create_account_screen.dart';

class AccountChoiceScreen extends StatelessWidget {
  const AccountChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: AppBackground(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: BrandLogo(size: 52)),
            const SizedBox(height: 20),
            Text('Create your account',
                style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: ac.txt)),
            const SizedBox(height: 6),
            Text('Choose how you want to join ${Branding.current.appName}.',
                style: GoogleFonts.inter(fontSize: 14, color: ac.txt2)),
            const SizedBox(height: 28),

            _ChoiceCard(
              icon: Icons.person_outline_rounded,
              iconColor: ac.primary,
              iconBg: ac.primaryBg,
              title: 'Individual',
              subtitle: 'Free. Get an identity to post, comment, and '
                  'message under your own name instead of anonymously.',
              badge: 'FREE',
              badgeColor: ac.grn,
              badgeBg: ac.grnBg,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateAccountScreen(tier: EntitlementTier.free))),
            ),
            const SizedBox(height: 16),

            _ChoiceCard(
              icon: Icons.workspace_premium_outlined,
              iconColor: ac.txt2,
              iconBg: ac.surf3,
              title: 'Premium Silver',
              subtitle: 'Direct payment or a vendor voucher. '
                  'Every premium feature — except Video Courses.',
              badge: 'PREMIUM',
              badgeColor: ac.navy,
              badgeBg: ac.surf3,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateAccountScreen(tier: EntitlementTier.silver))),
            ),
            const SizedBox(height: 16),

            _ChoiceCard(
              icon: Icons.workspace_premium_rounded,
              iconColor: ac.gold,
              iconBg: ac.goldBg,
              title: 'Premium Gold',
              subtitle: 'Direct payment or a vendor voucher. '
                  'Full access, including Video Courses.',
              badge: 'PREMIUM',
              badgeColor: ac.navy,
              badgeBg: ac.goldBg,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateAccountScreen(tier: EntitlementTier.gold))),
            ),

            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Continue browsing as Guest',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: ac.txt2)),
              ),
            ),
          ]),
        ),
      )),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.subtitle,
    required this.badge, required this.badgeColor, required this.badgeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ACard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(Rad.md)),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title,
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Text(badge,
                    style: GoogleFonts.sora(
                        fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: .3)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(subtitle,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2, height: 1.45)),
          ]),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ac.muted),
      ]),
    );
  }
}

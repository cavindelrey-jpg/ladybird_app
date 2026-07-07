// lib/features/onboarding/account_choice_screen.dart
// Reached from the Home dashboard's "Join Free" / "Create Free Account" CTAs.
// Three paths:
//   1. Normal   — free identity, no payment, no school.
//   2. Premium  — 5,000 FCFA via MoMo/Orange Money, unlocks all past
//                 questions across every school, independent of any
//                 institution.
//   3. Student  — enters a school code; the app re-skins to that
//                 institution's branding and pulls its data.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../institution/school_code_page.dart';
import 'create_account_screen.dart';

class AccountChoiceScreen extends StatelessWidget {
  const AccountChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AcademiaLogo(size: 52),
            const SizedBox(height: 20),
            Text('Create your account',
                style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: C.txt)),
            const SizedBox(height: 6),
            Text('Choose how you want to join Academia.',
                style: GoogleFonts.inter(fontSize: 14, color: C.txt2)),
            const SizedBox(height: 28),

            _ChoiceCard(
              icon: Icons.person_outline_rounded,
              iconColor: C.primary,
              iconBg: C.primaryBg,
              title: 'Normal Account',
              subtitle: 'Free. Get an identity to post, comment, and '
                  'message under your own name instead of anonymously.',
              badge: 'FREE',
              badgeColor: C.grn,
              badgeBg: C.grnb,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateAccountScreen(isPremium: false))),
            ),
            const SizedBox(height: 16),

            _ChoiceCard(
              icon: Icons.workspace_premium_rounded,
              iconColor: C.gold,
              iconBg: C.goldp,
              title: 'Premium Individual',
              subtitle: 'One-time 5,000 FCFA via MTN or Orange Money. '
                  'Unlocks every past question across all schools and boards.',
              badge: '5,000 FCFA',
              badgeColor: C.navy,
              badgeBg: C.goldp,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateAccountScreen(isPremium: true))),
            ),
            const SizedBox(height: 16),

            _ChoiceCard(
              icon: Icons.school_rounded,
              iconColor: Colors.white,
              iconBg: C.navy,
              iconOnDark: true,
              title: 'Student — My School',
              subtitle: "Enter your school's code. Academia re-skins to "
                  "your institution — its name, logo, courses, timetable, "
                  "and announcements.",
              badge: 'SCHOOL CODE',
              badgeColor: C.navy,
              badgeBg: C.surf3,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SchoolCodePage())),
            ),

            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Continue browsing as Guest',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: C.txt2)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool iconOnDark;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon, required this.iconColor, required this.iconBg,
    this.iconOnDark = false,
    required this.title, required this.subtitle,
    required this.badge, required this.badgeColor, required this.badgeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: C.txt))),
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
                style: GoogleFonts.inter(fontSize: 12.5, color: C.txt2, height: 1.45)),
          ]),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: C.muted),
      ]),
    );
  }
}

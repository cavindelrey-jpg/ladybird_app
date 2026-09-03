// lib/pages/about_academia_page.dart
// Replaces the ComingSoonPage stub. Static version/info screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';
import '../core/constants.dart';
import '../config/branding.dart';

import '../widgets/app_background.dart';
class AboutAcademiaPage extends StatelessWidget {
  const AboutAcademiaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final brand = Branding.current;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('About ${brand.appName}', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: BrandLogo(size: 72)),
          const SizedBox(height: 16),
          Center(
            child: Text(brand.appName, style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: ac.txt)),
          ),
          Center(
            child: Text('Version ${AppConstants.appVersion}',
                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
          ),
          const SizedBox(height: 28),
          _section(
            ac,
            'What is ${brand.appName}?',
            '${brand.appName} is ${brand.tagline} — courses, past exam '
            'questions, groups, the school magazine, and school management, '
            'all in one app for our students.',
          ),
          _section(
            ac,
            'School Features',
            'Timetables, marks, School Connect, and announcements keep '
            'students and staff in sync with what\'s happening at school.',
          ),
          _section(
            ac,
            'Payments',
            'Premium access is supported via MTN Mobile Money and Orange '
            'Money.',
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('© ${DateTime.now().year} ${brand.appName}. All rights reserved.',
                style: GoogleFonts.inter(fontSize: 11, color: ac.muted)),
          ),
        ],
      )),
    );
  }

  Widget _section(AppColors ac, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.sora(
            fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
        const SizedBox(height: 6),
        Text(body, style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.5)),
      ]),
    );
  }
}

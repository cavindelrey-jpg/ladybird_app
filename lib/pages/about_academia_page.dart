// lib/pages/about_academia_page.dart
// Replaces the ComingSoonPage stub. Static version/info screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';
import '../core/constants.dart';

import '../widgets/app_background.dart';
class AboutAcademiaPage extends StatelessWidget {
  const AboutAcademiaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('About Academia', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: AcademiaLogo(size: 72)),
          const SizedBox(height: 16),
          Center(
            child: Text(AppConstants.appName, style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: ac.txt)),
          ),
          Center(
            child: Text('Version ${AppConstants.appVersion}',
                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
          ),
          const SizedBox(height: 28),
          _section(
            ac,
            'What is Academia?',
            "Academia is Cameroon's platform for GCE and past exam questions, "
            'courses, clubs, the Academia Magazine, and school management — '
            'built for both independent students and partner schools.',
          ),
          _section(
            ac,
            'For Schools',
            'Academia offers white-label school management for institutions '
            'running the Anglo-Saxon / GCE curriculum, including student '
            'accounts, announcements, timetables, and academic records.',
          ),
          _section(
            ac,
            'Payments',
            'Premium access and school subscriptions are supported via MTN '
            'Mobile Money and Orange Money.',
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('© ${DateTime.now().year} Academia. All rights reserved.',
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

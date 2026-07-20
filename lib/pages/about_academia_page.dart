// lib/pages/about_academia_page.dart
// Replaces the ComingSoonPage stub. Static version/info screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../core/constants.dart';

import '../widgets/app_background.dart';
class AboutAcademiaPage extends StatelessWidget {
  const AboutAcademiaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('About Academia', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: AppBackground(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: AcademiaLogo(size: 72)),
          const SizedBox(height: 16),
          Center(
            child: Text(AppConstants.appName, style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: C.txt)),
          ),
          Center(
            child: Text('Version ${AppConstants.appVersion}',
                style: GoogleFonts.inter(fontSize: 12, color: C.txt2)),
          ),
          const SizedBox(height: 28),
          _section(
            'What is Academia?',
            "Academia is Cameroon's platform for GCE and past exam questions, "
            'courses, clubs, the Academia Magazine, and school management — '
            'built for both independent students and partner schools.',
          ),
          _section(
            'For Schools',
            'Academia offers white-label school management for institutions '
            'running the Anglo-Saxon / GCE curriculum, including student '
            'accounts, announcements, timetables, and academic records.',
          ),
          _section(
            'Payments',
            'Premium access and school subscriptions are supported via MTN '
            'Mobile Money and Orange Money.',
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('© ${DateTime.now().year} Academia. All rights reserved.',
                style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
          ),
        ],
      )),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.sora(
            fontSize: 14, fontWeight: FontWeight.w700, color: C.txt)),
        const SizedBox(height: 6),
        Text(body, style: GoogleFonts.inter(fontSize: 13, color: C.txt2, height: 1.5)),
      ]),
    );
  }
}

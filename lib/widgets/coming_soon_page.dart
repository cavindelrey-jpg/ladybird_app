// lib/widgets/coming_soon_page.dart
// Reusable placeholder for any nav destination that doesn't have a real
// screen built yet. Keeps the drawer and Quick Access grid fully tappable
// and honest about what's live vs. what's next, instead of dead buttons.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

class ComingSoonPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const ComingSoonPage({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.hourglass_top_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(title, style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.xl)),
              child: Icon(icon, size: 40, color: ac.primary),
            ),
            const SizedBox(height: 20),
            Text(subtitle == null ? 'Coming Soon' : title,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: ac.txt)),
            const SizedBox(height: 8),
            Text(
              subtitle ?? "$title isn't built yet — it's on the roadmap.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }
}

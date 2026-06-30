// lib/features/dashboard/analytics_page.dart
// Static mock charts and hardcoded subject averages REMOVED.
// Shows empty-state scaffold ready for live Firestore data.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class AnalyticsPage extends StatelessWidget {
  final AppUser user;
  const AnalyticsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stats grid — empty until wired to Firestore aggregates
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: const [
            _StatCard(icon: '📊', value: '—', label: 'School Average', bg: C.blub, color: C.blu),
            _StatCard(icon: '👥', value: '—', label: 'Students',       bg: C.grnb, color: C.grn),
            _StatCard(icon: '🏆', value: '—', label: 'Pass Rate',      bg: C.goldp, color: C.gold),
            _StatCard(icon: '⚠️', value: '—', label: 'At Risk',        bg: C.redb,  color: C.red),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeader(title: '📚 Subject Performance'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: C.surf, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.bdr)),
          child: Column(children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: C.muted),
            const SizedBox(height: 12),
            Text('Subject data will appear here',
              style: GoogleFonts.inter(color: C.muted, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Connect marks data to populate analytics',
              style: GoogleFonts.inter(color: C.muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 24),
        SectionHeader(title: '🏆 Top Students'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: C.surf, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.bdr)),
          child: Column(children: [
            Icon(Icons.emoji_events_outlined, size: 48, color: C.muted),
            const SizedBox(height: 12),
            Text('Rankings will appear here once marks are entered',
              style: GoogleFonts.inter(color: C.muted, fontSize: 14),
              textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color bg;
  final Color color;
  const _StatCard({
    required this.icon, required this.value,
    required this.label, required this.bg, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const Spacer(),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.sora(
            fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.inter(
            fontSize: 11, color: color.withValues(alpha: 0.8))),
        ]),
      ]),
    );
  }
}

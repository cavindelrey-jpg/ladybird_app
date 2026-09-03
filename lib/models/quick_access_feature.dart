// lib/models/quick_access_feature.dart
// Single registry of everything that can appear in the 4-icon Quick Access
// row on the Home dashboard. Ranked per-user by real tap frequency
// (AppUser.quickAccessUsage); ties fall back to defaultOrder so a
// brand-new user sees a sensible starting set instead of a random one.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class QuickAccessFeature {
  final String id; // key stored in AppUser.quickAccessUsage
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final int defaultOrder; // lower = shown first when usage is 0/tied

  const QuickAccessFeature({
    required this.id,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.defaultOrder,
  });
}

class QuickAccessRegistry {
  static const List<QuickAccessFeature> all = [
    QuickAccessFeature(id: 'library', label: 'Library',
        icon: Icons.menu_book_rounded, bg: C.primaryBg, fg: C.primary, defaultOrder: 0),
    QuickAccessFeature(id: 'past_questions', label: 'Past Questions',
        icon: Icons.description_rounded, bg: C.grnb, fg: C.grn, defaultOrder: 1),
    QuickAccessFeature(id: 'magazine', label: 'Magazine',
        icon: Icons.auto_stories_rounded, bg: C.purb, fg: C.pur, defaultOrder: 2),
    QuickAccessFeature(id: 'clubs', label: 'Groups',
        icon: Icons.groups_rounded, bg: C.goldp, fg: C.gold, defaultOrder: 3),
    QuickAccessFeature(id: 'courses', label: 'Courses',
        icon: Icons.school_rounded, bg: C.primaryBg, fg: C.primary, defaultOrder: 4),
    QuickAccessFeature(id: 'lecture_notes', label: 'Lecture Notes',
        icon: Icons.sticky_note_2_rounded, bg: C.goldp, fg: C.gold, defaultOrder: 5),
    QuickAccessFeature(id: 'assignments', label: 'Assignments',
        icon: Icons.assignment_rounded, bg: C.blub, fg: C.blu, defaultOrder: 6),
    QuickAccessFeature(id: 'results', label: 'Results',
        icon: Icons.bar_chart_rounded, bg: C.redb, fg: C.red, defaultOrder: 7),
    QuickAccessFeature(id: 'timetable', label: 'Timetable',
        icon: Icons.calendar_month_rounded, bg: C.purb, fg: C.pur, defaultOrder: 8),
  ];

  static QuickAccessFeature byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => all.first);

  /// Exactly 4 features, highest-tapped first. Empty/partial usage maps
  /// (new users, or users who've only tried 1-2 features) fall back to
  /// defaultOrder for the untapped remainder: Library, Past Questions,
  /// Magazine, Clubs.
  static List<QuickAccessFeature> topFour(Map<String, int> usage) {
    final sorted = [...all]..sort((a, b) {
        final ua = usage[a.id] ?? 0;
        final ub = usage[b.id] ?? 0;
        if (ua != ub) return ub.compareTo(ua);
        return a.defaultOrder.compareTo(b.defaultOrder);
      });
    return sorted.take(4).toList();
  }
}

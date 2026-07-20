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

  /// Shows a small "New" ribbon on the tile — for a just-launched feature
  /// that hasn't had time to earn real tap-frequency ranking yet.
  final bool isNew;

  const QuickAccessFeature({
    required this.id,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.defaultOrder,
    this.isNew = false,
  });
}

class QuickAccessRegistry {
  static const List<QuickAccessFeature> all = [
    // defaultOrder matches the approved model's tile order (Magazine,
    // Clubs, Library, Past Questions) for a zero-usage account. Once a
    // user actually taps tiles, topFour ranks by real usage instead —
    // so this order is what a brand-new account sees, not a permanent
    // guarantee. Flagged as an open question in chat: if you want the
    // order fixed regardless of usage, say so and I'll drop the
    // usage-ranking sort entirely instead.
    QuickAccessFeature(id: 'magazine', label: 'Magazine',
        icon: Icons.auto_stories_rounded, bg: C.purb, fg: C.pur, defaultOrder: 0),
    QuickAccessFeature(id: 'clubs', label: 'Clubs',
        icon: Icons.groups_rounded, bg: C.goldp, fg: C.gold, defaultOrder: 1),
    QuickAccessFeature(id: 'library', label: 'Library',
        icon: Icons.menu_book_rounded, bg: C.primaryBg, fg: C.primary, defaultOrder: 2),
    QuickAccessFeature(id: 'past_questions', label: 'Past Questions',
        icon: Icons.description_rounded, bg: C.grnb, fg: C.grn, defaultOrder: 3),
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
    // Front-end only for now — Daily Quizzes has no backend yet (see
    // Home's Daily Challenge card). Wired up here so the tile, badge, and
    // navigation are all ready the moment the backend lands.
    QuickAccessFeature(id: 'quizzes', label: 'Quizzes',
        icon: Icons.quiz_rounded, bg: C.orgb, fg: C.org, defaultOrder: 9, isNew: true),
  ];

  static QuickAccessFeature byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => all.first);

  /// Exactly 4 features, highest-tapped first. Empty/partial usage maps
  /// (new users, or users who've only tried 1-2 features) fall back to
  /// defaultOrder for the untapped remainder: Magazine, Clubs, Library,
  /// Past Questions. Excludes Quizzes — Home pins that on as a 5th tile
  /// via its `isNew` ribbon (see `topFourPlusNew`) rather than letting it
  /// compete on tap-frequency it hasn't had a chance to earn yet.
  static List<QuickAccessFeature> topFour(Map<String, int> usage) {
    final ranked = [...all].where((f) => !f.isNew).toList()
      ..sort((a, b) {
        final ua = usage[a.id] ?? 0;
        final ub = usage[b.id] ?? 0;
        if (ua != ub) return ub.compareTo(ua);
        return a.defaultOrder.compareTo(b.defaultOrder);
      });
    return ranked.take(4).toList();
  }

  /// [topFour] plus every `isNew` feature appended at the end (Quizzes,
  /// today) — what Home's Quick Access row actually renders.
  static List<QuickAccessFeature> topFourPlusNew(Map<String, int> usage) => [
        ...topFour(usage),
        ...all.where((f) => f.isNew),
      ];
}

// lib/theme/club_visuals.dart
//
// A club's real visual identity is Club.thumbnailUrl — an actual photo
// the admin uploads (see ClubRepository.uploadThumbnail,
// create_club_page.dart, club_settings_page.dart). There is no icon
// PICKER anywhere in the UI; the icon set below exists purely as an
// invisible, automatic fallback for a club that hasn't uploaded a
// thumbnail yet (most importantly, every club that existed before this
// field did), so a bare club still shows something coherent — a
// category-tinted tile, not a blank box or a raw emoji character.
//
// `Club.emoji` (the Firestore field) is untouched by this file; it's
// just no longer surfaced as something a person picks. See
// theme/club_visuals.dart's ClubLogo widget below for the actual
// rendering: thumbnail photo first, fallback icon only if there isn't one.

import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../models/club.dart';

class ClubIconOption {
  final String key;
  final IconData icon;
  final String label;
  const ClubIconOption(this.key, this.icon, this.label);
}

class ClubVisuals {
  ClubVisuals._();

  static const List<ClubIconOption> _options = [
    ClubIconOption('atom', Icons.hub_rounded, 'Science'),
    ClubIconOption('book', Icons.menu_book_rounded, 'Academic'),
    ClubIconOption('debate', Icons.record_voice_over_rounded, 'Debate'),
    ClubIconOption('camera', Icons.camera_alt_rounded, 'Photography'),
    ClubIconOption('palette', Icons.palette_rounded, 'Art & Design'),
    ClubIconOption('code', Icons.code_rounded, 'Tech'),
    ClubIconOption('trophy', Icons.emoji_events_rounded, 'Sports'),
    ClubIconOption('globe', Icons.public_rounded, 'Culture / Language'),
    ClubIconOption('heart', Icons.volunteer_activism_rounded, 'Volunteering'),
    ClubIconOption('group', Icons.groups_rounded, 'General'),
  ];

  static final Map<String, ClubIconOption> _byKey = {
    for (final o in _options) o.key: o,
  };

  /// Category (`_kClubCategories` in create_club_page.dart /
  /// club_settings_page.dart) -> fallback icon key. Public because the
  /// create/settings forms use it to keep the invisible fallback
  /// sensible as the admin changes category, even though there's no
  /// icon UI for them to see it in.
  static const Map<String, String> categoryDefaultKey = {
    'Academic': 'book',
    'Debate': 'debate',
    'Sports': 'trophy',
    'Arts': 'palette',
    'Tech': 'code',
    'Language': 'globe',
    'Volunteering': 'heart',
    'General': 'group',
  };

  /// A small, stable accent palette for the fallback tile's background —
  /// a stable per-club color, not a per-club problem to solve.
  static const _palette = [C.gold, C.blu, C.grn, C.pur, C.org];

  /// The fallback icon for [club] — only ever used when it has no
  /// [Club.thumbnailUrl]. Checks `emoji` as an icon key first (covers
  /// any club edited after this system landed, in case it's ever reused
  /// as a lookup key again); falls back to a category default; falls
  /// back to the generic group icon. Never throws, never renders a raw
  /// emoji character.
  static ClubIconOption fallbackIconFor(Club club) {
    final direct = _byKey[club.emoji];
    if (direct != null) return direct;
    final byCategory = categoryDefaultKey[club.category];
    if (byCategory != null) return _byKey[byCategory]!;
    return _byKey['group']!;
  }

  static Color colorFor(Club club) =>
      _palette[club.name.hashCode.abs() % _palette.length];
}

/// The one widget every club-identity render goes through — card
/// badges, the detail hero's big circle, the Messages inbox row. Shows
/// [Club.thumbnailUrl] (a real photo the admin uploaded) when the club
/// has one; otherwise a category-tinted icon tile
/// ([ClubVisuals.fallbackIconFor]), never a blank box.
class ClubLogo extends StatelessWidget {
  final Club club;
  final double size;

  /// Null = a full circle (the common case). Pass an explicit radius for
  /// the rounded-square badges (My Clubs / Discover cards).
  final BorderRadius? borderRadius;

  const ClubLogo({super.key, required this.club, required this.size, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final iconOption = ClubVisuals.fallbackIconFor(club);
    final accent = ClubVisuals.colorFor(club);
    final hasThumb = (club.thumbnailUrl ?? '').isNotEmpty;
    final radius = borderRadius ?? BorderRadius.circular(size / 2);

    Widget fallback() => Container(
          color: accent,
          alignment: Alignment.center,
          child: Icon(iconOption.icon, color: Colors.white, size: size * 0.42),
        );

    Widget content = hasThumb
        ? Image.network(
            club.thumbnailUrl!,
            width: size, height: size, fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: accent.withValues(alpha: .28),
                alignment: Alignment.center,
                child: SizedBox(
                  width: size * 0.32, height: size * 0.32,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                ),
              );
            },
            errorBuilder: (_, __, ___) => fallback(),
          )
        : fallback();

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: size, height: size, child: content),
    );
  }
}

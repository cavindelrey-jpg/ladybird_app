// lib/models/hero_slide.dart
// Backs the Home banner. Visually this is now the Gamma "big image + dark
// gradient + title/subtitle/stat line/CTA" card. Content-wise, it's a real,
// admin-editable, swipeable set of slides — not a single hardcoded banner.
//
// Supabase: public.hero_slides (shared table with academia-cameroon — see
// supabase/migrations/20260829390000_hero_slides_greenhills_extensions.sql
// for the messages/section destinations and placement column this app adds).

enum HeroDestination {
  library('Library'),
  clubs('Groups'),
  pastQuestions('Past Questions'),
  magazine('Magazine'),
  courses('Courses'),
  messages('Messages'),
  /// Doesn't leave the page the banner lives on -- jumps to a sub-section
  /// of it instead (a content-type filter, a subject, a course category,
  /// a scroll target). The section key lives in [HeroSlide.customRoute];
  /// each placement's host page decides what keys it understands via
  /// HeroBannerCarousel.onSectionSelect.
  section('Jump to Section'),
  custom('Custom Link');

  final String label;
  const HeroDestination(this.label);
}

/// Which surface a slide belongs to. production_plan.md §7B retired the
/// admin-controlled banner system everywhere except Home (the Universal
/// Homepage is explicitly kept unchanged by that same section) -- Courses,
/// Library, Past Questions, Clubs and Messages banners were replaced by
/// automatic, context-aware content recommendations instead (see
/// RecommendationRepository) and so lost their [HeroPlacement] entries.
/// Any pre-existing row still stamped with one of those retired placement
/// strings is not deleted -- it becomes "orphaned" (see
/// HeroSlideRepository.watchOrphaned) and surfaces read-only under the
/// admin manager's "Legacy" tab for cleanup, rather than silently
/// vanishing.
///
/// Magazine never had an entry here: its banner was always the computed
/// "Featured" carousel (most-read articles, see _FeaturedCarousel in
/// magazine_feed_page.dart), not an admin-curated one -- a social feed's
/// top slot should reflect what's actually popular right now.
enum HeroPlacement {
  home('Home');

  final String label;
  const HeroPlacement(this.label);
}

class HeroSlide {
  final String id;
  String headline;
  String subtext;
  String ctaLabel;
  String statLine;      // e.g. "4,521 Resources Available"
  HeroDestination destination;
  String? customRoute;
  String? imageUrl;
  int order;
  bool active;
  HeroPlacement placement;
  final String createdBy;
  final DateTime createdAt;

  HeroSlide({
    required this.id,
    required this.headline,
    required this.subtext,
    this.ctaLabel = 'Explore Now',
    this.statLine = '',
    this.destination = HeroDestination.custom,
    this.customRoute,
    this.imageUrl,
    this.order = 0,
    this.active = true,
    this.placement = HeroPlacement.home,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory HeroSlide.fromSupabase(Map<String, dynamic> d) {
    const destMap = {
      'library': HeroDestination.library, 'clubs': HeroDestination.clubs,
      'past_questions': HeroDestination.pastQuestions, 'magazine': HeroDestination.magazine,
      'courses': HeroDestination.courses, 'messages': HeroDestination.messages,
      'section': HeroDestination.section, 'custom': HeroDestination.custom,
    };
    return HeroSlide(
      id: d['id'] as String,
      headline: d['headline'] ?? '',
      subtext: d['subtext'] ?? '',
      ctaLabel: d['cta_label'] ?? 'Explore Now',
      statLine: d['stat_line'] ?? '',
      destination: destMap[d['destination']] ?? HeroDestination.custom,
      customRoute: d['custom_route'],
      imageUrl: d['image_url'],
      order: d['sort_order'] ?? 0,
      active: d['active'] ?? true,
      placement: HeroPlacement.values.firstWhere(
          (v) => v.name == d['placement'], orElse: () => HeroPlacement.home),
      createdBy: d['created_by'] ?? '',
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() => {
        'headline': headline,
        'subtext': subtext,
        'cta_label': ctaLabel,
        'stat_line': statLine,
        'destination': destination.name == 'pastQuestions' ? 'past_questions' : destination.name,
        'custom_route': customRoute,
        'image_url': imageUrl,
        'sort_order': order,
        'active': active,
        'placement': placement.name,
        'created_by': createdBy.isEmpty ? null : createdBy,
      };
}

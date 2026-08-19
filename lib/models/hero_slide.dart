// lib/models/hero_slide.dart
// Backs the Home banner. Visually this is now the Gamma "big image + dark
// gradient + title/subtitle/stat line/CTA" card. Content-wise, it's a real,
// admin-editable, swipeable set of slides — not a single hardcoded banner.
//
// Firestore: heroSlides/{slideId}   Storage: hero_slides/{slideId}.jpg

import 'package:cloud_firestore/cloud_firestore.dart';

enum HeroDestination {
  library('Library'),
  clubs('Clubs'),
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
/// Any pre-existing Firestore doc still stamped with one of those retired
/// placement strings is not deleted -- it becomes "orphaned" (see
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
  String? imageUrl;      // Firebase Storage download URL
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

  factory HeroSlide.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return HeroSlide(
      id: doc.id,
      headline: d['headline'] ?? '',
      subtext: d['subtext'] ?? '',
      ctaLabel: d['ctaLabel'] ?? 'Explore Now',
      statLine: d['statLine'] ?? '',
      destination: HeroDestination.values.firstWhere(
          (v) => v.name == d['destination'], orElse: () => HeroDestination.custom),
      customRoute: d['customRoute'],
      imageUrl: d['imageUrl'],
      order: d['order'] ?? 0,
      active: d['active'] ?? true,
      placement: HeroPlacement.values.firstWhere(
          (v) => v.name == d['placement'], orElse: () => HeroPlacement.home),
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'headline': headline,
        'subtext': subtext,
        'ctaLabel': ctaLabel,
        'statLine': statLine,
        'destination': destination.name,
        'customRoute': customRoute,
        'imageUrl': imageUrl,
        'order': order,
        'active': active,
        'placement': placement.name,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

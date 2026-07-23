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
  custom('Custom Link');

  final String label;
  const HeroDestination(this.label);
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
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

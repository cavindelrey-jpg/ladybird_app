// lib/models/hero_slide.dart
// Every Home banner ("Join a Club", "Every Past Question. One App.",
// "Your Voice in the Magazine.") is a row here instead of hardcoded text.
// Each slide can hold a real image (uploaded via the in-app image manager);
// with none set yet, the UI falls back to the existing navy gradient card.
//
// Firestore: heroSlides/{slideId}   Storage: hero_slides/{slideId}.jpg

import 'package:cloud_firestore/cloud_firestore.dart';

enum HeroDestination {
  clubs('Join a Club'),
  pastQuestions('Past Questions'),
  magazine('Magazine'),
  library('Library'),
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
  HeroDestination destination;
  String? customRoute;

  String? imageUrl;       // Firebase Storage download URL
  String? cachedImagePath; // local mirror for instant/offline paint

  int order;
  bool active;
  final String createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  HeroSlide({
    required this.id,
    required this.headline,
    required this.subtext,
    this.ctaLabel = 'Explore Now',
    this.destination = HeroDestination.custom,
    this.customRoute,
    this.imageUrl,
    this.cachedImagePath,
    this.order = 0,
    this.active = true,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory HeroSlide.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return HeroSlide(
      id: doc.id,
      headline: d['headline'] ?? '',
      subtext: d['subtext'] ?? '',
      ctaLabel: d['ctaLabel'] ?? 'Explore Now',
      destination: HeroDestination.values.firstWhere(
          (v) => v.name == d['destination'], orElse: () => HeroDestination.custom),
      customRoute: d['customRoute'],
      imageUrl: d['imageUrl'],
      order: d['order'] ?? 0,
      active: d['active'] ?? true,
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'headline': headline,
        'subtext': subtext,
        'ctaLabel': ctaLabel,
        'destination': destination.name,
        'customRoute': customRoute,
        'imageUrl': imageUrl,
        'order': order,
        'active': active,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

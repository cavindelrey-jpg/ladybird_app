// lib/models/academic_section.dart
// Shared "education-level" top tier reused across every hierarchical
// content browser in the app — Quizzes (features/testing), Course
// Navigation (features/courses_marketplace), and, via a subject-scoped
// cross-link, the Library (features/academic_content). A real Firestore
// doc (not free text) so a brand-new section (Nursery, Master's, PhD,
// Professional/Technical Education, ...) can be created independent of
// whether any content has been placed under it yet, each with its own
// admin-editable photo — same reasoning models/test.dart's original
// QuizCategory documented when this concept was first built for Quizzes.
//
// Firestore: quiz_categories/{sectionId} — kept under its original
// collection name (this started as Quiz-only) rather than migrating
// existing documents to a new collection name; nothing about the model
// or the collection is quiz-specific anymore. See
// repositories/academic_section_repository.dart for reads/writes, and
// models/test.dart, which now aliases its old QuizCategory name to this
// class so existing Quiz code didn't need to change.

import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicSection {
  final String id;
  final String name;
  final String emoji;
  final String imageUrl;
  final double order;
  final DateTime createdAt;

  const AcademicSection({
    required this.id,
    required this.name,
    this.emoji = '',
    this.imageUrl = '',
    this.order = 0,
    required this.createdAt,
  });

  factory AcademicSection.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    return AcademicSection(
      id: doc.id,
      name: d['name'] ?? '',
      emoji: d['icon'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      order: (d['order'] as num?)?.toDouble() ?? 0,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}

/// Seeded into the section collection the first time it's ever read
/// empty — the 5 sections asked for at launch. Purely a starting point:
/// any of these can be renamed or removed the same way an admin-added
/// one can, and more (Nursery, Master's, PhD, Professional/Technical
/// Education, ...) can be added from any page that shows this grid —
/// nothing in the app treats this list as the only allowed set.
const kDefaultAcademicSections = [
  'Primary School',
  'Junior Secondary School',
  'Senior Secondary School',
  'High School',
  'Undergraduate',
];

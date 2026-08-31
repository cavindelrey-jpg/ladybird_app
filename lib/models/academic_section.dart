// lib/models/academic_section.dart
// Shared "education-level" top tier reused across every hierarchical
// content browser in the app — Quizzes (features/testing), Course
// Navigation (features/courses_marketplace), and, via a subject-scoped
// cross-link, the Library (features/academic_content). A real Postgres
// row (not free text) so a brand-new section (Nursery, Master's, PhD,
// Professional/Technical Education, ...) can be created independent of
// whether any content has been placed under it yet, each with its own
// admin-editable photo.
//
// Supabase: public.academic_sections — see
// repositories/academic_section_repository.dart for reads/writes, and
// models/test.dart, which aliases its old QuizCategory name to this
// class so existing Quiz code didn't need to change.

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

  factory AcademicSection.fromSupabase(Map<String, dynamic> d) => AcademicSection(
        id: d['id'] as String,
        name: d['name'] ?? '',
        emoji: d['emoji'] ?? '',
        imageUrl: d['image_url'] ?? '',
        order: (d['sort_order'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Seeded into the section table the first time it's ever read empty —
/// the 5 sections asked for at launch. Purely a starting point: any of
/// these can be renamed or removed the same way an admin-added one can,
/// and more (Nursery, Master's, PhD, Professional/Technical Education,
/// ...) can be added from any page that shows this grid — nothing in the
/// app treats this list as the only allowed set.
const kDefaultAcademicSections = [
  'Primary School',
  'Junior Secondary School',
  'Senior Secondary School',
  'High School',
  'Undergraduate',
];

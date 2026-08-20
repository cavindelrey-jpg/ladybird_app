// lib/repositories/academic_section_repository.dart
// CRUD for the shared AcademicSection tree top-tier — the single admin-
// managed list of education levels (Primary School, JSS, SSS, High
// School, Undergraduate, plus anything an admin has added) that drives
// every hierarchical content browser in the app: Quizzes
// (features/testing/quiz_categories_page.dart), Course Navigation
// (features/courses_marketplace/course_navigation_page.dart), and the
// Library (features/academic_content, cross-linked by subject). One
// shared list so an admin manages a single set of sections/images
// instead of a separate one per feature, and so "Senior Secondary
// School" means the same thing — and shows the same photo — everywhere
// in the app.
//
// Firestore: quiz_categories/{sectionId} — kept under its original
// collection name (this started as Quiz-only) rather than migrating
// existing documents to a new collection name; nothing about the name is
// quiz-specific anymore. TestRepository's own
// quizCategoriesOnce()/addQuizCategory()/updateQuizCategoryIcon()/
// uploadQuizCategoryImage() now just delegate here instead of owning
// this collection directly, so every existing Quiz call site keeps
// working unchanged.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/result.dart';
import '../models/academic_section.dart';

class AcademicSectionRepository {
  AcademicSectionRepository._();
  static final AcademicSectionRepository instance = AcademicSectionRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _sections =>
      _db.collection('quiz_categories');

  static String _slug(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  /// All sections, ordered for the grid. Seeds [kDefaultAcademicSections]
  /// the first time this collection is ever read empty — a fresh install
  /// still shows the 5 sections asked for at launch instead of a blank
  /// page. Uses a stable slug doc-id per default name so two clients
  /// racing this on first load both just re-set the same 5 docs rather
  /// than creating duplicates.
  Future<List<AcademicSection>> sectionsOnce() async {
    final snap = await _sections.orderBy('order').get();
    if (snap.docs.isEmpty) {
      await _seedDefaults();
      final reSnap = await _sections.orderBy('order').get();
      return reSnap.docs.map(AcademicSection.fromFirestore).toList();
    }
    return snap.docs.map(AcademicSection.fromFirestore).toList();
  }

  Future<void> _seedDefaults() async {
    final batch = _db.batch();
    for (var i = 0; i < kDefaultAcademicSections.length; i++) {
      final name = kDefaultAcademicSections[i];
      batch.set(_sections.doc(_slug(name)), {
        'name': name,
        'icon': '',
        'imageUrl': '',
        'order': (i * 100).toDouble(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Adds a brand-new section (e.g. "Nursery"/"Master's"/"PhD") — the
  /// extensibility point every hierarchical browser's "+ New section"
  /// tile calls into. Sorts to the end by passing the current list's
  /// length * 100 as [order], the same large-gap spacing the seeded
  /// defaults use, leaving room for a future reorder feature without
  /// renumbering everything.
  Future<Result<String>> addSection({
    required String name,
    required double order,
    String emoji = '',
    String imageUrl = '',
  }) async {
    try {
      final ref = await _sections.add({
        'name': name.trim(),
        'icon': emoji,
        'imageUrl': imageUrl,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to add section', e);
    }
  }

  /// Changes an existing section's look. Passing both empty clears it
  /// back to the letter-avatar fallback.
  Future<Result<void>> updateSectionIcon(String id, {String emoji = '', String imageUrl = ''}) async {
    try {
      await _sections.doc(id).update({'icon': emoji, 'imageUrl': imageUrl});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update section', e);
    }
  }

  Future<Result<String>> uploadSectionImage({required String sectionId, required File imageFile}) async {
    try {
      final ref = FirebaseStorage.instance.ref('quiz_categories/$sectionId.jpg');
      await ref.putFile(imageFile).timeout(const Duration(seconds: 60),
          onTimeout: () => throw Exception(
              'Image upload is taking too long. Check your connection and try again.'));
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload image', e);
    }
  }
}

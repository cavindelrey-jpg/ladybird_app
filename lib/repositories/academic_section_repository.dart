// lib/repositories/academic_section_repository.dart
// CRUD for the shared AcademicSection tree top-tier — the single admin-
// managed list of education levels (Primary School, JSS, SSS, High
// School, Undergraduate, plus anything an admin has added) that drives
// every hierarchical content browser in the app: Quizzes
// (features/testing/quiz_categories_page.dart), Course Navigation
// (features/courses_marketplace/course_navigation_page.dart), and the
// Library (features/academic_content, cross-linked by subject). One
// shared list so an admin manages a single set of sections/images
// instead of a separate one per feature.
//
// Supabase: public.academic_sections. TestRepository's own
// quizCategoriesOnce()/addQuizCategory()/updateQuizCategoryIcon()/
// uploadQuizCategoryImage() delegate here instead of owning this table
// directly, so every existing Quiz call site keeps working unchanged.

import 'dart:async';

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';
import '../models/academic_section.dart';
import '../services/content_cache_service.dart';

class AcademicSectionRepository {
  AcademicSectionRepository._();
  static final AcademicSectionRepository instance = AcademicSectionRepository._();

  static const String _bucket = 'app-content';
  static const String _cacheKey = 'academic_sections';
  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _sections => _db.from('academic_sections');

  /// All sections, ordered for the grid. Seeds [kDefaultAcademicSections]
  /// the first time this table is ever read empty — a fresh install still
  /// shows the 5 sections asked for at launch instead of a blank page.
  ///
  /// This is the top of the browse tree for Quizzes/Course Navigation/
  /// Library — offline (or a flaky reconnect), a failure here used to
  /// throw straight out to the caller with nothing to fall back on.
  /// Now falls back to the last cached list first; only rethrows (real
  /// error state, not a silent blank page — see QuizCategoriesPage) if
  /// there's no cache to fall back on either.
  Future<List<AcademicSection>> sectionsOnce() async {
    try {
      final rows = await _sections.select().order('sort_order', ascending: true);
      if (rows.isEmpty) {
        await _seedDefaults();
        final reRows = await _sections.select().order('sort_order', ascending: true);
        final list = List<Map<String, dynamic>>.from(reRows);
        unawaited(ContentCacheService.instance.putList(_cacheKey, list));
        return list.map(AcademicSection.fromSupabase).toList();
      }
      final list = List<Map<String, dynamic>>.from(rows);
      unawaited(ContentCacheService.instance.putList(_cacheKey, list));
      return list.map(AcademicSection.fromSupabase).toList();
    } catch (e) {
      final cached = await ContentCacheService.instance.getList(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.map(AcademicSection.fromSupabase).toList();
      }
      rethrow;
    }
  }

  Future<void> _seedDefaults() async {
    try {
      await _sections.insert([
        for (var i = 0; i < kDefaultAcademicSections.length; i++)
          {'name': kDefaultAcademicSections[i], 'sort_order': (i * 100).toDouble()},
      ]);
    } catch (_) {
      // Two clients racing this on first load: the loser's insert is
      // harmless to lose (the winner's rows are what sectionsOnce() then
      // re-reads) — no unique constraint to violate, just redundant rows
      // to avoid, so best-effort is fine here.
    }
  }

  /// Adds a brand-new section (e.g. "Nursery"/"Master's"/"PhD") — the
  /// extensibility point every hierarchical browser's "+ New section"
  /// tile calls into.
  Future<Result<String>> addSection({
    required String name,
    required double order,
    String emoji = '',
    String imageUrl = '',
  }) async {
    try {
      final row = await _sections.insert({
        'name': name.trim(),
        'emoji': emoji,
        'image_url': imageUrl,
        'sort_order': order,
      }).select('id').single();
      return Success(row['id'] as String);
    } catch (e) {
      return Failure('Failed to add section', e);
    }
  }

  /// Changes an existing section's look. Passing both empty clears it
  /// back to the letter-avatar fallback.
  Future<Result<void>> updateSectionIcon(String id, {String emoji = '', String imageUrl = ''}) async {
    try {
      await _sections.update({'emoji': emoji, 'image_url': imageUrl}).eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update section', e);
    }
  }

  Future<Result<String>> uploadSectionImage({required String sectionId, required File imageFile}) async {
    try {
      final path = 'quiz_categories/$sectionId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload image', e);
    }
  }
}

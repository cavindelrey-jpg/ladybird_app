// lib/repositories/hero_slide_repository.dart

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hero_slide.dart';
import '../core/result.dart';
import '../core/realtime_tolerant.dart';

class HeroSlideRepository {
  HeroSlideRepository._();
  static final HeroSlideRepository instance = HeroSlideRepository._();

  static const String _bucket = 'app-content';
  SupabaseQueryBuilder get _table => Supabase.instance.client.from('hero_slides');

  Stream<List<HeroSlide>> watchActive({HeroPlacement placement = HeroPlacement.home}) => _table
      .stream(primaryKey: ['id'])
      .order('sort_order', ascending: true)
      .realtimeTolerant()
      .map((rows) => rows
          .where((r) => r['active'] == true && r['placement'] == placement.name)
          .map(HeroSlide.fromSupabase)
          .toList());

  /// All slides including inactive ones, for one placement — the admin
  /// manager UI's per-surface tab.
  Stream<List<HeroSlide>> watchAll({HeroPlacement placement = HeroPlacement.home}) => _table
      .stream(primaryKey: ['id'])
      .order('sort_order', ascending: true)
      .realtimeTolerant()
      .map((rows) => rows
          .where((r) => r['placement'] == placement.name)
          .map(HeroSlide.fromSupabase)
          .toList());

  /// Rows whose stored `placement` no longer matches any current
  /// [HeroPlacement] (e.g. legacy 'magazine' slides from before that
  /// placement was retired). watchActive/watchAll are both scoped to a
  /// single current placement, so without this query such rows -- and any
  /// Storage image they reference -- are permanently invisible to admins
  /// and can never be edited or deleted. Surfaced via the "Legacy" tab in
  /// HeroSlideManagerPage.
  Stream<List<Map<String, dynamic>>> watchOrphaned() {
    final known = HeroPlacement.values.map((p) => p.name).toSet();
    return _table.stream(primaryKey: ['id'])
        .realtimeTolerant().map(
        (rows) => rows.where((r) => !known.contains(r['placement'])).toList());
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _table.delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete slide', e);
    }
  }

  /// Persists a new manual order for the manager's drag-to-reorder list.
  Future<Result<void>> reorder(List<HeroSlide> inNewOrder) async {
    try {
      for (var i = 0; i < inNewOrder.length; i++) {
        await _table.update({'sort_order': i}).eq('id', inNewOrder[i].id);
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to reorder slides', e);
    }
  }

  Future<Result<String>> create(HeroSlide slide) async {
    try {
      final row = await _table.insert(slide.toSupabase()).select('id').single();
      return Success(row['id'] as String);
    } catch (e) {
      return Failure('Failed to create slide', e);
    }
  }

  Future<Result<void>> update(HeroSlide slide) async {
    try {
      await _table.update(slide.toSupabase()).eq('id', slide.id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update slide', e);
    }
  }

  Future<Result<String>> uploadImage({required String slideId, required File imageFile}) async {
    try {
      final path = 'hero_slides/$slideId.jpg';
      final db = Supabase.instance.client;
      await db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload slide image', e);
    }
  }
}

// The Home page's greeting hero background — an admin-editable photo
// instead of a fixed gradient. Deliberately a single well-known row, not
// a table with many rows -- there is only ever one Home hero background
// for this app.
//
// Supabase: public.home_hero (id text primary key, image_url text) --
// keyed by Branding.current.brandId so multi-tenant school apps never collide.

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/branding.dart';
import '../core/core.dart';
import '../core/offline_cache.dart';
import '../core/realtime_tolerant.dart';

class HomeHeroRepository {
  HomeHeroRepository._();
  static final HomeHeroRepository instance = HomeHeroRepository._();

  static String get _rowId => Branding.current.brandId;
  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;

  Stream<String> watchImageUrl() {
    final live = _db
        .from('home_hero')
        .stream(primaryKey: ['id'])
        .eq('id', _rowId)
        .realtimeTolerant()
        .map((rows) => rows.isNotEmpty ? (rows.first['image_url'] as String? ?? '') : '');
    return OfflineCache.instance.watch<String>(
      'home_hero_url_${Branding.current.brandId}',
      live,
      toJson: (url) => url,
      fromJson: (json) => json as String,
      emptyValue: '',
    );
  }

  Future<Result<String>> uploadImage(File imageFile) async {
    try {
      final path = 'home_hero/${Branding.current.brandId}_banner.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true))
          .timeout(const Duration(seconds: 60), onTimeout: () => throw Exception(
              'Image upload is taking too long. Check your connection and try again.'));
      final url = _db.storage.from(_bucket).getPublicUrl(path);
      return Success(url);
    } catch (e) {
      return Failure('Failed to upload banner image', e);
    }
  }

  Future<Result<void>> setImage(String imageUrl) async {
    try {
      await _db.from('home_hero').upsert({'id': _rowId, 'image_url': imageUrl});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save banner image', e);
    }
  }
}

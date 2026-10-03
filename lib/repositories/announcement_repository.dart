// lib/repositories/announcement_repository.dart
// All Supabase reads/writes for announcements. schoolId maps to
// institution_id — the schools/{id}/announcements subcollection nesting
// collapsed into one table with a nullable FK, same pattern as
// institution scoping elsewhere in this rewrite.

import 'dart:io';

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../core/result.dart';
import '../core/realtime_tolerant.dart';

class AnnouncementRepository {
  AnnouncementRepository._();
  static final AnnouncementRepository instance = AnnouncementRepository._();

  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _table => _db.from('announcements');

  Stream<List<Announcement>> watchAnnouncements({String? schoolId}) {
    final stream = _table.stream(primaryKey: ['id']).order('occurred_at', ascending: false).limit(50)
        .realtimeTolerant();
    if (schoolId == null || schoolId.isEmpty) {
      return stream.map((rows) => rows.map(Announcement.fromSupabase).toList());
    }
    return stream.map((rows) => rows
        .where((r) => r['institution_id'] == schoolId)
        .map(Announcement.fromSupabase)
        .toList());
  }

  /// A fresh, unused row id -- lets the composer upload an image to
  /// Storage keyed by the announcement's real id BEFORE the row itself is
  /// written (same order HeroSlideRepository's own image upload uses,
  /// just generated client-side here since Postgres would otherwise only
  /// hand out the id at insert time).
  String newId() => _uuidV4();

  Future<Result<String>> uploadImage({required String id, required File imageFile}) async {
    try {
      final path = 'announcement_images/$id.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload announcement image', e);
    }
  }

  /// Inserts with an explicit id (set via [newId] so an uploaded image can
  /// be keyed to the real id ahead of time), or lets Postgres assign one
  /// when [announcement.id] is empty (no photo attached).
  Future<Result<void>> post(Announcement announcement) async {
    try {
      final row = announcement.toSupabase();
      if (announcement.id.isNotEmpty) row['id'] = announcement.id;
      await _table.insert(row);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post announcement', e);
    }
  }

  Future<Result<void>> delete(String id, {String? schoolId}) async {
    try {
      await _table.delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete announcement', e);
    }
  }

  static const String _hex = '0123456789abcdef';
  String _uuidV4() {
    final rnd = Random.secure();
    final bytes = List.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    String hex(int i) => _hex[bytes[i] >> 4].toString() + _hex[bytes[i] & 0x0f];
    final b = StringBuffer();
    for (var i = 0; i < 16; i++) {
      b.write(hex(i));
      if (i == 3 || i == 5 || i == 7 || i == 9) b.write('-');
    }
    return b.toString();
  }
}

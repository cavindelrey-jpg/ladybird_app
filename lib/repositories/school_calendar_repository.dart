// lib/repositories/school_calendar_repository.dart
// Admin-authored School Calendar / Activities. Backed by
// public.school_calendar_events (see supabase/migrations/
// 20260903160000_homework_and_calendar_events.sql) -- write access
// mirrors AppUser.canManageSchool exactly, same as the Timetable manager.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/core.dart';
import '../models/school_calendar_event.dart';

class SchoolCalendarRepository {
  SchoolCalendarRepository._();
  static final SchoolCalendarRepository instance = SchoolCalendarRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _events => _db.from('school_calendar_events');
  final _streamCache = StreamCache();

  /// Every event for [schoolId], soonest-starting first.
  Stream<List<SchoolCalendarEvent>> watchAll(String schoolId) {
    if (schoolId.isEmpty) return Stream.value(const []);
    return _streamCache.watch('watchAll_$schoolId', () =>
      _events.stream(primaryKey: ['id']).eq('school_id', schoolId).map((rows) {
        final list = rows.map(SchoolCalendarEvent.fromSupabase).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
        return list;
      })
    );
  }

  /// Events on or after today, capped at [limit] -- powers "Upcoming Events".
  Stream<List<SchoolCalendarEvent>> watchUpcoming(String schoolId, {int limit = 10}) {
    return watchAll(schoolId).map((all) => upcomingFrom(all, limit: limit));
  }

  /// Pure filter version of [watchUpcoming], for a screen that already
  /// holds the full event list from its own StreamBuilder and doesn't
  /// need a second subscription just to compute the same slice.
  List<SchoolCalendarEvent> upcomingFrom(List<SchoolCalendarEvent> all, {int limit = 10}) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return all.where((e) => !e.endDate.isBefore(todayDate)).take(limit).toList();
  }

  Future<Result<void>> create(SchoolCalendarEvent event) async {
    try {
      await _events.insert(event.toSupabase());
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t save that event', e);
    }
  }

  Future<Result<void>> update(SchoolCalendarEvent event) async {
    try {
      await _events.update(event.toSupabase()).eq('id', event.id);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t update that event', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _events.delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t delete that event', e);
    }
  }
}

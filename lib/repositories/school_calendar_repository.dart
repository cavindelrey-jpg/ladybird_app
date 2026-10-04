// lib/repositories/school_calendar_repository.dart
// Admin-authored School Calendar / Activities. Backed by
// public.school_calendar_events (see supabase/migrations/
// 20260903160000_homework_and_calendar_events.sql) -- write access
// mirrors AppUser.canManageSchool exactly, same as the Timetable manager.

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/core.dart';
import '../models/school_calendar_event.dart';
import '../core/realtime_tolerant.dart';
import '../core/offline_cache.dart';

class SchoolCalendarRepository {
  SchoolCalendarRepository._();
  static final SchoolCalendarRepository instance = SchoolCalendarRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseQueryBuilder? get _events => _db?.from('school_calendar_events');
  final StreamController<String> _changeNotifier = StreamController<String>.broadcast();

  /// Every event for [schoolId], soonest-starting first.
  /// Combines 0ms local offline cache with live Supabase updates.
  Stream<List<SchoolCalendarEvent>> watchAll(String schoolId) async* {
    if (schoolId.isEmpty) {
      yield const [];
      return;
    }

    // 1. Initial instant cache load (0ms)
    final initial = await _getLocalEvents(schoolId);
    yield initial;

    // 2. Stream controller to combine local change notifications and live Supabase stream
    final controller = StreamController<List<SchoolCalendarEvent>>();

    final localSub = _changeNotifier.stream.where((sid) => sid == schoolId).listen((_) async {
      final updated = await _getLocalEvents(schoolId);
      if (!controller.isClosed) controller.add(updated);
    });

    StreamSubscription? remoteSub;
    final eventsQuery = _events;
    if (eventsQuery != null) {
      try {
        final live = eventsQuery
            .stream(primaryKey: ['id'])
            .eq('school_id', schoolId)
            .realtimeTolerant()
            .map((rows) {
          final list = rows.map(SchoolCalendarEvent.fromSupabase).toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate));
          return list;
        });

        remoteSub = live.listen((remoteList) async {
          await _setLocalEvents(schoolId, remoteList);
          if (!controller.isClosed) controller.add(remoteList);
        }, onError: (_) {});
      } catch (_) {}
    }

    try {
      yield* controller.stream;
    } finally {
      await localSub.cancel();
      await remoteSub?.cancel();
      await controller.close();
    }
  }

  /// Events on or after today, capped at [limit] -- powers "Upcoming Events".
  Stream<List<SchoolCalendarEvent>> watchUpcoming(String schoolId, {int limit = 10}) {
    return watchAll(schoolId).map((all) => upcomingFrom(all, limit: limit));
  }

  /// Pure filter version of [watchUpcoming].
  List<SchoolCalendarEvent> upcomingFrom(List<SchoolCalendarEvent> all, {int limit = 10}) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return all.where((e) => !e.endDate.isBefore(todayDate)).take(limit).toList();
  }

  Future<Result<void>> create(SchoolCalendarEvent event) async {
    await _saveLocalFallback(event);
    _changeNotifier.add(event.schoolId);

    final eventsQuery = _events;
    if (eventsQuery != null) {
      try {
        await eventsQuery.insert(event.toSupabase());
      } catch (_) {}
    }
    return const Success(null);
  }

  Future<Result<int>> batchCreate(String schoolId, List<SchoolCalendarEvent> events) async {
    if (events.isEmpty) return const Success(0);

    // Save locally first for instant display
    final existing = await _getLocalEvents(schoolId);
    final map = {for (final e in existing) e.id: e};
    for (final e in events) {
      map[e.id] = e;
    }
    final merged = map.values.toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
    await _setLocalEvents(schoolId, merged);
    _changeNotifier.add(schoolId);

    final eventsQuery = _events;
    if (eventsQuery != null) {
      try {
        final rows = events.map((e) => e.toSupabase()).toList();
        await eventsQuery.upsert(rows);
      } catch (_) {}
    }

    return Success(events.length);
  }

  Future<Result<void>> update(SchoolCalendarEvent event) async {
    await _saveLocalFallback(event);
    _changeNotifier.add(event.schoolId);

    final eventsQuery = _events;
    if (eventsQuery != null) {
      try {
        await eventsQuery.update(event.toSupabase()).eq('id', event.id);
      } catch (_) {}
    }
    return const Success(null);
  }

  Future<Result<void>> delete(String schoolId, String id) async {
    try {
      final existing = await _getLocalEvents(schoolId);
      final next = existing.where((e) => e.id != id).toList();
      await _setLocalEvents(schoolId, next);
      _changeNotifier.add(schoolId);
    } catch (_) {}

    final eventsQuery = _events;
    if (eventsQuery != null) {
      try {
        await eventsQuery.delete().eq('id', id);
      } catch (_) {}
    }
    return const Success(null);
  }

  Future<List<SchoolCalendarEvent>> getForSchoolOnce(String schoolId) async {
    if (schoolId.isEmpty) return const [];
    final cached = await _getLocalEvents(schoolId);
    if (cached.isNotEmpty) return cached;

    final eventsQuery = _events;
    if (eventsQuery != null) {
      try {
        final rows = await eventsQuery.select().eq('school_id', schoolId);
        final list = (rows as List).map((r) => SchoolCalendarEvent.fromSupabase(r as Map<String, dynamic>)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
        await _setLocalEvents(schoolId, list);
        return list;
      } catch (_) {}
    }
    return cached;
  }

  Future<List<SchoolCalendarEvent>> _getLocalEvents(String schoolId) async {
    try {
      final key = 'calendar_$schoolId';
      final existing = await OfflineCache.instance.get<List<SchoolCalendarEvent>>(
        key,
        (json) => OfflineCache.listFromJson(json, (j) => SchoolCalendarEvent.fromSupabase(j)),
      );
      if (existing != null) {
        existing.sort((a, b) => a.startDate.compareTo(b.startDate));
        return existing;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _setLocalEvents(String schoolId, List<SchoolCalendarEvent> list) async {
    try {
      final key = 'calendar_$schoolId';
      await OfflineCache.instance.put(
        key,
        OfflineCache.listToJson(list, (e) => (e as SchoolCalendarEvent).toSupabase()),
      );
    } catch (_) {}
  }

  Future<void> _saveLocalFallback(SchoolCalendarEvent event) async {
    try {
      final existing = await _getLocalEvents(event.schoolId);
      final next = [...existing.where((e) => e.id != event.id), event]
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
      await _setLocalEvents(event.schoolId, next);
    } catch (_) {}
  }
}

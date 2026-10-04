// lib/repositories/school_timetable_repository.dart
// The official, admin-authored School Timetable. Backed by
// public.school_timetable_slots (see
// supabase/migrations/20260901030000_school_timetable_slots.sql) --
// write access there mirrors AppUser.canManageSchool exactly, the same
// gate TimetableManagerPage already checks before showing its UI.

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../models/school_timetable_slot.dart';
import '../core/realtime_tolerant.dart';
import '../core/offline_cache.dart';

class SchoolTimetableRepository {
  SchoolTimetableRepository._();
  static final SchoolTimetableRepository instance = SchoolTimetableRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseQueryBuilder? get _slots => _db?.from('school_timetable_slots');
  final StreamController<String> _changeNotifier = StreamController<String>.broadcast();

  /// Every slot for [classLevel] in [schoolId], ordered for display.
  Stream<List<SchoolTimetableSlot>> watchForClass(String schoolId, String classLevel) {
    if (schoolId.isEmpty || classLevel.isEmpty) return Stream.value(const []);

    return watchForSchool(schoolId).map((all) {
      final list = all.where((s) => s.classLevel == classLevel).toList();
      list.sort((a, b) {
        final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
        return byDay != 0 ? byDay : a.startTime.compareTo(b.startTime);
      });
      return list;
    });
  }

  /// Every class's slots at [schoolId] -- what conflict checks need
  /// (a teacher or room clash is across classes).
  /// Combines 0ms local offline cache with live Supabase stream.
  Stream<List<SchoolTimetableSlot>> watchForSchool(String schoolId) async* {
    if (schoolId.isEmpty) {
      yield const [];
      return;
    }

    // 1. Initial instant cache load (0ms latency)
    final initial = await _getLocalSlots(schoolId);
    yield initial;

    // 2. Stream controller combining local updates and remote stream
    final controller = StreamController<List<SchoolTimetableSlot>>();

    final localSub = _changeNotifier.stream.where((sid) => sid == schoolId).listen((_) async {
      final updated = await _getLocalSlots(schoolId);
      if (!controller.isClosed) controller.add(updated);
    });

    StreamSubscription? remoteSub;
    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        final live = slotsQuery
            .stream(primaryKey: ['id'])
            .eq('school_id', schoolId)
            .realtimeTolerant()
            .map((rows) => rows.map(_fromRow).toList());

        remoteSub = live.listen((remoteList) async {
          await _setLocalSlots(schoolId, remoteList);
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

  /// Today's slots only, for [classLevel].
  Stream<List<SchoolTimetableSlot>> watchTodayForClass(String schoolId, String classLevel) {
    final today = DateTime.now().weekday;
    return watchForClass(schoolId, classLevel).map((all) => all.where((s) => s.dayOfWeek == today).toList());
  }

  Future<Result<void>> add(SchoolTimetableSlot slot) async {
    final slotToSave = slot.id.isNotEmpty
        ? slot
        : SchoolTimetableSlot(
            id: 'slot_${DateTime.now().millisecondsSinceEpoch}_${slot.classLevel}_${slot.dayOfWeek}_${slot.startTime}',
            schoolId: slot.schoolId,
            classLevel: slot.classLevel,
            dayOfWeek: slot.dayOfWeek,
            startTime: slot.startTime,
            endTime: slot.endTime,
            subject: slot.subject,
            teacherName: slot.teacherName,
            room: slot.room,
          );

    await _saveLocalFallback(slotToSave);
    _changeNotifier.add(slot.schoolId);

    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        await slotsQuery.insert(_toRow(slotToSave));
      } catch (_) {}
    }
    return const Success(null);
  }

  Future<Result<void>> update(SchoolTimetableSlot slot) async {
    await _saveLocalFallback(slot);
    _changeNotifier.add(slot.schoolId);

    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        await slotsQuery.update(_toRow(slot)).eq('id', slot.id);
      } catch (_) {}
    }
    return const Success(null);
  }

  Future<Result<void>> delete(dynamic arg1, [String? arg2]) async {
    final slotId = arg2 ?? arg1.toString();
    try {
      final slotsQuery = _slots;
      if (slotsQuery != null) {
        await slotsQuery.delete().eq('id', slotId);
      }
    } catch (_) {}

    return const Success(null);
  }

  Future<Result<int>> batchAdd(List<SchoolTimetableSlot> slots) async {
    if (slots.isEmpty) return const Success(0);
    final schoolId = slots.first.schoolId;

    // 1. Prepare slots with non-empty unique IDs
    final prepared = slots.map((s) {
      if (s.id.isNotEmpty) return s;
      return SchoolTimetableSlot(
        id: 'slot_${DateTime.now().millisecondsSinceEpoch}_${slots.indexOf(s)}_${s.classLevel}_${s.dayOfWeek}_${s.startTime.replaceAll(':', '')}',
        schoolId: s.schoolId,
        classLevel: s.classLevel,
        dayOfWeek: s.dayOfWeek,
        startTime: s.startTime,
        endTime: s.endTime,
        subject: s.subject,
        teacherName: s.teacherName,
        room: s.room,
      );
    }).toList();

    // 2. Persist locally first so 100% of imported slots appear immediately
    final existing = await _getLocalSlots(schoolId);
    final map = {for (final s in existing) s.id: s};
    for (final s in prepared) {
      map[s.id] = s;
    }
    await _setLocalSlots(schoolId, map.values.toList());
    _changeNotifier.add(schoolId);

    // 3. Sync to Supabase in background
    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        final rows = prepared.map(_toRow).toList();
        await slotsQuery.upsert(rows);
      } catch (_) {}
    }

    return Success(slots.length);
  }

  Future<List<SchoolTimetableSlot>> getForSchoolOnce(String schoolId) async {
    if (schoolId.isEmpty) return const [];
    final cached = await _getLocalSlots(schoolId);
    if (cached.isNotEmpty) return cached;

    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        final rows = await slotsQuery.select().eq('school_id', schoolId);
        final list = (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
        await _setLocalSlots(schoolId, list);
        return list;
      } catch (_) {}
    }
    return cached;
  }

  Future<List<SchoolTimetableSlot>> _getLocalSlots(String schoolId) async {
    try {
      final key = 'school_timetable_$schoolId';
      final existing = await OfflineCache.instance.get<List<SchoolTimetableSlot>>(
        key,
        (json) => OfflineCache.listFromJson(json, (j) => _fromRow(j)),
      );
      if (existing != null) return existing;
    } catch (_) {}
    return [];
  }

  Future<void> _setLocalSlots(String schoolId, List<SchoolTimetableSlot> list) async {
    try {
      final key = 'school_timetable_$schoolId';
      await OfflineCache.instance.put(
        key,
        OfflineCache.listToJson(list, (s) => _toRow(s as SchoolTimetableSlot)),
      );
    } catch (_) {}
  }

  Future<void> _saveLocalFallback(SchoolTimetableSlot slot) async {
    try {
      final existing = await _getLocalSlots(slot.schoolId);
      final next = [...existing.where((s) => s.id != slot.id), slot];
      await _setLocalSlots(slot.schoolId, next);
    } catch (_) {}
  }

  Map<String, dynamic> _toRow(SchoolTimetableSlot s) {
    final map = <String, dynamic>{
      'school_id': s.schoolId,
      'class_level': s.classLevel,
      'day_of_week': s.dayOfWeek,
      'start_time': s.startTime,
      'end_time': s.endTime,
      'subject': s.subject,
      'teacher_name': s.teacherName,
      'room': s.room,
    };
    if (s.id.isNotEmpty) {
      map['id'] = s.id;
    }
    return map;
  }

  SchoolTimetableSlot _fromRow(Map<String, dynamic> row) => SchoolTimetableSlot(
        id: row['id']?.toString() ?? '',
        schoolId: row['school_id']?.toString() ?? '',
        classLevel: row['class_level']?.toString() ?? '',
        dayOfWeek: (row['day_of_week'] as num?)?.toInt() ?? 1,
        startTime: row['start_time']?.toString() ?? '',
        endTime: row['end_time']?.toString() ?? '',
        subject: row['subject']?.toString() ?? '',
        teacherName: row['teacher_name']?.toString() ?? '',
        room: row['room']?.toString(),
      );
}

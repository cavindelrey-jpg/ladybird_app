// lib/repositories/personal_study_repository.dart
// production_plan.md §5's Personal Study Timetable — owner-only, per-user
// data. Backed by public.personal_study_slots (see
// supabase/migrations/20260901000000_personal_study_slots.sql) — a plain
// auth.uid() = user_id RLS check on every op, no security-definer RPC
// needed since there's no cross-user access at all.

import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/personal_study_slot.dart';
import '../core/result.dart';
import '../core/realtime_tolerant.dart';
import '../core/offline_cache.dart';
import '../data/local_database.dart';

class PersonalStudyRepository {
  PersonalStudyRepository._();
  static final PersonalStudyRepository instance = PersonalStudyRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseQueryBuilder? get _slots => _db?.from('personal_study_slots');

  final StreamController<String> _changeNotifier = StreamController<String>.broadcast();

  static const String _hex = '0123456789abcdef';
  static String _uuidV4() {
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

  Stream<List<PersonalStudySlot>> watchAll(String userId) async* {
    // 1. Initial instant load from local cache (0ms latency, works offline)
    final initial = await _getLocalSlots(userId);
    yield initial;

    // 2. Stream controller to combine local change notifications and live Supabase stream
    final controller = StreamController<List<PersonalStudySlot>>();

    final localSub = _changeNotifier.stream.where((uid) => uid == userId).listen((_) async {
      final updated = await _getLocalSlots(userId);
      if (!controller.isClosed) controller.add(updated);
    });

    StreamSubscription? remoteSub;
    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        final live = slotsQuery
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('day_of_week', ascending: true)
            .realtimeTolerant()
            .map((rows) => rows.map(_fromRow).toList());

        remoteSub = live.listen((remoteList) async {
          await _setLocalSlots(userId, remoteList);
          if (!controller.isClosed) controller.add(remoteList);
        }, onError: (_) {
          // Fall back gracefully on network or offline errors
        });
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

  /// Today's slots only — powers the "Today's Study Program" Home section.
  /// DateTime.weekday is already 1=Mon..7=Sun, matching PersonalStudySlot.dayOfWeek.
  Stream<List<PersonalStudySlot>> watchToday(String userId) {
    final today = DateTime.now().weekday;
    return watchAll(userId).map((all) => all.where((s) => s.dayOfWeek == today).toList());
  }

  Future<Result<void>> add(PersonalStudySlot slot) async {
    final id = slot.id.isNotEmpty ? slot.id : _uuidV4();
    final slotWithId = PersonalStudySlot(
      id: id,
      userId: slot.userId,
      dayOfWeek: slot.dayOfWeek,
      startTime: slot.startTime,
      endTime: slot.endTime,
      activity: slot.activity,
      subject: slot.subject,
    );

    // Save locally first for instant optimistic update and offline persistence
    await _saveLocalFallback(slotWithId);
    _changeNotifier.add(slot.userId);

    // Sync to Supabase in background/network if available
    final row = _toRow(slotWithId);
    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        final res = await slotsQuery.insert(row).select().maybeSingle();
        if (res != null) {
          final synced = _fromRow(res);
          if (synced.id != slotWithId.id) {
            await _replaceLocalSlot(slot.userId, slotWithId.id, synced);
            _changeNotifier.add(slot.userId);
          }
        }
      } catch (_) {
        await LocalDatabase.instance.queueSyncAction('upsert', 'personal_study_slots', slotWithId.id, row);
      }
    } else {
      await LocalDatabase.instance.queueSyncAction('upsert', 'personal_study_slots', slotWithId.id, row);
    }

    return const Success(null);
  }

  Future<Result<void>> update(PersonalStudySlot slot) async {
    await _saveLocalFallback(slot);
    _changeNotifier.add(slot.userId);

    final row = _toRow(slot);
    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        await slotsQuery.update(row).eq('id', slot.id);
      } catch (_) {
        await LocalDatabase.instance.queueSyncAction('update', 'personal_study_slots', slot.id, row);
      }
    } else {
      await LocalDatabase.instance.queueSyncAction('update', 'personal_study_slots', slot.id, row);
    }

    return const Success(null);
  }

  Future<Result<void>> delete(String userId, String slotId) async {
    try {
      final existing = await _getLocalSlots(userId);
      final next = existing.where((s) => s.id != slotId).toList();
      await _setLocalSlots(userId, next);
      _changeNotifier.add(userId);
    } catch (_) {}

    final slotsQuery = _slots;
    if (slotsQuery != null) {
      try {
        await slotsQuery.delete().eq('id', slotId).eq('user_id', userId);
      } catch (_) {
        await LocalDatabase.instance.queueSyncAction('delete', 'personal_study_slots', slotId, {});
      }
    } else {
      await LocalDatabase.instance.queueSyncAction('delete', 'personal_study_slots', slotId, {});
    }

    return const Success(null);
  }

  Future<List<PersonalStudySlot>> _getLocalSlots(String userId) async {
    try {
      final key = 'personal_study_$userId';
      final existing = await OfflineCache.instance.get<List<PersonalStudySlot>>(
        key,
        (json) => OfflineCache.listFromJson(json, (j) => PersonalStudySlot.fromJson(j)),
      );
      if (existing != null) {
        existing.sort((a, b) {
          final d = a.dayOfWeek.compareTo(b.dayOfWeek);
          if (d != 0) return d;
          return a.startTime.compareTo(b.startTime);
        });
        return existing;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _setLocalSlots(String userId, List<PersonalStudySlot> list) async {
    try {
      final key = 'personal_study_$userId';
      await OfflineCache.instance.put(
        key,
        OfflineCache.listToJson(list, (s) => s.toJson()),
      );
    } catch (_) {}
  }

  Future<void> _saveLocalFallback(PersonalStudySlot slot) async {
    try {
      final existing = await _getLocalSlots(slot.userId);
      final next = [...existing.where((s) => s.id != slot.id), slot];
      next.sort((a, b) {
        final d = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (d != 0) return d;
        return a.startTime.compareTo(b.startTime);
      });
      await _setLocalSlots(slot.userId, next);
    } catch (_) {}
  }

  Future<void> _replaceLocalSlot(String userId, String oldId, PersonalStudySlot newSlot) async {
    try {
      final existing = await _getLocalSlots(userId);
      final next = [...existing.where((s) => s.id != oldId && s.id != newSlot.id), newSlot];
      next.sort((a, b) {
        final d = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (d != 0) return d;
        return a.startTime.compareTo(b.startTime);
      });
      await _setLocalSlots(userId, next);
    } catch (_) {}
  }

  Map<String, dynamic> _toRow(PersonalStudySlot slot) {
    final map = <String, dynamic>{
      'user_id': slot.userId,
      'day_of_week': slot.dayOfWeek,
      'start_time': slot.startTime,
      'end_time': slot.endTime,
      'activity': slot.activity,
      'subject': slot.subject,
    };
    if (slot.id.isNotEmpty) {
      map['id'] = slot.id;
    }
    return map;
  }

  PersonalStudySlot _fromRow(Map<String, dynamic> row) => PersonalStudySlot(
        id: row['id']?.toString() ?? '',
        userId: row['user_id']?.toString() ?? '',
        dayOfWeek: (row['day_of_week'] as num?)?.toInt() ?? 1,
        startTime: row['start_time']?.toString() ?? '',
        endTime: row['end_time']?.toString() ?? '',
        activity: row['activity']?.toString() ?? '',
        subject: row['subject']?.toString(),
      );
}

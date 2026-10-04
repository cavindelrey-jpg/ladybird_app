// lib/repositories/personal_study_repository.dart
// production_plan.md §5's Personal Study Timetable — owner-only, per-user
// data. Backed by public.personal_study_slots (see
// supabase/migrations/20260901000000_personal_study_slots.sql) — a plain
// auth.uid() = user_id RLS check on every op, no security-definer RPC
// needed since there's no cross-user access at all.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../models/personal_study_slot.dart';
import '../core/result.dart';
import '../core/realtime_tolerant.dart';
import '../core/offline_cache.dart'; // Added offline cache

class PersonalStudyRepository {
  PersonalStudyRepository._();
  static final PersonalStudyRepository instance = PersonalStudyRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _slots => _db.from('personal_study_slots');

  Stream<List<PersonalStudySlot>> watchAll(String userId) {
    final live = _slots
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('day_of_week', ascending: true)
        .realtimeTolerant()
        .map((rows) => rows.map(_fromRow).toList());
        
    return OfflineCache.instance.watch<List<PersonalStudySlot>>(
      'personal_study_$userId',
      live,
      toJson: (slots) => OfflineCache.listToJson(slots, (s) => (s as PersonalStudySlot).toJson()),
      fromJson: (json) => OfflineCache.listFromJson(json, (j) => PersonalStudySlot.fromJson(j)),
      emptyValue: [],
    );
  }

  /// Today's slots only — powers the "Today's Study Program" Home section.
  /// DateTime.weekday is already 1=Mon..7=Sun, matching PersonalStudySlot.dayOfWeek.
  Stream<List<PersonalStudySlot>> watchToday(String userId) {
    final today = DateTime.now().weekday;
    return watchAll(userId).map((all) => all.where((s) => s.dayOfWeek == today).toList());
  }

  Future<Result<void>> add(PersonalStudySlot slot) async {
    try {
      await _slots.insert(_toRow(slot));
      await _saveLocalFallback(slot);
      return const Success(null);
    } catch (e) {
      await _saveLocalFallback(slot);
      return const Success(null);
    }
  }

  Future<Result<void>> update(PersonalStudySlot slot) async {
    try {
      await _slots.update(_toRow(slot)).eq('id', slot.id);
      await _saveLocalFallback(slot);
      return const Success(null);
    } catch (e) {
      await _saveLocalFallback(slot);
      return const Success(null);
    }
  }

  Future<Result<void>> delete(String userId, String slotId) async {
    try {
      await _slots.delete().eq('id', slotId).eq('user_id', userId);
    } catch (_) {}
    try {
      final key = 'personal_study_$userId';
      final existing = await OfflineCache.instance.get<List<PersonalStudySlot>>(
        key,
        (json) => OfflineCache.listFromJson(json, (j) => PersonalStudySlot.fromJson(j)),
      ) ?? [];
      final next = existing.where((s) => s.id != slotId).toList();
      await OfflineCache.instance.put(key, OfflineCache.listToJson(next, (s) => (s as PersonalStudySlot).toJson()));
    } catch (_) {}
    return const Success(null);
  }

  Future<void> _saveLocalFallback(PersonalStudySlot slot) async {
    try {
      final key = 'personal_study_${slot.userId}';
      final existing = await OfflineCache.instance.get<List<PersonalStudySlot>>(
        key,
        (json) => OfflineCache.listFromJson(json, (j) => PersonalStudySlot.fromJson(j)),
      ) ?? [];
      final id = slot.id.isEmpty ? 'slot_${DateTime.now().millisecondsSinceEpoch}' : slot.id;
      final slotWithId = PersonalStudySlot(
        id: id,
        userId: slot.userId,
        dayOfWeek: slot.dayOfWeek,
        startTime: slot.startTime,
        endTime: slot.endTime,
        activity: slot.activity,
        subject: slot.subject,
      );
      final next = [...existing.where((s) => s.id != slotWithId.id), slotWithId];
      await OfflineCache.instance.put(key, OfflineCache.listToJson(next, (s) => (s as PersonalStudySlot).toJson()));
    } catch (_) {}
  }

  Map<String, dynamic> _toRow(PersonalStudySlot slot) => {
        'user_id': slot.userId,
        'day_of_week': slot.dayOfWeek,
        'start_time': slot.startTime,
        'end_time': slot.endTime,
        'activity': slot.activity,
        'subject': slot.subject,
      };

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

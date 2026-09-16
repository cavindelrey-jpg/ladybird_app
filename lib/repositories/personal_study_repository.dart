// lib/repositories/personal_study_repository.dart
// production_plan.md §5's Personal Study Timetable — owner-only, per-user
// data. Backed by public.personal_study_slots (see
// supabase/migrations/20260901000000_personal_study_slots.sql) — a plain
// auth.uid() = user_id RLS check on every op, no security-definer RPC
// needed since there's no cross-user access at all.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/personal_study_slot.dart';
import '../core/result.dart';
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
        .order('day_of_week')
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
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t save that study slot', e);
    }
  }

  Future<Result<void>> update(PersonalStudySlot slot) async {
    try {
      await _slots.update(_toRow(slot)).eq('id', slot.id);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t update that study slot', e);
    }
  }

  Future<Result<void>> delete(String userId, String slotId) async {
    try {
      await _slots.delete().eq('id', slotId).eq('user_id', userId);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t delete that study slot', e);
    }
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

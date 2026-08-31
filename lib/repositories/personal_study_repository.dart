// lib/repositories/personal_study_repository.dart
// production_plan.md §5's Personal Study Timetable — owner-only, per-user
// data. No Postgres table yet — zero real data at migration time; an
// honest stub (empty streams, real Failure on write) rather than a
// fabricated schema. Add a table + wire this up for real when this
// feature becomes the active task.

import '../models/personal_study_slot.dart';
import '../core/result.dart';

class PersonalStudyRepository {
  PersonalStudyRepository._();
  static final PersonalStudyRepository instance = PersonalStudyRepository._();

  static const String _notAvailable = 'Personal study timetable isn\'t available yet.';

  Stream<List<PersonalStudySlot>> watchAll(String userId) => Stream.value(const []);

  /// Today's slots only — powers the "Today's Study Program" Home section.
  Stream<List<PersonalStudySlot>> watchToday(String userId) => Stream.value(const []);

  Future<Result<void>> add(PersonalStudySlot slot) async => const Failure(_notAvailable, null);

  Future<Result<void>> update(PersonalStudySlot slot) async => const Failure(_notAvailable, null);

  Future<Result<void>> delete(String userId, String slotId) async => const Failure(_notAvailable, null);
}

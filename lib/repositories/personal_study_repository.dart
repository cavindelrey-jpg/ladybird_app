// lib/repositories/personal_study_repository.dart
// CRUD for production_plan.md §5's Personal Study Timetable — owner-only,
// stored at users/{uid}/study_timetable/{id}. Separate collection from
// TimetableRepository (the school-authored, institution-scoped timetable).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/personal_study_slot.dart';
import '../core/constants.dart';
import '../core/result.dart';

class PersonalStudyRepository {
  PersonalStudyRepository._();
  static final PersonalStudyRepository instance = PersonalStudyRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection(AppConstants.colUsers).doc(userId).collection('study_timetable');

  Stream<List<PersonalStudySlot>> watchAll(String userId) => _col(userId)
      .orderBy('dayOfWeek')
      .snapshots()
      .map((s) => s.docs.map((d) => PersonalStudySlot.fromFirestore(d, userId)).toList());

  /// Today's slots only, ordered by start time — powers the "Today's
  /// Study Program" Home section (see universal_home_page.dart).
  Stream<List<PersonalStudySlot>> watchToday(String userId) {
    final today = DateTime.now().weekday; // 1=Mon…7=Sun, matches dayOfWeek
    return _col(userId)
        .where('dayOfWeek', isEqualTo: today)
        .snapshots()
        .map((s) {
      final slots = s.docs.map((d) => PersonalStudySlot.fromFirestore(d, userId)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return slots;
    });
  }

  Future<Result<void>> add(PersonalStudySlot slot) async {
    try {
      await _col(slot.userId).add(slot.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add study slot', e);
    }
  }

  Future<Result<void>> update(PersonalStudySlot slot) async {
    try {
      await _col(slot.userId).doc(slot.id).set(slot.toFirestore(), SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update study slot', e);
    }
  }

  Future<Result<void>> delete(String userId, String slotId) async {
    try {
      await _col(userId).doc(slotId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete study slot', e);
    }
  }
}

// lib/repositories/calendar_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class CalendarRepository {
  CalendarRepository._();
  static final CalendarRepository instance = CalendarRepository._();
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(AppConstants.colSchools).doc(schoolId)
         .collection(AppConstants.colCalendar);

  Stream<List<CalendarEvent>> watchAll(String schoolId) =>
      _col(schoolId).orderBy('startDate').snapshots()
          .map((s) => s.docs.map(CalendarEvent.fromFirestore).toList());

  Stream<List<CalendarEvent>> watchUpcoming(String schoolId) =>
      _col(schoolId)
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .orderBy('startDate').limit(10).snapshots()
          .map((s) => s.docs.map(CalendarEvent.fromFirestore).toList());

  Future<Result<void>> create(CalendarEvent e) async {
    try {
      await _col(e.schoolId).add(e.toFirestore());
      return const Success(null);
    } catch (e) { return Failure('Failed to create event', e); }
  }

  Future<Result<void>> delete(String schoolId, String id) async {
    try {
      await _col(schoolId).doc(id).delete();
      return const Success(null);
    } catch (e) { return Failure('Failed to delete event', e); }
  }
}

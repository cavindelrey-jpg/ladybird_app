// lib/repositories/school_event_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';
import '../models/school_event.dart';

class SchoolEventRepository {
  SchoolEventRepository._();
  static final SchoolEventRepository instance = SchoolEventRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) => _db
      .collection(AppConstants.colSchools)
      .doc(schoolId)
      .collection('academic_calendar');

  /// Every event for this school, soonest first -- both "Calendar of
  /// Activities" (the full list) and "Upcoming Events" (filtered
  /// client-side to isUpcoming) read from the same stream.
  Stream<List<SchoolEvent>> watchAll(String schoolId) {
    if (schoolId.isEmpty) return Stream.value(const []);
    return _col(schoolId).snapshots().map((snap) {
      final events = snap.docs.map((d) => SchoolEvent.fromFirestore(d, schoolId)).toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return events;
    });
  }

  Future<Result<void>> add(SchoolEvent event) async {
    try {
      await _col(event.schoolId).add(event.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add event', e);
    }
  }

  Future<Result<void>> delete(String schoolId, String eventId) async {
    try {
      await _col(schoolId).doc(eventId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete event', e);
    }
  }
}

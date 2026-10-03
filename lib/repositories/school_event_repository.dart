// lib/repositories/school_event_repository.dart
// School Connect's Calendar of Activities. No Postgres table yet — zero
// real data at migration time; an honest stub rather than a fabricated
// schema.

import '../core/result.dart';

import '../models/school_event.dart';

class SchoolEventRepository {
  SchoolEventRepository._();
  static final SchoolEventRepository instance = SchoolEventRepository._();

  /// Every event for this school, soonest first -- both "Calendar of
  /// Activities" (the full list) and "Upcoming Events" (filtered
  /// client-side to isUpcoming) read from the same stream.
  Stream<List<SchoolEvent>> watchAll(String schoolId) => Stream.value(const []);

  Future<Result<void>> add(SchoolEvent event) async =>
      const Failure('School events aren\'t available yet.', null);

  Future<Result<void>> delete(String schoolId, String eventId) async =>
      const Failure('School events aren\'t available yet.', null);
}

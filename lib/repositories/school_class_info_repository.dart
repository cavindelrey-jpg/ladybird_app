// lib/repositories/school_class_info_repository.dart
// Which teacher is a class's "Class Master". No Postgres table yet —
// zero real data at migration time; an honest stub rather than a
// fabricated schema.

import '../core/result.dart';


class SchoolClassInfoRepository {
  SchoolClassInfoRepository._();
  static final SchoolClassInfoRepository instance = SchoolClassInfoRepository._();

  Stream<String?> watchClassMasterName(String schoolId, String classLevel) => Stream.value(null);

  Future<Result<void>> setClassMasterName(String schoolId, String classLevel, String name) async =>
      const Failure('Class info isn\'t available yet.', null);
}

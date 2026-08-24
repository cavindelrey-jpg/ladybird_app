// lib/repositories/school_class_info_repository.dart
// The one genuinely new piece of data the mockups need that nothing in
// the app tracked before: which teacher is a class's "Class Master".
// Firestore: schools/{schoolId}/classInfo/{classLevel} -> {classMasterName}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';

class SchoolClassInfoRepository {
  SchoolClassInfoRepository._();
  static final SchoolClassInfoRepository instance = SchoolClassInfoRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String schoolId, String classLevel) => _db
      .collection(AppConstants.colSchools)
      .doc(schoolId)
      .collection('classInfo')
      .doc(classLevel);

  Stream<String?> watchClassMasterName(String schoolId, String classLevel) {
    if (schoolId.isEmpty || classLevel.isEmpty) return Stream.value(null);
    return _doc(schoolId, classLevel).snapshots().map((d) => d.data()?['classMasterName'] as String?);
  }

  Future<Result<void>> setClassMasterName(String schoolId, String classLevel, String name) async {
    try {
      await _doc(schoolId, classLevel).set({'classMasterName': name}, SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save class master', e);
    }
  }
}

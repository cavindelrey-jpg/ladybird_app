// lib/repositories/school_repository.dart
// CRUD for the schools/{schoolId} registry (see models/school.dart).
// Creating a school is a platform-level action (same tier as issuing the
// first voucher for it) — mirrors how "Register a School" is already
// documented as superAdmin-only in this codebase's history.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';
import '../models/school.dart';

class SchoolRepository {
  SchoolRepository._();
  static final SchoolRepository instance = SchoolRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(AppConstants.colSchools);

  Future<Result<School>> registerSchool({
    required String name,
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (name.trim().isEmpty || normalizedCode.isEmpty) {
      return const Failure('School name and code are required', null);
    }
    try {
      final existing = await _col.where('code', isEqualTo: normalizedCode).limit(1).get();
      if (existing.docs.isNotEmpty) {
        return Failure('School code "$normalizedCode" is already in use', null);
      }
      final doc = _col.doc();
      final school = School(id: doc.id, code: normalizedCode, name: name.trim(), createdAt: DateTime.now());
      await doc.set(school.toFirestore());
      return Success(school);
    } catch (e) {
      return Failure('Failed to register school', e);
    }
  }

  Future<School?> getByCodeOnce(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;
    final snap = await _col.where('code', isEqualTo: normalizedCode).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return School.fromFirestore(snap.docs.first);
  }

  Future<School?> getByIdOnce(String schoolId) async {
    if (schoolId.isEmpty) return null;
    final doc = await _col.doc(schoolId).get();
    if (!doc.exists) return null;
    return School.fromFirestore(doc);
  }

  Stream<List<School>> watchAll() =>
      _col.orderBy('name').snapshots().map((s) => s.docs.map(School.fromFirestore).toList());
}

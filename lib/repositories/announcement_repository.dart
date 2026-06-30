// lib/repositories/announcement_repository.dart
// All Firestore reads/writes for announcements.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class AnnouncementRepository {
  AnnouncementRepository._();
  static final AnnouncementRepository instance = AnnouncementRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String? schoolId) {
    if (schoolId != null && schoolId.isNotEmpty) {
      return _db
          .collection(AppConstants.colSchools)
          .doc(schoolId)
          .collection(AppConstants.colAnnounce);
    }
    return _db.collection(AppConstants.colAnnounce);
  }

  Stream<List<Announcement>> watchAnnouncements({String? schoolId}) {
    return _col(schoolId)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(Announcement.fromFirestore).toList());
  }

  Future<Result<void>> post(Announcement announcement) async {
    try {
      await _col(announcement.schoolId).add(announcement.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post announcement', e);
    }
  }

  Future<Result<void>> delete(String id, {String? schoolId}) async {
    try {
      await _col(schoolId).doc(id).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete announcement', e);
    }
  }
}

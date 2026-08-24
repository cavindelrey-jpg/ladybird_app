// lib/repositories/announcement_repository.dart
// All Firestore reads/writes for announcements.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  /// A real, unused doc id from the target collection -- lets the
  /// composer upload an image to Storage keyed by the announcement's
  /// real id BEFORE the Firestore doc itself is written (same order
  /// hero_slide_manager_page.dart / HeroSlideRepository already use for
  /// its own image upload).
  String newId(String? schoolId) => _col(schoolId).doc().id;

  Future<Result<String>> uploadImage({required String id, required File imageFile}) async {
    try {
      final ref = FirebaseStorage.instance.ref('announcement_images/$id.jpg');
      await ref.putFile(imageFile);
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload announcement image', e);
    }
  }

  /// Upserts when [announcement.id] is non-empty (set via [newId] so an
  /// uploaded image can be keyed to the real id ahead of time), otherwise
  /// lets Firestore assign one -- same shape SchoolMarksRepository.upsert
  /// already uses.
  Future<Result<void>> post(Announcement announcement) async {
    try {
      if (announcement.id.isEmpty) {
        await _col(announcement.schoolId).add(announcement.toFirestore());
      } else {
        await _col(announcement.schoolId).doc(announcement.id).set(announcement.toFirestore());
      }
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

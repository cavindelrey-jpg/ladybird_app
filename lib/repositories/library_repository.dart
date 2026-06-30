// lib/repositories/library_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class LibraryRepository {
  LibraryRepository._();
  static final LibraryRepository instance = LibraryRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<LibraryItem>> watchItems({String? schoolId, ContentType? type}) {
    Query<Map<String, dynamic>> q = _db.collection(AppConstants.colLibrary);
    if (schoolId != null) q = q.where('schoolId', isEqualTo: schoolId);
    if (type != null)     q = q.where('type', isEqualTo: type.name);
    return q.orderBy('views', descending: true).limit(60).snapshots()
        .map((snap) => snap.docs.map(LibraryItem.fromFirestore).toList());
  }

  Future<List<LibraryItem>> search(String query, {String? schoolId}) async {
    final lower = query.toLowerCase();
    final snap = await _db
        .collection(AppConstants.colLibrary)
        .orderBy('title')
        .get();
    return snap.docs
        .map(LibraryItem.fromFirestore)
        .where((item) =>
            item.title.toLowerCase().contains(lower) ||
            item.subject.toLowerCase().contains(lower))
        .toList();
  }

  Future<Result<void>> incrementViews(String docId) async {
    try {
      await _db.collection(AppConstants.colLibrary).doc(docId).update({
        'views': FieldValue.increment(1),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to increment view count', e);
    }
  }

  Future<Result<String>> addItem(LibraryItem item) async {
    try {
      final ref = await _db
          .collection(AppConstants.colLibrary)
          .add(item.toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to add library item', e);
    }
  }
}

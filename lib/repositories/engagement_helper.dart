// lib/repositories/engagement_helper.dart
// The like/bookmark toggle logic was byte-for-byte identical between
// MagazineRepository and PublicCourseRepository — only which top-level
// collection they pointed at differed. This extracts that shared logic
// into one place both repositories now call, instead of maintaining two
// copies of the same Firestore transaction pattern.
//
// Deliberately NOT a merge of the content models themselves (Magazine
// articles and Courses stay their own types with their own fields) —
// just the identical, verified-duplicate engagement mechanics.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/result.dart';
import '../core/constants.dart';

class EngagementHelper {
  EngagementHelper._();

  static Stream<bool> watchIsSet({
    required CollectionReference<Map<String, dynamic>> parentCollection,
    required String docId,
    required String subcollection,
    required String userId,
  }) =>
      parentCollection.doc(docId).collection(subcollection).doc(userId).snapshots().map((d) => d.exists);

  /// Toggles a simple presence doc (bookmark) with no counter field.
  static Future<Result<void>> togglePresence({
    required CollectionReference<Map<String, dynamic>> parentCollection,
    required String docId,
    required String subcollection,
    required String userId,
    String timestampField = 'savedAt',
    String failureMessage = 'Failed to update',
  }) async {
    try {
      final ref = parentCollection.doc(docId).collection(subcollection).doc(userId);
      final existing = await ref.get();
      if (existing.exists) {
        await ref.delete();
      } else {
        await ref.set({timestampField: FieldValue.serverTimestamp()});
      }
      return const Success(null);
    } catch (e) {
      return Failure(failureMessage, e);
    }
  }

  /// Toggles a presence doc AND increments/decrements a counter field on
  /// the parent doc in the same batch (likes).
  static Future<Result<void>> toggleWithCounter({
    required FirebaseFirestore db,
    required CollectionReference<Map<String, dynamic>> parentCollection,
    required String docId,
    required String subcollection,
    required String userId,
    required String counterField,
    String failureMessage = 'Failed to update',
  }) async {
    try {
      final ref = parentCollection.doc(docId).collection(subcollection).doc(userId);
      final existing = await ref.get();
      final batch = db.batch();
      if (existing.exists) {
        batch.delete(ref);
        batch.update(parentCollection.doc(docId), {counterField: FieldValue.increment(-1)});
      } else {
        batch.set(ref, {'createdAt': FieldValue.serverTimestamp()});
        batch.update(parentCollection.doc(docId), {counterField: FieldValue.increment(1)});
      }
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure(failureMessage, e);
    }
  }
}

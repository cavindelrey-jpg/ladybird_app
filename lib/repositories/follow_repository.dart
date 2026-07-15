// lib/repositories/follow_repository.dart
// One-way follow relationships — following someone gets you their new
// Magazine articles in your Following tab and a notification when they
// publish. This is separate from Messages' friend-request system: you
// can follow a writer without ever being able to message them, and vice
// versa.
//
// Firestore: follows/{followerId}_{followedId}
// Deliberately a flat top-level collection with a composite doc ID
// (rather than a subcollection under users) so both directions —
// "who do I follow" and "who follows me" — are simple single-field
// queries with no composite index required.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';

class FollowRepository {
  FollowRepository._();
  static final FollowRepository instance = FollowRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _follows =>
      _db.collection(AppConstants.colFollows);

  String _docId(String followerId, String followedId) => '${followerId}_$followedId';

  Future<Result<void>> follow(String followerId, String followedId) async {
    if (followerId == followedId) {
      return const Failure('You can\'t follow yourself', null);
    }
    try {
      await _follows.doc(_docId(followerId, followedId)).set({
        'followerId': followerId,
        'followedId': followedId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to follow', e);
    }
  }

  Future<Result<void>> unfollow(String followerId, String followedId) async {
    try {
      await _follows.doc(_docId(followerId, followedId)).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to unfollow', e);
    }
  }

  Stream<bool> watchIsFollowing(String followerId, String followedId) => _follows
      .doc(_docId(followerId, followedId))
      .snapshots()
      .map((d) => d.exists);

  /// IDs of everyone [userId] follows — feeds the Magazine "Following" tab.
  Stream<List<String>> watchFollowingIds(String userId) => _follows
      .where('followerId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()['followedId'] as String).toList());

  Stream<int> watchFollowerCount(String userId) => _follows
      .where('followedId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.length);

  /// IDs of everyone who follows [userId] — used to fan out "new article"
  /// notifications when they publish.
  Stream<List<String>> watchFollowerIds(String userId) => _follows
      .where('followedId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()['followerId'] as String).toList());

  Stream<int> watchFollowingCount(String userId) => _follows
      .where('followerId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.length);
}

// lib/repositories/follow_repository.dart
// One-way follow relationships — following someone gets you their new
// Magazine articles in your Following tab and a notification when they
// publish. Separate from Messages' friend-request system.
//
// Postgres: follows (follower_id, followed_id) composite primary key —
// same "no extra index needed for either direction" reasoning the
// Firestore composite-doc-id design had.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../core/realtime_tolerant.dart';

class FollowRepository {
  FollowRepository._();
  static final FollowRepository instance = FollowRepository._();

  SupabaseQueryBuilder get _follows => Supabase.instance.client.from('follows');

  Future<Result<void>> follow(String followerId, String followedId) async {
    if (followerId == followedId) {
      return const Failure('You can\'t follow yourself', null);
    }
    try {
      await _follows.upsert({'follower_id': followerId, 'followed_id': followedId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to follow', e);
    }
  }

  Future<Result<void>> unfollow(String followerId, String followedId) async {
    try {
      await _follows.delete().eq('follower_id', followerId).eq('followed_id', followedId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to unfollow', e);
    }
  }

  Stream<bool> watchIsFollowing(String followerId, String followedId) => _follows
      .stream(primaryKey: ['follower_id', 'followed_id'])
      .eq('follower_id', followerId)
      .realtimeTolerant()
      .map((rows) => rows.any((r) => r['followed_id'] == followedId));

  /// IDs of everyone [userId] follows — feeds the Magazine "Following" tab.
  Stream<List<String>> watchFollowingIds(String userId) => _follows
      .stream(primaryKey: ['follower_id', 'followed_id'])
      .eq('follower_id', userId)
      .realtimeTolerant()
      .map((rows) => rows.map((r) => r['followed_id'] as String).toList());

  Stream<int> watchFollowerCount(String userId) => _follows
      .stream(primaryKey: ['follower_id', 'followed_id'])
      .eq('followed_id', userId)
      .realtimeTolerant()
      .map((rows) => rows.length);

  /// IDs of everyone who follows [userId] — used to fan out "new article"
  /// notifications when they publish.
  Stream<List<String>> watchFollowerIds(String userId) => _follows
      .stream(primaryKey: ['follower_id', 'followed_id'])
      .eq('followed_id', userId)
      .realtimeTolerant()
      .map((rows) => rows.map((r) => r['follower_id'] as String).toList());

  Stream<int> watchFollowingCount(String userId) => _follows
      .stream(primaryKey: ['follower_id', 'followed_id'])
      .eq('follower_id', userId)
      .realtimeTolerant()
      .map((rows) => rows.length);
}

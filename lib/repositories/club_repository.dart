// lib/repositories/club_repository.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';
import 'xp_repository.dart';

class ClubRepository {
  ClubRepository._();
  static final ClubRepository instance = ClubRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Discovery ──────────────────────────────────────────

  Stream<List<Club>> watchClubs({String? schoolId}) {
    Query<Map<String, dynamic>> q = _db.collection(AppConstants.colClubs);
    if (schoolId != null) q = q.where('schoolId', isEqualTo: schoolId);
    return q.snapshots()
        .map((snap) => snap.docs.map(Club.fromFirestore).toList());
  }

  Future<List<Club>> searchClubs(String query, {String? category}) async {
    Query<Map<String, dynamic>> q = _db.collection(AppConstants.colClubs);
    if (category != null && category != 'All') {
      q = q.where('category', isEqualTo: category);
    }
    final snap = await q.get();
    final lower = query.toLowerCase();
    return snap.docs
        .map(Club.fromFirestore)
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(lower))
        .toList();
  }

  // ── Membership ─────────────────────────────────────────

  Stream<ClubRole> watchUserRole(String clubId, String userId) {
    return _db
        .collection(AppConstants.colClubs)
        .doc(clubId)
        .collection(AppConstants.colMembers)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return ClubRole.visitor;
      final roleStr = doc.data()?['role'] as String?;
      return ClubRole.values.firstWhere(
        (r) => r.name == roleStr, orElse: () => ClubRole.member);
    });
  }

  Future<Result<void>> joinClub(
    String clubId,
    String userId, {
    required String name,
    String? photoUrl,
  }) async {
    try {
      final batch = _db.batch();
      final memberRef = _db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMembers)
          .doc(userId);
      batch.set(memberRef, {
        'userId': userId, // also the doc id, but needed as a FIELD too --
                           // collectionGroup('members') queries (see
                           // watchMyClubIds()) can't filter by doc id.
        'name': name,
        'photoUrl': photoUrl,
        'role': ClubRole.member.name,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      batch.update(
        _db.collection(AppConstants.colClubs).doc(clubId),
        {'memberCount': FieldValue.increment(1)},
      );
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to join club', e);
    }
  }

  // ── Join requests (approval-gated clubs only) ─────────────
  // Open clubs skip all of this and call joinClub() directly — these
  // methods only matter when Club.requiresApproval is true.

  CollectionReference<Map<String, dynamic>> get _joinRequests =>
      _db.collection(AppConstants.colClubJoinRequests);

  Future<Result<void>> requestToJoin({
    required String clubId, required String clubName,
    required String userId, required String userName, String? userPhotoUrl,
  }) async {
    try {
      final existing = await _joinRequests
          .where('clubId', isEqualTo: clubId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return const Failure('Request already pending', null);

      await _joinRequests.add(ClubJoinRequest(
        id: '', clubId: clubId, clubName: clubName,
        userId: userId, userName: userName, userPhotoUrl: userPhotoUrl,
        createdAt: DateTime.now(),
      ).toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send join request', e);
    }
  }

  /// Pending/approved/declined status of this user's most recent request
  /// for this club — drives the "Pending" badge on My Clubs.
  Stream<ClubJoinRequestStatus?> watchMyRequestStatus(String clubId, String userId) => _joinRequests
      .where('clubId', isEqualTo: clubId)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : ClubJoinRequest.fromFirestore(s.docs.first).status);

  /// Pending requests for a club — for its admins/moderators to review.
  Stream<List<ClubJoinRequest>> watchPendingRequests(String clubId) => _joinRequests
      .where('clubId', isEqualTo: clubId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ClubJoinRequest.fromFirestore).toList());

  Future<Result<void>> approveJoinRequest(ClubJoinRequest req) async {
    try {
      final batch = _db.batch();
      batch.update(_joinRequests.doc(req.id), {'status': 'approved'});
      final memberRef = _db.collection(AppConstants.colClubs).doc(req.clubId)
          .collection(AppConstants.colMembers).doc(req.userId);
      batch.set(memberRef, {
        'userId': req.userId,
        'name': req.userName, 'photoUrl': req.userPhotoUrl,
        'role': ClubRole.member.name, 'joinedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection(AppConstants.colClubs).doc(req.clubId),
          {'memberCount': FieldValue.increment(1)});
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to approve request', e);
    }
  }

  Future<Result<void>> declineJoinRequest(String requestId) async {
    try {
      await _joinRequests.doc(requestId).update({'status': 'declined'});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to decline request', e);
    }
  }

  Future<Result<void>> leaveClub(String clubId, String userId) async {
    try {
      final batch = _db.batch();
      batch.delete(_db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMembers)
          .doc(userId));
      batch.update(
        _db.collection(AppConstants.colClubs).doc(clubId),
        {'memberCount': FieldValue.increment(-1)},
      );
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to leave club', e);
    }
  }

  // ── Chat ───────────────────────────────────────────────

  Stream<List<ClubMessage>> watchMessages(String clubId) {
    return _db
        .collection(AppConstants.colClubs)
        .doc(clubId)
        .collection(AppConstants.colMessages)
        .orderBy('time', descending: false)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(ClubMessage.fromFirestore).toList());
  }

  Future<Result<void>> sendMessage(String clubId, ClubMessage message) async {
    try {
      final batch = _db.batch();
      final msgRef = _db.collection(AppConstants.colClubs).doc(clubId)
          .collection(AppConstants.colMessages).doc();
      batch.set(msgRef, message.toFirestore());
      // Denormalized preview so this club can show up in the merged
      // Messages inbox (MessagesHomePage) alongside 1:1 conversations —
      // same shape as MessagingRepository.sendMessage's preview text.
      batch.update(_db.collection(AppConstants.colClubs).doc(clubId), {
        'lastMessageText': message.text,
        'lastMessageSenderId': message.senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send message', e);
    }
  }

  // ── Merged-inbox support (Messaging mockup: club threads alongside
  // 1:1 conversations in one Messages list) ─────────────────────────

  /// Shared source for [watchMyClubIds] and [watchMyClubReadState] -- one
  /// underlying collectionGroup query on `members` filtered by the
  /// `userId` FIELD (not doc id -- Firestore collection-group queries
  /// can't filter by document id across different parents), so both
  /// derived streams don't each pay for their own listener. Needs a
  /// matching collection-group index on `members.userId` -- see
  /// firestore.indexes.json (local file only, same deploy caveat as
  /// firestore.rules).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchMyMemberships(String userId) => _db
      .collectionGroup(AppConstants.colMembers)
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs);

  Stream<List<String>> watchMyClubIds(String userId) => _watchMyMemberships(userId)
      .map((docs) => docs
          .map((d) => d.reference.parent.parent?.id)
          .whereType<String>()
          .toList());

  /// clubId -> this user's `lastReadAt` in that club's Chat tab (null =
  /// never opened it). Powers the Club unread indicator in the merged
  /// Messages inbox (see MessagesHomePage) via [clubHasUnreadMessages],
  /// comparing this against each Club's own `lastMessageAt`.
  Stream<Map<String, DateTime?>> watchMyClubReadState(String userId) => _watchMyMemberships(userId)
      .map((docs) => {
            for (final d in docs)
              if (d.reference.parent.parent?.id != null)
                d.reference.parent.parent!.id: (d.data()['lastReadAt'] as Timestamp?)?.toDate(),
          });

  /// Records that [userId] has opened [clubId]'s Chat tab just now --
  /// call sites should call this when the Chat tab actually becomes
  /// visible (see ClubDetailPage), mirroring MessagingRepository
  /// .markConversationRead's best-effort, fire-and-forget shape.
  Future<void> markClubRead(String clubId, String userId) async {
    try {
      await _db.collection(AppConstants.colClubs).doc(clubId)
          .collection(AppConstants.colMembers).doc(userId)
          .update({'lastReadAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // best-effort -- a missed read-receipt update shouldn't block the UI
    }
  }

  /// Full Club docs for [watchMyClubIds] — the actual data the merged
  /// inbox renders (name, emoji, lastMessage*).
  Stream<List<Club>> watchMyClubs(String userId) => watchMyClubIds(userId).asyncMap((ids) async {
        if (ids.isEmpty) return <Club>[];
        final chunks = <List<String>>[];
        for (var i = 0; i < ids.length; i += 30) {
          chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
        }
        final clubs = <Club>[];
        for (final chunk in chunks) {
          final snap = await _db.collection(AppConstants.colClubs)
              .where(FieldPath.documentId, whereIn: chunk).get();
          clubs.addAll(snap.docs.map(Club.fromFirestore));
        }
        return clubs;
      });

  /// Soft-delete -- same reasoning as MessagingRepository.deleteMessage:
  /// keeps the doc so the thread shows a placeholder instead of a gap,
  /// sender-only both here and in firestore.rules.
  Future<Result<void>> deleteMessage(String clubId, String messageId, String userId) async {
    try {
      final ref = _db.collection(AppConstants.colClubs).doc(clubId)
          .collection(AppConstants.colMessages).doc(messageId);
      final doc = await ref.get();
      if (!doc.exists || doc.data()?['senderId'] != userId) {
        return const Failure('You can only delete your own messages', null);
      }
      await ref.update({'deleted': true, 'text': ''});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete message', e);
    }
  }

  // ── Create ─────────────────────────────────────────────

  Future<Result<String>> createClub(
    Club club,
    String founderId, {
    required String founderName,
    String? founderPhotoUrl,
  }) async {
    try {
      final docRef = _db.collection(AppConstants.colClubs).doc();
      final batch = _db.batch();
      batch.set(docRef, club.toFirestore());
      batch.set(
        docRef.collection(AppConstants.colMembers).doc(founderId),
        {
          'userId': founderId,
          'name': founderName,
          'photoUrl': founderPhotoUrl,
          'role': ClubRole.admin.name,
          'joinedAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      return Success(docRef.id);
    } catch (e) {
      return Failure('Failed to create club', e);
    }
  }

  // ── Member management (mod structure) ───────────────────
  // Normal roles: visitor (not joined) < member < moderator < admin.
  // Moderators can manage regular members; only admins can appoint or
  // remove other moderators/admins. Enforced both here (defense in
  // depth for the UI) and in firestore.rules (the real gate).

  Stream<List<ClubMember>> watchMembers(String clubId) => _db
      .collection(AppConstants.colClubs)
      .doc(clubId)
      .collection(AppConstants.colMembers)
      .orderBy('joinedAt')
      .snapshots()
      .map((s) => s.docs.map(ClubMember.fromFirestore).toList());

  Future<Result<void>> updateMemberRole(
      String clubId, String userId, ClubRole newRole) async {
    try {
      await _db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMembers)
          .doc(userId)
          .update({'role': newRole.name});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update member role', e);
    }
  }

  Future<Result<void>> removeMember(String clubId, String userId) async {
    try {
      final batch = _db.batch();
      batch.delete(_db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMembers)
          .doc(userId));
      batch.update(
        _db.collection(AppConstants.colClubs).doc(clubId),
        {'memberCount': FieldValue.increment(-1)},
      );
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to remove member', e);
    }
  }

  // ── Banner image ─────────────────────────────────────────

  Future<Result<String>> uploadBanner({
    required String clubId,
    required File imageFile,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref('club_banners/$clubId.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return Success(url);
    } catch (e) {
      return Failure('Failed to upload club banner', e);
    }
  }

  Future<Result<void>> updateClub(Club club) async {
    try {
      // toUpdateMap(), not toFirestore() -- the latter always stamps a
      // fresh createdAt, which would silently overwrite a club's real
      // creation date on every settings edit (same bug class this
      // session already fixed for CourseRepository/PublicCourseRepository).
      await _db.collection(AppConstants.colClubs).doc(club.id)
          .set(club.toUpdateMap(), SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update club', e);
    }
  }

  /// Founder or school staff only (mirrors firestore.rules' clubs delete
  /// rule) -- the club settings page is the only caller.
  Future<Result<void>> deleteClub(String clubId) async {
    try {
      await _db.collection(AppConstants.colClubs).doc(clubId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete club', e);
    }
  }

  // ── Feed (posts) ───────────────────────────────────────────
  // Replaces the old static "no announcements yet" placeholder tab with
  // a real, Firestore-backed feed. Mirrors firestore.rules'
  // clubs/{id}/posts/{id} shape (isOwner-or-staff write), which existed
  // before this repository code did.

  CollectionReference<Map<String, dynamic>> _posts(String clubId) => _db
      .collection(AppConstants.colClubs).doc(clubId).collection(AppConstants.colPosts);

  Stream<List<ClubPost>> watchPosts(String clubId) => _posts(clubId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => ClubPost.fromFirestore(d, clubId)).toList());

  Future<Result<void>> createPost(String clubId, ClubPost post) async {
    try {
      await _posts(clubId).add(post.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to publish post', e);
    }
  }

  Future<Result<void>> togglePostLike(String clubId, String postId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to like posts.', null);
    try {
      final likeRef = _posts(clubId).doc(postId).collection('likes').doc(userId);
      final exists = (await likeRef.get()).exists;
      if (exists) {
        await likeRef.delete();
        await _posts(clubId).doc(postId).update({'likeCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await _posts(clubId).doc(postId).update({'likeCount': FieldValue.increment(1)});
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  Stream<bool> watchIsPostLiked(String clubId, String postId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _posts(clubId).doc(postId).collection('likes').doc(userId).snapshots().map((d) => d.exists);
  }

  Stream<List<ClubPostComment>> watchPostComments(String clubId, String postId) => _posts(clubId)
      .doc(postId).collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ClubPostComment.fromFirestore).toList());

  Future<Result<void>> addPostComment(String clubId, String postId, ClubPostComment comment) async {
    try {
      final batch = _db.batch();
      batch.set(_posts(clubId).doc(postId).collection('comments').doc(), comment.toFirestore());
      batch.update(_posts(clubId).doc(postId), {'commentCount': FieldValue.increment(1)});
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add comment', e);
    }
  }

  // ── Discussions (Q&A with best-answer + XP) ─────────────────
  // See models/club.dart's ClubDiscussion/ClubDiscussionReply doc
  // comments for the shape. XP amounts (10 / 10 / 25) match the Physics
  // Society mockup exactly — see XpSource.clubQuestion/clubAnswer/
  // clubBestAnswer in models/xp_transaction.dart.

  CollectionReference<Map<String, dynamic>> _discussions(String clubId) => _db
      .collection(AppConstants.colClubs).doc(clubId).collection('discussions');

  Stream<List<ClubDiscussion>> watchDiscussions(String clubId) => _discussions(clubId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => ClubDiscussion.fromFirestore(d, clubId)).toList());

  Stream<ClubDiscussion?> watchDiscussion(String clubId, String discussionId) => _discussions(clubId)
      .doc(discussionId).snapshots()
      .map((d) => d.exists ? ClubDiscussion.fromFirestore(d, clubId) : null);

  Future<Result<String>> createDiscussion(String clubId, ClubDiscussion discussion) async {
    try {
      final ref = await _discussions(clubId).add(discussion.toFirestore());
      await XpRepository.instance.awardXp(discussion.authorId, XpSource.clubQuestion, XpSource.clubQuestion.baseXp, refId: ref.id);
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to post question', e);
    }
  }

  Future<void> incrementDiscussionView(String clubId, String discussionId) async {
    try {
      await _discussions(clubId).doc(discussionId).update({'viewCount': FieldValue.increment(1)});
    } catch (_) {
      // best-effort — a missed view count isn't worth surfacing
    }
  }

  Stream<List<ClubDiscussionReply>> watchReplies(String clubId, String discussionId) => _discussions(clubId)
      .doc(discussionId).collection('replies')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ClubDiscussionReply.fromFirestore).toList());

  Future<Result<void>> addReply(String clubId, String discussionId, ClubDiscussionReply reply) async {
    try {
      final batch = _db.batch();
      batch.set(_discussions(clubId).doc(discussionId).collection('replies').doc(), reply.toFirestore());
      batch.update(_discussions(clubId).doc(discussionId), {'replyCount': FieldValue.increment(1)});
      await batch.commit();
      await XpRepository.instance.awardXp(reply.authorId, XpSource.clubAnswer, XpSource.clubAnswer.baseXp, refId: discussionId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post reply', e);
    }
  }

  /// Only the discussion's own author or a club admin/moderator may mark
  /// a best answer (enforced in firestore.rules too). Awards the
  /// replying user a bonus on top of whatever they already got for
  /// posting the reply — moving the mark to a different reply first
  /// un-marks the old one so exactly one best answer (and one bonus
  /// payout) exists per discussion at a time.
  Future<Result<void>> markBestAnswer({
    required String clubId, required String discussionId,
    required String replyId, required String replyAuthorId,
    String? previousBestAnswerReplyId,
  }) async {
    try {
      final batch = _db.batch();
      batch.update(_discussions(clubId).doc(discussionId), {'bestAnswerReplyId': replyId});
      if (previousBestAnswerReplyId != null && previousBestAnswerReplyId != replyId) {
        batch.update(_discussions(clubId).doc(discussionId).collection('replies').doc(previousBestAnswerReplyId),
            {'isBestAnswer': false});
      }
      batch.update(_discussions(clubId).doc(discussionId).collection('replies').doc(replyId), {'isBestAnswer': true});
      await batch.commit();
      if (previousBestAnswerReplyId != replyId) {
        await XpRepository.instance.awardXp(replyAuthorId, XpSource.clubBestAnswer, XpSource.clubBestAnswer.baseXp, refId: replyId);
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to mark best answer', e);
    }
  }

  Future<Result<void>> toggleDiscussionLike(String clubId, String discussionId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to like discussions.', null);
    try {
      final likeRef = _discussions(clubId).doc(discussionId).collection('likes').doc(userId);
      final exists = (await likeRef.get()).exists;
      if (exists) {
        await likeRef.delete();
        await _discussions(clubId).doc(discussionId).update({'likeCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await _discussions(clubId).doc(discussionId).update({'likeCount': FieldValue.increment(1)});
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  Stream<bool> watchIsDiscussionLiked(String clubId, String discussionId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _discussions(clubId).doc(discussionId).collection('likes').doc(userId).snapshots().map((d) => d.exists);
  }

  // ── Resources ────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _resources(String clubId) => _db
      .collection(AppConstants.colClubs).doc(clubId).collection('resources');

  Stream<List<ClubResource>> watchResources(String clubId) => _resources(clubId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => ClubResource.fromFirestore(d, clubId)).toList());

  Future<Result<void>> addResource(String clubId, ClubResource resource) async {
    try {
      await _resources(clubId).add(resource.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add resource', e);
    }
  }

  Future<Result<String>> uploadResourceFile({required String clubId, required File file, required String fileName}) async {
    try {
      final ref = FirebaseStorage.instance.ref('club_resources/$clubId/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await ref.putFile(file).timeout(const Duration(minutes: 3), onTimeout: () => throw Exception(
          'Upload is taking too long. Check your connection and try again.'));
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload file', e);
    }
  }

  Future<Result<void>> deleteResource(String clubId, String resourceId) async {
    try {
      await _resources(clubId).doc(resourceId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete resource', e);
    }
  }

  // ── Events ───────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _events(String clubId) => _db
      .collection(AppConstants.colClubs).doc(clubId).collection(AppConstants.colEvents);

  Stream<List<ClubEvent>> watchEvents(String clubId) => _events(clubId)
      .orderBy('startAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ClubEvent.fromFirestore(d, clubId)).toList());

  Future<Result<void>> addEvent(String clubId, ClubEvent event) async {
    try {
      await _events(clubId).add(event.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add event', e);
    }
  }

  Future<Result<void>> deleteEvent(String clubId, String eventId) async {
    try {
      await _events(clubId).doc(eventId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete event', e);
    }
  }

  Future<Result<void>> toggleEventRsvp(String clubId, String eventId, String userId, bool going) async {
    if (userId.isEmpty) return const Failure('Sign in to RSVP.', null);
    try {
      final rsvpRef = _events(clubId).doc(eventId).collection('rsvps').doc(userId);
      if (going) {
        await rsvpRef.set({'rsvpAt': FieldValue.serverTimestamp()});
        await _events(clubId).doc(eventId).update({'rsvpCount': FieldValue.increment(1)});
      } else {
        await rsvpRef.delete();
        await _events(clubId).doc(eventId).update({'rsvpCount': FieldValue.increment(-1)});
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update RSVP', e);
    }
  }

  Stream<bool> watchIsGoingToEvent(String clubId, String eventId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _events(clubId).doc(eventId).collection('rsvps').doc(userId).snapshots().map((d) => d.exists);
  }
}

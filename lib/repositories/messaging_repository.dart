// lib/repositories/messaging_repository.dart
// Friend requests, friendships, conversations, and messages. Friendship
// (mutual, request-gated) is what unlocks messaging — Following
// (FollowRepository) is a completely separate, one-way relationship and
// grants no messaging rights on its own.
//
// ── 2024 remake changes ────────────────────────────────────────────────
// - watchConversations / watchMessages now emit a cached snapshot
//   immediately (via MessageCacheService) before the live Firestore
//   listener attaches, and write every live update back to the cache.
//   See message_cache_service.dart's file header for the reasoning.
// - pingActive(): a real (not faked) per-conversation "I have this
//   thread open right now" signal, built the exact same way setTyping()
//   already was — a cheap merged field write, no new collection.
// - unreadCount was declared on Conversation and read in the UI
//   (messages_home_page.dart's inbox badge) but never actually written
//   anywhere — sendMessage() didn't increment it and
//   markConversationRead() didn't reset it, so the badge was always 0.
//   Fixed in both places below.
// - sendMessage() gained `recipientId` (needed for the unreadCount fix
//   above — Firestore has no "every participant except the sender"
//   update) and `sharedThumbnailUrl` (denormalized alongside the
//   existing sharedTitle/sharedSubtitle, same treatment).

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/messaging.dart';
import '../models/app_user.dart';
import '../core/constants.dart';
import '../core/result.dart';
import '../services/message_cache_service.dart';

class MessagingRepository {
  MessagingRepository._();
  static final MessagingRepository instance = MessagingRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection(AppConstants.colFriendRequests);
  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection(AppConstants.colFriendships);
  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection(AppConstants.colConversations);

  /// Sorted pair so a friendship has exactly one canonical doc id
  /// regardless of who sent the original request.
  String _pairId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Friend requests ──────────────────────────────────────

  Future<Result<void>> sendFriendRequest({
    required String fromUserId,
    required String fromUserName,
    String? fromUserPhotoUrl,
    required String fromUserRoleLabel,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) return const Failure('You can\'t friend yourself', null);
    try {
      final alreadyFriends = await isFriend(fromUserId, toUserId);
      if (alreadyFriends) return const Failure('You\'re already friends', null);

      // Don't stack duplicate pending requests between the same pair.
      final existing = await _requests
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return const Failure('Request already sent', null);

      await _requests.add(FriendRequest(
        id: '', fromUserId: fromUserId, fromUserName: fromUserName,
        fromUserPhotoUrl: fromUserPhotoUrl, fromUserRoleLabel: fromUserRoleLabel,
        toUserId: toUserId, createdAt: DateTime.now(),
      ).toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send friend request', e);
    }
  }

  Stream<List<FriendRequest>> watchIncomingRequests(String userId) => _requests
      .where('toUserId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FriendRequest.fromFirestore).toList());

  Stream<int> watchIncomingRequestCount(String userId) =>
      watchIncomingRequests(userId).map((list) => list.length);

  Future<Result<void>> acceptRequest(FriendRequest request, String myName, String? myPhotoUrl) async {
    try {
      final batch = _db.batch();
      batch.update(_requests.doc(request.id), {'status': 'accepted'});
      final pairId = _pairId(request.fromUserId, request.toUserId);
      batch.set(_friendships.doc(pairId), {
        'userIds': [request.fromUserId, request.toUserId],
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to accept request', e);
    }
  }

  Future<Result<void>> declineRequest(String requestId) async {
    try {
      await _requests.doc(requestId).update({'status': 'declined'});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to decline request', e);
    }
  }

  // ── Friendships ──────────────────────────────────────────

  Future<bool> isFriend(String userId, String otherId) async {
    final doc = await _friendships.doc(_pairId(userId, otherId)).get();
    return doc.exists;
  }

  Stream<bool> watchIsFriend(String userId, String otherId) => _friendships
      .doc(_pairId(userId, otherId))
      .snapshots()
      .map((d) => d.exists);

  Stream<int> watchFriendCount(String userId) => _friendships
      .where('userIds', arrayContains: userId)
      .snapshots()
      .map((s) => s.docs.length);

  /// IDs of everyone [userId] is mutually friends with.
  Stream<List<String>> watchFriendIds(String userId) => _friendships
      .where('userIds', arrayContains: userId)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final ids = List<String>.from(d.data()['userIds'] ?? []);
            return ids.firstWhere((id) => id != userId, orElse: () => '');
          }).where((id) => id.isNotEmpty).toList());

  /// Full profiles behind [watchFriendIds] — powers the "My Friends" list.
  /// Firestore `whereIn` caps at 30, so this chunks for the rare user with
  /// more friends than that.
  Stream<List<AppUser>> watchFriends(String userId) => watchFriendIds(userId).asyncMap((ids) async {
        if (ids.isEmpty) return <AppUser>[];
        final users = <AppUser>[];
        for (var i = 0; i < ids.length; i += 30) {
          final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
          final snap = await _db
              .collection(AppConstants.colUsers)
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          users.addAll(snap.docs.map((d) => AppUser.fromFirestore(d.id, d.data())));
        }
        return users;
      });

  /// Same-school users [user] isn't already friends with or hasn't
  /// already sent a pending request to. Purely schoolId-based since
  /// there's no recommendation engine here — users with no schoolId
  /// (independent layer) get no suggestions rather than a fabricated list.
  Future<List<AppUser>> suggestedFriends(AppUser user, {int limit = 20}) async {
    if (user.schoolId == null || user.schoolId!.isEmpty) return [];
    final friendIds = await _friendships
        .where('userIds', arrayContains: user.id)
        .get()
        .then((s) => s.docs.map((d) {
              final ids = List<String>.from(d.data()['userIds'] ?? []);
              return ids.firstWhere((id) => id != user.id, orElse: () => '');
            }).where((id) => id.isNotEmpty).toSet());
    final pendingOutgoing = await _requests
        .where('fromUserId', isEqualTo: user.id)
        .where('status', isEqualTo: 'pending')
        .get()
        .then((s) => s.docs.map((d) => d.data()['toUserId'] as String).toSet());
    final exclude = {user.id, ...friendIds, ...pendingOutgoing};
    final snap = await _db
        .collection(AppConstants.colUsers)
        .where('schoolId', isEqualTo: user.schoolId)
        .limit(limit + exclude.length)
        .get();
    return snap.docs
        .where((d) => !exclude.contains(d.id))
        .take(limit)
        .map((d) => AppUser.fromFirestore(d.id, d.data()))
        .toList();
  }

  // ── Conversations ────────────────────────────────────────

  /// Finds the existing 1:1 conversation between two people, or creates
  /// one. Requires friendship — call sites should already have gated on
  /// watchIsFriend before reaching here, but this double-checks.
  Future<Result<String>> getOrCreateConversation({
    required String userAId, required String userAName, String? userAPhoto,
    required String userBId, required String userBName, String? userBPhoto,
  }) async {
    try {
      if (!await isFriend(userAId, userBId)) {
        return const Failure('You need to be friends to message each other', null);
      }
      final existing = await _conversations
          .where('participantIds', arrayContains: userAId)
          .get();
      for (final doc in existing.docs) {
        final ids = List<String>.from(doc.data()['participantIds'] ?? []);
        if (ids.contains(userBId) && ids.length == 2) {
          return Success(doc.id);
        }
      }
      final ref = await _conversations.add(Conversation(
        id: '',
        participantIds: [userAId, userBId],
        participantNames: {userAId: userAName, userBId: userBName},
        participantPhotos: {userAId: userAPhoto, userBId: userBPhoto},
        lastMessageAt: DateTime.now(),
      ).toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to open conversation', e);
    }
  }

  /// Recency-sorted conversations for [userId]. Emits a cached snapshot
  /// first (if one exists on disk from a previous session) so the inbox
  /// paints instantly instead of sitting blank until the first Firestore
  /// snapshot arrives, then switches to — and stays on — the live
  /// stream. Every live update is written back to the cache so the next
  /// cold start has fresher data to paint. See message_cache_service.dart.
  Stream<List<Conversation>> watchConversations(String userId) {
    late final StreamController<List<Conversation>> controller;
    StreamSubscription<List<Conversation>>? liveSub;

    controller = StreamController<List<Conversation>>(
      onListen: () {
        MessageCacheService.instance.getConversations(userId).then((cached) {
          if (cached.isNotEmpty && !controller.isClosed) controller.add(cached);
        });
        liveSub = _conversations
            .where('participantIds', arrayContains: userId)
            .orderBy('lastMessageAt', descending: true)
            .snapshots()
            .map((s) => s.docs.map(Conversation.fromFirestore).toList())
            .listen(
              (live) {
                if (controller.isClosed) return;
                controller.add(live);
                unawaited(MessageCacheService.instance.putConversations(userId, live));
              },
              onError: (Object e, StackTrace st) {
                if (!controller.isClosed) controller.addError(e, st);
              },
            );
      },
      onCancel: () async {
        await liveSub?.cancel();
        if (!controller.isClosed) await controller.close();
      },
    );
    return controller.stream;
  }

  /// Single conversation doc — backs the typing indicator, the
  /// per-conversation presence dot, and anything else the chat screen
  /// needs from the conversation itself rather than its message
  /// subcollection.
  Stream<Conversation?> watchConversation(String conversationId) => _conversations
      .doc(conversationId)
      .snapshots()
      .map((d) => d.exists ? Conversation.fromFirestore(d) : null);

  /// Records that [userId] is actively typing in [conversationId]. Call
  /// sites should throttle this (e.g. at most once every couple seconds
  /// per keystroke burst) — it's one small field write, not a message.
  /// There's no matching "stopped typing" call: readers treat any
  /// timestamp older than a few seconds as stale (see Conversation.typingAt).
  Future<void> setTyping(String conversationId, String userId) async {
    try {
      await _conversations.doc(conversationId)
          .set({'typingAt': {userId: FieldValue.serverTimestamp()}}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort — a missed typing ping is invisible, not worth surfacing
    }
  }

  /// Records that [userId] currently has [conversationId]'s screen open.
  /// Call sites should ping this on open and on a slow interval (e.g.
  /// every 45-60s) while the screen stays mounted — see
  /// Conversation.activeAt / isRecentlyActive for how readers interpret
  /// it, and this file's header comment for why this is real presence
  /// rather than a faked global "online" flag.
  Future<void> pingActive(String conversationId, String userId) async {
    try {
      await _conversations.doc(conversationId)
          .set({'activeAt': {userId: FieldValue.serverTimestamp()}}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort — same reasoning as setTyping
    }
  }

  /// Live message stream, most-recent [limit] messages. Emits a cached
  /// snapshot first (see watchConversations doc comment — same pattern,
  /// same reasoning) so reopening a conversation shows the last-known
  /// messages immediately instead of a loading spinner, then the live
  /// window takes over. `limitToLast` + ascending order keeps the query
  /// index-free (a single-field orderBy) while bounding what's fetched
  /// to a recent window.
  Stream<List<ChatMessage>> watchMessages(String conversationId, {int limit = 60}) {
    late final StreamController<List<ChatMessage>> controller;
    StreamSubscription<List<ChatMessage>>? liveSub;

    controller = StreamController<List<ChatMessage>>(
      onListen: () {
        MessageCacheService.instance.getMessages(conversationId).then((cached) {
          if (cached.isNotEmpty && !controller.isClosed) controller.add(cached);
        });
        liveSub = _conversations
            .doc(conversationId)
            .collection(AppConstants.colMessages)
            .orderBy('sentAt')
            .limitToLast(limit)
            .snapshots()
            .map((s) => s.docs.map((d) => ChatMessage.fromFirestore(d, conversationId)).toList())
            .listen(
              (live) {
                if (controller.isClosed) return;
                controller.add(live);
                unawaited(MessageCacheService.instance.putMessages(conversationId, live));
              },
              onError: (Object e, StackTrace st) {
                if (!controller.isClosed) controller.addError(e, st);
              },
            );
      },
      onCancel: () async {
        await liveSub?.cancel();
        if (!controller.isClosed) await controller.close();
      },
    );
    return controller.stream;
  }

  Future<Result<void>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    /// The other participant — used only to increment their unread
    /// counter (Firestore has no "increment for everyone except X"
    /// update). Optional so this stays source-compatible with any other
    /// call site; unreadCount simply won't advance without it.
    String? recipientId,
    String text = '',
    String? imageUrl,
    String? videoUrl,
    String? fileUrl,
    String? fileName,
    SharedContentType? sharedType,
    String? sharedId,
    String? sharedTitle,
    String? sharedSubtitle,
    String? sharedThumbnailUrl,
  }) async {
    try {
      final batch = _db.batch();
      final msgRef = _conversations.doc(conversationId).collection(AppConstants.colMessages).doc();
      batch.set(msgRef, ChatMessage(
        id: '', conversationId: conversationId, senderId: senderId, senderName: senderName,
        text: text, imageUrl: imageUrl, videoUrl: videoUrl, fileUrl: fileUrl, fileName: fileName,
        sentAt: DateTime.now(), readBy: [senderId],
        sharedType: sharedType, sharedId: sharedId, sharedTitle: sharedTitle,
        sharedSubtitle: sharedSubtitle, sharedThumbnailUrl: sharedThumbnailUrl,
      ).toFirestore());

      final preview = text.isNotEmpty ? text
          : (imageUrl != null ? '📷 Photo'
          : (videoUrl != null ? '🎥 Video'
          : (fileUrl != null ? '📎 ${fileName ?? "File"}'
          : (sharedType != null ? '${_sharedContentEmoji(sharedType)} ${sharedTitle ?? sharedType.label}' : ''))));
      final convUpdate = <String, dynamic>{
        'lastMessageText': preview,
        'lastMessageSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
      };
      // See file header — unreadCount was previously never written.
      if (recipientId != null && recipientId.isNotEmpty) {
        convUpdate['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
      batch.update(_conversations.doc(conversationId), convUpdate);
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send message', e);
    }
  }

  String _sharedContentEmoji(SharedContentType t) => switch (t) {
        SharedContentType.note => '📝',
        SharedContentType.course => '🎓',
        SharedContentType.quiz => '❓',
        SharedContentType.article => '📰',
        SharedContentType.pastPaper => '📄',
      };

  /// Toggles [userId]'s personal "pin to top" on a conversation — a view
  /// preference (see Conversation.pinnedBy), not something the other
  /// participant sees or is affected by.
  Future<Result<void>> togglePinned(String conversationId, String userId, bool pinned) async {
    try {
      await _conversations.doc(conversationId).update({
        'pinnedBy': pinned ? FieldValue.arrayUnion([userId]) : FieldValue.arrayRemove([userId]),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update pin', e);
    }
  }

  Future<Result<String>> uploadChatMedia({
    required String conversationId,
    required File file,
    required bool isVideo,
    void Function(double)? onProgress,
  }) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final ref = FirebaseStorage.instance
        .ref('chat_media/$conversationId/${DateTime.now().millisecondsSinceEpoch}.$ext');
    return _uploadWithRetry(ref, file, onProgress);
  }

  /// General file attachments — any type (PDF, docx, etc.), not just
  /// photo/video. Keeps the original filename in Storage so it downloads
  /// with a sensible name rather than a bare timestamp.
  Future<Result<String>> uploadChatFile({
    required String conversationId,
    required File file,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    final ref = FirebaseStorage.instance
        .ref('chat_files/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$fileName');
    return _uploadWithRetry(ref, file, onProgress);
  }

  /// Shared upload path for chat attachments: reports real progress via
  /// [onProgress] (UploadTask.snapshotEvents), times out instead of
  /// hanging forever on a dead connection, and retries once on failure —
  /// slow/flaky mobile connections were previously either a silent hang
  /// or a one-shot failure with no automatic recovery.
  Future<Result<String>> _uploadWithRetry(
    Reference ref,
    File file,
    void Function(double)? onProgress, {
    int attempt = 1,
  }) async {
    try {
      final task = ref.putFile(file);
      final sub = task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress?.call(snap.bytesTransferred / snap.totalBytes);
        }
      });
      final snapshot = await task.timeout(const Duration(minutes: 5));
      await sub.cancel();
      return Success(await snapshot.ref.getDownloadURL());
    } catch (e) {
      if (attempt < 2) {
        onProgress?.call(0);
        return _uploadWithRetry(ref, file, onProgress, attempt: attempt + 1);
      }
      return Failure('Upload failed — check your connection and try again', e);
    }
  }

  /// Soft-deletes one of the caller's own messages: clears the content,
  /// flips `deleted`, keeps the doc (sender/timestamp) so the thread shows
  /// a "message deleted" placeholder instead of a confusing gap. Only the
  /// sender can do this — enforced both here and in firestore.rules.
  Future<Result<void>> deleteMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final ref = _conversations.doc(conversationId).collection(AppConstants.colMessages).doc(messageId);
      final doc = await ref.get();
      if (!doc.exists || doc.data()?['senderId'] != userId) {
        return const Failure('You can only delete your own messages', null);
      }
      await ref.update({
        'deleted': true,
        'text': '',
        'imageUrl': null,
        'videoUrl': null,
        'fileUrl': null,
        'fileName': null,
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete message', e);
    }
  }

  /// Marks every message not yet read by [userId] as read — called on
  /// opening a conversation. Fetches recent messages and filters
  /// client-side (Firestore can't query "array doesn't contain X"
  /// directly) — fine for normal conversation lengths; revisit with a
  /// denormalized unread-count field if history grows very large.
  ///
  /// Also resets [userId]'s entry in `unreadCount` to 0 — always, even
  /// if there was nothing to update in `readBy` above, since the two are
  /// otherwise independent writes and a stale badge is worse than one
  /// extra cheap field update.
  Future<void> markConversationRead(String conversationId, String userId) async {
    try {
      final recent = await _conversations
          .doc(conversationId)
          .collection(AppConstants.colMessages)
          .orderBy('sentAt', descending: true)
          .limit(100)
          .get();
      final toUpdate = recent.docs.where((d) {
        final readBy = List<String>.from(d.data()['readBy'] ?? []);
        return !readBy.contains(userId);
      });
      final batch = _db.batch();
      for (final doc in toUpdate) {
        batch.update(doc.reference, {'readBy': FieldValue.arrayUnion([userId])});
      }
      batch.update(_conversations.doc(conversationId), {'unreadCount.$userId': 0});
      await batch.commit();
    } catch (_) {
      // best-effort — a failed read-receipt update shouldn't block the UI
    }
  }

  /// Simple name-prefix search across users — powers "Find People".
  /// Firestore doesn't do substring search natively; this does a
  /// prefix-range query on a lowercase name field. Requires user docs to
  /// have a `nameLower` field maintained alongside `name` — if that
  /// field doesn't exist yet on existing users, this returns nothing for
  /// them until they next update their profile. Flagging as a follow-up
  /// rather than silently returning incomplete results forever.
  Future<List<Map<String, dynamic>>> searchUsers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final snap = await _db
        .collection(AppConstants.colUsers)
        .orderBy('nameLower')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(limit)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}

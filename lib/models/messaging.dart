// lib/models/messaging.dart
// Backs the Messages feature. Two genuinely separate relationship
// systems, per the design conversation:
//   - Follow (FollowRepository, follows collection) — one-way, no
//     approval, just "notify me when they publish."
//   - Friends (this file) — mutual, gated by an explicit request +
//     accept, and it's friendship (not following) that unlocks 1:1
//     messaging.
//
// Firestore:
//   friend_requests/{id}              — one doc per pending/resolved request
//   friendships/{uidA_uidB}           — sorted-pair doc id, existence == friends
//   conversations/{id}                — one per friend pair (or future group chat)
//   conversations/{id}/messages/{id}  — the actual messages
//
// ── 2024 remake additions ──────────────────────────────────────────────
// 1. Cache-safe (de)serialization (`toCacheJson`/`fromCacheJson`) so
//    MessageCacheService can persist conversations/messages to disk
//    (SharedPreferences) between app launches. This is a PARALLEL
//    representation to `toFirestore`/`fromFirestore`, not a replacement:
//    Firestore keeps using Timestamp, the cache uses plain epoch-ms ints
//    so it round-trips through JSON without a Firestore dependency.
// 2. `activeAt` on Conversation — a real (not faked) "has this person
//    had this specific chat open in the last couple minutes" signal,
//    built the exact same way `typingAt` already was: a cheap merged
//    field write, no new collection, no realtime-presence
//    infrastructure. This deliberately stays OUT of the cache
//    serialization below — a stale "online" reading from yesterday's
//    cache would be actively misleading, which is worse than showing
//    nothing while the live stream reconnects.
// 3. `sharedThumbnailUrl` on ChatMessage — Course/Note/Article shares
//    already denormalize a title+subtitle onto the message at send
//    time; this adds the same treatment for the content's cover image
//    so the shared-content card can show a real thumbnail instead of
//    just a generic icon tile.

import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus { pending, accepted, declined }

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String? fromUserPhotoUrl;
  final String fromUserRoleLabel; // e.g. "Student at St. Joseph's College"
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserPhotoUrl,
    required this.fromUserRoleLabel,
    required this.toUserId,
    this.status = FriendRequestStatus.pending,
    required this.createdAt,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FriendRequest(
      id: doc.id,
      fromUserId: d['fromUserId'] ?? '',
      fromUserName: d['fromUserName'] ?? 'Unknown',
      fromUserPhotoUrl: d['fromUserPhotoUrl'],
      fromUserRoleLabel: d['fromUserRoleLabel'] ?? '',
      toUserId: d['toUserId'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => FriendRequestStatus.pending),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'fromUserPhotoUrl': fromUserPhotoUrl,
        'fromUserRoleLabel': fromUserRoleLabel,
        'toUserId': toUserId,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// A conversation between exactly two people (group chat is a future
/// extension, not built here — participantIds is a list to leave room
/// for that without a model change later).
class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String lastMessageText;
  final String? lastMessageSenderId;
  final DateTime lastMessageAt;
  final Map<String, int> unreadCount; // per participant

  /// userId -> last time they typed a keystroke in this conversation.
  /// No explicit "stopped typing" write — the UI treats an entry older
  /// than a few seconds as no-longer-typing, so this stays a single cheap
  /// field on the existing conversation doc rather than a new collection
  /// or a steady stream of "stopped" writes.
  final Map<String, DateTime> typingAt;

  /// userId -> last time that user had this conversation's screen open.
  /// Same mechanism as [typingAt] (a merged field write, no new
  /// collection), read the same way (anything older than a couple
  /// minutes is stale). This is real, scoped presence — "were they
  /// looking at this thread recently" — not a faked always-on global
  /// "online" dot, which is why it lives per-conversation instead of on
  /// the user profile.
  final Map<String, DateTime> activeAt;

  /// Per-user "pin to top" — a personal view preference (mirrors the
  /// mockup's Pinned/Recent split), not a shared conversation property,
  /// so it's a list of user ids rather than a single bool.
  final List<String> pinnedBy;

  const Conversation({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantPhotos,
    this.lastMessageText = '',
    this.lastMessageSenderId,
    required this.lastMessageAt,
    this.unreadCount = const {},
    this.typingAt = const {},
    this.activeAt = const {},
    this.pinnedBy = const [],
  });

  factory Conversation.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final typing = <String, DateTime>{};
    (d['typingAt'] as Map<String, dynamic>? ?? {}).forEach((uid, ts) {
      if (ts is Timestamp) typing[uid] = ts.toDate();
    });
    final active = <String, DateTime>{};
    (d['activeAt'] as Map<String, dynamic>? ?? {}).forEach((uid, ts) {
      if (ts is Timestamp) active[uid] = ts.toDate();
    });
    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(d['participantIds'] ?? []),
      participantNames: Map<String, String>.from(d['participantNames'] ?? {}),
      participantPhotos: Map<String, String?>.from(d['participantPhotos'] ?? {}),
      lastMessageText: d['lastMessageText'] ?? '',
      lastMessageSenderId: d['lastMessageSenderId'],
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(d['unreadCount'] ?? {}),
      typingAt: typing,
      activeAt: active,
      pinnedBy: List<String>.from(d['pinnedBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'participantIds': participantIds,
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'lastMessageText': lastMessageText,
        'lastMessageSenderId': lastMessageSenderId,
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
        'unreadCount': unreadCount,
        'pinnedBy': pinnedBy,
      };

  String otherParticipantId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => '');

  /// True if [userId] had this specific thread open within the last two
  /// minutes. See [activeAt] doc comment for why this is real rather
  /// than faked, and why it's scoped to the conversation.
  bool isRecentlyActive(String userId) {
    final at = activeAt[userId];
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(minutes: 2);
  }

  // ── Local disk cache (SharedPreferences via MessageCacheService) ──────
  // Deliberately excludes typingAt/activeAt — see file header. Epoch-ms
  // ints instead of Timestamp so this survives a plain jsonEncode/decode
  // round trip with zero Firestore dependency.

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'participantIds': participantIds,
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'lastMessageText': lastMessageText,
        'lastMessageSenderId': lastMessageSenderId,
        'lastMessageAtMs': lastMessageAt.millisecondsSinceEpoch,
        'unreadCount': unreadCount,
        'pinnedBy': pinnedBy,
      };

  factory Conversation.fromCacheJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        participantIds: List<String>.from(j['participantIds'] ?? const []),
        participantNames: Map<String, String>.from(j['participantNames'] ?? const {}),
        participantPhotos: Map<String, String?>.from(j['participantPhotos'] ?? const {}),
        lastMessageText: j['lastMessageText'] ?? '',
        lastMessageSenderId: j['lastMessageSenderId'],
        lastMessageAt: DateTime.fromMillisecondsSinceEpoch(
            (j['lastMessageAtMs'] as num?)?.toInt() ?? 0),
        unreadCount: Map<String, int>.from(j['unreadCount'] ?? const {}),
        pinnedBy: List<String>.from(j['pinnedBy'] ?? const []),
      );
}

/// What kind of real Academia content a shared-content message points at.
/// note/pastPaper both resolve to real AcademicContent items (ContentType
/// .note / .pastPaper) — added once that content type existed with real
/// pricing (production_plan.md §4.6/§4.7), matching the Messaging
/// mockup's full five-icon attach row (Note/Course/Quiz/Article/Past Paper).
enum SharedContentType { note, course, quiz, article, pastPaper }

extension SharedContentTypeExt on SharedContentType {
  String get label => switch (this) {
        SharedContentType.note => 'Note',
        SharedContentType.course => 'Course',
        SharedContentType.quiz => 'Quiz',
        SharedContentType.article => 'Article',
        SharedContentType.pastPaper => 'Past Paper',
      };

  static SharedContentType? fromKey(String? key) {
    if (key == null) return null;
    for (final t in SharedContentType.values) {
      if (t.name == key) return t;
    }
    return null;
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final String? videoUrl;
  final String? fileUrl;
  final String? fileName;
  final DateTime sentAt;
  final List<String> readBy;
  final bool deleted;

  /// Shared-content attachment (Course/Quiz/Article) — see
  /// [SharedContentType]. Type/id/title/subtitle are set together or not
  /// at all; thumbnail is best-effort (some content, e.g. a Quiz, has no
  /// cover image) so it stays independently nullable.
  final SharedContentType? sharedType;
  final String? sharedId;
  final String? sharedTitle;
  final String? sharedSubtitle;
  final String? sharedThumbnailUrl;

  /// True while this message only exists in Firestore's LOCAL write
  /// cache and hasn't been acknowledged by the server yet — sourced
  /// from `DocumentSnapshot.metadata.hasPendingWrites`, not stored in
  /// Firestore itself (there's no field for it; it's per-read metadata).
  /// This is what actually powers the chat bubble's "sending…" clock
  /// instead of a hand-rolled optimistic-message list: Firestore's own
  /// listener already reflects a just-sent message instantly from local
  /// cache, before the server round-trip completes, for exactly the
  /// live-query pattern MessagingRepository.watchMessages uses — this
  /// field just surfaces that existing signal to the UI. Always false
  /// for a message loaded from the local disk cache (MessageCacheService)
  /// or reconstructed via [fromCacheJson], since "pending" is only ever
  /// true in the instant after sending within the same live session.
  final bool isPending;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.text = '',
    this.imageUrl,
    this.videoUrl,
    this.fileUrl,
    this.fileName,
    required this.sentAt,
    this.readBy = const [],
    this.deleted = false,
    this.sharedType,
    this.sharedId,
    this.sharedTitle,
    this.sharedSubtitle,
    this.sharedThumbnailUrl,
    this.isPending = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, String conversationId) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      conversationId: conversationId,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? '',
      text: d['text'] ?? '',
      imageUrl: d['imageUrl'],
      videoUrl: d['videoUrl'],
      fileUrl: d['fileUrl'],
      fileName: d['fileName'],
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(d['readBy'] ?? []),
      deleted: d['deleted'] ?? false,
      sharedType: SharedContentTypeExt.fromKey(d['sharedType']),
      sharedId: d['sharedId'],
      sharedTitle: d['sharedTitle'],
      sharedSubtitle: d['sharedSubtitle'],
      sharedThumbnailUrl: d['sharedThumbnailUrl'],
      isPending: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'sentAt': Timestamp.fromDate(sentAt),
        'readBy': readBy,
        'sharedType': sharedType?.name,
        'sharedId': sharedId,
        'sharedTitle': sharedTitle,
        'sharedSubtitle': sharedSubtitle,
        'sharedThumbnailUrl': sharedThumbnailUrl,
      };

  // ── Local disk cache ───────────────────────────────────────────────
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'sentAtMs': sentAt.millisecondsSinceEpoch,
        'readBy': readBy,
        'deleted': deleted,
        'sharedType': sharedType?.name,
        'sharedId': sharedId,
        'sharedTitle': sharedTitle,
        'sharedSubtitle': sharedSubtitle,
        'sharedThumbnailUrl': sharedThumbnailUrl,
      };

  factory ChatMessage.fromCacheJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] ?? '',
        senderName: j['senderName'] ?? '',
        text: j['text'] ?? '',
        imageUrl: j['imageUrl'],
        videoUrl: j['videoUrl'],
        fileUrl: j['fileUrl'],
        fileName: j['fileName'],
        sentAt: DateTime.fromMillisecondsSinceEpoch((j['sentAtMs'] as num?)?.toInt() ?? 0),
        readBy: List<String>.from(j['readBy'] ?? const []),
        deleted: j['deleted'] ?? false,
        sharedType: SharedContentTypeExt.fromKey(j['sharedType']),
        sharedId: j['sharedId'],
        sharedTitle: j['sharedTitle'],
        sharedSubtitle: j['sharedSubtitle'],
        sharedThumbnailUrl: j['sharedThumbnailUrl'],
      );
}

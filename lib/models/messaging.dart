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

  factory FriendRequest.fromSupabase(Map<String, dynamic> d) {
    return FriendRequest(
      id: d['id'] as String,
      fromUserId: d['from_user_id'] ?? '',
      fromUserName: d['from_user_name'] ?? 'Unknown',
      fromUserPhotoUrl: d['from_user_photo_url'],
      fromUserRoleLabel: d['from_user_role_label'] ?? '',
      toUserId: d['to_user_id'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => FriendRequestStatus.pending),
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() => {
        'from_user_id': fromUserId,
        'from_user_name': fromUserName,
        'from_user_photo_url': fromUserPhotoUrl,
        'from_user_role_label': fromUserRoleLabel,
        'to_user_id': toUserId,
        'status': status.name,
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
  /// Same mechanism as [typingAt] (a merged field write, no new table),
  /// read the same way (anything older than a couple minutes is stale).
  /// This is real, scoped presence — "were they looking at this thread
  /// recently" — not a faked always-on global "online" dot, which is why
  /// it lives per-conversation instead of on the user profile.
  final Map<String, DateTime> activeAt;

  /// Per-user "pin to top" — a personal view preference, not a shared
  /// conversation property, so it's a list of user ids rather than a
  /// single bool.
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

  factory Conversation.fromSupabase(Map<String, dynamic> d) {
    final typing = <String, DateTime>{};
    (d['typing_at'] as Map<String, dynamic>? ?? {}).forEach((uid, ts) {
      final parsed = DateTime.tryParse(ts?.toString() ?? '');
      if (parsed != null) typing[uid] = parsed;
    });
    final active = <String, DateTime>{};
    (d['active_at'] as Map<String, dynamic>? ?? {}).forEach((uid, ts) {
      final parsed = DateTime.tryParse(ts?.toString() ?? '');
      if (parsed != null) active[uid] = parsed;
    });
    return Conversation(
      id: d['id'] as String,
      participantIds: List<String>.from(d['participant_ids'] ?? []),
      participantNames: Map<String, String>.from(d['participant_names'] ?? {}),
      participantPhotos: Map<String, String?>.from(d['participant_photos'] ?? {}),
      lastMessageText: d['last_message_text'] ?? '',
      lastMessageSenderId: d['last_message_sender_id'],
      lastMessageAt: DateTime.tryParse(d['last_message_at']?.toString() ?? '') ?? DateTime.now(),
      unreadCount: Map<String, int>.from(d['unread_count'] ?? {}),
      typingAt: typing,
      activeAt: active,
      pinnedBy: List<String>.from(d['pinned_by'] ?? []),
    );
  }

  Map<String, dynamic> toSupabase() => {
        'participant_ids': participantIds,
        'participant_names': participantNames,
        'participant_photos': participantPhotos,
        'last_message_text': lastMessageText,
        'last_message_sender_id': lastMessageSenderId,
        'last_message_at': lastMessageAt.toIso8601String(),
        'unread_count': unreadCount,
        'pinned_by': pinnedBy,
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
  // Deliberately excludes typingAt/activeAt — a stale "online" reading
  // from yesterday's cache would be actively misleading, worse than
  // showing nothing while the live stream reconnects. Epoch-ms ints
  // instead of ISO strings so this survives a plain jsonEncode/decode
  // round trip with zero backend dependency.

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
enum SharedContentType { note, course, quiz, article, pastPaper, clubPost, authorProfile }

extension SharedContentTypeExt on SharedContentType {
  String get label => switch (this) {
        SharedContentType.note => 'Note',
        SharedContentType.course => 'Course',
        SharedContentType.quiz => 'Quiz',
        SharedContentType.article => 'Article',
        SharedContentType.pastPaper => 'Past Paper',
        SharedContentType.clubPost => 'Club Post',
        SharedContentType.authorProfile => 'Author Profile',
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

  /// Shared-content attachment (Course/Quiz/Article/Note/Past Paper).
  /// Type/id/title/subtitle are set together or not at all; thumbnail is
  /// best-effort (some content, e.g. a Quiz, has no cover image) so it
  /// stays independently nullable.
  final SharedContentType? sharedType;
  final String? sharedId;
  final String? sharedTitle;
  final String? sharedSubtitle;
  final String? sharedThumbnailUrl;

  /// True while this message only exists in the client's local optimistic
  /// state and hasn't been acknowledged by the server yet. Always false
  /// for a message loaded from Supabase or the local disk cache
  /// (MessageCacheService) — "pending" only ever applies in the instant
  /// after sending within the same live session; see
  /// MessagingRepository.sendMessage for where this actually gets set.
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

  factory ChatMessage.fromSupabase(Map<String, dynamic> d) {
    return ChatMessage(
      id: d['id'] as String,
      conversationId: d['conversation_id'] as String,
      senderId: d['sender_id'] ?? '',
      senderName: d['sender_name'] ?? '',
      text: d['body'] ?? '',
      imageUrl: d['image_url'],
      videoUrl: d['video_url'],
      fileUrl: d['file_url'],
      fileName: d['file_name'],
      sentAt: DateTime.tryParse(d['sent_at']?.toString() ?? '') ?? DateTime.now(),
      readBy: List<String>.from(d['read_by'] ?? []),
      deleted: d['deleted'] ?? false,
      sharedType: SharedContentTypeExt.fromKey(d['shared_type']),
      sharedId: d['shared_id'],
      sharedTitle: d['shared_title'],
      sharedSubtitle: d['shared_subtitle'],
      sharedThumbnailUrl: d['shared_thumbnail_url'],
    );
  }

  Map<String, dynamic> toSupabase() => {
        'sender_id': senderId,
        'sender_name': senderName,
        'body': text,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'file_url': fileUrl,
        'file_name': fileName,
        'sent_at': sentAt.toIso8601String(),
        'read_by': readBy,
        'deleted': deleted,
        'shared_type': sharedType?.name,
        'shared_id': sharedId,
        'shared_title': sharedTitle,
        'shared_subtitle': sharedSubtitle,
        'shared_thumbnail_url': sharedThumbnailUrl,
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

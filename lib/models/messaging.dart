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
  });

  factory Conversation.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final typing = <String, DateTime>{};
    (d['typingAt'] as Map<String, dynamic>? ?? {}).forEach((uid, ts) {
      if (ts is Timestamp) typing[uid] = ts.toDate();
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
      };

  String otherParticipantId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => '');
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
      };
}

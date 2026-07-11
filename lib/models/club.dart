// lib/models/club.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ClubRole { visitor, member, moderator, admin }

class Club {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String moderatorName;
  final String moderatorId;
  final String category;
  final String? bannerUrl;
  final int memberCount;
  final String? schoolId;
  final bool requiresApproval;

  const Club({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.moderatorName,
    required this.moderatorId,
    this.category = 'General',
    this.bannerUrl,
    this.memberCount = 0,
    this.schoolId,
    this.requiresApproval = false,
  });

  factory Club.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Club(
      id: doc.id,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '🎓',
      description: d['description'] ?? '',
      moderatorName: d['moderatorName'] ?? '',
      moderatorId: d['moderatorId'] ?? '',
      category: d['category'] ?? 'General',
      bannerUrl: d['bannerUrl'],
      memberCount: (d['memberCount'] as num?)?.toInt() ?? 0,
      schoolId: d['schoolId'],
      requiresApproval: d['requiresApproval'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'emoji': emoji,
    'description': description,
    'moderatorName': moderatorName,
    'moderatorId': moderatorId,
    'category': category,
    'bannerUrl': bannerUrl,
    'memberCount': memberCount,
    'schoolId': schoolId,
    'requiresApproval': requiresApproval,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

enum ClubJoinRequestStatus { pending, approved, declined }

/// A pending request to join an approval-gated club. Only created when
/// Club.requiresApproval is true — open clubs skip this entirely and go
/// straight to ClubRepository.joinClub().
class ClubJoinRequest {
  final String id;
  final String clubId;
  final String clubName;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final ClubJoinRequestStatus status;
  final DateTime createdAt;

  const ClubJoinRequest({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.status = ClubJoinRequestStatus.pending,
    required this.createdAt,
  });

  factory ClubJoinRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubJoinRequest(
      id: doc.id,
      clubId: d['clubId'] ?? '',
      clubName: d['clubName'] ?? '',
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      userPhotoUrl: d['userPhotoUrl'],
      status: ClubJoinRequestStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => ClubJoinRequestStatus.pending),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'clubId': clubId,
    'clubName': clubName,
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class ClubMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderInitials;
  final String text;
  final DateTime time;

  const ClubMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderInitials,
    required this.text,
    required this.time,
  });

  factory ClubMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubMessage(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? '',
      senderInitials: d['senderInitials'] ?? '',
      text: d['text'] ?? '',
      time: (d['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'senderId': senderId,
    'senderName': senderName,
    'senderInitials': senderInitials,
    'text': text,
    'time': Timestamp.fromDate(time),
  };
}

/// One row in a club's member-management list. Stored at
/// clubs/{clubId}/members/{userId} alongside the role.
class ClubMember {
  final String userId;
  final String name;
  final String? photoUrl;
  final ClubRole role;
  final DateTime joinedAt;

  const ClubMember({
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.role,
    required this.joinedAt,
  });

  factory ClubMember.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubMember(
      userId: doc.id,
      name: d['name'] ?? 'Member',
      photoUrl: d['photoUrl'],
      role: ClubRole.values.firstWhere(
          (r) => r.name == d['role'], orElse: () => ClubRole.member),
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// lib/models/club.dart
//
// ── Clubs remake changes ────────────────────────────────────────────────
// ClubDiscussionReply gained an optional attached-resource trio (see its
// doc comment) for the reply composer's "Resource" action.
//
// Club gained `thumbnailUrl` — a real, admin-uploaded square logo photo,
// separate from the existing wide `bannerUrl` cover photo. `emoji` is
// now ONLY an invisible fallback (a category-derived icon key, shown
// only for clubs that haven't uploaded a thumbnail yet) — there is no
// picker UI for it anymore; see theme/club_visuals.dart's `ClubLogo`
// widget for how the two combine, and create_club_page.dart /
// club_settings_page.dart for the actual photo-upload flow.

import 'package:cloud_firestore/cloud_firestore.dart';

/// True when there's chat activity the caller hasn't seen yet — no
/// activity ever (`lastMessageAt` null) is never unread; activity with no
/// read record at all (`lastReadAt` null) is always unread; otherwise it's
/// a strict after-comparison, so an exactly-equal timestamp counts as read.
bool clubHasUnreadMessages({
  required DateTime? lastMessageAt,
  required DateTime? lastReadAt,
}) {
  if (lastMessageAt == null) return false;
  if (lastReadAt == null) return true;
  return lastMessageAt.isAfter(lastReadAt);
}

enum ClubRole { visitor, member, moderator, admin }

class Club {
  final String id;
  final String name;

  /// Fallback-only from here on — see file header. Never user-facing as
  /// a picker; auto-derived from [category] when a club has no
  /// [thumbnailUrl] of its own.
  final String emoji;
  final String description;
  final String moderatorName;
  final String moderatorId;
  final String category;

  /// Wide cover photo shown behind the club name on the detail hero.
  final String? bannerUrl;

  /// A real photo the club's admin uploaded as its logo/badge — shown
  /// wherever the club's identity needs to be compact and recognizable
  /// (card badges, the hero's circular logo, the Messages inbox row).
  /// Null until an admin uploads one, in which case [emoji]'s
  /// category-derived icon is shown instead (see ClubLogo).
  final String? thumbnailUrl;

  final int memberCount;
  final String? schoolId;
  final bool requiresApproval;

  /// Denormalized preview of the club chat's most recent message — same
  /// shape/purpose as Conversation's lastMessage* fields, so a club can
  /// be listed alongside 1:1 conversations in one merged, recency-sorted
  /// Messages inbox (see MessagesHomePage's _combinedInboxStream).
  final String lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;

  const Club({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.moderatorName,
    required this.moderatorId,
    this.category = 'General',
    this.bannerUrl,
    this.thumbnailUrl,
    this.memberCount = 0,
    this.schoolId,
    this.requiresApproval = false,
    this.lastMessageText = '',
    this.lastMessageSenderId,
    this.lastMessageAt,
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
      thumbnailUrl: d['thumbnailUrl'],
      memberCount: (d['memberCount'] as num?)?.toInt() ?? 0,
      schoolId: d['schoolId'],
      requiresApproval: d['requiresApproval'] ?? false,
      lastMessageText: d['lastMessageText'] ?? '',
      lastMessageSenderId: d['lastMessageSenderId'],
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  /// For CREATE only — see [toUpdateMap] for editing an existing club
  /// without clobbering its real `createdAt`, the same createdAt-on-
  /// update bug this session already fixed for CourseRepository/
  /// PublicCourseRepository.
  Map<String, dynamic> toFirestore() => {
    ...toUpdateMap(),
    'createdAt': FieldValue.serverTimestamp(),
  };

  /// Every field EXCEPT createdAt — safe to use for both create (spread
  /// into toFirestore() above) and update (ClubRepository.updateClub()).
  Map<String, dynamic> toUpdateMap() => {
    'name': name,
    'emoji': emoji,
    'description': description,
    'moderatorName': moderatorName,
    'moderatorId': moderatorId,
    'category': category,
    'bannerUrl': bannerUrl,
    'thumbnailUrl': thumbnailUrl,
    'memberCount': memberCount,
    'schoolId': schoolId,
    'requiresApproval': requiresApproval,
    'lastMessageText': lastMessageText,
    'lastMessageSenderId': lastMessageSenderId,
    'lastMessageAt': lastMessageAt == null ? null : Timestamp.fromDate(lastMessageAt!),
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
  final bool deleted;

  const ClubMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderInitials,
    required this.text,
    required this.time,
    this.deleted = false,
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
      deleted: d['deleted'] ?? false,
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

/// A post in a club's Feed tab — replaces the old dead `_AnnTab`
/// placeholder. Stored at clubs/{clubId}/posts/{postId}, matching a
/// firestore.rules shape that already existed (authorId-owner rule) but
/// had no real model/repository writing to it until now.
class ClubPost {
  final String id;
  final String clubId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final bool isAnnouncement;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  const ClubPost({
    required this.id,
    required this.clubId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.isAnnouncement = false,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory ClubPost.fromFirestore(DocumentSnapshot doc, String clubId) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubPost(
      id: doc.id,
      clubId: clubId,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Member',
      authorPhotoUrl: d['authorPhotoUrl'],
      isAnnouncement: d['isAnnouncement'] ?? false,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      imageUrl: d['imageUrl'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (d['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'isAnnouncement': isAnnouncement,
    'title': title,
    'body': body,
    'imageUrl': imageUrl,
    'createdAt': FieldValue.serverTimestamp(),
    'likeCount': 0,
    'commentCount': 0,
  };
}

class ClubPostComment {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;

  const ClubPostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  factory ClubPostComment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubPostComment(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Member',
      authorPhotoUrl: d['authorPhotoUrl'],
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// A Q&A thread in a club's Discussions tab (see the Physics Society
/// mockup) — a question with a "best answer" a moderator/admin or the
/// original poster can mark, which awards the answerer bonus XP
/// (XpSource.clubBestAnswer). Stored at clubs/{clubId}/discussions/{id}.
class ClubDiscussion {
  final String id;
  final String clubId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String title;
  final String body;
  final String? tag;
  final DateTime createdAt;
  final int replyCount;
  final int viewCount;
  final int likeCount;
  final String? bestAnswerReplyId;

  const ClubDiscussion({
    required this.id,
    required this.clubId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.title,
    required this.body,
    this.tag,
    required this.createdAt,
    this.replyCount = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.bestAnswerReplyId,
  });

  factory ClubDiscussion.fromFirestore(DocumentSnapshot doc, String clubId) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubDiscussion(
      id: doc.id,
      clubId: clubId,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Member',
      authorPhotoUrl: d['authorPhotoUrl'],
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      tag: d['tag'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyCount: (d['replyCount'] as num?)?.toInt() ?? 0,
      viewCount: (d['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      bestAnswerReplyId: d['bestAnswerReplyId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'title': title,
    'body': body,
    'tag': tag,
    'createdAt': FieldValue.serverTimestamp(),
    'replyCount': 0,
    'viewCount': 0,
    'likeCount': 0,
    'bestAnswerReplyId': null,
  };
}

class ClubDiscussionReply {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final bool authorIsStaff;
  final String body;
  final DateTime createdAt;
  final int likeCount;
  final bool isBestAnswer;

  /// Optional attached resource — the reply-composer's "Resource" action
  /// (see club_discussion_page.dart) lets you point a reply at an
  /// existing ClubResource instead of only free text, denormalized the
  /// same way ChatMessage's sharedTitle/sharedThumbnailUrl already are
  /// for Messages. All three are set together or not at all.
  final String? attachedResourceId;
  final String? attachedResourceTitle;
  final String? attachedResourceUrl;

  const ClubDiscussionReply({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.authorIsStaff = false,
    required this.body,
    required this.createdAt,
    this.likeCount = 0,
    this.isBestAnswer = false,
    this.attachedResourceId,
    this.attachedResourceTitle,
    this.attachedResourceUrl,
  });

  factory ClubDiscussionReply.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubDiscussionReply(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Member',
      authorPhotoUrl: d['authorPhotoUrl'],
      authorIsStaff: d['authorIsStaff'] ?? false,
      body: d['body'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      isBestAnswer: d['isBestAnswer'] ?? false,
      attachedResourceId: d['attachedResourceId'],
      attachedResourceTitle: d['attachedResourceTitle'],
      attachedResourceUrl: d['attachedResourceUrl'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'authorIsStaff': authorIsStaff,
    'body': body,
    'createdAt': FieldValue.serverTimestamp(),
    'likeCount': 0,
    'isBestAnswer': false,
    'attachedResourceId': attachedResourceId,
    'attachedResourceTitle': attachedResourceTitle,
    'attachedResourceUrl': attachedResourceUrl,
  };
}

/// A shared link/file in a club's Resources tab. Stored at
/// clubs/{clubId}/resources/{id}.
class ClubResource {
  final String id;
  final String clubId;
  final String title;
  final String? description;
  final String url;
  final bool isFile; // true = uploaded to Storage; false = an external link
  final String uploaderId;
  final String uploaderName;
  final String? uploaderPhotoUrl;
  final DateTime createdAt;

  const ClubResource({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    required this.url,
    this.isFile = false,
    required this.uploaderId,
    required this.uploaderName,
    this.uploaderPhotoUrl,
    required this.createdAt,
  });

  factory ClubResource.fromFirestore(DocumentSnapshot doc, String clubId) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubResource(
      id: doc.id,
      clubId: clubId,
      title: d['title'] ?? '',
      description: d['description'],
      url: d['url'] ?? '',
      isFile: d['isFile'] ?? false,
      uploaderId: d['uploaderId'] ?? '',
      uploaderName: d['uploaderName'] ?? 'Member',
      uploaderPhotoUrl: d['uploaderPhotoUrl'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'url': url,
    'isFile': isFile,
    'uploaderId': uploaderId,
    'uploaderName': uploaderName,
    'uploaderPhotoUrl': uploaderPhotoUrl,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// An upcoming club event. Stored at clubs/{clubId}/events/{id} — the
/// firestore.rules path for this already existed (school-staff-only,
/// pre-dating this model); loosened alongside this model landing so a
/// club's own admins/moderators can create events too, not just staff.
class ClubEvent {
  final String id;
  final String clubId;
  final String title;
  final String? description;
  final DateTime startAt;
  final String? location;
  final String creatorId;
  final String creatorName;
  final int rsvpCount;

  const ClubEvent({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    required this.startAt,
    this.location,
    required this.creatorId,
    required this.creatorName,
    this.rsvpCount = 0,
  });

  factory ClubEvent.fromFirestore(DocumentSnapshot doc, String clubId) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClubEvent(
      id: doc.id,
      clubId: clubId,
      title: d['title'] ?? '',
      description: d['description'],
      startAt: (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: d['location'],
      creatorId: d['creatorId'] ?? '',
      creatorName: d['creatorName'] ?? 'Member',
      rsvpCount: (d['rsvpCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'startAt': Timestamp.fromDate(startAt),
    'location': location,
    'creatorId': creatorId,
    'creatorName': creatorName,
    'rsvpCount': rsvpCount,
    'createdAt': FieldValue.serverTimestamp(),
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

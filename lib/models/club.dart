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
//
// Supabase: public.clubs plus one table per feature area (club_posts,
// club_discussions/_replies, club_resources, club_events) — see
// supabase/migrations/20260829450000_clubs_remake.sql.

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
  /// Set only for a class group (create_class_group RPC) -- never shown in
  /// Discover, never self-joinable.
  final String? classLevel;
  bool get isClassGroup => (classLevel ?? '').isNotEmpty;

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
    this.classLevel,
    this.lastMessageText = '',
    this.lastMessageSenderId,
    this.lastMessageAt,
  });

  factory Club.fromSupabase(Map<String, dynamic> d) {
    return Club(
      id: d['id'] as String,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '🎓',
      description: d['description'] ?? '',
      moderatorName: d['moderator_name'] ?? '',
      moderatorId: d['moderator_id'] ?? '',
      category: d['category'] ?? 'General',
      bannerUrl: d['banner_url'],
      thumbnailUrl: d['thumbnail_url'],
      memberCount: (d['member_count'] as num?)?.toInt() ?? 0,
      schoolId: (d['school_id'] ?? d['institution_id']) as String?,
      requiresApproval: d['requires_approval'] ?? false,
      classLevel: d['class_level'] as String?,
      lastMessageText: d['last_message_text'] ?? '',
      lastMessageSenderId: d['last_message_sender_id'],
      lastMessageAt: DateTime.tryParse(d['last_message_at']?.toString() ?? ''),
    );
  }

  /// For CREATE only — see [toUpdateMap] for editing an existing club
  /// without clobbering its real `created_at`.
  Map<String, dynamic> toSupabase() => toUpdateMap();

  /// Every field safe to use for both create and update
  /// (ClubRepository.updateClub()) — `created_at` has a database default
  /// and is never touched by either.
  Map<String, dynamic> toUpdateMap() => {
    'name': name,
    'emoji': emoji,
    'description': description,
    'moderator_name': moderatorName,
    'moderator_id': moderatorId.isEmpty ? null : moderatorId,
    'category': category,
    'banner_url': bannerUrl,
    'thumbnail_url': thumbnailUrl,
    'member_count': memberCount,
    'institution_id': schoolId,
    'school_id': schoolId,
    'requires_approval': requiresApproval,
    'last_message_text': lastMessageText,
    'last_message_sender_id': lastMessageSenderId,
    'last_message_at': lastMessageAt?.toIso8601String(),
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

  factory ClubJoinRequest.fromSupabase(Map<String, dynamic> d) {
    return ClubJoinRequest(
      id: d['id'] as String,
      clubId: d['club_id'] ?? '',
      clubName: d['club_name'] ?? '',
      userId: d['user_id'] ?? '',
      userName: d['user_name'] ?? '',
      userPhotoUrl: d['user_photo_url'],
      status: ClubJoinRequestStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => ClubJoinRequestStatus.pending),
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() => {
    'club_id': clubId,
    'club_name': clubName,
    'user_id': userId,
    'user_name': userName,
    'user_photo_url': userPhotoUrl,
    'status': status.name,
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

  factory ClubMessage.fromSupabase(Map<String, dynamic> d) {
    return ClubMessage(
      id: d['id'] as String,
      senderId: d['sender_id'] ?? '',
      senderName: d['sender_name'] ?? '',
      senderInitials: d['sender_initials'] ?? '',
      text: d['body'] ?? '',
      time: DateTime.tryParse(d['sent_at']?.toString() ?? '') ?? DateTime.now(),
      deleted: d['deleted'] ?? false,
    );
  }

  Map<String, dynamic> toSupabase() => {
    'sender_id': senderId,
    'sender_name': senderName,
    'sender_initials': senderInitials,
    'body': text,
    'deleted': deleted,
  };
}

/// A post in a club's Feed tab. Stored in club_posts.
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

  factory ClubPost.fromSupabase(Map<String, dynamic> d) {
    return ClubPost(
      id: d['id'] as String,
      clubId: d['club_id'] ?? '',
      authorId: d['author_id'] ?? '',
      authorName: d['author_name'] ?? 'Member',
      authorPhotoUrl: d['author_photo_url'],
      isAnnouncement: d['is_announcement'] ?? false,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      imageUrl: d['image_url'],
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      likeCount: (d['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (d['comment_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() => {
    'club_id': clubId,
    'author_id': authorId.isEmpty ? null : authorId,
    'author_name': authorName,
    'author_photo_url': authorPhotoUrl,
    'is_announcement': isAnnouncement,
    'title': title,
    'body': body,
    'image_url': imageUrl,
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

  factory ClubPostComment.fromSupabase(Map<String, dynamic> d) {
    return ClubPostComment(
      id: d['id'] as String,
      authorId: d['author_id'] ?? '',
      authorName: d['author_name'] ?? 'Member',
      authorPhotoUrl: d['author_photo_url'],
      text: d['text'] ?? '',
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// A Q&A thread in a club's Discussions tab (see the Physics Society
/// mockup) — a question with a "best answer" a moderator/admin or the
/// original poster can mark, which awards the answerer bonus XP
/// (XpSource.clubBestAnswer). Stored in club_discussions.
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

  factory ClubDiscussion.fromSupabase(Map<String, dynamic> d) {
    return ClubDiscussion(
      id: d['id'] as String,
      clubId: d['club_id'] ?? '',
      authorId: d['author_id'] ?? '',
      authorName: d['author_name'] ?? 'Member',
      authorPhotoUrl: d['author_photo_url'],
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      tag: d['tag'],
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      replyCount: (d['reply_count'] as num?)?.toInt() ?? 0,
      viewCount: (d['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (d['like_count'] as num?)?.toInt() ?? 0,
      bestAnswerReplyId: d['best_answer_reply_id'],
    );
  }

  Map<String, dynamic> toSupabase() => {
    'club_id': clubId,
    'author_id': authorId.isEmpty ? null : authorId,
    'author_name': authorName,
    'author_photo_url': authorPhotoUrl,
    'title': title,
    'body': body,
    'tag': tag,
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
  /// lets you point a reply at an existing ClubResource instead of only
  /// free text. All three are set together or not at all.
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

  factory ClubDiscussionReply.fromSupabase(Map<String, dynamic> d) {
    return ClubDiscussionReply(
      id: d['id'] as String,
      authorId: d['author_id'] ?? '',
      authorName: d['author_name'] ?? 'Member',
      authorPhotoUrl: d['author_photo_url'],
      authorIsStaff: d['author_is_staff'] ?? false,
      body: d['body'] ?? '',
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      likeCount: (d['like_count'] as num?)?.toInt() ?? 0,
      isBestAnswer: d['is_best_answer'] ?? false,
      attachedResourceId: d['attached_resource_id'],
      attachedResourceTitle: d['attached_resource_title'],
      attachedResourceUrl: d['attached_resource_url'],
    );
  }
}

/// A shared link/file in a club's Resources tab. Stored in club_resources.
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

  factory ClubResource.fromSupabase(Map<String, dynamic> d) {
    return ClubResource(
      id: d['id'] as String,
      clubId: d['club_id'] ?? '',
      title: d['title'] ?? '',
      description: d['description'],
      url: d['url'] ?? '',
      isFile: d['is_file'] ?? false,
      uploaderId: d['uploader_id'] ?? '',
      uploaderName: d['uploader_name'] ?? 'Member',
      uploaderPhotoUrl: d['uploader_photo_url'],
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() => {
    'club_id': clubId,
    'title': title,
    'description': description,
    'url': url,
    'is_file': isFile,
    'uploader_id': uploaderId.isEmpty ? null : uploaderId,
    'uploader_name': uploaderName,
    'uploader_photo_url': uploaderPhotoUrl,
  };
}

/// An upcoming club event. Stored in club_events.
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

  factory ClubEvent.fromSupabase(Map<String, dynamic> d) {
    return ClubEvent(
      id: d['id'] as String,
      clubId: d['club_id'] ?? '',
      title: d['title'] ?? '',
      description: d['description'],
      startAt: DateTime.tryParse(d['start_at']?.toString() ?? '') ?? DateTime.now(),
      location: d['location'],
      creatorId: d['creator_id'] ?? '',
      creatorName: d['creator_name'] ?? 'Member',
      rsvpCount: (d['rsvp_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() => {
    'club_id': clubId,
    'title': title,
    'description': description,
    'start_at': startAt.toIso8601String(),
    'location': location,
    'creator_id': creatorId.isEmpty ? null : creatorId,
    'creator_name': creatorName,
  };
}

/// One row in a club's member-management list. Stored in club_members,
/// keyed by (club_id, user_id).
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

  factory ClubMember.fromSupabase(Map<String, dynamic> d) {
    return ClubMember(
      userId: d['user_id'] as String,
      name: d['name'] ?? 'Member',
      photoUrl: d['photo_url'],
      role: ClubRole.values.firstWhere(
          (r) => r.name == d['role'], orElse: () => ClubRole.member),
      joinedAt: DateTime.tryParse(d['joined_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

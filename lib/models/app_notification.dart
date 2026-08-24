// lib/models/app_notification.dart
// Backs the Notifications feed (bell icon on Home, drawer entry, and the
// Settings > Notification Preferences screen). Each row lives under the
// recipient's own subcollection so a user only ever reads their own feed —
// no cross-user query is possible even before Firestore rules are checked.
//
// Firestore: users/{uid}/notifications/{notificationId}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/branding.dart';

enum NotificationType {
  announcement,
  comment,
  reply,
  articlePublished,
  system;

  String get label {
    switch (this) {
      case NotificationType.announcement:     return 'Announcement';
      case NotificationType.comment:          return 'Comment';
      case NotificationType.reply:            return 'Reply';
      case NotificationType.articlePublished: return 'New Article';
      case NotificationType.system:           return Branding.current.appName;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? deepLinkId; // e.g. articleId, announcementId
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.deepLinkId,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: NotificationType.values.firstWhere(
          (t) => t.name == d['type'], orElse: () => NotificationType.system),
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      deepLinkId: d['deepLinkId'],
      read: d['read'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'title': title,
        'body': body,
        'deepLinkId': deepLinkId,
        'read': read,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// Per-user toggle preferences, stored as a single doc so reads/writes are
/// one round trip instead of N. Firestore: users/{uid}/settings/notifications
class NotificationPreferences {
  final bool announcements;
  final bool comments;
  final bool replies;
  final bool newArticles;

  const NotificationPreferences({
    this.announcements = true,
    this.comments = true,
    this.replies = true,
    this.newArticles = true,
  });

  factory NotificationPreferences.fromFirestore(Map<String, dynamic>? d) {
    if (d == null) return const NotificationPreferences();
    return NotificationPreferences(
      announcements: d['announcements'] ?? true,
      comments: d['comments'] ?? true,
      replies: d['replies'] ?? true,
      newArticles: d['newArticles'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'announcements': announcements,
        'comments': comments,
        'replies': replies,
        'newArticles': newArticles,
      };

  NotificationPreferences copyWith({
    bool? announcements, bool? comments, bool? replies, bool? newArticles,
  }) => NotificationPreferences(
        announcements: announcements ?? this.announcements,
        comments: comments ?? this.comments,
        replies: replies ?? this.replies,
        newArticles: newArticles ?? this.newArticles,
      );
}

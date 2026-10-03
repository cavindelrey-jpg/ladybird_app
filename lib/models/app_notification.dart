// lib/models/app_notification.dart
// Backs the Notifications feed (bell icon on Home, drawer entry, and the
// Settings > Notification Preferences screen). RLS on `notifications`
// restricts rows to their own user_id (see schema.sql), same isolation
// guarantee the Firestore subcollection-per-user layout gave.

import '../config/branding.dart';

enum NotificationType {
  announcement,
  comment,
  reply,
  articlePublished,
  system,
  homework,
  dailyProgram,
  message,
  recommendation;

  String get label {
    switch (this) {
      case NotificationType.announcement:     return 'Announcement';
      case NotificationType.comment:          return 'Comment';
      case NotificationType.reply:            return 'Reply';
      case NotificationType.articlePublished: return 'New Article';
      case NotificationType.system:           return Branding.current.appName;
      case NotificationType.homework:         return 'Homework';
      case NotificationType.dailyProgram:     return "Tomorrow's Program";
      case NotificationType.message:          return 'Message';
      case NotificationType.recommendation:   return 'Recommended for you';
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

  factory AppNotification.fromSupabase(Map<String, dynamic> d) {
    const typeMap = {
      'announcement': NotificationType.announcement, 'comment': NotificationType.comment,
      'reply': NotificationType.reply, 'article_published': NotificationType.articlePublished,
      'system': NotificationType.system, 'homework': NotificationType.homework,
      'daily_program': NotificationType.dailyProgram,
      'message': NotificationType.message, 'recommendation': NotificationType.recommendation,
    };
    return AppNotification(
      id: d['id'] as String,
      type: typeMap[d['type']] ?? NotificationType.system,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      deepLinkId: d['deep_link_id'],
      read: d['read'] ?? false,
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() => {
        'type': switch (type) {
          NotificationType.articlePublished => 'article_published',
          NotificationType.dailyProgram => 'daily_program',
          _ => type.name,
        },
        'title': title,
        'body': body,
        'deep_link_id': deepLinkId,
        'read': read,
      };
}

/// Per-user toggle preferences, stored as a single row so reads/writes
/// are one round trip instead of N.
class NotificationPreferences {
  final bool announcements;
  final bool comments;
  final bool replies;
  final bool newArticles;
  /// 7 PM "Tomorrow" programme (timetable, homework, school events).
  final bool dailyProgram;
  /// Morning Daily Challenge reminder + course/book recommendations.
  final bool recommendations;

  const NotificationPreferences({
    this.announcements = true,
    this.comments = true,
    this.replies = true,
    this.newArticles = true,
    this.dailyProgram = true,
    this.recommendations = true,
  });

  factory NotificationPreferences.fromSupabase(Map<String, dynamic>? d) {
    if (d == null) return const NotificationPreferences();
    return NotificationPreferences(
      announcements: d['announcements'] ?? true,
      comments: d['comments'] ?? true,
      replies: d['replies'] ?? true,
      newArticles: d['new_articles'] ?? true,
      dailyProgram: d['daily_program'] ?? true,
      recommendations: d['recommendations'] ?? true,
    );
  }

  Map<String, dynamic> toSupabase() => {
        'announcements': announcements,
        'comments': comments,
        'replies': replies,
        'new_articles': newArticles,
        'daily_program': dailyProgram,
        'recommendations': recommendations,
      };

  NotificationPreferences copyWith({
    bool? announcements, bool? comments, bool? replies, bool? newArticles,
    bool? dailyProgram, bool? recommendations,
  }) => NotificationPreferences(
        announcements: announcements ?? this.announcements,
        comments: comments ?? this.comments,
        replies: replies ?? this.replies,
        newArticles: newArticles ?? this.newArticles,
        dailyProgram: dailyProgram ?? this.dailyProgram,
        recommendations: recommendations ?? this.recommendations,
      );
}

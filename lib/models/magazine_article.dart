// lib/models/magazine_article.dart
// Full schema for the Magazine module: feed, composer, reader, author
// profile, and bookmarks all read/write this shape. Zero seed/demo
// articles ship with this file — everything starts empty until a real
// post exists.
//
// Firestore: articles/{articleId}
//            articles/{articleId}/comments/{commentId}
//            articles/{articleId}/reads/{uid}   (unique-reader tracking)
//            articles/{articleId}/likes/{uid}
//            users/{uid}/bookmarks/{articleId}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Predefined categories shown in the composer's picker.
const List<String> kArticleCategories = [
  'Academics', 'Sports', 'Arts & Culture', 'Science & Tech',
  'Opinion', 'Campus Life', 'Careers', 'Other',
];

/// Predefined tag suggestions shown as chips in the composer.
const List<String> kArticleTags = [
  'GCE', 'Study Tips', 'Exam Prep', 'Clubs', 'Announcements',
  'Interview', 'Achievement', 'Event',
];

class MagazineArticle {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl; // null -> generic thumbnail in the UI
  final String? schoolId;       // null -> independent/global article

  String title;
  String description;   // short excerpt shown in feed cards
  String body;           // plain-text/HTML body (used by feed previews,
                          // simple rendering, and as a fallback when
                          // bodyDelta isn't populated)
  dynamic bodyDelta;    // rich-text delta (flutter_quill JSON), untyped so
                         // the composer can assign a List or a String as it
                         // serializes its editor state
  String category;      // one of kArticleCategories (or 'Other')
  List<String> tags;

  String? thumbnailUrl;
  bool featured;

  int readCount;
  int commentCount;
  int likeCount;

  /// XP earned by the author from unique reads that hasn't been credited
  /// to their AppUser.xpTotal yet — settled via
  /// MagazineRepository.settlePendingXp(authorId), called once at app
  /// start (see app_router.dart). 2 XP per unique new reader, per spec.
  int pendingAuthorXp;

  bool published;
  final DateTime createdAt;
  DateTime updatedAt;

  MagazineArticle({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.schoolId,
    this.title = '',
    this.description = '',
    this.body = '',
    this.bodyDelta = '',
    this.category = 'Other',
    List<String>? tags,
    this.thumbnailUrl,
    this.featured = false,
    this.readCount = 0,
    this.commentCount = 0,
    this.likeCount = 0,
    this.pendingAuthorXp = 0,
    this.published = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Empty draft used by the composer before the first save.
  factory MagazineArticle.draft({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    String? schoolId,
  }) =>
      MagazineArticle(
        id: '',
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        schoolId: schoolId,
        published: false,
      );

  factory MagazineArticle.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MagazineArticle(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorPhotoUrl: d['authorPhotoUrl'],
      schoolId: d['schoolId'],
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      body: d['body'] ?? '',
      bodyDelta: d['bodyDelta'] ?? '',
      category: d['category'] ?? 'Other',
      tags: List<String>.from(d['tags'] ?? []),
      thumbnailUrl: d['thumbnailUrl'],
      featured: d['featured'] ?? false,
      readCount: (d['readCount'] as num?)?.toInt() ?? 0,
      commentCount: (d['commentCount'] as num?)?.toInt() ?? 0,
      likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      pendingAuthorXp: (d['pendingAuthorXp'] as num?)?.toInt() ?? 0,
      published: d['published'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'schoolId': schoolId,
        'title': title,
        'description': description,
        'body': body,
        'bodyDelta': bodyDelta,
        'category': category,
        'tags': tags,
        'thumbnailUrl': thumbnailUrl,
        'featured': featured,
        'readCount': readCount,
        'commentCount': commentCount,
        'likeCount': likeCount,
        'pendingAuthorXp': pendingAuthorXp,
        'published': published,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class ArticleComment {
  final String id;
  final String articleId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String? parentCommentId; // non-null = reply
  String body;
  final DateTime createdAt;

  ArticleComment({
    required this.id,
    required this.articleId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.parentCommentId,
    required this.body,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ArticleComment.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, String articleId) {
    final d = doc.data() ?? {};
    return ArticleComment(
      id: doc.id,
      articleId: articleId,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorPhotoUrl: d['authorPhotoUrl'],
      parentCommentId: d['parentCommentId'],
      body: d['body'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'parentCommentId': parentCommentId,
        'body': body,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// One row in Home's "Top Writers" leaderboard.
/// score = (totalReads * 0.4) + (totalComments * 0.6) — comments weighted
/// higher, per spec.
class TopWriterEntry {
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final int totalReads;
  final int totalComments;

  const TopWriterEntry({
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.totalReads,
    required this.totalComments,
  });

  double get score => (totalReads * 0.4) + (totalComments * 0.6);
}

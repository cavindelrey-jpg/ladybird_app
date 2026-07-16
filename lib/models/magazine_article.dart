// lib/models/magazine_article.dart
// Core schema for the Magazine module. Establishes the shape now so
// Home's "Top Writers" section can be wired to real data even before the
// full Magazine feed UI ships. Zero seed/demo articles — the feed and
// leaderboard are simply empty until the first real post exists.
//
// Firestore: articles/{articleId}
//            articles/{articleId}/comments/{commentId}

import 'package:cloud_firestore/cloud_firestore.dart';

class MagazineArticle {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl; // null -> generic thumbnail in the UI
  String title;

  /// Plain-text body — kept as a fallback/derived value for card excerpts,
  /// search, and feed previews. Always regenerated from bodyDelta's plain
  /// text whenever the rich content is saved; never edited directly once
  /// bodyDelta exists.
  String body;

  /// Short author-written summary shown on feed cards, distinct from the
  /// full `body` — never auto-derived, so it stays empty for articles
  /// published before this field existed (UI falls back to the
  /// auto-truncated body excerpt in that case).
  String description;

  /// Rich content as a Quill Delta, JSON-encoded. Null/empty means this
  /// article predates rich text and only has plain `body` — the reader
  /// falls back to rendering that as plain text in that case.
  String? bodyDelta;

  String? thumbnailUrl;    // author-supplied cover image
  String? cachedThumbnailPath;

  /// Free-text category label (Essay, Opinion, Story, News, etc.) — shown
  /// as the small colored tag on article cards. No fixed enum since this
  /// is editorial, not structural — see kArticleCategories for the
  /// suggested picker list in the composer.
  String category;

  /// Free-text multi-select tags, in addition to the single `category` —
  /// finer-grained than category (e.g. an Essay article might be tagged
  /// 'GCE A-Level' and 'Exam Prep'). See kArticleTags for the suggested
  /// picker list; custom tags are allowed too.
  List<String> tags;

  /// Author's schoolId at time of publish (nullable — independent users
  /// have none). Backs the "Local Feed" tab; "Global Feed" ignores it.
  final String? schoolId;

  int readCount;
  int commentCount;
  int likeCount;
  bool published;
  final DateTime createdAt;
  DateTime updatedAt;

  MagazineArticle({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.title,
    required this.body,
    this.description = '',
    this.bodyDelta,
    this.thumbnailUrl,
    this.cachedThumbnailPath,
    this.category = 'Essay',
    List<String>? tags,
    this.schoolId,
    this.readCount = 0,
    this.commentCount = 0,
    this.likeCount = 0,
    this.published = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory MagazineArticle.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MagazineArticle(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorPhotoUrl: d['authorPhotoUrl'],
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      description: d['description'] ?? '',
      bodyDelta: d['bodyDelta'],
      thumbnailUrl: d['thumbnailUrl'],
      category: d['category'] ?? 'Essay',
      tags: List<String>.from(d['tags'] ?? const []),
      schoolId: d['schoolId'],
      readCount: d['readCount'] ?? 0,
      commentCount: d['commentCount'] ?? 0,
      likeCount: d['likeCount'] ?? 0,
      published: d['published'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'title': title,
        'body': body,
        'description': description,
        'bodyDelta': bodyDelta,
        'thumbnailUrl': thumbnailUrl,
        'category': category,
        'tags': tags,
        'schoolId': schoolId,
        'readCount': readCount,
        'commentCount': commentCount,
        'likeCount': likeCount,
        'published': published,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// Suggested category picker options for the composer. Free-text under
/// the hood, but a fixed list keeps the tags visually consistent.
const kArticleCategories = [
  'Essay', 'Opinion', 'Story', 'Creative Writing', 'News', 'Guide', 'Interview', 'Review',
];

/// Suggested tag picker options — free-text under the hood (see `tags` on
/// MagazineArticle), same pattern as kArticleCategories.
const kArticleTags = [
  'GCE O-Level', 'GCE A-Level', 'Study Tips', 'Exam Prep', 'Career Advice',
  'Campus Life', 'Technology', 'Motivation', 'Culture', 'Trending',
];

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

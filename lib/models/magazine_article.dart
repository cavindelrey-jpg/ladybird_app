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
  String body;

  String? thumbnailUrl;    // author-supplied cover image
  String? cachedThumbnailPath;

  int readCount;
  int commentCount;
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
    this.thumbnailUrl,
    this.cachedThumbnailPath,
    this.readCount = 0,
    this.commentCount = 0,
    this.published = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
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
      thumbnailUrl: d['thumbnailUrl'],
      readCount: d['readCount'] ?? 0,
      commentCount: d['commentCount'] ?? 0,
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
        'thumbnailUrl': thumbnailUrl,
        'readCount': readCount,
        'commentCount': commentCount,
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

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


/// Predefined categories shown in the composer's picker.
const List<String> kArticleCategories = [
  'Academics', 'Sports', 'Arts & Culture', 'Science & Tech',
  'Opinion', 'Campus Life', 'Careers', 'Other',
];

/// Predefined tag suggestions shown as chips in the composer.
const List<String> kArticleTags = [
  'GCE', 'Study Tips', 'Exam Prep', 'Groups', 'Announcements',
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
  int shareCount;

  /// DEPRECATED — the old flat "2 XP per unique read, credited whenever
  /// the author's session next runs settlePendingXp()" mechanism. Kept on
  /// the model so old rows still deserialize; nothing new writes to it.
  /// Replaced by production_plan.md §4.5's formula-based, 24h-delayed,
  /// once-per-article settlement — see [magazineXpSettled] and
  /// MagazineRepository.settleMagazineXpIfDue().
  int pendingAuthorXp;

  /// True once this article's one-time §4.5 XP settlement has run
  /// (views/50 + likes*2 + comments*5 + shares*4, capped at 80, computed
  /// no earlier than 24h after [createdAt]). Never recomputed after —
  /// late engagement past the 24h mark intentionally doesn't earn more,
  /// matching the plan's "defined measurement window."
  bool magazineXpSettled;

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
    this.shareCount = 0,
    this.pendingAuthorXp = 0,
    this.magazineXpSettled = false,
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

  factory MagazineArticle.fromSupabase(Map<String, dynamic> d) {
    return MagazineArticle(
      id: d['id'] as String,
      authorId: d['author_id'] ?? '',
      authorName: d['author_name'] ?? 'Unknown',
      authorPhotoUrl: d['author_photo_url'],
      schoolId: d['institution_id'],
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      body: d['body'] ?? '',
      bodyDelta: d['body_delta'] ?? '',
      category: d['category'] ?? 'Other',
      tags: List<String>.from(d['tags'] ?? []),
      thumbnailUrl: d['thumbnail_url'],
      featured: d['featured'] ?? false,
      readCount: (d['read_count'] as num?)?.toInt() ?? 0,
      commentCount: (d['comment_count'] as num?)?.toInt() ?? 0,
      likeCount: (d['like_count'] as num?)?.toInt() ?? 0,
      shareCount: (d['share_count'] as num?)?.toInt() ?? 0,
      pendingAuthorXp: (d['pending_author_xp'] as num?)?.toInt() ?? 0,
      magazineXpSettled: d['magazine_xp_settled'] ?? false,
      published: d['published'] ?? true,
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(d['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() => {
        'author_id': authorId.isEmpty ? null : authorId,
        'author_name': authorName,
        'author_photo_url': authorPhotoUrl,
        'institution_id': schoolId,
        'title': title,
        'description': description,
        'body': body,
        'body_delta': bodyDelta,
        'category': category,
        'tags': tags,
        'thumbnail_url': thumbnailUrl,
        'featured': featured,
        'read_count': readCount,
        'comment_count': commentCount,
        'like_count': likeCount,
        'share_count': shareCount,
        'pending_author_xp': pendingAuthorXp,
        'magazine_xp_settled': magazineXpSettled,
        'published': published,
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
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

  factory ArticleComment.fromSupabase(Map<String, dynamic> d) {
    return ArticleComment(
      id: d['id'] as String,
      articleId: d['article_id'] as String,
      authorId: d['author_id'] ?? '',
      authorName: d['author_name'] ?? 'Unknown',
      authorPhotoUrl: d['author_photo_url'],
      parentCommentId: d['parent_comment_id'],
      body: d['body'] ?? '',
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
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

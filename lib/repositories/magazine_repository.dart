// lib/repositories/magazine_repository.dart
// Supabase backing for the Magazine module: feed variants, a single
// article's comments/likes/bookmarks/shares, publishing/editing,
// thumbnail upload, and the engagement -> formula-based, 24h-delayed,
// one-time XP settlement pipeline (production_plan.md §4.5) — see
// settleMagazineXpIfDue(). Several operations are SECURITY DEFINER RPCs
// (supabase/migrations/20260829200000_magazine_engagement_rpcs.sql,
// 20260829410000_magazine_xp_settlement_rpcs.sql) for the same reason as
// academia-cameroon's own version: Postgres has no client-side atomic
// increment and these need to run as more than the caller's own
// RLS-restricted permissions allow.
//
// ── Student Gallery / Latest Videos ─────────────────────────────────────
// No Postgres table exists for either yet — zero real data at migration
// time (mirrors magazine_media.dart's other non-article content types,
// which academia-cameroon already stubs the same way). watch* methods
// return an empty stream; create/upload methods return an honest Failure
// rather than silently doing nothing, since gallery_composer_page.dart /
// video_composer_page.dart already surface a Failure's message as a toast.
//
// ── searchArticles() ─────────────────────────────────────────────────────
// Real (if bounded) search: fetches a window of recent published articles
// and filters client-side by title/description/category/tags/author, same
// "fetch a window, filter client-side" pattern ClubRepository.searchClubs
// already uses — this project has no full-text search index.

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/magazine_article.dart';
import '../models/magazine_gallery_post.dart';
import '../models/magazine_video_post.dart';
import '../models/xp_transaction.dart';
import '../core/result.dart';
import '../services/content_cache_service.dart';
import 'dart:async';
import 'xp_repository.dart';
import '../core/realtime_tolerant.dart';

class MagazineRepository {
  MagazineRepository._();
  static final MagazineRepository instance = MagazineRepository._();

  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _articles => _db.from('magazine_articles');

  // ── Feed variants ──────────────────────────────────────────────────────

  Stream<List<MagazineArticle>> watchFeed({int limit = 30}) {
    final controller = StreamController<List<MagazineArticle>>();
    StreamSubscription? liveSub;

    controller.onListen = () async {
      final cached = await ContentCacheService.instance.getList('magazine_feed');
      if (cached != null && !controller.isClosed) {
        controller.add(cached.map(MagazineArticle.fromSupabase).toList());
      }
      liveSub = _articles
          .stream(primaryKey: ['id'])
          .eq('published', true)
          .order('created_at', ascending: false)
          .limit(limit)
          .realtimeTolerant()
          .listen((rows) {
        if (controller.isClosed) return;
        final list = List<Map<String, dynamic>>.from(rows);
        unawaited(ContentCacheService.instance.putList('magazine_feed', list));
        controller.add(list.map(MagazineArticle.fromSupabase).toList());
      }, onError: (e) {
        if (cached == null && !controller.isClosed) controller.addError(e);
      });
    };

    controller.onCancel = () => liveSub?.cancel();
    return controller.stream;
  }

  /// "Following" feed — articles by a specific set of authors.
  Stream<List<MagazineArticle>> watchFeedFromAuthors(List<String> authorIds) {
    if (authorIds.isEmpty) return Stream.value(const []);
    final capped = authorIds.take(30).toSet();
    return _articles
        .stream(primaryKey: ['id'])
        .eq('published', true)
        .order('created_at', ascending: false)
        .realtimeTolerant()
        .map((rows) => rows
            .where((r) => capped.contains(r['author_id']))
            .map(MagazineArticle.fromSupabase)
            .toList());
  }

  /// School-scoped feed.
  Stream<List<MagazineArticle>> watchLocalFeed(String schoolId) => _articles
      .stream(primaryKey: ['id'])
      .eq('institution_id', schoolId)
      .order('created_at', ascending: false)
      .realtimeTolerant()
      .map((rows) => rows
          .where((r) => r['published'] == true)
          .map(MagazineArticle.fromSupabase)
          .toList());

  /// One-time fetch of featured/pinned articles.
  Future<List<MagazineArticle>> watchFeaturedOnce({int limit = 5}) async {
    final rows = await _articles
        .select()
        .eq('published', true)
        .eq('featured', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(MagazineArticle.fromSupabase).toList();
  }

  /// Engagement score used to rank "Trending Now" / "Popular in Your
  /// Network" — reads count most, then comments, then likes.
  int _engagementScore(MagazineArticle a) =>
      a.readCount + a.commentCount * 3 + a.likeCount * 2;

  /// Highest-engagement articles published in the last [days] days.
  Stream<List<MagazineArticle>> watchTrending({int days = 14, int limit = 10}) {
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return _articles
        .stream(primaryKey: ['id'])
        .eq('published', true)
        .order('created_at', ascending: false)
        .realtimeTolerant()
        .map((rows) {
      final items = rows
          .where((r) => (r['created_at'] as String).compareTo(cutoff) >= 0)
          .map(MagazineArticle.fromSupabase)
          .toList()
        ..sort((a, b) => _engagementScore(b).compareTo(_engagementScore(a)));
      return items.take(limit).toList();
    });
  }

  /// Highest-engagement articles among a set of authors.
  Stream<List<MagazineArticle>> watchPopularFromAuthors(List<String> authorIds, {int limit = 10}) {
    if (authorIds.isEmpty) return Stream.value(const []);
    return watchFeedFromAuthors(authorIds).map((items) {
      final sorted = List<MagazineArticle>.from(items)
        ..sort((a, b) => _engagementScore(b).compareTo(_engagementScore(a)));
      return sorted.take(limit).toList();
    });
  }

  /// One-time "Trending" fetch — computed from real engagement over the
  /// last [windowDays] days (likes + 2×comments), not manually curated.
  Future<List<MagazineArticle>> watchTrendingOnce({int limit = 10, int windowDays = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    final recent = await watchFeed(limit: 80).first;
    final windowed = recent.where((a) => a.createdAt.isAfter(cutoff)).toList();
    final pool = windowed.isNotEmpty ? windowed : recent; // quiet week fallback: still show *something* real
    pool.sort((a, b) => (b.likeCount + b.commentCount * 2).compareTo(a.likeCount + a.commentCount * 2));
    return pool.take(limit).toList();
  }

  /// Real search, bounded on purpose: fetches the [sampleSize] most recent
  /// published articles once and filters client-side by title,
  /// description, category, and tags — no full-text search index exists.
  Future<List<MagazineArticle>> searchArticles(String query, {int sampleSize = 200}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final rows = await _articles
        .select()
        .eq('published', true)
        .order('created_at', ascending: false)
        .limit(sampleSize);
    return rows
        .map(MagazineArticle.fromSupabase)
        .where((a) =>
            a.title.toLowerCase().contains(q) ||
            a.description.toLowerCase().contains(q) ||
            a.category.toLowerCase().contains(q) ||
            a.tags.any((t) => t.toLowerCase().contains(q)) ||
            a.authorName.toLowerCase().contains(q))
        .toList();
  }

  // ── Student Gallery (stub — see file header) ────────────────────────────

  Stream<List<MagazineGalleryPost>> watchGalleryPosts({int limit = 20}) => Stream.value(const []);

  Future<Result<String>> createGalleryPost(MagazineGalleryPost post) async =>
      const Failure('Photo posts aren\'t available yet.', null);

  Future<Result<void>> setGalleryImages(String postId, List<String> imageUrls) async =>
      const Failure('Photo posts aren\'t available yet.', null);

  Future<Result<String>> uploadGalleryImage({required String postId, required int index, required File file}) async =>
      const Failure('Photo posts aren\'t available yet.', null);

  Future<Result<void>> toggleGalleryLike(String postId, String userId) async =>
      const Failure('Photo posts aren\'t available yet.', null);

  Stream<bool> watchIsGalleryLiked(String postId, String userId) => Stream.value(false);

  // ── Latest Videos (stub — see file header) ──────────────────────────────

  Stream<List<MagazineVideoPost>> watchVideoPosts({int limit = 20}) => Stream.value(const []);

  Future<Result<String>> createVideoPost(MagazineVideoPost post) async =>
      const Failure('Video posts aren\'t available yet.', null);

  Future<Result<String>> uploadVideoFile({required String postId, required File file}) async =>
      const Failure('Video posts aren\'t available yet.', null);

  Future<Result<String>> uploadVideoThumbnail({required String postId, required File file}) async =>
      const Failure('Video posts aren\'t available yet.', null);

  Future<Result<void>> setVideoUrls(String postId, {required String videoUrl, String? thumbnailUrl}) async =>
      const Failure('Video posts aren\'t available yet.', null);

  Future<void> incrementVideoViews(String postId) async {} // best-effort no-op, nothing to increment yet

  Stream<List<MagazineArticle>> watchByAuthor(String authorId) => _articles
      .stream(primaryKey: ['id'])
      .eq('author_id', authorId)
      .order('created_at', ascending: false)
      .realtimeTolerant()
      .map((rows) => rows.map(MagazineArticle.fromSupabase).toList());

  Future<MagazineArticle?> getById(String id) async {
    final row = await _articles.select().eq('id', id).maybeSingle();
    return row != null ? MagazineArticle.fromSupabase(row) : null;
  }

  // ── Publish / edit / delete ─────────────────────────────────────────────

  Future<Result<String>> publish(MagazineArticle article) async {
    try {
      final row = await _articles.insert(article.toSupabase()).select('id').single();
      return Success(row['id'] as String);
    } catch (e) {
      return Failure('Failed to publish article', e);
    }
  }

  Future<Result<void>> update(MagazineArticle article) async {
    try {
      await _articles.update(article.toSupabase()).eq('id', article.id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update article', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _articles.delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete article', e);
    }
  }

  Future<Result<String>> uploadThumbnail({
    required String articleId,
    required File imageFile,
  }) async {
    try {
      final path = 'magazine_thumbnails/$articleId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload thumbnail', e);
    }
  }

  // ── Comments ───────────────────────────────────────────────────────────

  Stream<List<ArticleComment>> watchComments(String articleId) => _db
      .from('article_comments')
      .stream(primaryKey: ['id'])
      .eq('article_id', articleId)
      .order('created_at')
      .realtimeTolerant()
      .map((rows) => rows.map(ArticleComment.fromSupabase).toList());

  Future<Result<void>> postComment(ArticleComment comment) async {
    try {
      await _db.rpc('post_article_comment', params: {
        'p_article_id': comment.articleId,
        'p_author_id': comment.authorId,
        'p_author_name': comment.authorName,
        'p_author_photo_url': comment.authorPhotoUrl,
        'p_parent_comment_id': comment.parentCommentId,
        'p_body': comment.body,
      });
      await settleMagazineXpIfDue(comment.articleId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post comment', e);
    }
  }

  // ── Reads, shares -> engagement counters ────────────────────────────────
  // production_plan.md §4.5: author XP is NOT credited per-event. record*
  // below only ever increments raw counters; the actual XP is computed
  // ONCE, no earlier than 24h after publish, from the plan's formula —
  // see settleMagazineXpIfDue().

  Future<Result<void>> recordRead(String articleId, {
    required String? readerId,
    required String authorId,
  }) async {
    if (readerId == null || readerId.isEmpty) {
      return const Success(null); // guests don't earn/track reads
    }
    try {
      await _db.rpc('record_article_read', params: {'p_article_id': articleId, 'p_reader_id': readerId});
      await settleMagazineXpIfDue(articleId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to record read', e);
    }
  }

  /// Same unique-per-user dedup as reads/likes — sharing the same article
  /// five times shouldn't count as five shares toward the author's XP.
  Future<Result<void>> recordShare(String articleId, String userId) async {
    if (userId.isEmpty) return const Success(null); // guests don't earn/track shares
    try {
      await _db.rpc('record_article_share', params: {'p_article_id': articleId});
      await settleMagazineXpIfDue(articleId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to record share', e);
    }
  }

  /// production_plan.md §4.5's formula, run exactly once per article, no
  /// earlier than 24h after publish: XP = (views/50) + (likes*2) +
  /// (comments*5) + (shares*4), capped at [kMagazinePerPostXpCap]. There's
  /// no Cloud Scheduler / pg_cron job wired up to fire this automatically
  /// at the 24h mark, so it's checked opportunistically as a side effect
  /// of any reader interaction with the article (read/share/comment/like)
  /// — eventually-consistent, and safe to call redundantly: the RPC's own
  /// `magazine_xp_settled` check (under a row lock) makes it a no-op after
  /// the first successful run.
  Future<void> settleMagazineXpIfDue(String articleId) async {
    try {
      final rows = await _db.rpc('settle_magazine_xp_if_due', params: {'p_article_id': articleId}) as List;
      if (rows.isEmpty) return;
      final result = rows.first as Map<String, dynamic>;
      final authorId = result['out_author_id'] as String?;
      final amount = (result['out_amount'] as num?)?.toInt() ?? 0;
      if (authorId != null && authorId.isNotEmpty && amount > 0) {
        await XpRepository.instance.awardXp(authorId, XpSource.magazineRead, amount, articleId: articleId);
      }
    } catch (_) {
      // best-effort — the next interaction with this article will retry
    }
  }

  /// Called once per app session (see app_router.dart) to catch any of
  /// this user's OWN authored articles that crossed the 24h mark since
  /// their last session, in case nobody else interacted with it meanwhile
  /// to trigger settleMagazineXpIfDue() as a side effect.
  Future<void> settlePendingXp(String userId) async {
    if (userId.isEmpty) return;
    try {
      final rows = await _articles.select('id').eq('author_id', userId).eq('magazine_xp_settled', false);
      for (final row in rows) {
        await settleMagazineXpIfDue(row['id'] as String);
      }
    } catch (_) {
      // best-effort, same policy as the rest of this settlement pipeline
    }
  }

  // ── Likes ──────────────────────────────────────────────────────────────

  Future<Result<void>> toggleLike(String articleId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to like articles.', null);
    try {
      await _db.rpc('toggle_article_like', params: {'p_article_id': articleId});
      await settleMagazineXpIfDue(articleId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  Stream<bool> watchIsLiked(String articleId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db
        .from('article_likes')
        .stream(primaryKey: ['article_id', 'user_id'])
        .eq('article_id', articleId)
        .realtimeTolerant()
        .map((rows) => rows.any((r) => r['user_id'] == userId));
  }

  // ── Bookmarks ────────────────────────────────────────────────────────────

  Future<Result<void>> toggleBookmark(String articleId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to bookmark articles.', null);
    try {
      await _db.rpc('toggle_article_bookmark', params: {'p_article_id': articleId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update bookmark', e);
    }
  }

  Stream<bool> watchIsBookmarked(String articleId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db
        .from('article_bookmarks')
        .stream(primaryKey: ['article_id', 'user_id'])
        .eq('article_id', articleId)
        .realtimeTolerant()
        .map((rows) => rows.any((r) => r['user_id'] == userId));
  }

  /// Live list of the user's bookmarked articles, newest-saved first.
  Stream<List<MagazineArticle>> watchBookmarkedArticles(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _db
        .from('article_bookmarks')
        .stream(primaryKey: ['article_id', 'user_id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .realtimeTolerant()
        .asyncMap((rows) async {
      if (rows.isEmpty) return <MagazineArticle>[];
      final ids = rows.map((r) => r['article_id'] as String).toList();
      final articles = await _articles.select().inFilter('id', ids);
      final byId = {for (final a in articles) a['id'] as String: a};
      return ids.where(byId.containsKey).map((id) => MagazineArticle.fromSupabase(byId[id]!)).toList();
    });
  }

  // ── Top Writers leaderboard ─────────────────────────────────────────────
  // score = (reads * 0.4) + (comments * 0.6). Aggregated client-side over
  // recent articles; fine at this scale.

  Future<List<TopWriterEntry>> topWriters({int articleSampleSize = 200}) async {
    final rows = await _articles
        .select()
        .eq('published', true)
        .order('created_at', ascending: false)
        .limit(articleSampleSize);

    final byAuthor = <String, ({String name, String? photo, int reads, int comments})>{};
    for (final row in rows) {
      final a = MagazineArticle.fromSupabase(row);
      final existing = byAuthor[a.authorId];
      byAuthor[a.authorId] = (
        name: a.authorName,
        photo: a.authorPhotoUrl,
        reads: (existing?.reads ?? 0) + a.readCount,
        comments: (existing?.comments ?? 0) + a.commentCount,
      );
    }

    final entries = byAuthor.entries
        .map((e) => TopWriterEntry(
              authorId: e.key,
              authorName: e.value.name,
              authorPhotoUrl: e.value.photo,
              totalReads: e.value.reads,
              totalComments: e.value.comments,
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return entries;
  }
}

// lib/repositories/magazine_repository.dart
// Full Firestore backing for the Magazine module: feed variants, a single
// article's comments/likes/bookmarks/shares, publishing/editing, thumbnail
// upload, and the engagement -> formula-based, 24h-delayed, one-time XP
// settlement pipeline (production_plan.md §4.5) — see
// settleMagazineXpIfDue().

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/magazine_article.dart';
import '../models/magazine_gallery_post.dart';
import '../models/magazine_video_post.dart';
import '../models/xp_transaction.dart';
import '../core/result.dart';
import 'xp_repository.dart';

class MagazineRepository {
  MagazineRepository._();
  static final MagazineRepository instance = MagazineRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _articles => _db.collection('articles');
  CollectionReference<Map<String, dynamic>> get _galleryPosts => _db.collection('magazine_gallery');
  CollectionReference<Map<String, dynamic>> get _videoPosts => _db.collection('magazine_videos');

  // ── Student Gallery ──────────────────────────────────────────────────────

  Stream<List<MagazineGalleryPost>> watchGalleryPosts({int limit = 20}) => _galleryPosts
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(MagazineGalleryPost.fromFirestore).toList());

  Future<Result<String>> createGalleryPost(MagazineGalleryPost post) async {
    try {
      final ref = await _galleryPosts.add(post.toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to publish gallery post', e);
    }
  }

  /// Called after createGalleryPost() + uploadGalleryImage() to attach the
  /// now-uploaded image URLs to the post doc created before the images
  /// existed (the doc id is needed as the Storage path, so create has to
  /// happen first).
  Future<Result<void>> setGalleryImages(String postId, List<String> imageUrls) async {
    try {
      await _galleryPosts.doc(postId).update({'imageUrls': imageUrls});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to attach photos', e);
    }
  }

  Future<Result<String>> uploadGalleryImage({required String postId, required int index, required File file}) async {
    try {
      final ref = FirebaseStorage.instance.ref('magazine_gallery/$postId/$index.jpg');
      await ref.putFile(file).timeout(const Duration(seconds: 60), onTimeout: () => throw Exception(
          'Upload is taking too long. Check your connection and try again.'));
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload image', e);
    }
  }

  Future<Result<void>> toggleGalleryLike(String postId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to like posts.', null);
    try {
      final likeRef = _galleryPosts.doc(postId).collection('likes').doc(userId);
      final exists = (await likeRef.get()).exists;
      if (exists) {
        await likeRef.delete();
        await _galleryPosts.doc(postId).update({'likeCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await _galleryPosts.doc(postId).update({'likeCount': FieldValue.increment(1)});
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  Stream<bool> watchIsGalleryLiked(String postId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _galleryPosts.doc(postId).collection('likes').doc(userId).snapshots().map((d) => d.exists);
  }

  // ── Latest Videos ─────────────────────────────────────────────────────────

  Stream<List<MagazineVideoPost>> watchVideoPosts({int limit = 20}) => _videoPosts
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(MagazineVideoPost.fromFirestore).toList());

  Future<Result<String>> createVideoPost(MagazineVideoPost post) async {
    try {
      final ref = await _videoPosts.add(post.toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to publish video', e);
    }
  }

  Future<Result<String>> uploadVideoFile({required String postId, required File file}) async {
    try {
      final ref = FirebaseStorage.instance.ref('magazine_videos/$postId/video.mp4');
      await ref.putFile(file).timeout(const Duration(minutes: 5), onTimeout: () => throw Exception(
          'Upload is taking too long. Check your connection and try again.'));
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload video', e);
    }
  }

  Future<Result<String>> uploadVideoThumbnail({required String postId, required File file}) async {
    try {
      final ref = FirebaseStorage.instance.ref('magazine_videos/$postId/thumbnail.jpg');
      await ref.putFile(file).timeout(const Duration(seconds: 60), onTimeout: () => throw Exception(
          'Upload is taking too long. Check your connection and try again.'));
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload thumbnail', e);
    }
  }

  /// Same create-then-attach-media pattern as gallery posts — the doc id
  /// is needed as the Storage path, so create() has to run before upload.
  Future<Result<void>> setVideoUrls(String postId, {required String videoUrl, String? thumbnailUrl}) async {
    try {
      await _videoPosts.doc(postId).update({'videoUrl': videoUrl, if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to attach video', e);
    }
  }

  Future<void> incrementVideoViews(String postId) async {
    try {
      await _videoPosts.doc(postId).update({'viewCount': FieldValue.increment(1)});
    } catch (_) {
      // best-effort — a missed view count isn't worth surfacing
    }
  }

  // ── Feed variants ──────────────────────────────────────────────────────

  Stream<List<MagazineArticle>> watchFeed({int limit = 30}) => _articles
      .where('published', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(MagazineArticle.fromFirestore).toList());

  /// "Following" feed — articles by a specific set of authors. Firestore's
  /// whereIn caps at 30 values; callers with more should page/batch.
  Stream<List<MagazineArticle>> watchFeedFromAuthors(List<String> authorIds) {
    if (authorIds.isEmpty) return Stream.value(const []);
    final capped = authorIds.take(30).toList();
    return _articles
        .where('published', isEqualTo: true)
        .where('authorId', whereIn: capped)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(MagazineArticle.fromFirestore).toList());
  }

  /// School-scoped feed.
  Stream<List<MagazineArticle>> watchLocalFeed(String schoolId) => _articles
      .where('published', isEqualTo: true)
      .where('schoolId', isEqualTo: schoolId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MagazineArticle.fromFirestore).toList());

  /// One-time fetch of featured/pinned articles (e.g. for a carousel at
  /// the top of the feed) — not a live stream, called once per feed load.
  Future<List<MagazineArticle>> watchFeaturedOnce({int limit = 5}) async {
    final snap = await _articles
        .where('published', isEqualTo: true)
        .where('featured', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MagazineArticle.fromFirestore).toList();
  }

  /// One-time "Trending" fetch — computed from real engagement over the
  /// last 7 days (likes + 2×comments), not manually curated. Reuses
  /// watchFeed's already-time-ordered, index-free query and filters/sorts
  /// client-side rather than adding a new composite index for a field
  /// (createdAt range + published equality + a computed engagement sort)
  /// Firestore can't express in one query anyway.
  Future<List<MagazineArticle>> watchTrendingOnce({int limit = 10, int windowDays = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    final recent = await watchFeed(limit: 80).first;
    final windowed = recent.where((a) => a.createdAt.isAfter(cutoff)).toList();
    final pool = windowed.isNotEmpty ? windowed : recent; // quiet week fallback: still show *something* real
    pool.sort((a, b) => (b.likeCount + b.commentCount * 2).compareTo(a.likeCount + a.commentCount * 2));
    return pool.take(limit).toList();
  }

  Stream<List<MagazineArticle>> watchByAuthor(String authorId) => _articles
      .where('authorId', isEqualTo: authorId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MagazineArticle.fromFirestore).toList());

  Future<MagazineArticle?> getById(String id) async {
    final doc = await _articles.doc(id).get();
    return doc.exists ? MagazineArticle.fromFirestore(doc) : null;
  }

  // ── Publish / edit / delete ─────────────────────────────────────────────

  Future<Result<String>> publish(MagazineArticle article) async {
    try {
      final ref = await _articles.add(article.toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to publish article', e);
    }
  }

  Future<Result<void>> update(MagazineArticle article) async {
    try {
      await _articles.doc(article.id).set(article.toFirestore(), SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update article', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _articles.doc(id).delete();
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
      final ref = FirebaseStorage.instance.ref('article_thumbnails/$articleId.jpg');
      await ref.putFile(imageFile);
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload thumbnail', e);
    }
  }

  // ── Comments ───────────────────────────────────────────────────────────

  Stream<List<ArticleComment>> watchComments(String articleId) => _articles
      .doc(articleId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ArticleComment.fromFirestore(d, articleId)).toList());

  Future<Result<void>> postComment(ArticleComment comment) async {
    try {
      final batch = _db.batch();
      final ref = _articles.doc(comment.articleId).collection('comments').doc();
      batch.set(ref, comment.toFirestore());
      batch.update(_articles.doc(comment.articleId), {'commentCount': FieldValue.increment(1)});
      await batch.commit();
      unawaited(settleMagazineXpIfDue(comment.articleId));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post comment', e);
    }
  }

  // ── Reads, shares -> engagement counters ────────────────────────────────
  // production_plan.md §4.5: author XP is NOT credited per-event anymore.
  // recordRead/recordShare (and toggleLike/postComment below) only ever
  // increment raw counters; the actual XP is computed ONCE, 24h after
  // publish, from the plan's formula — see settleMagazineXpIfDue().

  Future<Result<void>> recordRead(String articleId, {
    required String? readerId,
    required String authorId,
  }) async {
    if (readerId == null || readerId.isEmpty) {
      return const Success(null); // guests don't earn/track reads
    }
    try {
      final readRef = _articles.doc(articleId).collection('reads').doc(readerId);
      await _db.runTransaction((tx) async {
        final readDoc = await tx.get(readRef);
        if (readDoc.exists) return; // already read by this person — no-op
        tx.set(readRef, {'readAt': FieldValue.serverTimestamp()});
        tx.update(_articles.doc(articleId), {'readCount': FieldValue.increment(1)});
      });
      unawaited(settleMagazineXpIfDue(articleId));
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
      final shareRef = _articles.doc(articleId).collection('shares').doc(userId);
      await _db.runTransaction((tx) async {
        final shareDoc = await tx.get(shareRef);
        if (shareDoc.exists) return;
        tx.set(shareRef, {'sharedAt': FieldValue.serverTimestamp()});
        tx.update(_articles.doc(articleId), {'shareCount': FieldValue.increment(1)});
      });
      unawaited(settleMagazineXpIfDue(articleId));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to record share', e);
    }
  }

  /// production_plan.md §4.5's formula, run exactly once per article, no
  /// earlier than 24h after publish: XP = (views/50) + (likes*2) +
  /// (comments*5) + (shares*4), capped at [kMagazinePerPostXpCap]. There's
  /// no Cloud Scheduler in this project to fire this automatically at the
  /// 24h mark, so it's checked opportunistically as a side effect of any
  /// reader interaction with the article (read/share here, like/comment
  /// below) — eventually-consistent (an article nobody touches again
  /// after the 24h mark simply settles the next time anyone does), and
  /// safe to call redundantly: the transaction's `magazineXpSettled`
  /// check makes it a no-op after the first successful run.
  Future<void> settleMagazineXpIfDue(String articleId) async {
    try {
      int? amountToAward;
      String? authorId;
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_articles.doc(articleId));
        if (!snap.exists) return;
        final article = MagazineArticle.fromFirestore(snap);
        if (article.magazineXpSettled) return;
        if (DateTime.now().difference(article.createdAt) < const Duration(hours: 24)) return;

        final raw = (article.readCount / 50) +
            (article.likeCount * 2) +
            (article.commentCount * 5) +
            (article.shareCount * 4);
        final amount = raw.round().clamp(0, kMagazinePerPostXpCap);
        tx.update(_articles.doc(articleId), {'magazineXpSettled': true});
        if (amount > 0) {
          amountToAward = amount;
          authorId = article.authorId;
        }
      });
      if (amountToAward != null && authorId != null && authorId!.isNotEmpty) {
        await XpRepository.instance.awardXp(
          authorId!, XpSource.magazineRead, amountToAward!, articleId: articleId,
        );
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
    final snap = await _articles
        .where('authorId', isEqualTo: userId)
        .where('magazineXpSettled', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      await settleMagazineXpIfDue(doc.id);
    }
  }

  // ── Likes ──────────────────────────────────────────────────────────────

  Future<Result<void>> toggleLike(String articleId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to like articles.', null);
    try {
      final likeRef = _articles.doc(articleId).collection('likes').doc(userId);
      final exists = (await likeRef.get()).exists;
      if (exists) {
        await likeRef.delete();
        await _articles.doc(articleId).update({'likeCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await _articles.doc(articleId).update({'likeCount': FieldValue.increment(1)});
      }
      unawaited(settleMagazineXpIfDue(articleId));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  Stream<bool> watchIsLiked(String articleId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _articles.doc(articleId).collection('likes').doc(userId)
        .snapshots().map((d) => d.exists);
  }

  // ── Bookmarks (stored per-user for easy "My Bookmarks" queries) ────────

  Future<Result<void>> toggleBookmark(String articleId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to bookmark articles.', null);
    try {
      final ref = _db.collection('users').doc(userId).collection('bookmarks').doc(articleId);
      final exists = (await ref.get()).exists;
      if (exists) {
        await ref.delete();
      } else {
        await ref.set({'savedAt': FieldValue.serverTimestamp()});
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update bookmark', e);
    }
  }

  Stream<bool> watchIsBookmarked(String articleId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db.collection('users').doc(userId).collection('bookmarks').doc(articleId)
        .snapshots().map((d) => d.exists);
  }

  /// Live list of the user's bookmarked articles, newest-saved first.
  Stream<List<MagazineArticle>> watchBookmarkedArticles(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _db
        .collection('users').doc(userId).collection('bookmarks')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return <MagazineArticle>[];
      final articles = await Future.wait(snap.docs.map((d) => _articles.doc(d.id).get()));
      return articles.where((a) => a.exists).map(MagazineArticle.fromFirestore).toList();
    });
  }

  // ── Top Writers leaderboard ─────────────────────────────────────────────
  // score = (reads * 0.4) + (comments * 0.6). Aggregated client-side over
  // recent articles; fine at this scale, revisit with a scheduled Cloud
  // Function aggregate if the magazine grows large.

  Future<List<TopWriterEntry>> topWriters({int articleSampleSize = 200}) async {
    final snap = await _articles
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(articleSampleSize)
        .get();

    final byAuthor = <String, ({String name, String? photo, int reads, int comments})>{};
    for (final doc in snap.docs) {
      final a = MagazineArticle.fromFirestore(doc);
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

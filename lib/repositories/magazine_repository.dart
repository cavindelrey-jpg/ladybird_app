// lib/repositories/magazine_repository.dart
// Full Firestore backing for the Magazine module: feed variants, a single
// article's comments/likes/bookmarks, publishing/editing, thumbnail
// upload, and the reads -> pending-XP -> settlement pipeline (2 XP per
// unique new reader, credited to the author's AppUser.xpTotal).

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/magazine_article.dart';
import '../models/xp_transaction.dart';
import '../core/result.dart';
import '../services/auth_service.dart';

class MagazineRepository {
  MagazineRepository._();
  static final MagazineRepository instance = MagazineRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _articles => _db.collection('articles');

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
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post comment', e);
    }
  }

  // ── Reads -> pending author XP ───────────────────────────────────────────
  // 2 XP per UNIQUE reader, credited to the author — matches the decided
  // XP source. Repeat reads by the same person never earn XP again.

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
        tx.update(_articles.doc(articleId), {
          'readCount': FieldValue.increment(1),
          'pendingAuthorXp': FieldValue.increment(2),
        });
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to record read', e);
    }
  }

  /// Called once per app session (see app_router.dart) to credit any XP
  /// this user has earned as an AUTHOR since the last settlement.
  Future<void> settlePendingXp(String userId) async {
    if (userId.isEmpty) return;
    final snap = await _articles
        .where('authorId', isEqualTo: userId)
        .where('pendingAuthorXp', isGreaterThan: 0)
        .get();
    if (snap.docs.isEmpty) return;

    var totalOwed = 0;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final owed = (doc.data()['pendingAuthorXp'] as num?)?.toInt() ?? 0;
      totalOwed += owed;
      batch.update(doc.reference, {'pendingAuthorXp': 0});
    }
    await batch.commit();
    if (totalOwed > 0) {
      await AuthService.instance.addXp(userId, totalOwed, XpSource.magazineRead);
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

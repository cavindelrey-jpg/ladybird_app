// lib/repositories/magazine_repository.dart
// All Firestore reads/writes for the Magazine module (articles + comments)
// and the Top Writers leaderboard computation.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/magazine_article.dart';
import '../core/result.dart';

class MagazineRepository {
  MagazineRepository._();
  static final MagazineRepository instance = MagazineRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _articles => _db.collection('articles');

  // ── Feed ───────────────────────────────────────────────

  Stream<List<MagazineArticle>> watchFeed({int limit = 30}) => _articles
      .where('published', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(MagazineArticle.fromFirestore).toList());

  Stream<List<MagazineArticle>> watchByAuthor(String authorId) => _articles
      .where('authorId', isEqualTo: authorId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MagazineArticle.fromFirestore).toList());

  Future<MagazineArticle?> getById(String id) async {
    final doc = await _articles.doc(id).get();
    return doc.exists ? MagazineArticle.fromFirestore(doc) : null;
  }

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

  /// Uploads a cover image for [articleId], returns the download URL.
  /// Caller should then call update() with thumbnailUrl set.
  Future<Result<String>> uploadThumbnail({
    required String articleId,
    required File imageFile,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref('magazine_thumbnails/$articleId.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return Success(url);
    } catch (e) {
      return Failure('Failed to upload cover image', e);
    }
  }

  Future<Result<void>> incrementReads(String articleId) async {
    try {
      await _articles.doc(articleId).update({'readCount': FieldValue.increment(1)});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to record read', e);
    }
  }

  // ── Comments ───────────────────────────────────────────

  Stream<List<ArticleComment>> watchComments(String articleId) => _articles
      .doc(articleId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ArticleComment.fromFirestore(d, articleId)).toList());

  Future<Result<void>> postComment(ArticleComment comment) async {
    try {
      final batch = _db.batch();
      final commentRef = _articles.doc(comment.articleId).collection('comments').doc();
      batch.set(commentRef, comment.toFirestore());
      batch.update(_articles.doc(comment.articleId), {'commentCount': FieldValue.increment(1)});
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post comment', e);
    }
  }

  /// All comments authored by [userId] across every article — backs the
  /// Magazine "Discussions" tab (your comments + replies to them).
  Stream<List<ArticleComment>> watchUserComments(String userId) {
    return _db
        .collectionGroup('comments')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ArticleComment.fromFirestore(d, d.reference.parent.parent!.id))
            .toList());
  }

  // ── Top Writers leaderboard ───────────────────────────────
  // Firestore can't do a weighted cross-document sort natively, so we pull
  // the most-active recent articles and aggregate client-side. Fine at
  // this scale; revisit with a scheduled Cloud Function aggregate if the
  // magazine grows large.

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

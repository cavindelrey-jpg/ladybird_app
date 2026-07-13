// lib/repositories/magazine_repository.dart
// All Firestore reads/writes for the Magazine module (articles + comments)
// and the Top Writers leaderboard computation.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/magazine_article.dart';
import '../models/xp_transaction.dart';
import '../core/result.dart';
import '../core/constants.dart';
import 'xp_repository.dart';

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

  /// Following tab — articles from authors the user follows.
  /// Firestore whereIn caps at 30 values; fine for now (following >30
  /// writers hitting a silent cap is an acceptable edge case at this
  /// stage — revisit with a fan-out feed if that becomes real usage).
  Stream<List<MagazineArticle>> watchFeedFromAuthors(List<String> authorIds, {int limit = 30}) {
    if (authorIds.isEmpty) return Stream.value(const []);
    final capped = authorIds.take(30).toList();
    return _articles
        .where('published', isEqualTo: true)
        .where('authorId', whereIn: capped)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(MagazineArticle.fromFirestore).toList());
  }

  /// Local Feed tab — articles published by writers at the same school.
  /// Independent (no schoolId) callers get an empty stream rather than an
  /// invalid query — the UI should offer Global Feed instead in that case.
  Stream<List<MagazineArticle>> watchLocalFeed(String schoolId, {int limit = 30}) {
    if (schoolId.isEmpty) return Stream.value(const []);
    return _articles
        .where('published', isEqualTo: true)
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(MagazineArticle.fromFirestore).toList());
  }

  /// Featured carousel — most-read articles from the last 14 days. This
  /// is a real, computed signal (not manual curation, not fake) so it's
  /// honest to label "Featured" without a human editor picking it.
  Future<List<MagazineArticle>> watchFeaturedOnce({int count = 5}) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final snap = await _articles
        .where('published', isEqualTo: true)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    final articles = snap.docs.map(MagazineArticle.fromFirestore).toList()
      ..sort((a, b) => b.readCount.compareTo(a.readCount));
    return articles.take(count).toList();
  }

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

  /// Records a view of [articleId]. Deliberately NOT a bare increment —
  /// this is the choke point that stops an author (or a friend acting on
  /// their behalf) from farming XP by simply reopening the same article
  /// over and over. Two cases:
  ///
  ///  - [readerId] is null (logged-out reader) or equals [authorId] (the
  ///    author previewing their own piece): readCount still ticks up for
  ///    the vanity metric, but no uniqueness record is kept and no XP is
  ///    ever awarded — there's no reader identity here to gate on safely.
  ///  - Otherwise: articles/{articleId}/readers/{readerId} existence is
  ///    the uniqueness check. First time -> increment readCount AND write
  ///    a pendingMagazineXp record IN THE SAME TRANSACTION as the
  ///    uniqueness check (see below for why), then attempt to settle it
  ///    immediately via XpRepository. Every subsequent open by the same
  ///    reader is a no-op on readCount, XP, and the pending record.
  ///
  /// Known, deliberately unfixed gap: this only blocks the exact-same-
  /// account self-read case. Nothing here stops an author from reading
  /// their own article from a second account they control — sock-puppet
  /// reads are indistinguishable from real ones at this layer. That
  /// needs a platform-level signal (App Check, account-age/verification
  /// heuristics) this repository doesn't have access to, not a client
  /// code fix — flagging rather than pretending it's solved.
  ///
  /// Why a pending record instead of calling awardXp() directly: the
  /// uniqueness-check-and-readCount-increment transaction and the
  /// awardXp() transaction touch two different documents (this article
  /// vs. the author's user doc) and can't be merged into one atomic
  /// Firestore transaction. Without the pending record, a failure in
  /// awardXp() after the read was already counted (author's user doc
  /// briefly unreachable, connection drop, whatever) would silently lose
  /// that XP forever — readCount goes up, author never gets paid, nothing
  /// notices. Writing the "XP owed" fact atomically with the uniqueness
  /// check means a failed settlement attempt is recoverable: it just
  /// stays 'pending' until settlePendingXp() sweeps it on the author's
  /// next session, instead of vanishing.
  Future<Result<void>> recordRead(
    String articleId, {
    String? readerId,
    required String authorId,
  }) async {
    try {
      final articleSnap = await _articles.doc(articleId).get();
      if (!articleSnap.exists || articleSnap.data()?['published'] != true) {
        // Unpublished/deleted/stale-link — no vanity metric, no XP.
        return const Success(null);
      }

      if (readerId == null || readerId.isEmpty || readerId == authorId) {
        await _articles.doc(articleId).update({'readCount': FieldValue.increment(1)});
        return const Success(null);
      }

      final readerRef = _articles.doc(articleId).collection('readers').doc(readerId);
      final pendingRef = _db.collection(AppConstants.colPendingMagazineXp).doc('${articleId}_$readerId');

      final isNewReader = await _db.runTransaction<bool>((tx) async {
        final existing = await tx.get(readerRef);
        if (existing.exists) return false;
        tx.set(readerRef, {'readAt': FieldValue.serverTimestamp()});
        tx.update(_articles.doc(articleId), {'readCount': FieldValue.increment(1)});
        tx.set(pendingRef, {
          'authorId': authorId,
          'articleId': articleId,
          'readerId': readerId,
          'amount': kMagazineReadXp,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

      // Best-effort immediate settlement. If this fails (offline, author
      // doc briefly unreachable, etc.) the pending record above already
      // durably captured "this XP is owed" — settlePendingXp() will pick
      // it up later. Not awaited into the read-recording's own result:
      // a slow/failed settlement shouldn't make the reader's own article
      // view look like it failed.
      if (isNewReader) {
        unawaited(_settleOne(pendingRef.id));
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to record read', e);
    }
  }

  /// Attempts to settle one pendingMagazineXp record: award the XP, then
  /// mark it 'completed'. Safe to call more than once on the same record
  /// (checks status first) — settlePendingXp() may re-sweep records this
  /// method already handled if the 'completed' write itself raced.
  Future<void> _settleOne(String pendingId) async {
    final ref = _db.collection(AppConstants.colPendingMagazineXp).doc(pendingId);
    try {
      final snap = await ref.get();
      if (!snap.exists) return;
      final d = snap.data()!;
      if (d['status'] != 'pending') return;

      final result = await XpRepository.instance.awardXp(
        d['authorId'] as String,
        XpSource.magazineRead,
        (d['amount'] as num).toInt(),
        articleId: d['articleId'] as String?,
      );
      if (result is Success) {
        await ref.update({'status': 'completed', 'settledAt': FieldValue.serverTimestamp()});
      }
      // On Failure, leave status == 'pending' — settlePendingXp() will
      // retry it on the author's next session rather than losing it.
    } catch (_) {
      // Leave pending; next settlePendingXp() sweep retries.
    }
  }

  /// Sweeps up to [limit] pending magazine-read XP payouts owed to
  /// [authorId] and attempts to settle each. Call this once per app
  /// session for the signed-in user (e.g. from HomeShell.initState) —
  /// it's the recovery path for any award that failed at read-time (see
  /// recordRead()'s doc comment). Cheap no-op on a clean account with
  /// nothing pending.
  Future<void> settlePendingXp(String authorId, {int limit = 50}) async {
    try {
      final snap = await _db
          .collection(AppConstants.colPendingMagazineXp)
          .where('authorId', isEqualTo: authorId)
          .where('status', isEqualTo: 'pending')
          .limit(limit)
          .get();
      for (final doc in snap.docs) {
        await _settleOne(doc.id);
      }
    } catch (_) {
      // Best-effort sweep — next app session tries again.
    }
  }

  // ── Likes ────────────────────────────────────────────────
  // articles/{id}/likes/{userId} — existence of the doc == liked.
  // likeCount on the article doc is denormalized for fast card display.

  Stream<bool> watchIsLiked(String articleId, String userId) => _articles
      .doc(articleId)
      .collection(AppConstants.colLikes)
      .doc(userId)
      .snapshots()
      .map((d) => d.exists);

  Future<Result<void>> toggleLike(String articleId, String userId) async {
    try {
      final likeRef = _articles.doc(articleId).collection(AppConstants.colLikes).doc(userId);
      final existing = await likeRef.get();
      final batch = _db.batch();
      if (existing.exists) {
        batch.delete(likeRef);
        batch.update(_articles.doc(articleId), {'likeCount': FieldValue.increment(-1)});
      } else {
        batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        batch.update(_articles.doc(articleId), {'likeCount': FieldValue.increment(1)});
      }
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
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

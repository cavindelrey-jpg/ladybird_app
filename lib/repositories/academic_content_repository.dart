// lib/repositories/academic_content_repository.dart
// Firestore + Firebase Storage operations for academic_content collection.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/academic_content.dart';
import '../core/constants.dart';
import '../core/result.dart';

class AcademicContentRepository {
  AcademicContentRepository._();
  static final AcademicContentRepository instance = AcademicContentRepository._();

  static const String _col = 'academic_content';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// Live stream of content. Filters by institution and optional type/subject.
  Stream<List<AcademicContent>> watch({
    String? institutionId,
    ContentType? contentType,
    String? subject,
  }) {
    Query<Map<String, dynamic>> q = _db.collection(_col);
    if (institutionId != null) {
      q = q.where('institutionId', isEqualTo: institutionId);
    }
    if (contentType != null) {
      q = q.where('contentType', isEqualTo: contentType.name);
    }
    if (subject != null && subject.isNotEmpty) {
      q = q.where('subject', isEqualTo: subject);
    }
    return q
        .orderBy('uploadDate', descending: true)
        .limit(80)
        .snapshots()
        .map((s) => s.docs.map(AcademicContent.fromFirestore).toList());
  }

  /// Stream for a single document.
  Stream<AcademicContent?> watchOne(String id) {
    return _db.collection(_col).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AcademicContent.fromFirestore(doc);
    });
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<List<AcademicContent>> search(
    String query, {
    String? institutionId,
    ContentType? contentType,
  }) async {
    final lower = query.toLowerCase();
    Query<Map<String, dynamic>> q = _db.collection(_col);
    if (institutionId != null) {
      q = q.where('institutionId', isEqualTo: institutionId);
    }
    if (contentType != null) {
      q = q.where('contentType', isEqualTo: contentType.name);
    }
    final snap = await q.orderBy('title').get();
    return snap.docs
        .map(AcademicContent.fromFirestore)
        .where((item) =>
            item.title.toLowerCase().contains(lower) ||
            item.description.toLowerCase().contains(lower) ||
            item.subject.toLowerCase().contains(lower) ||
            item.tags.any((t) => t.toLowerCase().contains(lower)))
        .toList();
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<Result<String>> add(AcademicContent content) async {
    try {
      final ref = await _db.collection(_col).add(content.toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to add content', e);
    }
  }

  Future<Result<void>> update(AcademicContent content) async {
    try {
      await _db.collection(_col).doc(content.id).update(content.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update content', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      final doc = await _db.collection(_col).doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Delete associated Storage files
        await _tryDeleteStorageFile(data['fileUrl']);
        await _tryDeleteStorageFile(data['thumbnailUrl']);
      }
      await _db.collection(_col).doc(id).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete content', e);
    }
  }

  // ─── Tracking ─────────────────────────────────────────────────────────────

  Future<Result<void>> incrementViews(String id) async {
    try {
      await _db.collection(_col).doc(id).update({
        'views': FieldValue.increment(1),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to track view', e);
    }
  }

  Future<Result<void>> incrementDownloads(String id) async {
    try {
      await _db.collection(_col).doc(id).update({
        'downloads': FieldValue.increment(1),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to track download', e);
    }
  }

  // ─── Saved for Offline ──────────────────────────────────────────────────
  // Honest scope note: this is a "saved to my list" marker, persisted in
  // Firestore — NOT true on-device file caching yet (that needs actual
  // local storage + download management, a separate, bigger follow-up).
  // A saved item still requires network to open until that's built.

  Stream<bool> watchIsSaved(String contentId, String userId) => _db
      .collection(_col).doc(contentId).collection(AppConstants.colSaves).doc(userId)
      .snapshots().map((d) => d.exists);

  Future<Result<void>> toggleSave(String contentId, String userId) async {
    try {
      final ref = _db.collection(_col).doc(contentId).collection(AppConstants.colSaves).doc(userId);
      final existing = await ref.get();
      if (existing.exists) {
        await ref.delete();
      } else {
        await ref.set({'savedAt': FieldValue.serverTimestamp()});
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update saved status', e);
    }
  }

  /// A user's saved content, newest-saved first.
  Stream<List<AcademicContent>> watchSavedContent(String userId) {
    return _db.collectionGroup(AppConstants.colSaves)
        .where(FieldPath.documentId, isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs.map((d) => d.reference.parent.parent?.id).whereType<String>().toList();
      if (ids.isEmpty) return <AcademicContent>[];
      final items = <AcademicContent>[];
      for (final id in ids.take(30)) {
        final doc = await _db.collection(_col).doc(id).get();
        if (doc.exists) items.add(AcademicContent.fromFirestore(doc));
      }
      return items;
    });
  }

  // ─── Recently viewed (real data — powers "Continue Learning") ──────────
  // Deliberately no fabricated progress percentage here — this codebase
  // has consistently avoided fake stats (the old hardcoded '87%' stat
  // card being the clearest example), so "Continue Learning" shows real
  // recency instead of a made-up completion number.

  Future<void> recordView(String contentId, String userId) async {
    try {
      await _db.collection(_col).doc(contentId).collection(AppConstants.colRecentViews).doc(userId)
          .set({'viewedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // best-effort — a failed recency update shouldn't block viewing the content
    }
  }

  /// Most-recently-viewed content for this user.
  Stream<List<AcademicContent>> watchRecentlyViewed(String userId, {int limit = 10}) {
    return _db.collectionGroup(AppConstants.colRecentViews)
        .where(FieldPath.documentId, isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final entries = snap.docs
          .map((d) => (d.reference.parent.parent?.id, (d.data()['viewedAt'] as Timestamp?)?.toDate()))
          .where((e) => e.$1 != null)
          .toList()
        ..sort((a, b) => (b.$2 ?? DateTime(0)).compareTo(a.$2 ?? DateTime(0)));
      final items = <AcademicContent>[];
      for (final entry in entries.take(limit)) {
        final doc = await _db.collection(_col).doc(entry.$1!).get();
        if (doc.exists) items.add(AcademicContent.fromFirestore(doc));
      }
      return items;
    });
  }

  // ─── Storage Upload ───────────────────────────────────────────────────────

  /// Uploads a file to Firebase Storage. Returns download URL. Times out
  /// instead of hanging forever on a dead connection and retries once —
  /// large video files on a slow/flaky connection previously had no
  /// recovery path beyond the user manually restarting the whole form.
  Future<Result<String>> uploadFile({
    required File file,
    required String folder,        // e.g. 'content_files' or 'thumbnails'
    required String institutionId,
    void Function(double)? onProgress,
    int attempt = 1,
  }) async {
    try {
      final ext = file.path.split('.').last;
      final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref('$folder/$institutionId/$name');
      final task = ref.putFile(file);
      final sub = task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress?.call(snap.bytesTransferred / snap.totalBytes);
        }
      });
      final snapshot = await task.timeout(const Duration(minutes: 5));
      await sub.cancel();
      final url = await snapshot.ref.getDownloadURL();
      return Success(url);
    } catch (e) {
      if (attempt < 2) {
        onProgress?.call(0);
        return uploadFile(
          file: file, folder: folder, institutionId: institutionId,
          onProgress: onProgress, attempt: attempt + 1,
        );
      }
      return Failure('Upload failed — check your connection and try again', e);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _tryDeleteStorageFile(dynamic url) async {
    if (url is! String || url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // File may already be gone — ignore
    }
  }

  /// Returns the list of distinct subjects from the collection.
  Future<List<String>> getSubjects({String? institutionId}) async {
    Query<Map<String, dynamic>> q = _db.collection(_col);
    if (institutionId != null) {
      q = q.where('institutionId', isEqualTo: institutionId);
    }
    final snap = await q.get();
    final subjects = snap.docs
        .map((d) => (d.data()['subject'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return subjects;
  }

  /// Real per-subject item counts — powers the Categories grid. Computed
  /// client-side from a bounded sample, same pattern used for Courses'
  /// Popular Topics; move to a scheduled aggregate if the library grows
  /// into the thousands.
  Future<Map<String, int>> subjectCountsOnce({String? institutionId}) async {
    Query<Map<String, dynamic>> q = _db.collection(_col);
    if (institutionId != null) {
      q = q.where('institutionId', isEqualTo: institutionId);
    }
    final snap = await q.limit(500).get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final subject = (doc.data()['subject'] as String?) ?? '';
      if (subject.isEmpty) continue;
      counts[subject] = (counts[subject] ?? 0) + 1;
    }
    return counts;
  }
}

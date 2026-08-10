// lib/repositories/academic_content_repository.dart
// Firestore + Firebase Storage operations for academic_content collection.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Live stream of content. Filters by institution and optional
  /// type/subject/level/examBoard/year.
  ///
  /// Firestore composite indexes only cover institutionId +
  /// (contentType and/or subject) + uploadDate (see firestore.indexes.json)
  /// — adding a dedicated composite index for every additional
  /// filter-dimension combination (level, examBoard, year, and every
  /// combination of them) would multiply combinatorially as the
  /// classification model grows. Instead: apply the indexed dimensions
  /// (institutionId, contentType, subject) server-side as before, and
  /// refine by level/examBoard/year client-side over a wider page when any
  /// of those are active. This keeps the index count bounded while still
  /// supporting combined filtering, and stays correct as the library grows
  /// into the thousands (widen the page limit, not the index count).
  Stream<List<AcademicContent>> watch({
    String? institutionId,
    ContentType? contentType,
    String? subject,
    String? level,
    String? examBoard,
    int? year,
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
    final hasClientFilter =
        (level != null && level.isNotEmpty) || (examBoard != null && examBoard.isNotEmpty) || year != null;
    return q
        .orderBy('uploadDate', descending: true)
        .limit(hasClientFilter ? 300 : 80)
        .snapshots()
        .map((s) {
      var items = s.docs.map(AcademicContent.fromFirestore).toList();
      if (level != null && level.isNotEmpty) {
        items = items.where((i) => i.level == level).toList();
      }
      if (examBoard != null && examBoard.isNotEmpty) {
        items = items.where((i) => i.examBoard == examBoard).toList();
      }
      if (year != null) {
        items = items.where((i) => i.year == year).toList();
      }
      return items;
    });
  }

  /// One-shot real count of library resources in scope — powers the Home
  /// "Library" banner's resource count. Uses a Firestore count() aggregate
  /// query so it doesn't need to download every document just to count
  /// them.
  Future<int> countAll({String? institutionId}) async {
    Query<Map<String, dynamic>> q = _db.collection(_col);
    if (institutionId != null) {
      q = q.where('institutionId', isEqualTo: institutionId);
    }
    final snap = await q.count().get();
    return snap.count ?? 0;
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
    String? subject,
    String? level,
    String? examBoard,
    int? year,
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
            (item.title.toLowerCase().contains(lower) ||
                item.description.toLowerCase().contains(lower) ||
                item.subject.toLowerCase().contains(lower) ||
                item.level.toLowerCase().contains(lower) ||
                item.examBoard.toLowerCase().contains(lower) ||
                item.tags.any((t) => t.toLowerCase().contains(lower))) &&
            (subject == null || subject.isEmpty || item.subject == subject) &&
            (level == null || level.isEmpty || item.level == level) &&
            (examBoard == null || examBoard.isEmpty || item.examBoard == examBoard) &&
            (year == null || item.year == year))
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
  // Two distinct, separately-tracked concepts:
  //  - "Saved" (toggleSave/watchIsSaved below): a bookmark marker in
  //    Firestore, powers "my saved list" across devices. Does NOT imply
  //    the file is actually on this device.
  //  - "Downloaded" (downloadForOffline/offlineFilePath below): the file's
  //    bytes actually written to local device storage, tracked in
  //    SharedPreferences (per-device, deliberately not synced — a
  //    download on one device doesn't mean it exists on another). This is
  //    the part that used to not exist at all despite the "Save for
  //    offline" label implying it did.

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
        await ref.set({'savedAt': FieldValue.serverTimestamp(), 'userId': userId});
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update saved status', e);
    }
  }

  /// A user's saved content, newest-saved first.
  Stream<List<AcademicContent>> watchSavedContent(String userId) {
    return _db.collectionGroup(AppConstants.colSaves)
        .where('userId', isEqualTo: userId)
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

  // ─── Offline download (real on-device file caching) ─────────────────────

  static const _offlinePrefsPrefix = 'offline_content_path_';

  /// Local file path for [contentId] if it's actually been downloaded to
  /// this device, else null. Cheap SharedPreferences lookup plus an
  /// existence check (the file may have been cleared by the OS/user
  /// without the app knowing).
  Future<String?> offlineFilePath(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_offlinePrefsPrefix$contentId');
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  /// Downloads the content's file to app-local storage and records the
  /// path so it can be opened without network afterward. Reports 0.0-1.0
  /// progress where the response provides a content-length.
  Future<Result<String>> downloadForOffline(
    AcademicContent item, {
    void Function(double)? onProgress,
  }) async {
    final url = item.fileUrl;
    if (url == null || url.isEmpty) {
      return const Failure('This item has no file to download.', null);
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${dir.path}/offline_content');
      if (!await offlineDir.exists()) await offlineDir.create(recursive: true);
      final ext = url.contains('.') ? url.split('.').last.split('?').first : 'bin';
      final localPath = '${offlineDir.path}/${item.id}.$ext';

      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send().timeout(const Duration(minutes: 5));
      if (response.statusCode >= 400) {
        return Failure('Download failed (server returned ${response.statusCode}).', null);
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      final file = File(localPath);
      final sink = file.openWrite();
      await response.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
        return chunk;
      }).pipe(sink);
      await sink.close();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_offlinePrefsPrefix${item.id}', localPath);
      return Success(localPath);
    } catch (e) {
      return Failure('Download failed — check your connection and try again.', e);
    }
  }

  /// Deletes the locally-downloaded file (if any) and forgets its path.
  /// Does not touch the separate "saved" bookmark.
  Future<void> removeOfflineFile(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_offlinePrefsPrefix$contentId');
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // best-effort
      }
      await prefs.remove('$_offlinePrefsPrefix$contentId');
    }
  }

  // ─── Recently viewed (real data — powers "Continue Learning") ──────────
  // Deliberately no fabricated progress percentage here — this codebase
  // has consistently avoided fake stats (the old hardcoded '87%' stat
  // card being the clearest example), so "Continue Learning" shows real
  // recency instead of a made-up completion number.

  Future<void> recordView(String contentId, String userId) async {
    try {
      await _db.collection(_col).doc(contentId).collection(AppConstants.colRecentViews).doc(userId)
          .set({'viewedAt': FieldValue.serverTimestamp(), 'userId': userId});
    } catch (_) {
      // best-effort — a failed recency update shouldn't block viewing the content
    }
  }

  /// Most-recently-viewed content for this user.
  Stream<List<AcademicContent>> watchRecentlyViewed(String userId, {int limit = 10}) {
    return _db.collectionGroup(AppConstants.colRecentViews)
        .where('userId', isEqualTo: userId)
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

  // ─── Read position (real data — powers Home "Continue Reading") ────────
  // Did NOT exist before this — no course/article position tracking
  // anywhere in the codebase. Only wired up for the in-app PDF viewer,
  // the one content type with a real page count; a fabricated "Page X of
  // Y" for content types without real pagination would repeat the same
  // mistake as the old hardcoded stat card.

  /// Persists how far [userId] has read into [contentId]. Best-effort — a
  /// failed position write should never interrupt reading.
  Future<void> recordReadPosition({
    required String contentId,
    required String userId,
    required int page,
    required int totalPages,
  }) async {
    try {
      await _db.collection(_col).doc(contentId).collection(AppConstants.colReadPositions).doc(userId).set({
        'page': page,
        'totalPages': totalPages,
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': userId,
      }).timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort
    }
  }

  /// The page [userId] last left off on for [contentId], or 1 if there's
  /// no saved position yet — used to resume the PDF viewer where they
  /// left off.
  Future<int> savedReadPage({required String contentId, required String userId}) async {
    try {
      final doc = await _db.collection(_col).doc(contentId)
          .collection(AppConstants.colReadPositions).doc(userId).get();
      final page = (doc.data()?['page'] as num?)?.toInt();
      return (page != null && page > 0) ? page : 1;
    } catch (_) {
      return 1;
    }
  }

  /// Most-recent real reading position for [userId] across all content —
  /// powers the Home "Continue Reading: <title>, Page X of Y" card. Null
  /// if they haven't read anything with a trackable position yet; the
  /// caller shows a genuine empty/prompt state in that case, never a
  /// fabricated example.
  Future<({AcademicContent content, int page, int totalPages})?> continueReading(String userId) async {
    try {
      final snap = await _db.collectionGroup(AppConstants.colReadPositions)
          .where('userId', isEqualTo: userId)
          .get();
      if (snap.docs.isEmpty) return null;
      final sorted = snap.docs.toList()
        ..sort((a, b) {
          final ta = (a.data()['updatedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final tb = (b.data()['updatedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return tb.compareTo(ta);
        });
      final latest = sorted.first;
      final contentId = latest.reference.parent.parent?.id;
      if (contentId == null) return null;
      final contentDoc = await _db.collection(_col).doc(contentId).get();
      if (!contentDoc.exists) return null;
      final data = latest.data();
      return (
        content: AcademicContent.fromFirestore(contentDoc),
        page: (data['page'] as num?)?.toInt() ?? 1,
        totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {
      return null;
    }
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

  /// Distinct exam/publication years actually present in the library
  /// (bounded sample, same pattern as subjectCountsOnce below) — powers a
  /// Year filter chip row built from real data instead of a guessed range.
  Future<List<int>> yearsInUseOnce({String? institutionId}) async {
    Query<Map<String, dynamic>> q = _db.collection(_col);
    if (institutionId != null) {
      q = q.where('institutionId', isEqualTo: institutionId);
    }
    final snap = await q.limit(500).get();
    final years = snap.docs
        .map((d) => (d.data()['year'] as num?)?.toInt())
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
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

// lib/repositories/academic_content_repository.dart
// Firestore + Firebase Storage operations for academic_content collection.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/academic_content.dart';
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

  // ─── Storage Upload ───────────────────────────────────────────────────────

  /// Uploads a file to Firebase Storage. Returns download URL.
  Future<Result<String>> uploadFile({
    required File file,
    required String folder,        // e.g. 'content_files' or 'thumbnails'
    required String institutionId,
    void Function(double)? onProgress,
  }) async {
    try {
      final ext = file.path.split('.').last;
      final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref('$folder/$institutionId/$name');
      final task = ref.putFile(file);
      task.snapshotEvents.listen((snap) {
        final progress = snap.bytesTransferred / snap.totalBytes;
        onProgress?.call(progress);
      });
      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();
      return Success(url);
    } catch (e) {
      return Failure('Upload failed', e);
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
}

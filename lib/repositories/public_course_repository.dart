// lib/repositories/public_course_repository.dart
// All reads/writes for the marketplace Courses system. Fully separate
// from CourseRepository (school-scoped) — different collection
// (public_courses vs courses), different model, no shared code.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/public_course.dart';
import '../core/constants.dart';
import '../core/result.dart';
import 'engagement_helper.dart';

/// Result of [PublicCourseRepository.continueReadingFor] — previous/next
/// lesson within the same topic sequence, plus the topic's full lesson
/// list for a "more in this topic" rail. Any of the lesson fields can be
/// null (e.g. this is the first/last lesson in the topic, or the course
/// isn't placed in the curriculum tree at all).
class CourseSequenceContext {
  final PublicCourse? previous;
  final PublicCourse? next;
  final List<PublicCourse> topicLessons;
  const CourseSequenceContext({this.previous, this.next, this.topicLessons = const []});
}

class PublicCourseRepository {
  PublicCourseRepository._();
  static final PublicCourseRepository instance = PublicCourseRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _courses =>
      _db.collection(AppConstants.colPublicCourses);

  // ── Feed queries ─────────────────────────────────────────

  Stream<List<PublicCourse>> watchLatest({int limit = 30}) => _courses
      .where('published', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(PublicCourse.fromFirestore).toList());

  Stream<List<PublicCourse>> watchByCategory(String category, {int limit = 30}) => _courses
      .where('published', isEqualTo: true)
      .where('category', isEqualTo: category)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(PublicCourse.fromFirestore).toList());

  Stream<List<PublicCourse>> watchByCreator(String creatorId) => _courses
      .where('creatorId', isEqualTo: creatorId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PublicCourse.fromFirestore).toList());

  Stream<PublicCourse?> watchOne(String courseId) => _courses
      .doc(courseId)
      .snapshots()
      .map((d) => d.exists ? PublicCourse.fromFirestore(d) : null);

  /// Featured — top-rated among reasonably-enrolled courses. Computed,
  /// not manually curated (same honesty principle as Magazine's Featured).
  Future<List<PublicCourse>> watchFeaturedOnce({int count = 6}) async {
    final snap = await _courses
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .get();
    final courses = snap.docs.map(PublicCourse.fromFirestore).toList()
      ..sort((a, b) {
        final scoreA = a.avgRating * 10 + a.enrolledCount * 0.1;
        final scoreB = b.avgRating * 10 + b.enrolledCount * 0.1;
        return scoreB.compareTo(scoreA);
      });
    return courses.take(count).toList();
  }

  /// Category counts for "Popular Topics" — computed client-side from a
  /// bounded sample. Fine at this scale; move to a scheduled aggregate
  /// if the catalogue grows into the thousands.
  Future<Map<String, int>> categoryCountsOnce() async {
    final snap = await _courses.where('published', isEqualTo: true).limit(500).get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final cat = doc.data()['category'] ?? 'Other';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  // ── Curriculum hierarchy ─────────────────────────────────
  // Category → Subject → Level → Topic → ordered lessons. Nothing here
  // is a fixed taxonomy table — subject/level/topic are free text on
  // each course, and these queries just derive the distinct values
  // that already exist, the same "grow from real data" approach as
  // categoryCountsOnce() above. Bounded client-side aggregation is
  // fine at this scale; revisit with a scheduled aggregate if the
  // catalogue grows into the thousands.

  /// Distinct subjects that already exist under [category].
  Future<List<String>> subjectsIn(String category) async {
    final snap = await _courses
        .where('published', isEqualTo: true)
        .where('category', isEqualTo: category)
        .limit(500)
        .get();
    return _distinctNonEmpty(snap.docs.map((d) => d.data()['subject'] as String?));
  }

  /// Distinct curriculum/levels that already exist under [category] + [subject].
  Future<List<String>> levelsIn(String category, String subject) async {
    final snap = await _courses
        .where('published', isEqualTo: true)
        .where('category', isEqualTo: category)
        .where('subject', isEqualTo: subject)
        .limit(500)
        .get();
    return _distinctNonEmpty(snap.docs.map((d) => d.data()['level'] as String?));
  }

  /// Distinct topics that already exist under category + subject + level.
  Future<List<String>> topicsIn(String category, String subject, String level) async {
    final snap = await _courses
        .where('published', isEqualTo: true)
        .where('category', isEqualTo: category)
        .where('subject', isEqualTo: subject)
        .where('level', isEqualTo: level)
        .limit(500)
        .get();
    return _distinctNonEmpty(snap.docs.map((d) => d.data()['topic'] as String?));
  }

  List<String> _distinctNonEmpty(Iterable<String?> values) {
    final set = <String>{};
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) set.add(v);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// The full, in-order lesson sequence for one topic — the "table of
  /// contents" for e.g. Social Studies → History → GCE Advanced Level →
  /// World War I in Cameroon. Ordered by the hidden `order` field.
  Future<List<PublicCourse>> topicSequence(String category, String subject, String level, String topic) async {
    final snap = await _courses
        .where('published', isEqualTo: true)
        .where('category', isEqualTo: category)
        .where('subject', isEqualTo: subject)
        .where('level', isEqualTo: level)
        .where('topic', isEqualTo: topic)
        .orderBy('order')
        .get();
    return snap.docs.map(PublicCourse.fromFirestore).toList();
  }

  /// Courses grouped into the curriculum tree, for the browse page —
  /// one query per distinct (category, subject, level, topic) isn't
  /// practical, so this pulls a bounded published set once and buckets
  /// it client-side. Courses missing any hierarchy field are omitted;
  /// they only show in the flat marketplace feed.
  Future<Map<String, Map<String, Map<String, Map<String, List<PublicCourse>>>>>> curriculumTreeOnce() async {
    final snap = await _courses.where('published', isEqualTo: true).limit(1000).get();
    final tree = <String, Map<String, Map<String, Map<String, List<PublicCourse>>>>>{};
    for (final doc in snap.docs) {
      final course = PublicCourse.fromFirestore(doc);
      if (!course.hasCurriculumPlacement) continue;
      final byCategory = tree.putIfAbsent(course.category, () => {});
      final bySubject = byCategory.putIfAbsent(course.subject, () => {});
      final byLevel = bySubject.putIfAbsent(course.level, () => {});
      final byTopic = byLevel.putIfAbsent(course.topic, () => []);
      byTopic.add(course);
    }
    for (final byCategory in tree.values) {
      for (final bySubject in byCategory.values) {
        for (final byLevel in bySubject.values) {
          for (final lessons in byLevel.values) {
            lessons.sort((a, b) => a.order.compareTo(b.order));
          }
        }
      }
    }
    return tree;
  }

  // ── Sequence placement — "where does this lesson belong?" ────────
  // Large gaps between positions (100, 200, 300…) so a new lesson can
  // be slotted in anywhere later without renumbering existing ones.
  // The composer never lets an author type a number directly — it
  // offers Before/Between/After choices against the existing sequence
  // and calls one of these to compute the hidden value.

  static const double _gap = 100;

  double positionAtStart(List<PublicCourse> existingSequence) =>
      existingSequence.isEmpty ? _gap : existingSequence.first.order - _gap;

  double positionAtEnd(List<PublicCourse> existingSequence) =>
      existingSequence.isEmpty ? _gap : existingSequence.last.order + _gap;

  double positionBetween(PublicCourse before, PublicCourse after) =>
      (before.order + after.order) / 2;

  /// Previous/next lesson relative to [course] within its own topic,
  /// plus the topic's full sequence. Returns an empty context (all
  /// nulls) if the course isn't placed in the curriculum tree.
  Future<CourseSequenceContext> continueReadingFor(PublicCourse course) async {
    if (!course.hasCurriculumPlacement) return const CourseSequenceContext();
    final sequence = await topicSequence(course.category, course.subject, course.level, course.topic);
    final index = sequence.indexWhere((c) => c.id == course.id);
    if (index == -1) return CourseSequenceContext(topicLessons: sequence);
    return CourseSequenceContext(
      previous: index > 0 ? sequence[index - 1] : null,
      next: index < sequence.length - 1 ? sequence[index + 1] : null,
      topicLessons: sequence,
    );
  }

  // ── CRUD ─────────────────────────────────────────────────

  Future<Result<String>> create(PublicCourse course) async {
    try {
      final ref = await _courses.add(course.toFirestore())
          .timeout(const Duration(seconds: 20), onTimeout: () => throw Exception(
              'Saving is taking too long. Check your connection and try again.'));
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to create course', e);
    }
  }

  Future<Result<void>> update(PublicCourse course) async {
    try {
      await _courses.doc(course.id).set(course.toFirestore(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 20), onTimeout: () => throw Exception(
              'Saving is taking too long. Check your connection and try again.'));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update course', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _courses.doc(id).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete course', e);
    }
  }

  Future<Result<String>> uploadCover({required String courseId, required File imageFile}) async {
    try {
      final ref = FirebaseStorage.instance.ref('course_covers/$courseId.jpg');
      await ref.putFile(imageFile)
          .timeout(const Duration(seconds: 60), onTimeout: () => throw Exception(
              'Image upload is taking too long. Check your connection and try again.'));
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload cover image', e);
    }
  }

  // ── Enrollment (learner count) ────────────────────────────
  // One doc per learner — existence prevents double-counting if someone
  // opens the course multiple times.

  Stream<bool> watchIsEnrolled(String courseId, String userId) => _courses
      .doc(courseId)
      .collection(AppConstants.colLearners)
      .doc(userId)
      .snapshots()
      .map((d) => d.exists);

  Future<Result<void>> markEnrolled(String courseId, String userId) async {
    try {
      final ref = _courses.doc(courseId).collection(AppConstants.colLearners).doc(userId);
      final existing = await ref.get();
      if (existing.exists) return const Success(null); // already counted
      final batch = _db.batch();
      batch.set(ref, {'startedAt': FieldValue.serverTimestamp()});
      batch.update(_courses.doc(courseId), {'enrolledCount': FieldValue.increment(1)});
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to record enrollment', e);
    }
  }

  // ── Ratings ──────────────────────────────────────────────
  // One rating per user; avgRating/ratingCount recomputed from the
  // ratings subcollection on every change (bounded, fine at this scale).

  Stream<int?> watchMyRating(String courseId, String userId) => _courses
      .doc(courseId)
      .collection(AppConstants.colRatings)
      .doc(userId)
      .snapshots()
      .map((d) => d.data()?['stars'] as int?);

  Future<Result<void>> rate(String courseId, String userId, int stars) async {
    try {
      final ratingsRef = _courses.doc(courseId).collection(AppConstants.colRatings);
      await ratingsRef.doc(userId).set({'stars': stars, 'ratedAt': FieldValue.serverTimestamp()});
      // Recompute the aggregate from all ratings — simple and correct,
      // avoids drift from incremental running-average math.
      final all = await ratingsRef.get();
      final starsList = all.docs.map((d) => (d.data()['stars'] as num).toDouble()).toList();
      final avg = starsList.isEmpty ? 0.0 : starsList.reduce((a, b) => a + b) / starsList.length;
      await _courses.doc(courseId).update({'avgRating': avg, 'ratingCount': starsList.length});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to submit rating', e);
    }
  }

  // ── Bookmarks (save to my list — not offline caching, just a marker) ──

  Stream<bool> watchIsBookmarked(String courseId, String userId) => EngagementHelper.watchIsSet(
      parentCollection: _courses, docId: courseId, subcollection: AppConstants.colBookmarks, userId: userId);

  Future<Result<void>> toggleBookmark(String courseId, String userId) => EngagementHelper.togglePresence(
      parentCollection: _courses, docId: courseId, subcollection: AppConstants.colBookmarks,
      userId: userId, failureMessage: 'Failed to update bookmark');

  /// A user's bookmarked courses — powers "My Saved Courses". Uses a
  /// collection-group query since bookmarks live per-course.
  Stream<List<PublicCourse>> watchBookmarkedCourses(String userId) {
    return _db
        .collectionGroup(AppConstants.colBookmarks)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final courseIds = snap.docs
          .map((d) => d.reference.parent.parent?.id)
          .whereType<String>()
          .toList();
      if (courseIds.isEmpty) return <PublicCourse>[];
      final courses = <PublicCourse>[];
      for (final id in courseIds.take(30)) {
        final doc = await _courses.doc(id).get();
        if (doc.exists) courses.add(PublicCourse.fromFirestore(doc));
      }
      return courses;
    });
  }

  // ── Likes (same shape as Magazine's) ──────────────────────

  Stream<bool> watchIsLiked(String courseId, String userId) => EngagementHelper.watchIsSet(
      parentCollection: _courses, docId: courseId, subcollection: AppConstants.colLikes, userId: userId);

  Future<Result<void>> toggleLike(String courseId, String userId) => EngagementHelper.toggleWithCounter(
      db: _db, parentCollection: _courses, docId: courseId, subcollection: AppConstants.colLikes,
      userId: userId, counterField: 'likeCount', failureMessage: 'Failed to update like');

  // ── Comments ───────────────────────────────────────────────

  Stream<List<CourseComment>> watchComments(String courseId) => _courses
      .doc(courseId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => CourseComment.fromFirestore(d, courseId)).toList());

  Future<Result<void>> postComment(CourseComment comment) async {
    try {
      final batch = _db.batch();
      final ref = _courses.doc(comment.courseId).collection('comments').doc();
      batch.set(ref, comment.toFirestore());
      batch.update(_courses.doc(comment.courseId), {'commentCount': FieldValue.increment(1)});
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post comment', e);
    }
  }
}

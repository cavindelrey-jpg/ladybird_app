// lib/repositories/public_course_repository.dart
// All reads/writes for the marketplace Courses system. Fully separate
// from CourseRepository (school-scoped) — different table (courses vs
// the school-scoped one), different model, no shared code.
//
// Several operations (toggle like/bookmark, mark enrolled, rate, post
// comment) are SECURITY DEFINER RPCs (see
// supabase/migrations/20260829240000_course_engagement.sql) since they
// pair a subtable write with a counter update on `courses` the way
// Firestore batches used to.

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/public_course.dart';
import '../core/result.dart';

/// Result of [PublicCourseRepository.continueReadingFor] — previous/next
/// lesson within the same topic sequence, plus the topic's full lesson
/// list for a "more in this topic" rail.
class CourseSequenceContext {
  final PublicCourse? previous;
  final PublicCourse? next;
  final List<PublicCourse> topicLessons;
  const CourseSequenceContext({this.previous, this.next, this.topicLessons = const []});
}

class PublicCourseRepository {
  PublicCourseRepository._();
  static final PublicCourseRepository instance = PublicCourseRepository._();

  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _courses => _db.from('courses');

  // ── Feed queries ─────────────────────────────────────────

  Stream<List<PublicCourse>> watchLatest({int limit = 30}) => _courses
      .stream(primaryKey: ['id'])
      .eq('published', true)
      .order('created_at', ascending: false)
      .limit(limit)
      .map((rows) => rows.map(PublicCourse.fromSupabase).toList());

  Stream<List<PublicCourse>> watchByCategory(String category, {int limit = 30}) => _courses
      .stream(primaryKey: ['id'])
      .eq('category', category)
      .order('created_at', ascending: false)
      .limit(limit)
      .map((rows) => rows
          .where((r) => r['published'] == true)
          .map(PublicCourse.fromSupabase)
          .toList());

  Stream<List<PublicCourse>> watchByCreator(String creatorId) => _courses
      .stream(primaryKey: ['id'])
      .eq('creator_id', creatorId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(PublicCourse.fromSupabase).toList());

  Stream<PublicCourse?> watchOne(String courseId) => _courses
      .stream(primaryKey: ['id'])
      .eq('id', courseId)
      .map((rows) => rows.isNotEmpty ? PublicCourse.fromSupabase(rows.first) : null);

  /// Featured — top-rated among reasonably-enrolled courses. Computed,
  /// not manually curated.
  Future<List<PublicCourse>> watchFeaturedOnce({int count = 6}) async {
    final rows = await _courses.select().eq('published', true).order('created_at', ascending: false).limit(60);
    final courses = rows.map(PublicCourse.fromSupabase).toList()
      ..sort((a, b) {
        final scoreA = a.avgRating * 10 + a.enrolledCount * 0.1;
        final scoreB = b.avgRating * 10 + b.enrolledCount * 0.1;
        return scoreB.compareTo(scoreA);
      });
    return courses.take(count).toList();
  }

  /// Category counts for "Popular Topics" — computed client-side from a
  /// bounded sample.
  Future<Map<String, int>> categoryCountsOnce() async {
    final rows = await _courses.select('category').eq('published', true).limit(500);
    final counts = <String, int>{};
    for (final row in rows) {
      final cat = row['category'] ?? 'Other';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  // ── Curriculum node icons ─────────────────────────────────────────

  static String subjectIconKey(String category, String subject) => 'subject::$category::$subject';
  static String levelIconKey(String category, String subject, String level) =>
      'level::$category::$subject::$level';
  static String topicIconKey(String category, String subject, String level, String topic) =>
      'topic::$category::$subject::$level::$topic';

  SupabaseQueryBuilder get _curriculumIcons => _db.from('curriculum_icons');

  /// All node->look assignments made so far.
  Future<Map<String, CurriculumIcon>> curriculumIconsOnce() async {
    final rows = await _curriculumIcons.select().limit(2000);
    return {
      for (final r in rows)
        r['key'] as String: CurriculumIcon(
          emoji: r['emoji'] as String? ?? '',
          imageUrl: r['image_url'] as String? ?? '',
        ),
    };
  }

  /// Assigns/updates the look for one tree node. Pass whichever of
  /// `emoji`/`imageUrl` the author picked; passing both empty clears
  /// the node back to the default letter-avatar.
  Future<void> setCurriculumIcon(String key, {String emoji = '', String imageUrl = ''}) async {
    if (emoji.isEmpty && imageUrl.isEmpty) {
      await _curriculumIcons.delete().eq('key', key);
    } else {
      await _curriculumIcons.upsert({'key': key, 'emoji': emoji, 'image_url': imageUrl});
    }
  }

  /// Uploads a photo for one Subject/Level/Topic node, returning its
  /// public URL. Storage path derived from the same tree-path key.
  Future<Result<String>> uploadCurriculumNodeImage({required String key, required File imageFile}) async {
    try {
      final docId = key.replaceAll('/', '-');
      final path = 'curriculum_icons/$docId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true))
          .timeout(const Duration(seconds: 60), onTimeout: () => throw Exception(
              'Image upload is taking too long. Check your connection and try again.'));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload image', e);
    }
  }

  // ── Curriculum hierarchy ─────────────────────────────────

  Future<List<String>> subjectsIn(String category) async {
    final rows = await _courses.select('subject').eq('published', true).eq('category', category).limit(500);
    return _distinctNonEmpty(rows.map((r) => r['subject'] as String?));
  }

  Future<List<String>> levelsIn(String category, String subject) async {
    final rows = await _courses
        .select('level').eq('published', true).eq('category', category).eq('subject', subject).limit(500);
    return _distinctNonEmpty(rows.map((r) => r['level'] as String?));
  }

  Future<List<String>> topicsIn(String category, String subject, String level) async {
    final rows = await _courses
        .select('topic')
        .eq('published', true).eq('category', category).eq('subject', subject).eq('level', level)
        .limit(500);
    return _distinctNonEmpty(rows.map((r) => r['topic'] as String?));
  }

  List<String> _distinctNonEmpty(Iterable<String?> values) {
    final set = <String>{};
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) set.add(v);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// The full, in-order lesson sequence for one topic.
  Future<List<PublicCourse>> topicSequence(String category, String subject, String level, String topic) async {
    final rows = await _courses
        .select()
        .eq('published', true).eq('category', category).eq('subject', subject)
        .eq('level', level).eq('topic', topic)
        .order('sort_order');
    return rows.map(PublicCourse.fromSupabase).toList();
  }

  /// Courses grouped into the curriculum tree, for the browse page.
  Future<Map<String, Map<String, Map<String, Map<String, List<PublicCourse>>>>>> curriculumTreeOnce() async {
    final rows = await _courses.select().eq('published', true).limit(1000);
    final tree = <String, Map<String, Map<String, Map<String, List<PublicCourse>>>>>{};
    for (final row in rows) {
      final course = PublicCourse.fromSupabase(row);
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

  // ── Course Navigation ("Section" tree) ────────────────────
  // Course Navigation unified onto the shared AcademicSection list (see
  // models/academic_section.dart / repositories/academic_section_repository.dart)
  // rather than growing its own separate tree — a course's [level] field
  // holds the section NAME (e.g. "Senior Secondary School") instead of a
  // free-text curriculum level, one tier shallower than the
  // Category/Subject/Level/Topic tree above (no separate Level tier,
  // since the section already IS that tier).

  static String navSubjectIconKey(String section, String subject) => 'navSubject::$section::$subject';
  static String navTopicIconKey(String section, String subject, String topic) =>
      'navTopic::$section::$subject::$topic';

  /// Distinct subjects that already exist under [section].
  Future<List<String>> subjectsInSection(String section) async {
    final rows = await _courses.select('subject').eq('published', true).eq('level', section).limit(500);
    return _distinctNonEmpty(rows.map((r) => r['subject'] as String?));
  }

  /// Distinct topics that already exist under [section] + [subject].
  Future<List<String>> topicsInSection(String section, String subject) async {
    final rows = await _courses
        .select('topic').eq('published', true).eq('level', section).eq('subject', subject).limit(500);
    return _distinctNonEmpty(rows.map((r) => r['topic'] as String?));
  }

  /// The full, in-order lesson sequence for one topic within [section] —
  /// same shape as [topicSequence], scoped by section instead of
  /// category+level.
  Future<List<PublicCourse>> topicSequenceInSection(String section, String subject, String topic) async {
    final rows = await _courses
        .select()
        .eq('published', true).eq('level', section).eq('subject', subject).eq('topic', topic)
        .order('sort_order');
    return rows.map(PublicCourse.fromSupabase).toList();
  }

  /// Real per-section course counts — powers the Course Navigation top
  /// grid's "N courses" line.
  Future<Map<String, int>> courseCountsBySection() async {
    final rows = await _courses.select('level').eq('published', true).limit(1000);
    final counts = <String, int>{};
    for (final row in rows) {
      final section = (row['level'] as String?) ?? '';
      if (section.isEmpty) continue;
      counts[section] = (counts[section] ?? 0) + 1;
    }
    return counts;
  }

  /// Real per-subject course counts within [section] — powers the
  /// Subject picker tier.
  Future<Map<String, int>> subjectCountsInSection(String section) async {
    final rows = await _courses.select('subject').eq('published', true).eq('level', section).limit(500);
    final counts = <String, int>{};
    for (final row in rows) {
      final subject = (row['subject'] as String?) ?? '';
      if (subject.isEmpty) continue;
      counts[subject] = (counts[subject] ?? 0) + 1;
    }
    return counts;
  }

  /// Real per-topic course counts within [section] + [subject] — powers
  /// the Topic picker tier.
  Future<Map<String, int>> topicCountsInSection(String section, String subject) async {
    final rows = await _courses
        .select('topic').eq('published', true).eq('level', section).eq('subject', subject).limit(500);
    final counts = <String, int>{};
    for (final row in rows) {
      final topic = (row['topic'] as String?) ?? '';
      if (topic.isEmpty) continue;
      counts[topic] = (counts[topic] ?? 0) + 1;
    }
    return counts;
  }

  // ── Sequence placement ────────────────────────────────────

  static const double _gap = 100;

  double positionAtStart(List<PublicCourse> existingSequence) =>
      existingSequence.isEmpty ? _gap : existingSequence.first.order - _gap;

  double positionAtEnd(List<PublicCourse> existingSequence) =>
      existingSequence.isEmpty ? _gap : existingSequence.last.order + _gap;

  double positionBetween(PublicCourse before, PublicCourse after) =>
      (before.order + after.order) / 2;

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
      final row = await _courses.insert(course.toSupabase()).select('id').single()
          .timeout(const Duration(seconds: 20), onTimeout: () => throw Exception(
              'Saving is taking too long. Check your connection and try again.'));
      return Success(row['id'] as String);
    } catch (e) {
      return Failure('Failed to create course', e);
    }
  }

  Future<Result<void>> update(PublicCourse course) async {
    try {
      await _courses.update(course.toSupabase()).eq('id', course.id)
          .timeout(const Duration(seconds: 20), onTimeout: () => throw Exception(
              'Saving is taking too long. Check your connection and try again.'));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update course', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _courses.delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete course', e);
    }
  }

  Future<Result<String>> uploadCover({required String courseId, required File imageFile}) async {
    try {
      final path = 'course_covers/$courseId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true))
          .timeout(const Duration(seconds: 60), onTimeout: () => throw Exception(
              'Image upload is taking too long. Check your connection and try again.'));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload cover image', e);
    }
  }

  // ── Enrollment (learner count) ────────────────────────────

  Stream<bool> watchIsEnrolled(String courseId, String userId) => _db
      .from('course_learners')
      .stream(primaryKey: ['course_id', 'user_id'])
      .eq('course_id', courseId)
      .map((rows) => rows.any((r) => r['user_id'] == userId));

  Future<Result<void>> markEnrolled(String courseId, String userId) async {
    try {
      await _db.rpc('mark_course_enrolled', params: {'p_course_id': courseId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to record enrollment', e);
    }
  }

  // ── Ratings ──────────────────────────────────────────────

  Stream<int?> watchMyRating(String courseId, String userId) => _db
      .from('course_ratings')
      .stream(primaryKey: ['course_id', 'user_id'])
      .eq('course_id', courseId)
      .map((rows) {
    final mine = rows.where((r) => r['user_id'] == userId);
    return mine.isEmpty ? null : mine.first['rating'] as int?;
  });

  Future<Result<void>> rate(String courseId, String userId, int stars) async {
    try {
      await _db.rpc('rate_course', params: {'p_course_id': courseId, 'p_rating': stars});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to submit rating', e);
    }
  }

  // ── Bookmarks ──────────────────────────────────────────────

  Stream<bool> watchIsBookmarked(String courseId, String userId) => _db
      .from('course_bookmarks')
      .stream(primaryKey: ['course_id', 'user_id'])
      .eq('course_id', courseId)
      .map((rows) => rows.any((r) => r['user_id'] == userId));

  Future<Result<void>> toggleBookmark(String courseId, String userId) async {
    try {
      await _db.rpc('toggle_course_bookmark', params: {'p_course_id': courseId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update bookmark', e);
    }
  }

  /// A user's bookmarked courses — powers "My Saved Courses".
  Stream<List<PublicCourse>> watchBookmarkedCourses(String userId) {
    return _db
        .from('course_bookmarks')
        .stream(primaryKey: ['course_id', 'user_id'])
        .eq('user_id', userId)
        .asyncMap((rows) async {
      final ids = rows.map((r) => r['course_id'] as String).toList();
      if (ids.isEmpty) return <PublicCourse>[];
      final courses = await _courses.select().inFilter('id', ids.take(30).toList());
      return courses.map(PublicCourse.fromSupabase).toList();
    });
  }

  // ── Likes ──────────────────────────────────────────────────

  Stream<bool> watchIsLiked(String courseId, String userId) => _db
      .from('course_likes')
      .stream(primaryKey: ['course_id', 'user_id'])
      .eq('course_id', courseId)
      .map((rows) => rows.any((r) => r['user_id'] == userId));

  Future<Result<void>> toggleLike(String courseId, String userId) async {
    try {
      await _db.rpc('toggle_course_like', params: {'p_course_id': courseId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  // ── Comments ───────────────────────────────────────────────

  Stream<List<CourseComment>> watchComments(String courseId) => _db
      .from('course_comments')
      .stream(primaryKey: ['id'])
      .eq('course_id', courseId)
      .order('created_at')
      .map((rows) => rows.map(CourseComment.fromSupabase).toList());

  Future<Result<void>> postComment(CourseComment comment) async {
    try {
      await _db.rpc('post_course_comment', params: {
        'p_course_id': comment.courseId,
        'p_author_id': comment.authorId,
        'p_author_name': comment.authorName,
        'p_author_photo_url': comment.authorPhotoUrl,
        'p_body': comment.body,
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post comment', e);
    }
  }
}

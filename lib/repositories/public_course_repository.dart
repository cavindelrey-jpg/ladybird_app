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

import 'dart:async';

import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/public_course.dart';
import '../core/core.dart';
import '../services/content_cache_service.dart';
import '../services/course_offline_service.dart';
import '../core/realtime_tolerant.dart';
import '../core/content_quality.dart';

/// Text a course actually carries -- plain body, or the Quill delta some
/// courses are stored in instead.
String _courseText(PublicCourse c) => c.body.trim().isNotEmpty ? c.body : (c.bodyDelta ?? '');

/// What students are shown: no stub/filler courses, and one copy of each
/// (title, subject, level) -- the most complete one.
List<PublicCourse> cleanCourses(Iterable<PublicCourse> courses) => dedupeBest(
      courses.where((c) => !isPlaceholderCourse(title: c.title, body: _courseText(c), description: c.description)),
      keyOf: (c) => '${c.title.trim().toLowerCase()}|${c.subject.trim().toLowerCase()}|${c.level.trim().toLowerCase()}',
      scoreOf: (c) => _courseText(c).length + (c.coverImageUrl == null ? 0 : 200) + c.enrolledCount * 50,
    );

/// One row of [PublicCourseRepository.levelsOnce] — a canonical education
/// level plus its live course count. Never hardcoded: `name` comes from
/// the `course_levels` table, `courseCount` from a real query.
class CourseLevelInfo {
  final String name;
  final int courseCount;
  const CourseLevelInfo({required this.name, required this.courseCount});
}

class PublicCourseRepository {
  PublicCourseRepository._();
  static final PublicCourseRepository instance = PublicCourseRepository._();

  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _courses => _db.from('courses');
  
  final _streamCache = StreamCache();
  final _memoizer = Memoizer();

  // ── Feed queries ─────────────────────────────────────────

  /// Cache-backed: offline (or a flaky reconnect), Realtime's `.stream()`
  /// below either never delivers a row or errors outright, which used to
  /// leave the Courses feed permanently empty with no way to tell that
  /// apart from "there really are no courses". Paints the last cached
  /// page instantly, replaces it with a fresh fetch as soon as one
  /// succeeds, then layers live updates on top — a Realtime error is
  /// swallowed (the cached/fetched list keeps showing), never forwarded.
  Stream<List<PublicCourse>> watchLatest({int limit = 30}) {
    const cacheKey = 'courses_latest';
    final controller = StreamController<List<PublicCourse>>();

    Future<void> emitCacheThenFetch() async {
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && !controller.isClosed) {
        controller.add(cleanCourses(cached.map(PublicCourse.fromSupabase)));
      }
      try {
        final rows = await _courses
            .select()
            .eq('published', true)
            .order('created_at', ascending: false)
            .limit(limit);
        if (controller.isClosed) return;
        final list = List<Map<String, dynamic>>.from(rows);
        unawaited(ContentCacheService.instance.putList(cacheKey, list));
        controller.add(cleanCourses(list.map(PublicCourse.fromSupabase)));
      } catch (e, st) {
        if (controller.isClosed) return;
        if (cached != null) {
          // Already showing something real (offline/flaky reconnect) --
          // keep it, don't replace a good state with an error.
          return;
        }
        // No cache to fall back on: this is the FIRST fetch ever failing
        // (RLS denial, wrong query, genuine outage) -- forwarding it as a
        // real stream error, instead of silently doing nothing, is what
        // lets CoursesMarketplacePage's own snap.hasError branch show
        // "Failed to load: ..." instead of an infinite loading shimmer
        // that looks identical to "nothing happens when I open Courses".
        controller.addError(e, st);
      }
    }

    unawaited(emitCacheThenFetch());

    final sub = _courses
        .stream(primaryKey: ['id'])
        .eq('published', true)
        .order('created_at', ascending: false)
        .limit(limit)
        .realtimeTolerant()
        .listen(
          (rows) {
            if (controller.isClosed) return;
            final list = List<Map<String, dynamic>>.from(rows);
            unawaited(ContentCacheService.instance.putList(cacheKey, list));
            controller.add(cleanCourses(list.map(PublicCourse.fromSupabase)));
          },
          onError: (_) {
            // Realtime disconnected/errored -- keep showing whatever was
            // last emitted, don't propagate.
          },
        );

    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  Stream<List<PublicCourse>> watchByCategory(String category, {int limit = 30}) => _streamCache.watch(
      'watchByCategory_${category}_$limit',
      () => _courses
          .stream(primaryKey: ['id'])
          .eq('category', category)
          .order('created_at', ascending: false)
          .limit(limit)
          .realtimeTolerant()
          .map((rows) => cleanCourses(rows
              .where((r) => r['published'] == true)
              .map(PublicCourse.fromSupabase))));

  Stream<List<PublicCourse>> watchByCreator(String creatorId) => _streamCache.watch(
      'watchByCreator_$creatorId',
      () => _courses
          .stream(primaryKey: ['id'])
          .eq('creator_id', creatorId)
          .order('created_at', ascending: false)
          .realtimeTolerant()
          .map((rows) => rows.map(PublicCourse.fromSupabase).toList()));

  Stream<PublicCourse?> watchOne(String courseId) => _streamCache.watch(
      'watchOne_$courseId',
      () => _courses
          .stream(primaryKey: ['id'])
          .eq('id', courseId)
          .realtimeTolerant()
          .map((rows) => rows.isNotEmpty ? PublicCourse.fromSupabase(rows.first) : null));

  /// Featured — top-rated among reasonably-enrolled courses. Computed,
  /// not manually curated.
  Future<List<PublicCourse>> watchFeaturedOnce({int count = 6}) async {
    return _memoizer.runOnce('watchFeaturedOnce_$count', () async {
      final rows = await _courses.select().eq('published', true).order('created_at', ascending: false).limit(60);
      final courses = cleanCourses(rows.map(PublicCourse.fromSupabase))
        ..sort((a, b) {
          final scoreA = a.avgRating * 10 + a.enrolledCount * 0.1;
          final scoreB = b.avgRating * 10 + b.enrolledCount * 0.1;
          return scoreB.compareTo(scoreA);
        });
      return courses.take(count).toList();
    });
  }

  /// Category counts for "Popular Topics" — computed client-side from a
  /// bounded sample.
  Future<Map<String, int>> categoryCountsOnce() async {
    return _memoizer.runOnce('categoryCountsOnce', () async {
      final rows = await _courses.select().eq('published', true).limit(5000);
      final counts = <String, int>{};
      for (final c in cleanCourses(rows.map(PublicCourse.fromSupabase))) {
        final cat = c.subject.trim().isEmpty ? 'Other' : c.subject;
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ── Curriculum node icons ─────────────────────────────────────────
  // Key formats for the Level -> Subject -> Topic hierarchy live further
  // down, under "Information architecture node icons" —
  // eduLevelIconKey/eduSubjectIconKey/eduTopicIconKey.

  SupabaseQueryBuilder get _curriculumIcons => _db.from('curriculum_icons');

  /// All node->look assignments made so far.
  Future<Map<String, CurriculumIcon>> curriculumIconsOnce() async {
    return _memoizer.runOnce('curriculumIconsOnce', () async {
      final rows = await _curriculumIcons.select().limit(2000);
      return {
        for (final r in rows)
          r['key'] as String: CurriculumIcon(
            emoji: r['emoji'] as String? ?? '',
            imageUrl: r['image_url'] as String? ?? '',
          ),
      };
    });
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
    _memoizer.clear();
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

  // ── Information architecture: Level -> Subject -> Topic -> Course ──
  // Level = courses.level, Subject = courses.category, Topic = courses.topic.
  // Level already held the AcademicSection name here (Course Navigation's
  // old scheme) — this migration just gives it a canonical, ordered source
  // table (course_levels) instead of ad hoc section names. The old
  // `subject` field (Category -> Subject -> Level -> Topic) and the
  // Section-based methods that powered course_navigation_page.dart (now
  // removed) are no longer part of the browse hierarchy.

  SupabaseQueryBuilder get _courseLevels => _db.from('course_levels');

  /// The 5 canonical levels in order, each with its live course count.
  /// Never a hardcoded list — reads whatever admins have configured.
  Future<List<CourseLevelInfo>> levelsOnce() async {
    return _memoizer.runOnce('levelsOnce', () async {
      final results = await Future.wait([
        _courseLevels.select().order('sort_order', ascending: true),
        _courses.select().eq('published', true).limit(5000),
      ]);
      final levelRows = results[0] as List<Map<String, dynamic>>;
      // Count only what students can actually see (no filler, de-duplicated),
      // so the level tiles' numbers match the lists behind them.
      final courses = cleanCourses((results[1] as List<Map<String, dynamic>>).map(PublicCourse.fromSupabase));
      final counts = <String, int>{};
      for (final c in courses) {
        if (c.level.trim().isNotEmpty) counts[c.level] = (counts[c.level] ?? 0) + 1;
      }
      return levelRows
          .map((r) => CourseLevelInfo(name: r['name'] as String, courseCount: counts[r['name']] ?? 0))
          .toList();
    });
  }

  Future<List<String>> subjectsInLevel(String level) async {
    return _memoizer.runOnce('subjectsInLevel_$level', () async {
      final rows = await _courses.select().eq('published', true).eq('level', level).limit(5000);
      return _distinctNonEmpty(cleanCourses(rows.map(PublicCourse.fromSupabase)).map((c) => c.subject));
    });
  }

  Future<Map<String, int>> subjectCountsInLevel(String level) async {
    return _memoizer.runOnce('subjectCountsInLevel_$level', () async {
      final rows = await _courses.select().eq('published', true).eq('level', level).limit(5000);
      return _countBy(cleanCourses(rows.map(PublicCourse.fromSupabase)).map((c) => c.subject));
    });
  }

  Future<List<String>> topicsInSubject(String level, String subject) async {
    return _memoizer.runOnce('topicsInSubject_${level}_$subject', () async {
      final rows = await _courses
          .select().eq('published', true).eq('level', level).eq('category', subject).limit(5000);
      return _distinctNonEmpty(cleanCourses(rows.map(PublicCourse.fromSupabase)).map((c) => c.topic));
    });
  }

  Future<Map<String, int>> topicCountsInSubject(String level, String subject) async {
    return _memoizer.runOnce('topicCountsInSubject_${level}_$subject', () async {
      final rows = await _courses
          .select().eq('published', true).eq('level', level).eq('category', subject).limit(5000);
      return _countBy(cleanCourses(rows.map(PublicCourse.fromSupabase)).map((c) => c.topic));
    });
  }

  Future<List<PublicCourse>> coursesInTopic(String level, String subject, String topic) async {
    return _memoizer.runOnce('coursesInTopic_${level}_${subject}_$topic', () async {
      final rows = await _courses
          .select()
          .eq('published', true).eq('level', level).eq('category', subject).eq('topic', topic)
          .order('sort_order', ascending: true);
      return cleanCourses(rows.map(PublicCourse.fromSupabase));
    });
  }

  Map<String, int> _countBy(Iterable<String?> values) {
    final counts = <String, int>{};
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) counts[v] = (counts[v] ?? 0) + 1;
    }
    return counts;
  }

  List<String> _distinctNonEmpty(Iterable<String?> values) {
    final set = <String>{};
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) set.add(v);
    }
    final list = set.toList()..sort();
    return list;
  }

  // ── Information architecture node icons ─────────────────────────────
  // Reuses the existing curriculum_icons lookup with new key formats for
  // the new 3-tier hierarchy — distinct prefixes from the old
  // navSubjectIconKey/navTopicIconKey so old and new rows can never
  // collide even though both live in the same table.

  static String eduLevelIconKey(String level) => 'edu_level::$level';
  static String eduSubjectIconKey(String level, String subject) => 'edu_subject::$level::$subject';
  static String eduTopicIconKey(String level, String subject, String topic) =>
      'edu_topic::$level::$subject::$topic';

  // ── Recommendations & recent reads ──────────────────────────────────

  Future<void> recordCourseView(String courseId, String userId) async {
    try {
      await _db.from('course_recent_views').upsert(
        {'course_id': courseId, 'user_id': userId, 'viewed_at': DateTime.now().toIso8601String()},
        onConflict: 'course_id,user_id',
      );
    } catch (_) {
      // best-effort — a failed recency update shouldn't block viewing the course
    }
  }

  /// Most-recently-opened courses for this user — powers Courses Home
  /// "Recent Reads".
  Stream<List<PublicCourse>> watchRecentlyViewedCourses(String userId, {int limit = 10}) {
    return _db
        .from('course_recent_views')
        .stream(primaryKey: ['course_id', 'user_id'])
        .eq('user_id', userId)
        .realtimeTolerant()
        .asyncMap((rows) async {
      final sorted = rows.toList()
        ..sort((a, b) => (b['viewed_at'] as String).compareTo(a['viewed_at'] as String));
      final ids = sorted.take(limit).map((r) => r['course_id'] as String).toList();
      if (ids.isEmpty) return <PublicCourse>[];
      final courses = await _courses.select().inFilter('id', ids);
      final byId = {for (final c in courses) c['id'] as String: c};
      return ids.where(byId.containsKey).map((id) => PublicCourse.fromSupabase(byId[id]!)).toList();
    });
  }

  /// Courses matching the subjects/topics this user has actually engaged
  /// with, ranked by rating/enrollment, then rotated with a date-seeded
  /// shuffle so the set visibly changes day to day without being random
  /// noise. Falls back to latest/most-enrolled for guests or users with no
  /// history yet — never a fabricated or hardcoded list.
  Future<List<PublicCourse>> recommendedForUser(String? userId, {int limit = 5}) async {
    final cacheKey = 'courses_recommended_${userId ?? "all"}';
    try {
      final pool = await _courses.select().eq('published', true).order('created_at', ascending: false).limit(200);
      var courses = cleanCourses(pool.map(PublicCourse.fromSupabase));
      if (courses.isEmpty) return const [];

      Set<String> subjects = {};
      if (userId != null) {
        final recentRows = await _db
            .from('course_recent_views')
            .select('course_id')
            .eq('user_id', userId)
            .order('viewed_at', ascending: false)
            .limit(20);
        final recentIds = recentRows.map((r) => r['course_id'] as String).toSet();
        subjects = courses.where((c) => recentIds.contains(c.id) && c.category.isNotEmpty)
            .map((c) => c.category).toSet();
      }

      final scored = courses.where((c) => subjects.isEmpty || subjects.contains(c.category)).toList();
      final candidates = scored.length >= limit ? scored : courses;
      candidates.sort((a, b) {
        final scoreA = a.avgRating * 10 + a.enrolledCount * 0.1;
        final scoreB = b.avgRating * 10 + b.enrolledCount * 0.1;
        return scoreB.compareTo(scoreA);
      });
      final top = candidates.take(limit * 3).toList();
      final seed = DateTime.now().difference(DateTime(2020)).inDays + (userId?.hashCode ?? 0);
      top.shuffle(Random(seed));
      final result = top.take(limit).toList();
      unawaited(ContentCacheService.instance.putList(cacheKey, result.map((e) => e.toSupabase()).toList()));
      return result;
    } catch (_) {
      // Offline fallback: try cache, then downloaded courses
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cleanCourses(cached.map(PublicCourse.fromSupabase)).take(limit).toList();
      }
      final downloaded = await CourseOfflineService.instance.getDownloadedCourses();
      return downloaded.take(limit).toList();
    }
  }

  // ── Sequence placement ────────────────────────────────────

  static const double _gap = 100;

  double positionAtStart(List<PublicCourse> existingSequence) =>
      existingSequence.isEmpty ? _gap : existingSequence.first.order - _gap;

  double positionAtEnd(List<PublicCourse> existingSequence) =>
      existingSequence.isEmpty ? _gap : existingSequence.last.order + _gap;

  double positionBetween(PublicCourse before, PublicCourse after) =>
      (before.order + after.order) / 2;

  // ── CRUD ─────────────────────────────────────────────────

  Future<Result<String>> create(PublicCourse course) async {
    try {
      final row = await _courses.insert(course.toSupabase()).select('id').single()
          .timeout(const Duration(seconds: 20), onTimeout: () => throw Exception(
              'Saving is taking too long. Check your connection and try again.'));
      _memoizer.clear();
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
      _memoizer.clear();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update course', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _courses.delete().eq('id', id);
      _memoizer.clear();
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
      .realtimeTolerant()
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
      .realtimeTolerant()
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
      .realtimeTolerant()
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
        .realtimeTolerant()
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
      .realtimeTolerant()
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
      .realtimeTolerant()
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

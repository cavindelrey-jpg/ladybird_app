// lib/repositories/course_lesson_repository.dart
// Lessons inside one marketplace Course — see models/course_lesson.dart for
// why this is a separate table from `courses` rather than more columns on
// it. Mirrors PublicCourseRepository's CRUD/Result/ordering conventions.

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course_lesson.dart';
import '../core/core.dart';
import '../core/realtime_tolerant.dart';
import '../services/course_offline_service.dart';

class CourseLessonRepository {
  CourseLessonRepository._();
  static final CourseLessonRepository instance = CourseLessonRepository._();

  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _lessons => _db.from('course_lessons');

  final _memoizer = Memoizer();
  final _streamCache = StreamCache();

  Stream<List<CourseLesson>> watchLessons(String courseId) => _streamCache.watch(
      'watchLessons_$courseId',
      () {
        final controller = StreamController<List<CourseLesson>>();

        () async {
          // 1. Immediately emit offline lessons (0ms) so user never sees an endless spinner offline
          final offline = await CourseOfflineService.instance.getOfflineLessons(courseId);
          if (offline.isNotEmpty && !controller.isClosed) {
            controller.add(offline);
          }

          // 2. Fetch live lessons
          try {
            final rows = await _lessons
                .select()
                .eq('course_id', courseId)
                .order('sort_order', ascending: true);
            if (rows.isNotEmpty && !controller.isClosed) {
              controller.add(rows.map(CourseLesson.fromSupabase).toList());
            }
          } catch (_) {
            if (offline.isEmpty && !controller.isClosed) {
              final fallback = await CourseOfflineService.instance.getOfflineLessons(courseId);
              controller.add(fallback);
            }
          }

          // 3. Listen to realtime stream
          final sub = _lessons
              .stream(primaryKey: ['id'])
              .eq('course_id', courseId)
              .order('sort_order', ascending: true)
              .realtimeTolerant()
              .listen(
                (rows) {
                  if (rows.isNotEmpty && !controller.isClosed) {
                    controller.add(rows.map(CourseLesson.fromSupabase).toList());
                  }
                },
                onError: (_) {
                  // Realtime failed / offline -- keep showing cached lessons!
                },
              );
          controller.onCancel = () => sub.cancel();
        }();

        return controller.stream;
      });

  Future<List<CourseLesson>> lessonsOnce(String courseId) async {
    return _memoizer.runOnce('lessonsOnce_$courseId', () async {
      try {
        final rows = await _lessons.select().eq('course_id', courseId).order('sort_order', ascending: true);
        if (rows.isNotEmpty) {
          return rows.map(CourseLesson.fromSupabase).toList();
        }
      } catch (_) {}
      final offline = await CourseOfflineService.instance.getOfflineLessons(courseId);
      return offline;
    });
  }

  Stream<CourseLesson?> watchOne(String lessonId) => _streamCache.watch(
      'watchOne_$lessonId',
      () => _lessons
          .stream(primaryKey: ['id'])
          .eq('id', lessonId)
          .realtimeTolerant()
          .map((rows) => rows.isNotEmpty ? CourseLesson.fromSupabase(rows.first) : null));

  // ── Sequence placement — same gap-of-100 pattern as PublicCourseRepository ──

  static const double _gap = 100;

  double positionAtStart(List<CourseLesson> existingSequence) =>
      existingSequence.isEmpty ? _gap : existingSequence.first.order - _gap;

  double positionAtEnd(List<CourseLesson> existingSequence) =>
      existingSequence.isEmpty ? _gap : existingSequence.last.order + _gap;

  double positionBetween(CourseLesson before, CourseLesson after) =>
      (before.order + after.order) / 2;

  /// Previous/next lesson relative to [lessonId] within [courseId]'s
  /// ordered sequence — powers "Continue Lesson" navigation.
  Future<({CourseLesson? previous, CourseLesson? next})> adjacentTo(String courseId, String lessonId) async {
    final sequence = await lessonsOnce(courseId);
    final index = sequence.indexWhere((l) => l.id == lessonId);
    if (index == -1) return (previous: null, next: null);
    return (
      previous: index > 0 ? sequence[index - 1] : null,
      next: index < sequence.length - 1 ? sequence[index + 1] : null,
    );
  }

  // ── CRUD ─────────────────────────────────────────────────

  Future<Result<String>> create(CourseLesson lesson) async {
    try {
      final row = await _lessons.insert(lesson.toSupabase()).select('id').single()
          .timeout(const Duration(seconds: 20), onTimeout: () => throw Exception(
              'Saving is taking too long. Check your connection and try again.'));
      _memoizer.clear();
      return Success(row['id'] as String);
    } catch (e) {
      return Failure('Failed to create lesson', e);
    }
  }

  Future<Result<void>> update(CourseLesson lesson) async {
    try {
      await _lessons.update(lesson.toSupabase()).eq('id', lesson.id)
          .timeout(const Duration(seconds: 20), onTimeout: () => throw Exception(
              'Saving is taking too long. Check your connection and try again.'));
      _memoizer.clear();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update lesson', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _lessons.delete().eq('id', id);
      _memoizer.clear();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete lesson', e);
    }
  }

  Future<Result<String>> uploadCover({required String lessonId, required File imageFile}) async {
    try {
      final path = 'lesson_covers/$lessonId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true))
          .timeout(const Duration(seconds: 60), onTimeout: () => throw Exception(
              'Image upload is taking too long. Check your connection and try again.'));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload cover image', e);
    }
  }

  Future<Result<String>> uploadVideo({required String lessonId, required File videoFile}) async {
    try {
      final ext = videoFile.path.split('.').last;
      final path = 'lesson_videos/$lessonId.$ext';
      await _db.storage.from(_bucket).upload(path, videoFile, fileOptions: const FileOptions(upsert: true))
          .timeout(const Duration(minutes: 5), onTimeout: () => throw Exception(
              'Video upload is taking too long. Check your connection and try again.'));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload video', e);
    }
  }

  /// Best-effort view-count bump — never blocks watching/reading the lesson.
  Future<void> incrementView(String lessonId) async {
    try {
      await _db.rpc('increment_lesson_view', params: {'p_lesson_id': lessonId});
    } catch (_) {
      // best-effort
    }
  }
}

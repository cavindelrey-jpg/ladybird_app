// lib/repositories/exam_repository.dart
// Production-ready repository for Question Bank, Collections, Exam Composer,
// and School Exam Templates. Supports online Supabase persistence with local
// SQLite cache fallback, and integrates with Academia Library resources.

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local_database.dart';
import '../models/exam_question.dart';
import '../models/examination.dart';
import '../services/exam_content_indexer_service.dart';
import '../core/realtime_tolerant.dart';
import '../config/branding.dart';

class ExamRepository {
  ExamRepository._();
  static final ExamRepository instance = ExamRepository._();

  final SupabaseClient _db = Supabase.instance.client;

  // ─── Examinations ─────────────────────────────────────────────────────────

  Stream<List<Examination>> watchExaminations({
    required String schoolId,
    String? teacherId,
  }) async* {
    if (schoolId.isEmpty) {
      yield const [];
      return;
    }

    // 1. Offline-first: render the locally cached state immediately, without
    //    waiting for the network (see FIX 3, AUTOPILOT_LOG).
    final cached = await _getLocalExaminations(schoolId, teacherId);
    if (cached.isNotEmpty) yield cached;

    // 2. Then sync in the background from the live stream, which refreshes the
    //    cache and the UI. Errors are swallowed so offline use stays silent.
    yield* _db
        .from('examinations')
        .stream(primaryKey: ['id'])
        .eq('school_id', schoolId)
        .order('updated_at', ascending: false)
        .realtimeTolerant()
        .asyncMap((rows) async {
      try {
        final list = rows
            .map((r) => Examination.fromJson(r))
            .where((e) => teacherId == null || e.examinerId == teacherId || e.examinerId.isEmpty)
            .toList();

        // Cache locally for offline use
        for (final exam in list) {
          await LocalDatabase.instance.cacheData('examinations', exam.id, exam.toJson());
        }
        return list;
      } catch (_) {
        // Fall back to local SQLite cache
        return _getLocalExaminations(schoolId, teacherId);
      }
    }).handleError((_) {});
  }

  Future<List<Examination>> _getLocalExaminations(String schoolId, String? teacherId) async {
    try {
      final cached = await LocalDatabase.instance.getCachedCollection('examinations');
      return cached
          .map(Examination.fromJson)
          .where((e) => e.schoolId == schoolId && (teacherId == null || e.examinerId == teacherId))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Examination?> getExamination(String examId) async {
    if (examId.isEmpty) return null;
    try {
      final row = await _db.from('examinations').select().eq('id', examId).maybeSingle();
      if (row != null) {
        final exam = Examination.fromJson(row);
        await LocalDatabase.instance.cacheData('examinations', exam.id, exam.toJson());
        return exam;
      }
    } catch (_) {}

    // Fall back to local cache
    final local = await LocalDatabase.instance.getCachedData('examinations', examId);
    if (local != null) return Examination.fromJson(local);
    return null;
  }

  Future<bool> saveExamination(Examination exam) async {
    final json = exam.toJson();
    await LocalDatabase.instance.cacheData('examinations', exam.id, json);

    try {
      await _db.from('examinations').upsert(json, onConflict: 'id');
      return true;
    } catch (e) {
      // Queue offline sync
      await LocalDatabase.instance.queueSyncAction('upsert', 'examinations', exam.id, json);
      return false;
    }
  }

  Future<bool> deleteExamination(String examId) async {
    await LocalDatabase.instance.deleteCachedData('examinations', examId);
    try {
      await _db.from('examinations').delete().eq('id', examId);
    } catch (_) {
      await LocalDatabase.instance.queueSyncAction('delete', 'examinations', examId, {});
    }
    return true;
  }

  // ─── Question Collections ──────────────────────────────────────────────────

  Stream<List<QuestionCollection>> watchCollections({
    required String schoolId,
    required String teacherId,
  }) async* {
    if (schoolId.isEmpty || teacherId.isEmpty) {
      yield const [];
      return;
    }

    // Offline-first: emit cached collections immediately, then sync live.
    final cached = await _getLocalCollections(schoolId, teacherId);
    if (cached.isNotEmpty) yield cached;

    yield* _db
        .from('question_collections')
        .stream(primaryKey: ['id'])
        .eq('teacher_id', teacherId)
        .order('updated_at', ascending: false)
        .realtimeTolerant()
        .asyncMap((rows) async {
      try {
        final list = rows
            .map((r) => QuestionCollection.fromJson(r))
            .where((c) => c.schoolId == schoolId)
            .toList();

        for (final col in list) {
          await LocalDatabase.instance.cacheData('question_collections', col.id, col.toJson());
        }
        return list;
      } catch (_) {
        return _getLocalCollections(schoolId, teacherId);
      }
    }).handleError((_) {});
  }

  Future<List<QuestionCollection>> _getLocalCollections(String schoolId, String teacherId) async {
    try {
      final cached = await LocalDatabase.instance.getCachedCollection('question_collections');
      return cached
          .map(QuestionCollection.fromJson)
          .where((c) => c.schoolId == schoolId && c.teacherId == teacherId)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveCollection(QuestionCollection collection) async {
    final json = collection.toJson();
    await LocalDatabase.instance.cacheData('question_collections', collection.id, json);

    try {
      await _db.from('question_collections').upsert(json, onConflict: 'id');
      return true;
    } catch (e) {
      await LocalDatabase.instance.queueSyncAction('upsert', 'question_collections', collection.id, json);
      return false;
    }
  }

  Future<bool> deleteCollection(String collectionId) async {
    await LocalDatabase.instance.deleteCachedData('question_collections', collectionId);
    try {
      await _db.from('question_collections').delete().eq('id', collectionId);
    } catch (_) {
      await LocalDatabase.instance.queueSyncAction('delete', 'question_collections', collectionId, {});
    }
    return true;
  }

  // ─── Question Bank & Academia Library Integration ──────────────────────────

  Future<bool> saveQuestionToBank(ExamQuestion question) async {
    final json = question.toJson();
    await LocalDatabase.instance.cacheData('question_bank', question.id, json);

    try {
      await _db.from('question_bank').upsert(json, onConflict: 'id');
      return true;
    } catch (e) {
      await LocalDatabase.instance.queueSyncAction('upsert', 'question_bank', question.id, json);
      return false;
    }
  }

  /// Searches the Question Bank, Teacher Collections, and authorized Academia Library resources
  /// with intelligent multi-dimensional filtering.
  Future<List<ExamQuestion>> searchQuestionBank({
    required String schoolId,
    String? query,
    String? subject,
    String? classLevel,
    String? topic,
    String? subtopic,
    String? difficulty,
    String? source,
    int? year,
    int? minMarks,
    int? maxMarks,
  }) async {
    final results = <ExamQuestion>[];
    final qLower = (query ?? '').toLowerCase().trim();

    // 1. Fetch from database question_bank
    try {
      var dbQuery = _db.from('question_bank').select();
      if (subject != null && subject.isNotEmpty) {
        dbQuery = dbQuery.eq('subject', subject);
      }
      final rows = await dbQuery.limit(100);
      for (final r in rows) {
        results.add(ExamQuestion.fromJson(r));
      }
    } catch (_) {
      // Load from local SQLite cache
      final local = await LocalDatabase.instance.getCachedCollection('question_bank');
      results.addAll(local.map(ExamQuestion.fromJson));
    }

    // 2. Search indexed PDF/EPUB past papers and Academia Library resources
    try {
      final libraryQuestions = await ExamContentIndexerService.instance.searchIndexedLibraryQuestions(
        schoolId: schoolId,
        query: query,
        subject: subject,
        classLevel: classLevel,
        year: year,
        difficulty: difficulty,
      );
      results.addAll(libraryQuestions);
    } catch (_) {}

    // 3. Apply intelligent multi-field filtering. If nothing matches, the UI
    //    shows its empty state — we never fabricate placeholder questions
    //    (see FIX 1, AUTOPILOT_LOG).
    return results.where((q) {
      if (qLower.isNotEmpty) {
        final matches = q.content.toLowerCase().contains(qLower) ||
            q.topic.toLowerCase().contains(qLower) ||
            q.subtopic.toLowerCase().contains(qLower) ||
            q.source.toLowerCase().contains(qLower);
        if (!matches) return false;
      }

      if (subject != null && subject.isNotEmpty && q.subject.isNotEmpty) {
        if (!q.subject.toLowerCase().contains(subject.toLowerCase())) return false;
      }

      if (classLevel != null && classLevel.isNotEmpty && q.classLevel.isNotEmpty) {
        if (!q.classLevel.toLowerCase().contains(classLevel.toLowerCase())) return false;
      }

      if (topic != null && topic.isNotEmpty) {
        if (!q.topic.toLowerCase().contains(topic.toLowerCase())) return false;
      }

      if (subtopic != null && subtopic.isNotEmpty) {
        if (!q.subtopic.toLowerCase().contains(subtopic.toLowerCase())) return false;
      }

      if (difficulty != null && difficulty.isNotEmpty) {
        if (q.difficulty.toLowerCase() != difficulty.toLowerCase()) return false;
      }

      if (source != null && source.isNotEmpty) {
        if (!q.source.toLowerCase().contains(source.toLowerCase())) return false;
      }

      if (year != null && q.year != null) {
        if (q.year != year) return false;
      }

      if (minMarks != null && q.marks < minMarks) return false;
      if (maxMarks != null && q.marks > maxMarks) return false;

      return true;
    }).toList();
  }

  // ─── School Exam Templates & Digital Letterheads ───────────────────────────

  Stream<List<SchoolExamTemplate>> watchSchoolTemplates(String schoolId) async* {
    if (schoolId.isEmpty) {
      yield const [];
      return;
    }

    // Offline-first: emit cached templates (falling back to the built-in
    // default letterhead) immediately, then sync live.
    yield await _getLocalTemplates(schoolId);

    yield* _db
        .from('school_exam_templates')
        .stream(primaryKey: ['id'])
        .eq('school_id', schoolId)
        .realtimeTolerant()
        .asyncMap((rows) async {
      try {
        final list = rows.map((r) => SchoolExamTemplate.fromJson(r)).toList();
        if (list.isEmpty) {
          return [getDefaultTemplate(schoolId)];
        }
        for (final tmpl in list) {
          await LocalDatabase.instance.cacheData('school_exam_templates', tmpl.id, tmpl.toJson());
        }
        return list;
      } catch (_) {
        return _getLocalTemplates(schoolId);
      }
    }).handleError((_) {});
  }

  Future<List<SchoolExamTemplate>> _getLocalTemplates(String schoolId) async {
    try {
      final cached = await LocalDatabase.instance.getCachedCollection('school_exam_templates');
      final list = cached.map(SchoolExamTemplate.fromJson).where((t) => t.schoolId == schoolId).toList();
      return list.isNotEmpty ? list : [getDefaultTemplate(schoolId)];
    } catch (_) {
      return [getDefaultTemplate(schoolId)];
    }
  }

  Future<bool> saveSchoolTemplate(SchoolExamTemplate template) async {
    final json = template.toJson();
    await LocalDatabase.instance.cacheData('school_exam_templates', template.id, json);

    try {
      await _db.from('school_exam_templates').upsert(json, onConflict: 'id');
      return true;
    } catch (e) {
      await LocalDatabase.instance.queueSyncAction('upsert', 'school_exam_templates', template.id, json);
      return false;
    }
  }

  SchoolExamTemplate getDefaultTemplate(String schoolId, {String? schoolName}) {
    final effectiveName = (schoolName != null && schoolName.isNotEmpty)
        ? schoolName
        : Branding.current.appName;
    final effectiveId = schoolId.isNotEmpty ? schoolId : (Branding.current.effectiveSchoolId ?? 'default');
    return SchoolExamTemplate(
      id: 'default_$effectiveId',
      schoolId: effectiveId,
      name: 'Standard Examination Letterhead',
      type: ExamTemplateType.examination,
      schoolName: effectiveName,
      countryHeader: 'REPUBLIC OF CAMEROON\nPeace - Work - Fatherland\nMINISTRY OF SECONDARY EDUCATION',
      subHeader: 'REGIONAL DELEGATION OF SECONDARY EDUCATION\nP.O. Box 1234, Douala | Tel: +237 670 000 000',
      motto: 'Excellence - Discipline - Success',
      includeStudentFields: true,
      includeInstructionsBox: true,
      includeMarksBox: true,
      fontFamily: 'Serif',
      isDefault: true,
      defaultInstructions: 'Answer ALL questions in Section A and any TWO questions in Section B. '
          'All rough work must be in your answer booklet. Non-programmable calculators are allowed.',
    );
  }

}

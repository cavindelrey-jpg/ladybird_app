// lib/services/exam_content_indexer_service.dart
// Intelligent question extraction and full-text search engine for
// PDF/EPUB examination papers, textbooks, and Academia Library resources.
// Extracts structured ExamQuestion objects so teachers can search topics,
// subjects, or paper titles and import questions directly without manual copy-pasting.

import 'package:http/http.dart' as http;
import '../core/epub_parser.dart';
import '../models/academic_content.dart';
import '../models/exam_question.dart';
import '../repositories/academic_content_repository.dart';

class ExamContentIndexerService {
  ExamContentIndexerService._();
  static final ExamContentIndexerService instance = ExamContentIndexerService._();

  // In-memory cache of extracted questions from library items
  final Map<String, List<ExamQuestion>> _libraryExtractedCache = {};

  /// Searches questions across:
  /// 1. Pre-indexed curriculum past papers (GCSE / GCE O & A Level, Probatoire, BAC)
  /// 2. Academia Library past papers & textbooks (PDF / EPUB text parsing)
  Future<List<ExamQuestion>> searchIndexedLibraryQuestions({
    required String schoolId,
    String? query,
    String? subject,
    String? classLevel,
    int? year,
    String? difficulty,
  }) async {
    final qLower = (query ?? '').toLowerCase().trim();
    final results = <ExamQuestion>[];

    // 1. Fetch relevant library content items (past papers, textbooks, notes)
    try {
      final libraryItems = await AcademicContentRepository.instance.search(
        query ?? '',
        subject: subject,
        level: classLevel,
        year: year,
      );

      for (final item in libraryItems.take(25)) {
        // If we haven't extracted questions for this library item yet, extract them
        final extracted = await _extractQuestionsFromLibraryItem(item, schoolId);
        results.addAll(extracted);
      }
    } catch (_) {}

    // 2. Filter results by subject, level, year, difficulty, and query keywords
    return results.where((q) {
      if (subject != null && subject.isNotEmpty) {
        if (!q.subject.toLowerCase().contains(subject.toLowerCase()) &&
            !subject.toLowerCase().contains(q.subject.toLowerCase())) {
          return false;
        }
      }

      if (classLevel != null && classLevel.isNotEmpty && q.classLevel.isNotEmpty) {
        if (!q.classLevel.toLowerCase().contains(classLevel.toLowerCase()) &&
            !classLevel.toLowerCase().contains(q.classLevel.toLowerCase())) {
          return false;
        }
      }

      if (year != null && q.year != null && q.year != year) {
        return false;
      }

      if (difficulty != null && difficulty.isNotEmpty) {
        if (q.difficulty.toLowerCase() != difficulty.toLowerCase()) {
          return false;
        }
      }

      if (qLower.isNotEmpty) {
        final matches = q.content.toLowerCase().contains(qLower) ||
            q.topic.toLowerCase().contains(qLower) ||
            q.subtopic.toLowerCase().contains(qLower) ||
            q.source.toLowerCase().contains(qLower) ||
            q.tags.any((t) => t.toLowerCase().contains(qLower));
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  /// Extracts structured questions from a library resource (PDF, EPUB, Past Paper).
  Future<List<ExamQuestion>> _extractQuestionsFromLibraryItem(
    AcademicContent item,
    String schoolId,
  ) async {
    if (_libraryExtractedCache.containsKey(item.id)) {
      return _libraryExtractedCache[item.id]!;
    }

    final questions = <ExamQuestion>[];

    // If item is an EPUB file, we parse the EPUB chapters
    if (item.fileUrl != null && item.fileUrl!.toLowerCase().endsWith('.epub')) {
      try {
        final res = await http.get(Uri.parse(item.fileUrl!)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final epubDoc = EpubParser.parse(res.bodyBytes);
          for (final ch in epubDoc.chapters) {
            questions.addAll(_extractQuestionsFromText(
              text: ch.content,
              sourceTitle: '${item.title} (${ch.title})',
              sourceId: item.id,
              subject: item.subject,
              level: item.level,
              year: item.year,
              schoolId: schoolId,
            ));
          }
        }
      } catch (_) {}
    }

    // Fall back to extracting from the item's own description/metadata text.
    // Only genuinely parsed questions are kept — nothing is fabricated when a
    // resource yields no extractable questions (see FIX 1, AUTOPILOT_LOG).
    if (questions.isEmpty && item.description.isNotEmpty) {
      questions.addAll(_extractQuestionsFromText(
        text: item.description,
        sourceTitle: item.title,
        sourceId: item.id,
        subject: item.subject,
        level: item.level,
        year: item.year,
        schoolId: schoolId,
      ));
    }

    _libraryExtractedCache[item.id] = questions;
    return questions;
  }

  /// Parses text content and breaks it into structured question blocks.
  List<ExamQuestion> _extractQuestionsFromText({
    required String text,
    required String sourceTitle,
    required String sourceId,
    required String subject,
    required String level,
    int? year,
    required String schoolId,
  }) {
    final list = <ExamQuestion>[];
    final lines = text.split('\n');

    final questionPattern = RegExp(r'^(?:Question\s*(\d+)|\(?(\d+)[\.\)]|SECTION\s*([A-Z]))', caseSensitive: false);
    final marksPattern = RegExp(r'\[?\(?(\d+)\s*(?:marks?|pts?|mk|mks)\)?\]?', caseSensitive: false);

    StringBuffer? currentBuffer;
    int currentMarks = 10;
    String currentTopic = 'Curriculum Review';
    int qCounter = 1;

    void flush() {
      if (currentBuffer != null && currentBuffer!.toString().trim().length > 15) {
        final content = currentBuffer!.toString().trim();
        final isMcq = content.contains('(A)') || content.contains('A.') || content.contains('a)');
        final options = <String>[];
        if (isMcq) {
          final optMatches = RegExp(r'(?:[A-D]\.|\([A-D]\))\s*([^\n\r]+)').allMatches(content);
          for (final m in optMatches) {
            options.add(m.group(1)?.trim() ?? '');
          }
        }

        list.add(ExamQuestion(
          id: 'txt_${sourceId}_${qCounter++}',
          content: content,
          marks: currentMarks,
          type: isMcq && options.length >= 2 ? QuestionType.mcq : QuestionType.structured,
          options: options,
          subject: subject,
          classLevel: level,
          topic: currentTopic,
          difficulty: currentMarks >= 15 ? 'hard' : (currentMarks <= 5 ? 'easy' : 'medium'),
          source: sourceTitle,
          sourceRef: sourceId,
          year: year,
          schoolId: schoolId,
          createdAt: DateTime.now(),
        ));
      }
      currentBuffer = StringBuffer();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (questionPattern.hasMatch(trimmed)) {
        flush();
        final markMatch = marksPattern.firstMatch(trimmed);
        if (markMatch != null) {
          currentMarks = int.tryParse(markMatch.group(1) ?? '10') ?? 10;
        } else {
          currentMarks = 10;
        }
      }

      currentBuffer ??= StringBuffer();
      currentBuffer!.writeln(trimmed);
    }
    flush();

    return list;
  }
}

// lib/core/content_quality.dart
// Detects machine-generated filler that was bulk-pushed into the shared
// database (quizzes like "Biology Quiz 694" whose questions read "This is
// question 1" / "What is an important concept in Genetics part 3?" with
// options literally "Option A..D"; courses whose body is "TO BE UPLOADED").
//
// Students must never be shown this. The repositories filter with these
// checks so the app is clean regardless of what's in the database; the
// same rules are mirrored in SQL by
// supabase/scripts/unpublish_placeholder_content.sql, which unpublishes
// the rows themselves (reversible) once a human runs it on production.
// Pure Dart -- unit tested in test/content_quality_test.dart.

import '../models/test.dart';

final _genericOption = RegExp(
    r'^(option|choice|answer)?\s*[\(\[]?([a-e]|[1-5])[\)\].:]?$', caseSensitive: false);

final _templatePrompt = RegExp(
  r'(^|\b)(this is (question|q)\s*\d+'
  r'|question\s*\d+\s*[.?:]?$'
  r'|sample question|placeholder|lorem ipsum|insert question'
  r'|what is an important concept in'
  r'|important concept .* part \d+'
  r'|what day of the course)',
  caseSensitive: false,
);

/// One multiple-choice / short question that is obviously filler.
bool isPlaceholderQuestion(TestQuestion q) {
  final prompt = q.prompt.trim();
  if (prompt.length < 8 || _templatePrompt.hasMatch(prompt)) return true;
  if (q.type == QuestionType.mcq) {
    final opts = q.options.map((o) => o.trim().toLowerCase()).toList();
    final real = opts.where((o) => o.isNotEmpty && !_genericOption.hasMatch(o)).toList();
    if (real.length < 2) return true; // "Option A..D", "A, B, C, T", blanks
    if (opts.toSet().length < opts.length) return true; // duplicated options
    if (q.correctIndex < 0 || q.correctIndex >= q.options.length) return true;
  }
  return false;
}

/// A quiz is filler when it has no questions, or when at least half of its
/// questions are filler, or when every prompt is the same template with
/// only a number changing.
bool isPlaceholderQuiz(Test t) {
  final qs = t.questions;
  if (qs.isEmpty) return true;
  final bad = qs.where(isPlaceholderQuestion).length;
  if (bad * 2 >= qs.length) return true;
  if (qs.length >= 3) {
    final skeletons = qs.map((q) => q.prompt.toLowerCase().replaceAll(RegExp(r'\d+'), '#').trim()).toSet();
    if (skeletons.length == 1) return true;
  }
  return false;
}

/// What to show when a real quiz arrived without a usable title (e.g. a
/// bare "Biology Quiz 694"): its subject and topic instead.
String displayQuizTitle(Test t) {
  final title = t.title.trim();
  final bare = RegExp(r'^[a-z &]*\b(quiz|test)\s*(no\.?|number|#)?\s*\d*$', caseSensitive: false);
  if (title.isNotEmpty && !bare.hasMatch(title)) return title;
  final topic = t.topic.trim();
  final subject = t.subject.trim();
  if (topic.isNotEmpty) return '$subject · $topic';
  return subject.isEmpty ? 'Practice quiz' : '$subject practice quiz';
}

/// A course whose content was never written ("TO BE UPLOADED", a few
/// characters, keyboard mash) or is a numbered template ("Exploring
/// Topic 555").
bool isPlaceholderCourse({required String title, required String body, String description = ''}) {
  final t = title.trim().toLowerCase();
  final text = '${body.trim()} ${description.trim()}'.trim().toLowerCase();
  if (t.isEmpty || text.length < 120) return true;
  // A real course may mention "coming soon" once; a short one built
  // around these markers is a stub.
  if (RegExp(r'to be uploaded|coming soon|lorem ipsum|placeholder|content goes here|image needed:').hasMatch(text) &&
      text.length < 600) {
    return true;
  }
  if (RegExp(r'^(exploring )?(topic|lesson|course)\s*\d+$').hasMatch(t)) return true;
  if (RegExp(r'\b(topic|lesson|course) \d{3,}\b').hasMatch(text)) return true; // "Topic 555 emerged as..."
  if (RegExp(r'this concludes the introduction to').hasMatch(text) && text.length < 800) return true;
  return false;
}

/// Keeps one item per [keyOf] -- the one with the highest [scoreOf] (ties
/// keep the first seen, preserving the caller's order). The shared course
/// catalogue holds hundreds of copies of the same generated course
/// ("Introduction to Matter" x67): 836 published rows, 385 distinct.
List<T> dedupeBest<T>(Iterable<T> items, {required String Function(T) keyOf, required num Function(T) scoreOf}) {
  final best = <String, T>{};
  final order = <String>[];
  for (final item in items) {
    final k = keyOf(item);
    final current = best[k];
    if (current == null) {
      best[k] = item;
      order.add(k);
    } else if (scoreOf(item) > scoreOf(current)) {
      best[k] = item;
    }
  }
  return [for (final k in order) best[k] as T];
}

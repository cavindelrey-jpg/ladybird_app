// lib/models/daily_learning.dart
// Home's Daily Challenge, evolved from a single static question card into
// a real, modular set of short learning courses (Duolingo/W3Schools-
// style: a couple of short "did you know" teaching facts, then a small
// quiz that reinforces them). Etymology is the first course; the model
// shape is deliberately course-agnostic so a second subject can be added
// later without touching this file or the UI that renders it.
//
// Course/lesson CONTENT lives in code (see
// lib/data/etymology_course.dart) rather than Firestore for now -- there
// is no admin authoring UI for this yet, and standing up one wasn't in
// scope for "establish the structure for Etymology" (see
// docs/AUTOPILOT_LOG.md). Per-user PROGRESS is real and Firestore-backed
// (DailyLearningRepository, users/{uid}/dailyLearningProgress/{courseId}),
// same as everything else in this app. Moving content into Firestore
// later is a repository-layer change only -- DailyLearningCourse/Lesson
// below don't know or care where they came from.

class DailyLearningQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  /// One short line shown after answering -- reinforces *why*, not just
  /// whether the pick was right.
  final String explanation;

  const DailyLearningQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class DailyLearningLesson {
  final String id;
  final String title;
  /// Short "did you know" teaching facts shown before the quiz -- 2-4
  /// sentences, not a full article. Duolingo-style bite size.
  final List<String> teachingPoints;
  final List<DailyLearningQuestion> questions;

  const DailyLearningLesson({
    required this.id,
    required this.title,
    required this.teachingPoints,
    required this.questions,
  });
}

class DailyLearningCourse {
  final String id;
  final String title;
  final String description;
  final List<DailyLearningLesson> lessons;

  const DailyLearningCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
  });
}

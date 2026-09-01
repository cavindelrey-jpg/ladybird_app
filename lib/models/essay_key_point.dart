// lib/models/essay_key_point.dart
// One fact/idea a structured or long-form (AC) answer is graded against.
// [keywords] are alternate phrasings of [text] — core/essay_matching.dart
// tries each and keeps whichever scores highest against the student's
// answer, so an author isn't forced to guess the one "correct" wording.

class EssayKeyPoint {
  final String id;
  final String text;
  final List<String> keywords;

  const EssayKeyPoint({
    required this.id,
    required this.text,
    this.keywords = const [],
  });

  factory EssayKeyPoint.fromMap(Map<String, dynamic> m) => EssayKeyPoint(
        id: m['id'] ?? '',
        text: m['text'] ?? '',
        keywords: List<String>.from(m['keywords'] ?? const []),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'keywords': keywords,
      };
}

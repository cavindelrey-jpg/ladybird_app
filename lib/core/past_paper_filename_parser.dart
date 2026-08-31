// lib/core/past_paper_filename_parser.dart
// Parses a past-paper filename like "Physics GCE O Level 2024 Paper 1.pdf"
// (underscores or spaces as separators, either works) into structured
// metadata, so bulk-uploading a folder of papers doesn't require
// hand-filling a form per file. Pure function, no I/O — easy to reason
// about/extend independently of the upload page that calls it.

class ParsedPastPaper {
  /// The specific discipline as typed in the filename, e.g. "Physics" —
  /// kept verbatim (not forced into [kAcademicSubjects]'s broad
  /// categories) so nothing is lost; [subjectCategory] below is the best-
  /// effort mapping onto that predefined list for the DB's `subject`
  /// column, which the rest of the Library filter bar depends on.
  final String discipline;

  /// Best-guess match onto kExamBoards (models/academic_content.dart) —
  /// the DB's examBoard field follows the same "predefined list, not
  /// free text" convention subject/level already use.
  final String examBoard;

  final int? year;
  final int? paperNumber;

  /// The reconstructed, cleaned-up title — same wording as the filename
  /// (underscores normalized to spaces), used as-is for
  /// AcademicContent.title since title IS free text.
  final String title;

  const ParsedPastPaper({
    required this.discipline,
    required this.examBoard,
    required this.year,
    required this.paperNumber,
    required this.title,
  });
}

const _kKnownExamPhrases = [
  'GCE Advanced Level', 'GCE Ordinary Level', 'GCE O Level', 'GCE A Level',
  'Probatoire', 'BEPC', 'BAC', 'Mock Exam', 'School Exam', 'GCE',
];

String _mapToKnownExamBoard(String? matchedPhrase) {
  if (matchedPhrase == null) return 'N/A';
  final p = matchedPhrase.toLowerCase();
  if (p.startsWith('gce')) return 'GCE';
  if (p == 'probatoire') return 'Probatoire';
  if (p == 'bepc') return 'BEPC';
  if (p == 'bac') return 'BAC';
  if (p == 'mock exam') return 'Mock Exam';
  if (p == 'school exam') return 'School Exam';
  return 'N/A';
}

/// Maps a free-text discipline (e.g. "Physics") onto the DB's predefined
/// broad subject category (kAcademicSubjects) — best-effort keyword
/// match, falls back to 'Other' rather than guessing wrong silently.
/// The exact discipline name is never lost either way: it's kept in
/// [ParsedPastPaper.discipline]/the title/tags regardless of which
/// broad category it gets filed under.
String mapDisciplineToSubjectCategory(String discipline) {
  final d = discipline.toLowerCase();
  if (d.contains('math')) return 'Mathematics';
  if (['physics', 'chemistry', 'biology', 'science', 'agriculture', 'health']
      .any(d.contains)) {
    return 'Science';
  }
  if (['english', 'french', 'language'].any(d.contains)) return 'Languages';
  if ([
    'history', 'geography', 'citizenship', 'social studies', 'economics',
    'government', 'religious',
  ].any(d.contains)) {
    return 'Social Studies';
  }
  if (['computer', 'ict', 'coding'].any(d.contains)) return 'Computer Science';
  if (['literature', 'art', 'music'].any(d.contains)) return 'Arts & Literature';
  if (['business', 'commerce', 'accounting', 'entrepreneurship']
      .any(d.contains)) {
    return 'Business';
  }
  return 'Other';
}

/// Returns null if the filename doesn't look like a past paper at all
/// (no recognizable "Paper N" marker) — the caller should fall back to
/// manual entry for that file rather than guessing.
ParsedPastPaper? parsePastPaperFilename(String rawFilename) {
  var name = rawFilename.replaceAll(RegExp(r'\.[^.]+$'), ''); // strip extension
  name = name.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  final paperMatch = RegExp(r'paper\s*(\d+)', caseSensitive: false).firstMatch(name);
  if (paperMatch == null) return null;
  final paperNumber = int.tryParse(paperMatch.group(1)!);

  final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(name);
  final year = yearMatch != null ? int.tryParse(yearMatch.group(0)!) : null;

  String? matchedPhrase;
  final lower = name.toLowerCase();
  for (final phrase in _kKnownExamPhrases) {
    if (lower.contains(phrase.toLowerCase())) {
      matchedPhrase = phrase;
      break;
    }
  }

  String discipline;
  if (matchedPhrase != null) {
    final idx = lower.indexOf(matchedPhrase.toLowerCase());
    discipline = name.substring(0, idx).trim();
  } else if (year != null) {
    final idx = name.indexOf(year.toString());
    discipline = name.substring(0, idx).trim();
  } else {
    discipline = name.substring(0, paperMatch.start).trim();
  }
  if (discipline.isEmpty) discipline = 'Unspecified Subject';

  return ParsedPastPaper(
    discipline: discipline,
    examBoard: _mapToKnownExamBoard(matchedPhrase),
    year: year,
    paperNumber: paperNumber,
    title: name,
  );
}

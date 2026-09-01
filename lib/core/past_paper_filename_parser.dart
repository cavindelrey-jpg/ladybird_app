// lib/core/past_paper_filename_parser.dart
// Parses a past-paper filename into structured metadata so bulk-uploading
// a folder of papers doesn't require hand-filling a form per file. Pure
// function, no I/O — easy to reason about/extend independently of the
// upload page that calls it.
//
// Real filenames off a teacher's phone/laptop don't follow one fixed
// word order — seen in the wild: "Physics GCE O Level 2024 Paper 1",
// "0750-2017-A-GEOGRAPHY-1" (syllabus code, year, level, subject, paper
// number), "A-GEOGRAPHY-2-2015" (level, subject, paper number, year),
// "2020-Advanced-Level-Literature-PAPER-2", "A-LEVEL-2025-Computer-
// science-3-Copy" (duplicate-download suffix). So instead of assuming a
// fixed left-to-right shape, this tokenizes on every separator seen
// (space/underscore/dash) and *consumes* recognizable tokens (year,
// "Paper N", exam-level phrase, any other bare digit run) out of the
// token list — whatever's left, in its original order, is the subject.

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
  /// (separators normalized to spaces, duplicate-download suffix
  /// stripped), used as-is for AcademicContent.title since title IS free
  /// text.
  final String title;

  const ParsedPastPaper({
    required this.discipline,
    required this.examBoard,
    required this.year,
    required this.paperNumber,
    required this.title,
  });
}

// Longest phrase first within each word-count so e.g. "GCE A Level" is
// matched whole rather than leaving a stray "GCE" + matched "A Level".
const _kKnownExamPhrases = [
  'GCE Advanced Level', 'GCE Ordinary Level', 'GCE O Level', 'GCE A Level',
  'Advanced Level', 'Ordinary Level', 'A Level', 'O Level',
  'Probatoire', 'BEPC', 'BAC', 'Mock Exam', 'School Exam', 'GCE',
];

String _mapToKnownExamBoard(String? matchedPhrase) {
  if (matchedPhrase == null) return 'N/A';
  final p = matchedPhrase.toLowerCase();
  if (p.startsWith('gce')) return 'GCE';
  // A/O/Advanced/Ordinary Level without an explicit "GCE" prefix still
  // means GCE in this context — GCE is the only board in kExamBoards
  // that uses that level naming at all.
  if (p == 'advanced level' || p == 'ordinary level' || p == 'a level' || p == 'o level') {
    return 'GCE';
  }
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

/// Returns null only when nothing recognizable at all was found (no
/// year, no paper number, no exam-level phrase) — the caller should fall
/// back to full manual entry for that file rather than guessing.
ParsedPastPaper? parsePastPaperFilename(String rawFilename) {
  var name = rawFilename.replaceAll(RegExp(r'\.[^.]+$'), ''); // strip extension
  // Dashes and underscores are both used as word separators in the wild
  // (e.g. "A-LEVEL-2025-Computer-science-1" vs "Physics_GCE_O_Level_2024_Paper_1").
  name = name.replaceAll(RegExp(r'[-_]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  // Strip a trailing duplicate-download marker some file pickers/browsers
  // append ("... Copy", "... Copy 2", "...(1)") — not part of the real name.
  name = name.replaceAll(RegExp(r'\s*\(\d+\)$'), '');
  name = name.replaceAll(RegExp(r'\s+copy(\s+\d+)?$', caseSensitive: false), '').trim();

  final tokens = name.split(' ').where((t) => t.isNotEmpty).toList();
  final consumed = List<bool>.filled(tokens.length, false);

  // Explicit "Paper N" (as two tokens, e.g. "PAPER 2") is the highest-
  // confidence source for the paper number.
  int? paperNumber;
  for (var i = 0; i < tokens.length - 1; i++) {
    if (tokens[i].toLowerCase() == 'paper' && RegExp(r'^\d+$').hasMatch(tokens[i + 1])) {
      paperNumber = int.parse(tokens[i + 1]);
      consumed[i] = true;
      consumed[i + 1] = true;
      break;
    }
  }
  // Some filenames glue it into one token instead ("Paper2").
  if (paperNumber == null) {
    for (var i = 0; i < tokens.length; i++) {
      final m = RegExp(r'^paper(\d+)$', caseSensitive: false).firstMatch(tokens[i]);
      if (m != null) {
        paperNumber = int.parse(m.group(1)!);
        consumed[i] = true;
        break;
      }
    }
  }

  // Year — a standalone 19xx/20xx token.
  int? year;
  for (var i = 0; i < tokens.length; i++) {
    if (RegExp(r'^(19|20)\d{2}$').hasMatch(tokens[i])) {
      year = int.parse(tokens[i]);
      consumed[i] = true;
      break;
    }
  }

  // Known exam-level phrase, checked longest-first (already ordered in
  // _kKnownExamPhrases) so "GCE A Level" wins over a bare "A Level".
  String? matchedPhrase;
  for (final phrase in _kKnownExamPhrases) {
    final words = phrase.split(' ');
    var found = false;
    for (var i = 0; i + words.length <= tokens.length; i++) {
      if (consumed.sublist(i, i + words.length).any((c) => c)) continue;
      var match = true;
      for (var j = 0; j < words.length; j++) {
        if (tokens[i + j].toLowerCase() != words[j].toLowerCase()) {
          match = false;
          break;
        }
      }
      if (match) {
        matchedPhrase = phrase;
        for (var j = 0; j < words.length; j++) {
          consumed[i + j] = true;
        }
        found = true;
        break;
      }
    }
    if (found) break;
  }

  // No explicit "Paper N" keyword found — fall back to the last
  // remaining short (1-2 digit) number as the paper number. Longer
  // digit runs (syllabus/board codes like "0750") are excluded so they
  // don't get misread as a paper number.
  if (paperNumber == null) {
    for (var i = tokens.length - 1; i >= 0; i--) {
      if (consumed[i]) continue;
      if (RegExp(r'^\d{1,2}$').hasMatch(tokens[i])) {
        paperNumber = int.parse(tokens[i]);
        consumed[i] = true;
        break;
      }
    }
  }

  // Whatever digits are still left over (syllabus codes, a second
  // ambiguous number, etc.) are real metadata but never part of a
  // subject name — drop them from the discipline text too.
  for (var i = 0; i < tokens.length; i++) {
    if (!consumed[i] && RegExp(r'^\d+$').hasMatch(tokens[i])) consumed[i] = true;
  }

  if (year == null && paperNumber == null && matchedPhrase == null) return null;

  final disciplineTokens = [
    for (var i = 0; i < tokens.length; i++)
      if (!consumed[i]) tokens[i],
  ];
  var discipline = disciplineTokens.join(' ').trim();
  if (discipline.isEmpty) discipline = 'Unspecified Subject';

  return ParsedPastPaper(
    discipline: discipline,
    examBoard: _mapToKnownExamBoard(matchedPhrase),
    year: year,
    paperNumber: paperNumber,
    title: name,
  );
}

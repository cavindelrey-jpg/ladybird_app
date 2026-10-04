// lib/core/marks_csv.dart
// Pure (no Flutter, no Supabase) half of the marks CSV import/export
// pipeline, so the whole parse -> validate -> resolve -> export round
// trip is unit-testable with a real 60-student class (see
// test/marks_csv_test.dart). marks_csv_import_page.dart and
// marks_entry_page.dart are thin UI over this.
//
// Student resolution is against the class ROSTER (one fetch per class),
// not a per-row global name search: the old per-row
// MessagingRepository.searchUsers() call was a platform-wide prefix
// search capped at 20 results, so 60 rows meant 60 round trips and a
// common surname could push the real student past the cap.

import '../models/school_mark.dart';

const List<String> kMarksCsvColumns = [
  'studentName', 'classLevel', 'subject', 'sequence', 'academicYear', 'score', 'maxScore',
];

/// One student in a class, as the importer needs them.
class RosterStudent {
  final String id;
  final String name;
  final String classLevel;
  const RosterStudent({required this.id, required this.name, required this.classLevel});
}

String _normName(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// RFC 4180 encoder (quotes fields containing , " or newlines).
String encodeCsv(List<List<String>> rows) {
  String encodeField(String f) {
    if (f.contains(',') || f.contains('"') || f.contains('\n') || f.contains('\r')) {
      return '"${f.replaceAll('"', '""')}"';
    }
    return f;
  }
  return rows.map((row) => row.map(encodeField).join(',')).join('\r\n');
}

/// Matching decoder -- quoted fields, escaped "" quotes, \n / \r\n line
/// endings (including inside a quoted field), and a leading UTF-8 BOM.
/// Excel's "CSV UTF-8" export starts with a BOM; without stripping it the
/// first header cell reads "﻿studentName" and the whole file was
/// rejected with "Missing column(s): studentName".
List<List<String>> decodeCsv(String content) {
  if (content.startsWith('﻿')) content = content.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < content.length) {
    final ch = content[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          field.write('"');
          i += 2;
        } else {
          inQuotes = false;
          i++;
        }
      } else {
        field.write(ch);
        i++;
      }
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      i++;
    } else if (ch == ',') {
      row.add(field.toString());
      field.clear();
      i++;
    } else if (ch == '\n' || ch == '\r') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = [];
      i += (ch == '\r' && i + 1 < content.length && content[i + 1] == '\n') ? 2 : 1;
    } else {
      field.write(ch);
      i++;
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

class MarksImportRow {
  final int lineNumber;
  final Map<String, String> raw;
  String? error;
  SchoolMark? resolved;
  MarksImportRow({required this.lineNumber, required this.raw});
  bool get isValid => error == null && resolved != null;
  String get studentName => raw['studentName'] ?? '';
}

class MarksImportPlan {
  /// File-level problem (empty file, wrong header) -- when set, [rows] is empty.
  final String? fileError;
  final List<MarksImportRow> rows;
  const MarksImportPlan({this.fileError, this.rows = const []});

  List<MarksImportRow> get valid => rows.where((r) => r.isValid).toList();
  List<MarksImportRow> get invalid => rows.where((r) => !r.isValid).toList();

  /// Class levels referenced by the file -- what the caller must fetch
  /// rosters for before calling [planMarksImport].
  static Set<String> classLevelsIn(List<List<String>> table) {
    if (table.isEmpty) return {};
    final header = table.first.map((c) => c.trim()).toList();
    final idx = header.indexOf('classLevel');
    if (idx < 0) return {};
    return {
      for (final r in table.skip(1))
        if (r.length > idx && r[idx].trim().isNotEmpty) r[idx].trim(),
    };
  }
}

/// Validates every row and resolves student names against [rosters]
/// (classLevel -> students). Never touches the network.
///
/// Rejects, with a per-line reason: missing fields, unknown sequence,
/// non-numeric / out-of-range scores, rows the staff member isn't
/// authorized for ([canRecord]), students not in that class, ambiguous
/// names, and DUPLICATES -- the same student+subject+sequence+year twice
/// in one file. Both copies of a duplicate are rejected rather than
/// "last one wins", since a silent overwrite is exactly how a wrong mark
/// ends up on a report card.
MarksImportPlan planMarksImport({
  required List<List<String>> table,
  required Map<String, List<RosterStudent>> rosters,
  required bool Function(String subject, String classLevel) canRecord,
  required String schoolId,
  required String teacherName,
  required String gradedBy,
  required String defaultYear,
}) {
  if (table.isEmpty || table.every((r) => r.every((c) => c.trim().isEmpty))) {
    return const MarksImportPlan(fileError: 'The file is empty.');
  }
  final header = table.first.map((c) => c.trim()).toList();
  if (header.length == 1 && header.first.contains(';')) {
    return const MarksImportPlan(
        fileError: 'This file uses ";" between columns. Re-save it as "CSV (comma delimited)" and upload again.');
  }
  final missing = kMarksCsvColumns.where((c) => !header.contains(c)).toList();
  if (missing.isNotEmpty) {
    return MarksImportPlan(
        fileError: 'Missing column(s): ${missing.join(', ')}. Download the template to see the exact format.');
  }

  final rows = <MarksImportRow>[];
  for (var i = 1; i < table.length; i++) {
    final cells = table[i];
    if (cells.every((c) => c.trim().isEmpty)) continue;
    final raw = <String, String>{
      for (var c = 0; c < header.length && c < cells.length; c++) header[c]: cells[c].trim(),
    };
    final row = MarksImportRow(lineNumber: i + 1, raw: raw);
    rows.add(row);

    final studentName = raw['studentName'] ?? '';
    final classLevel = raw['classLevel'] ?? '';
    final subject = raw['subject'] ?? '';
    if (studentName.isEmpty || classLevel.isEmpty || subject.isEmpty) {
      row.error = 'studentName, classLevel and subject are required.';
      continue;
    }
    final sequence = AcademicSequence.fromKey(raw['sequence'] ?? '');
    if (sequence == null) {
      row.error = 'Unknown sequence "${raw['sequence'] ?? ''}" — use one of: '
          '${AcademicSequence.values.map((s) => s.name).join(', ')}.';
      continue;
    }
    final scoreStr = (raw['score'] ?? '').replaceAll(',', '.');
    final maxStr = (raw['maxScore'] ?? '').replaceAll(',', '.');
    if (scoreStr.isEmpty) {
      row.error = 'No score given.';
      continue;
    }
    final score = double.tryParse(scoreStr);
    final maxScore = maxStr.isEmpty ? 20.0 : double.tryParse(maxStr);
    if (score == null || maxScore == null || !score.isFinite || !maxScore.isFinite) {
      row.error = 'score and maxScore must be numbers.';
      continue;
    }
    if (maxScore <= 0) {
      row.error = 'maxScore must be greater than 0.';
      continue;
    }
    if (score < 0 || score > maxScore) {
      row.error = 'Score ${_fmt(score)} must be between 0 and ${_fmt(maxScore)}.';
      continue;
    }
    if (!canRecord(subject, classLevel)) {
      row.error = 'You\'re not assigned to teach $subject in $classLevel.';
      continue;
    }
    final roster = rosters[classLevel] ?? const <RosterStudent>[];
    final matches = roster.where((s) => _normName(s.name) == _normName(studentName)).toList();
    if (matches.isEmpty) {
      row.error = 'No student named "$studentName" in $classLevel at your school.';
      continue;
    }
    if (matches.length > 1) {
      row.error = '${matches.length} students named "$studentName" in $classLevel — enter this one manually.';
      continue;
    }
    final year = (raw['academicYear'] ?? '').isEmpty ? defaultYear : raw['academicYear']!;
    row.resolved = SchoolMark(
      id: '',
      schoolId: schoolId,
      studentId: matches.first.id,
      classLevel: classLevel,
      subject: subject,
      teacherName: teacherName,
      sequence: sequence,
      academicYear: year,
      score: score,
      maxScore: maxScore,
      gradedBy: gradedBy,
    );
  }

  // Duplicate detection on the DB's own unique key.
  final byKey = <String, List<MarksImportRow>>{};
  for (final r in rows.where((r) => r.isValid)) {
    final m = r.resolved!;
    byKey.putIfAbsent('${m.studentId}|${m.subject}|${m.sequence.name}|${m.academicYear}', () => []).add(r);
  }
  for (final dupes in byKey.values.where((l) => l.length > 1)) {
    final lines = dupes.map((d) => d.lineNumber).join(', ');
    for (final d in dupes) {
      d.error = 'Duplicate: ${d.studentName} appears on lines $lines for the same subject and sequence.';
      d.resolved = null;
    }
  }
  return MarksImportPlan(rows: rows);
}

/// Export in the exact import format, sorted by student name, so an
/// exported file can be edited and re-imported unchanged.
String exportMarksCsv({
  required List<RosterStudent> roster,
  required Map<String, SchoolMark> marksByStudentId,
  required String classLevel,
  required String subject,
  required AcademicSequence sequence,
  required String academicYear,
  bool includeUnmarked = true,
}) {
  final sorted = [...roster]..sort((a, b) => _normName(a.name).compareTo(_normName(b.name)));
  final rows = <List<String>>[kMarksCsvColumns];
  for (final s in sorted) {
    final m = marksByStudentId[s.id];
    if (m == null && !includeUnmarked) continue;
    rows.add([
      s.name, classLevel, subject, sequence.name, academicYear,
      m == null ? '' : _fmt(m.score),
      m == null ? '20' : _fmt(m.maxScore),
    ]);
  }
  return encodeCsv(rows);
}

/// Generates a valid example CSV template for marks import.
String generateMarksCsvTemplate() {
  final currentYear = DateTime.now().year.toString();
  return encodeCsv([
    kMarksCsvColumns,
    ['Brice Ngono', 'Form 5', 'Mathematics', 't1s1', currentYear, '15.5', '20'],
    ['Marie Claire', 'Form 5', 'Mathematics', 't1s1', currentYear, '18', '20'],
    ['Loïc Kamga', 'Form 5', 'Mathematics', 't1s1', currentYear, '12', '20'],
  ]);
}

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Parses a typed score for the grid entry page. Returns null for blank
/// (= "no mark yet", not zero). Accepts a comma decimal ("12,5") since
/// French-locale keyboards produce one.
({double? value, String? error}) parseScoreInput(String text, double maxScore) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return (value: null, error: null);
  final v = double.tryParse(t);
  if (v == null || !v.isFinite) return (value: null, error: 'Not a number');
  if (v < 0) return (value: null, error: 'Min 0');
  if (v > maxScore) return (value: null, error: 'Max ${_fmt(maxScore)}');
  if ((v * 100).roundToDouble() != v * 100) return (value: null, error: '2 decimals max');
  return (value: v, error: null);
}

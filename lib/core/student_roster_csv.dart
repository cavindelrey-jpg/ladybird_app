// lib/core/student_roster_csv.dart
// Pure Dart (no Flutter, no Supabase) Student Roster / Class List CSV parser, validator, and exporter.
// Follows the marks_csv.dart and timetable_csv.dart architecture.

import '../models/academic_content.dart' show kAcademicLevels;
import '../models/student_record.dart';
import 'marks_csv.dart' show encodeCsv, decodeCsv;

const List<String> kStudentRosterCsvColumns = [
  'studentName',
  'classLevel',
  'matricule',
  'parentContact',
  'gender',
];

List<String> get _defaultSchoolClasses => kAcademicLevels.take(7).toList();

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Single row from a Student Roster CSV file.
class StudentRosterImportRow {
  final int lineNumber;
  final Map<String, String> raw;
  String? error;
  String? warning;
  StudentRecord? resolved;

  StudentRosterImportRow({required this.lineNumber, required this.raw});

  bool get isValid => error == null && resolved != null;
}

/// Consolidated plan for student roster bulk import.
class StudentRosterPlan {
  final String? fileError;
  final List<StudentRosterImportRow> rows;

  const StudentRosterPlan({
    this.fileError,
    this.rows = const [],
  });

  List<StudentRosterImportRow> get valid => rows.where((r) => r.isValid).toList();
  List<StudentRosterImportRow> get errors => rows.where((r) => r.error != null).toList();
}

/// Parses and validates a Student Roster CSV string.
StudentRosterPlan parseStudentRosterCsv(
  String content,
  String schoolId, {
  List<StudentRecord>? existingStudents,
  List<String>? availableClasses,
}) {
  if (content.trim().isEmpty) {
    return const StudentRosterPlan(fileError: 'That file is completely empty.');
  }

  final table = decodeCsv(content);
  if (table.isEmpty) {
    return const StudentRosterPlan(fileError: 'That file could not be read as CSV.');
  }

  final rawHeader = table.first.map((c) => c.trim()).toList();
  if (rawHeader.length == 1 && rawHeader.first.contains(';')) {
    return const StudentRosterPlan(
      fileError: 'This file uses semicolons between columns. Re-save it as "CSV (comma delimited)" and upload again.',
    );
  }

  // Header column normalization
  final colMap = <String, int>{};
  for (var i = 0; i < rawHeader.length; i++) {
    final h = rawHeader[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (h == 'studentname' || h == 'name' || h == 'fullname') {
      colMap['studentName'] = i;
    } else if (h == 'classlevel' || h == 'class' || h == 'form') {
      colMap['classLevel'] = i;
    } else if (h == 'matricule' || h == 'studentid' || h == 'id' || h == 'registrationnumber') {
      colMap['matricule'] = i;
    } else if (h == 'parentcontact' || h == 'parentphone' || h == 'parentemail' || h == 'guardiancontact' || h == 'phone') {
      colMap['parentContact'] = i;
    } else if (h == 'gender' || h == 'sex') {
      colMap['gender'] = i;
    }
  }

  if (!colMap.containsKey('studentName') || !colMap.containsKey('classLevel')) {
    return const StudentRosterPlan(
      fileError: 'Missing required column(s): studentName, classLevel. Use the template for the required columns.',
    );
  }

  final validClasses = availableClasses ?? _defaultSchoolClasses;
  final rows = <StudentRosterImportRow>[];
  final seenInFileMatricules = <String, int>{};
  final seenInFileNameAndClass = <String, int>{};

  for (var i = 1; i < table.length; i++) {
    final cells = table[i];
    if (cells.every((c) => c.trim().isEmpty)) continue;

    final raw = <String, String>{};
    for (final entry in colMap.entries) {
      if (entry.value < cells.length) {
        raw[entry.key] = cells[entry.value].trim();
      } else {
        raw[entry.key] = '';
      }
    }

    final row = StudentRosterImportRow(lineNumber: i + 1, raw: raw);
    rows.add(row);

    final name = raw['studentName'] ?? '';
    final rawClass = raw['classLevel'] ?? '';
    final matricule = raw['matricule'] ?? '';
    final parentContact = raw['parentContact'] ?? '';
    final gender = raw['gender'] ?? '';

    if (name.length < 2) {
      row.error = 'Student name must have at least 2 characters.';
      continue;
    }

    if (rawClass.isEmpty) {
      row.error = 'Class level is required.';
      continue;
    }

    final matchedClass = validClasses.firstWhere(
      (c) => _norm(c) == _norm(rawClass),
      orElse: () => '',
    );

    if (matchedClass.isEmpty) {
      row.error = 'Unknown class "$rawClass". Supported classes: ${validClasses.join(', ')}.';
      continue;
    }

    // Intra-file duplicate detection
    if (matricule.isNotEmpty) {
      final prevLine = seenInFileMatricules[matricule.toLowerCase()];
      if (prevLine != null) {
        row.error = 'Duplicate matricule "$matricule" on line $prevLine.';
        continue;
      }
      seenInFileMatricules[matricule.toLowerCase()] = i + 1;
    }

    final nameClassKey = '${_norm(name)}|${_norm(matchedClass)}';
    final prevNameLine = seenInFileNameAndClass[nameClassKey];
    if (prevNameLine != null) {
      row.warning = 'Student "$name" is repeated for $matchedClass (first seen on line $prevNameLine).';
    } else {
      seenInFileNameAndClass[nameClassKey] = i + 1;
    }

    // Check existing students
    String studentId = 'stu_${DateTime.now().millisecondsSinceEpoch}_${i}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    if (existingStudents != null && existingStudents.isNotEmpty) {
      StudentRecord? existing;
      if (matricule.isNotEmpty) {
        final mMatches = existingStudents.where((s) => s.matricule?.toLowerCase() == matricule.toLowerCase());
        if (mMatches.isNotEmpty) existing = mMatches.first;
      }
      if (existing == null) {
        final nMatches = existingStudents.where((s) => _norm(s.name) == _norm(name) && _norm(s.classLevel) == _norm(matchedClass));
        if (nMatches.isNotEmpty) existing = nMatches.first;
      }

      if (existing != null) {
        studentId = existing.id;
        row.warning = 'Will update existing student "${existing.name}".';
      }
    }

    row.resolved = StudentRecord(
      id: studentId,
      schoolId: schoolId,
      name: name,
      classLevel: matchedClass,
      matricule: matricule.isNotEmpty ? matricule : null,
      parentContact: parentContact.isNotEmpty ? parentContact : null,
      gender: gender.isNotEmpty ? gender : null,
      createdAt: DateTime.now(),
    );
  }

  return StudentRosterPlan(rows: rows);
}

/// Generates a starter CSV template for student class lists.
String generateStudentRosterCsvTemplate() {
  final rows = [
    kStudentRosterCsvColumns,
    ['Brice Ngono', 'Form 4', 'LBS-2026-001', '+237 670001122', 'M'],
    ['Clarisse Tchakounte', 'Form 4', 'LBS-2026-002', '+237 671112233', 'F'],
    ['Yannick Ebanda', 'Form 5', 'LBS-2026-015', '+237 690223344', 'M'],
    ['Vanessa Nkwenti', 'Form 5', 'LBS-2026-016', '+237 673334455', 'F'],
  ];
  return encodeCsv(rows);
}

/// Exports a list of student records to CSV format.
String exportStudentRosterCsv(List<StudentRecord> students) {
  final rows = <List<String>>[kStudentRosterCsvColumns];
  for (final s in students) {
    rows.add([
      s.name,
      s.classLevel,
      s.matricule ?? '',
      s.parentContact ?? '',
      s.gender ?? '',
    ]);
  }
  return encodeCsv(rows);
}

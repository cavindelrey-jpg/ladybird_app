// lib/core/teacher_csv.dart
// Pure Dart (no Flutter, no Supabase) teacher assignments CSV parser, validator, and exporter.
// Mirrors the architecture of lib/core/marks_csv.dart and timetable_csv.dart.

import '../models/app_user.dart';
import '../models/academic_content.dart' show kAcademicSubjects, kAcademicLevels;
import '../models/teaching_assignment.dart';
import 'marks_csv.dart' show encodeCsv, decodeCsv;

const List<String> kTeacherCsvColumns = [
  'teacherName',
  'teacherEmail',
  'subjects',
  'classes',
  'classMasterOf',
];

List<String> get _defaultSchoolClasses => kAcademicLevels.take(7).toList();

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Single row from a Teacher CSV file.
class TeacherImportRow {
  final int lineNumber;
  final Map<String, String> raw;
  String? error;
  String? warning;
  String? resolvedTeacherId;
  String? resolvedTeacherName;
  String? resolvedTeacherEmail;
  List<TeachingAssignment> assignments = [];
  String? classMasterOf;

  TeacherImportRow({required this.lineNumber, required this.raw});

  bool get isValid => error == null && resolvedTeacherId != null;
}

/// Consolidated assignments per teacher for bulk applying.
class TeacherAssignmentPlan {
  final String? fileError;
  final List<TeacherImportRow> rows;
  final Map<String, ({String teacherName, String email, List<TeachingAssignment> assignments, String? classMasterOf, bool isNewTeacher})> teacherUpdates;

  const TeacherAssignmentPlan({
    this.fileError,
    this.rows = const [],
    this.teacherUpdates = const {},
  });

  List<TeacherImportRow> get valid => rows.where((r) => r.isValid).toList();
  List<TeacherImportRow> get errors => rows.where((r) => r.error != null).toList();
}

List<String> _splitList(String raw) {
  if (raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[,;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Parses and validates a Teacher Assignments CSV string.
TeacherAssignmentPlan parseTeacherAssignmentsCsv(
  String content, {
  required List<AppUser> existingStaff,
  List<String>? availableSubjects,
  List<String>? availableClasses,
  bool allowNewTeachers = false,
}) {
  if (content.trim().isEmpty) {
    return const TeacherAssignmentPlan(fileError: 'That file is completely empty.');
  }

  final table = decodeCsv(content);
  if (table.isEmpty) {
    return const TeacherAssignmentPlan(fileError: 'That file could not be read as CSV.');
  }

  final rawHeader = table.first.map((c) => c.trim()).toList();
  if (rawHeader.length == 1 && rawHeader.first.contains(';')) {
    return const TeacherAssignmentPlan(
      fileError: 'This file uses semicolons between columns. Re-save it as "CSV (comma delimited)" and upload again.',
    );
  }

  // Header column normalization
  final colMap = <String, int>{};
  for (var i = 0; i < rawHeader.length; i++) {
    final h = rawHeader[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (h == 'teachername' || h == 'name' || h == 'staffname') {
      colMap['teacherName'] = i;
    } else if (h == 'teacheremail' || h == 'email') {
      colMap['teacherEmail'] = i;
    } else if (h == 'subjects' || h == 'subject') {
      colMap['subjects'] = i;
    } else if (h == 'classes' || h == 'class' || h == 'classlevel' || h == 'form') {
      colMap['classes'] = i;
    } else if (h == 'classmasterof' || h == 'classmaster' || h == 'classmasterofclass') {
      colMap['classMasterOf'] = i;
    }
  }

  if (!colMap.containsKey('teacherName') && !colMap.containsKey('teacherEmail')) {
    return const TeacherAssignmentPlan(
      fileError: 'Missing required teacher name or email column. Use the template for the required columns.',
    );
  }

  final validClasses = availableClasses ?? _defaultSchoolClasses;
  final validSubjects = availableSubjects ?? kAcademicSubjects;

  final rows = <TeacherImportRow>[];
  final teacherUpdates = <String, ({String teacherName, String email, List<TeachingAssignment> assignments, String? classMasterOf, bool isNewTeacher})>{};

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

    final row = TeacherImportRow(lineNumber: i + 1, raw: raw);
    rows.add(row);

    final name = raw['teacherName'] ?? '';
    final email = (raw['teacherEmail'] ?? '').toLowerCase();
    final rawSubjects = raw['subjects'] ?? '';
    final rawClasses = raw['classes'] ?? '';
    final rawMaster = raw['classMasterOf'] ?? '';

    if (name.isEmpty && email.isEmpty) {
      row.error = 'Teacher name or email is required.';
      continue;
    }

    // Match teacher against existing school staff
    AppUser? matched;
    if (email.isNotEmpty) {
      final matches = existingStaff.where((u) => u.email.trim().toLowerCase() == email).toList();
      if (matches.isNotEmpty) {
        matched = matches.first;
      }
    }

    if (matched == null && name.isNotEmpty) {
      final normGiven = _norm(name);
      if (normGiven.length >= 2) {
        final exact = existingStaff.where((u) => _norm(u.name) == normGiven).toList();
        if (exact.isNotEmpty) {
          matched = exact.first;
        } else {
          final matches = existingStaff.where((u) {
            final staffNorm = _norm(u.name);
            if (staffNorm.length < 2) return false;
            return (staffNorm.length >= 4 && normGiven.contains(staffNorm)) ||
                (normGiven.length >= 4 && staffNorm.contains(normGiven));
          }).toList();

          if (matches.length == 1) {
            matched = matches.first;
          } else if (matches.length > 1) {
            row.error = 'Multiple staff found matching "$name". Provide teacherEmail to identify which teacher.';
            continue;
          }
        }
      }
    }

    bool isNew = false;
    if (matched == null) {
      if (!allowNewTeachers) {
        row.error = 'No staff member found for "${name.isNotEmpty ? name : email}". Check spelling or create user account first.';
        continue;
      }
      final safeName = name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : 'Staff Member');
      final newId = 'staff_${DateTime.now().millisecondsSinceEpoch}_${i}_${safeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
      matched = AppUser(
        id: newId,
        name: safeName,
        email: email,
        role: UserRole.lecturer,
        schoolId: existingStaff.isNotEmpty ? existingStaff.first.schoolId : null,
      );
      isNew = true;
      row.warning = 'New teacher - will be added to the school staff directory.';
    }

    row.resolvedTeacherId = matched.id;
    row.resolvedTeacherName = matched.name;
    row.resolvedTeacherEmail = matched.email;

    // Parse subjects
    final subjectList = _splitList(rawSubjects);
    final resolvedSubjects = <String>[];
    for (final s in subjectList) {
      final match = validSubjects.firstWhere(
        (sub) => _norm(sub) == _norm(s),
        orElse: () => s,
      );
      resolvedSubjects.add(match);
    }

    // Parse classes
    final classList = _splitList(rawClasses);
    final resolvedClasses = <String>[];
    for (final c in classList) {
      final match = validClasses.firstWhere(
        (cls) => _norm(cls) == _norm(c),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        resolvedClasses.add(match);
      } else {
        row.warning = 'Class "$c" does not match any known school class.';
      }
    }

    // Create assignment pairs
    final newAssignments = <TeachingAssignment>[];
    if (resolvedSubjects.isNotEmpty && resolvedClasses.isNotEmpty) {
      for (final s in resolvedSubjects) {
        for (final c in resolvedClasses) {
          newAssignments.add(TeachingAssignment(subject: s, classLevel: c));
        }
      }
    } else if (resolvedSubjects.isNotEmpty && resolvedClasses.isEmpty && classList.isEmpty) {
      // Teacher assigned to subject across classes or not specified
      row.warning = 'No classes specified for assigned subjects.';
    }

    row.assignments = newAssignments;

    // Parse Class Master
    String? masterClass;
    if (rawMaster.isNotEmpty && _norm(rawMaster) != 'none' && _norm(rawMaster) != 'null') {
      final match = validClasses.firstWhere(
        (cls) => _norm(cls) == _norm(rawMaster),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        masterClass = match;
        row.classMasterOf = match;
      } else {
        row.error = 'Invalid class master class: "$rawMaster".';
        continue;
      }
    }

    // Accumulate into plan map
    final current = teacherUpdates[matched.id];
    final combinedAssignments = <TeachingAssignment>{
      if (current != null) ...current.assignments,
      ...newAssignments,
    }.toList();

    final effectiveMaster = masterClass ?? current?.classMasterOf;
    teacherUpdates[matched.id] = (
      teacherName: matched.name,
      email: matched.email,
      assignments: combinedAssignments,
      classMasterOf: effectiveMaster,
      isNewTeacher: isNew || (current?.isNewTeacher ?? false),
    );
  }

  return TeacherAssignmentPlan(
    rows: rows,
    teacherUpdates: teacherUpdates,
  );
}

/// Generates a starter CSV template for teacher assignments.
String generateTeacherCsvTemplate() {
  final rows = [
    kTeacherCsvColumns,
    ['John Fon', 'john.fon@school.cm', 'Mathematics, Further Mathematics', 'Form 4, Form 5', 'Form 5'],
    ['Marie Bih', 'marie.bih@school.cm', 'English Language, Literature', 'Form 2, Form 3', ''],
    ['Paul Taku', 'paul.taku@school.cm', 'Physics, Chemistry', 'Form 5, Lower Sixth Science', ''],
  ];
  return encodeCsv(rows);
}

/// Exports existing staff assignments to CSV format.
String exportTeacherAssignmentsCsv(List<AppUser> staff) {
  final rows = <List<String>>[kTeacherCsvColumns];
  for (final t in staff) {
    if (t.teachingAssignments.isEmpty && t.classMasterOfClass == null) continue;
    final subjects = t.teachingAssignments.map((a) => a.subject).toSet().join('; ');
    final classes = t.teachingAssignments.map((a) => a.classLevel).toSet().join('; ');
    final master = t.classMasterOfClass ?? '';
    rows.add([
      t.name,
      t.email,
      subjects,
      classes,
      master,
    ]);
  }
  return encodeCsv(rows);
}

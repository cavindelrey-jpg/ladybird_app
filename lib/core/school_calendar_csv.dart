// lib/core/school_calendar_csv.dart
// Pure Dart (no Flutter, no Supabase) School Calendar / Program of Activities
// CSV parser, validator, and exporter.
// Mirrors the architecture of marks_csv.dart, timetable_csv.dart, and student_roster_csv.dart.

import '../models/school_calendar_event.dart';
import 'marks_csv.dart' show encodeCsv, decodeCsv;

const List<String> kSchoolCalendarCsvColumns = [
  'date',
  'activity',
  'description',
  'category',
  'responsiblePerson',
  'location',
  'targetGroup',
  'status',
];

class SchoolCalendarImportRow {
  final int lineNumber;
  final Map<String, String> raw;
  String? error;
  String? warning;
  SchoolCalendarEvent? resolved;

  SchoolCalendarImportRow({required this.lineNumber, required this.raw});

  bool get isValid => error == null && resolved != null;
}

class SchoolCalendarPlan {
  final String? fileError;
  final List<SchoolCalendarImportRow> rows;

  const SchoolCalendarPlan({this.fileError, this.rows = const []});

  List<SchoolCalendarImportRow> get valid => rows.where((r) => r.isValid).toList();
  List<SchoolCalendarImportRow> get errors => rows.where((r) => r.error != null).toList();
}

/// Normalizes dates supporting YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY, YYYY/MM/DD.
DateTime? parseFlexibleDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  // Try standard ISO
  final direct = DateTime.tryParse(s);
  if (direct != null) return DateTime(direct.year, direct.month, direct.day);

  // Try DD/MM/YYYY or DD-MM-YYYY
  final parts = s.split(RegExp(r'[/.\-]'));
  if (parts.length == 3) {
    // If first part is 4 digits -> YYYY/MM/DD
    if (parts[0].length == 4) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    }
    // Else DD/MM/YYYY
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      final fullYear = y < 100 ? 2000 + y : y;
      return DateTime(fullYear, m, d);
    }
  }

  return null;
}

SchoolEventCategory parseCategory(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.contains('exam') || s.contains('test') || s.contains('quiz')) {
    return SchoolEventCategory.exam;
  }
  if (s.contains('meet') || s.contains('pta') || s.contains('assembly') || s.contains('council')) {
    return SchoolEventCategory.meeting;
  }
  if (s.contains('sport') || s.contains('game') || s.contains('match') || s.contains('tourn')) {
    return SchoolEventCategory.sports;
  }
  if (s.contains('holi') || s.contains('break') || s.contains('vacat') || s.contains('fest')) {
    return SchoolEventCategory.holiday;
  }
  return SchoolEventCategory.academic;
}

/// Generates a standardized, ready-to-use CSV template.
String generateSchoolCalendarCsvTemplate() {
  final now = DateTime.now();
  final d1 = '${now.year}-${now.month.toString().padLeft(2, '0')}-15';
  final d2 = '${now.year}-${now.month.toString().padLeft(2, '0')}-22';
  final d3 = '${now.year}-${now.month.toString().padLeft(2, '0')}-28';

  final rows = [
    kSchoolCalendarCsvColumns,
    [
      d1,
      'First Term General Assembly',
      'Opening school assembly and orientation for students',
      'Meeting',
      'Principal / Discipline Master',
      'Main Auditorium',
      'All Students',
      'Confirmed',
    ],
    [
      d2,
      'Inter-House Football Championship',
      'Preliminary sports tournament round',
      'Sports',
      'Sports Coordinator',
      'School Sports Complex',
      'Form 1, Form 2, Form 3',
      'Planned',
    ],
    [
      d3,
      'Mid-Term Sequence 1 Examinations',
      'First sequence written evaluations across all subjects',
      'Exam',
      'Academic Dean',
      'Classrooms',
      'All Students',
      'Confirmed',
    ],
  ];
  return encodeCsv(rows);
}

/// Parses and validates a Program of Activities CSV string.
SchoolCalendarPlan parseSchoolCalendarCsv(String content, String schoolId) {
  if (content.trim().isEmpty) {
    return const SchoolCalendarPlan(fileError: 'That file is completely empty.');
  }

  final table = decodeCsv(content);
  if (table.isEmpty) {
    return const SchoolCalendarPlan(fileError: 'That file could not be read as CSV.');
  }

  final rawHeader = table.first.map((c) => c.trim()).toList();
  if (rawHeader.length == 1 && rawHeader.first.contains(';')) {
    return const SchoolCalendarPlan(
      fileError: 'This file uses semicolons between columns. Re-save it as "CSV (comma delimited)" and upload again.',
    );
  }

  // Header column normalization
  final colMap = <String, int>{};
  for (var i = 0; i < rawHeader.length; i++) {
    final h = rawHeader[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (h == 'date' || h == 'startdate' || h == 'activitydate') {
      colMap['date'] = i;
    } else if (h == 'activity' || h == 'title' || h == 'activityname' || h == 'event') {
      colMap['activity'] = i;
    } else if (h == 'description' || h == 'desc' || h == 'details' || h == 'notes') {
      colMap['description'] = i;
    } else if (h == 'category' || h == 'type') {
      colMap['category'] = i;
    } else if (h == 'responsibleperson' || h == 'responsible' || h == 'organizer' || h == 'staff') {
      colMap['responsiblePerson'] = i;
    } else if (h == 'location' || h == 'venue' || h == 'room') {
      colMap['location'] = i;
    } else if (h == 'targetgroup' || h == 'target' || h == 'classes' || h == 'audience') {
      colMap['targetGroup'] = i;
    } else if (h == 'status') {
      colMap['status'] = i;
    }
  }

  if (!colMap.containsKey('date') || !colMap.containsKey('activity')) {
    return const SchoolCalendarPlan(
      fileError: 'Missing required columns: "date" and "activity". Download the template for the required format.',
    );
  }

  final rows = <SchoolCalendarImportRow>[];
  final seenInFile = <String, int>{};

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

    final row = SchoolCalendarImportRow(lineNumber: i + 1, raw: raw);
    rows.add(row);

    final rawDate = raw['date'] ?? '';
    final activity = raw['activity'] ?? '';
    final description = raw['description'] ?? '';
    final rawCategory = raw['category'] ?? '';
    final location = raw['location'] ?? '';
    final targetGroup = raw['targetGroup'] ?? '';
    final responsible = raw['responsiblePerson'] ?? '';

    if (activity.length < 2) {
      row.error = 'Activity title must have at least 2 characters.';
      continue;
    }

    final parsedDate = parseFlexibleDate(rawDate);
    if (parsedDate == null) {
      row.error = 'Invalid date format "$rawDate". Expected YYYY-MM-DD or DD/MM/YYYY.';
      continue;
    }

    // Check for duplicate activity on the same date within the file
    final dedupeKey = '${parsedDate.year}-${parsedDate.month}-${parsedDate.day}|${activity.toLowerCase()}';
    final prevLine = seenInFile[dedupeKey];
    if (prevLine != null) {
      row.warning = 'Activity "$activity" is repeated for this date (first seen on line $prevLine).';
    } else {
      seenInFile[dedupeKey] = i + 1;
    }

    final category = parseCategory(rawCategory);

    // Target group handling: comma separated classes, or empty for all
    final affectedClasses = <String>[];
    if (targetGroup.isNotEmpty && !targetGroup.toLowerCase().contains('all')) {
      for (final part in targetGroup.split(RegExp(r'[,;]'))) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) affectedClasses.add(trimmed);
      }
    }

    final fullDesc = StringBuffer(description);
    if (responsible.isNotEmpty) {
      if (fullDesc.isNotEmpty) fullDesc.write(' | ');
      fullDesc.write('Lead: $responsible');
    }

    final eventId = 'act_${parsedDate.millisecondsSinceEpoch}_${i}_${activity.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

    row.resolved = SchoolCalendarEvent(
      id: eventId,
      schoolId: schoolId,
      title: activity,
      description: fullDesc.toString(),
      category: category,
      startDate: parsedDate,
      endDate: parsedDate,
      allDay: true,
      location: location.isNotEmpty ? location : null,
      affectedClasses: affectedClasses,
      notifyParents: true,
    );
  }

  return SchoolCalendarPlan(rows: rows);
}

/// Encodes an existing list of events to CSV.
String exportSchoolCalendarCsv(List<SchoolCalendarEvent> events) {
  final rows = <List<String>>[
    kSchoolCalendarCsvColumns,
  ];

  final sorted = List<SchoolCalendarEvent>.from(events)
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  for (final e in sorted) {
    final dateStr = '${e.startDate.year}-${e.startDate.month.toString().padLeft(2, '0')}-${e.startDate.day.toString().padLeft(2, '0')}';
    rows.add([
      dateStr,
      e.title,
      e.description,
      e.category.label,
      '', // responsiblePerson
      e.location ?? '',
      e.affectedClasses.isEmpty ? 'All Students' : e.affectedClasses.join(', '),
      'Confirmed',
    ]);
  }

  return encodeCsv(rows);
}

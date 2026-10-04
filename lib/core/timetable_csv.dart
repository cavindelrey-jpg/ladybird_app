// lib/core/timetable_csv.dart
// Pure Dart (no Flutter, no Supabase) timetable CSV parser, validator, and exporter.
// Mirrors the architecture of lib/core/marks_csv.dart for consistent school data handling.

import '../models/school_timetable_slot.dart';
import 'marks_csv.dart' show encodeCsv, decodeCsv;

const List<String> kTimetableCsvColumns = [
  'classLevel',
  'dayOfWeek',
  'startTime',
  'endTime',
  'subject',
  'teacherName',
  'room',
];

class TimetableImportRow {
  final int lineNumber;
  final Map<String, String> raw;
  String? error;
  String? warning;
  SchoolTimetableSlot? resolved;

  TimetableImportRow({required this.lineNumber, required this.raw});

  bool get isValid => error == null && resolved != null;

  String get classLevel => resolved?.classLevel ?? (raw['classLevel'] ?? raw['class'] ?? raw['class_level'] ?? '');
}

/// Normalizes day string (e.g. "Monday", "Mon", "1") to an integer 1..7 (1=Monday).
int? parseDayOfWeek(String raw) {
  final s = raw.trim().toLowerCase();
  final numVal = int.tryParse(s);
  if (numVal != null && numVal >= 1 && numVal <= 7) return numVal;

  if (s.startsWith('mon')) return 1;
  if (s.startsWith('tue')) return 2;
  if (s.startsWith('wed')) return 3;
  if (s.startsWith('thu')) return 4;
  if (s.startsWith('fri')) return 5;
  if (s.startsWith('sat')) return 6;
  if (s.startsWith('sun')) return 7;
  return null;
}

/// Formats an integer day 1..7 to friendly name.
String dayNameFromInt(int day) {
  const names = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  if (day >= 1 && day <= 7) return names[day];
  return 'Day $day';
}

/// Normalizes time strings like "8:00", "08:00", "8", "14:30", "2:30 pm" to "HH:mm".
String? normalizeTime(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;

  bool isPm = s.contains('pm');
  bool isAm = s.contains('am');
  s = s.replaceAll(RegExp(r'[a-z\s]'), '');

  final parts = s.split(':');
  int? hour;
  int minute = 0;

  if (parts.isNotEmpty) {
    hour = int.tryParse(parts[0]);
  }
  if (parts.length > 1) {
    minute = int.tryParse(parts[1]) ?? 0;
  }

  if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }

  if (isPm && hour < 12) hour += 12;
  if (isAm && hour == 12) hour = 0;

  final hStr = hour.toString().padLeft(2, '0');
  final mStr = minute.toString().padLeft(2, '0');
  return '$hStr:$mStr';
}

/// Parses and validates a Timetable CSV file string.
({String? fileError, List<TimetableImportRow> rows}) parseTimetableCsv(
  String content,
  String schoolId, {
  List<SchoolTimetableSlot>? existingSchoolSlots,
}) {
  if (content.trim().isEmpty) {
    return (fileError: 'That file is completely empty.', rows: const []);
  }

  final table = decodeCsv(content);
  if (table.isEmpty) {
    return (fileError: 'That file could not be read as CSV.', rows: const []);
  }

  final header = table.first.map((c) => c.trim()).toList();
  final lowerHeader = header.map((c) => c.toLowerCase()).toList();

  int findCol(List<String> aliases) {
    for (final a in aliases) {
      final idx = lowerHeader.indexOf(a.toLowerCase());
      if (idx != -1) return idx;
    }
    return -1;
  }

  final classIdx = findCol(['classLevel', 'class', 'level', 'class_level']);
  final dayIdx = findCol(['dayOfWeek', 'day', 'day_of_week']);
  final startIdx = findCol(['startTime', 'start', 'from', 'start_time']);
  final endIdx = findCol(['endTime', 'end', 'to', 'end_time']);
  final subjectIdx = findCol(['subject', 'course']);
  final teacherIdx = findCol(['teacherName', 'teacher', 'teacher_name', 'lecturer']);
  final roomIdx = findCol(['room', 'classroom', 'hall']);

  final missing = <String>[];
  if (classIdx == -1) missing.add('classLevel');
  if (dayIdx == -1) missing.add('dayOfWeek');
  if (startIdx == -1) missing.add('startTime');
  if (endIdx == -1) missing.add('endTime');
  if (subjectIdx == -1) missing.add('subject');

  if (missing.isNotEmpty) {
    return (
      fileError: 'Missing required column(s): ${missing.join(', ')}. Use the template for the required columns.',
      rows: const [],
    );
  }

  final out = <TimetableImportRow>[];
  final seenFileSlots = <SchoolTimetableSlot>[];

  for (var i = 1; i < table.length; i++) {
    final line = table[i];
    if (line.isEmpty || (line.length == 1 && line.first.trim().isEmpty)) continue;

    String getVal(int idx) => (idx >= 0 && idx < line.length) ? line[idx].trim() : '';

    final rawMap = <String, String>{
      'classLevel': getVal(classIdx),
      'dayOfWeek': getVal(dayIdx),
      'startTime': getVal(startIdx),
      'endTime': getVal(endIdx),
      'subject': getVal(subjectIdx),
      'teacherName': getVal(teacherIdx),
      'room': getVal(roomIdx),
    };

    final row = TimetableImportRow(lineNumber: i + 1, raw: rawMap);
    out.add(row);

    final classLevel = rawMap['classLevel']!;
    final dayRaw = rawMap['dayOfWeek']!;
    final startRaw = rawMap['startTime']!;
    final endRaw = rawMap['endTime']!;
    final subject = rawMap['subject']!;
    final teacher = rawMap['teacherName'] ?? '';
    final room = rawMap['room'];

    if (classLevel.isEmpty) {
      row.error = 'Class is required.';
      continue;
    }
    if (subject.isEmpty) {
      row.error = 'Subject is required.';
      continue;
    }

    final day = parseDayOfWeek(dayRaw);
    if (day == null) {
      row.error = 'Invalid day "$dayRaw" — enter Monday–Sunday or 1–7.';
      continue;
    }

    final startTime = normalizeTime(startRaw);
    if (startTime == null) {
      row.error = 'Invalid start time "$startRaw" (use HH:mm, e.g. 08:00).';
      continue;
    }

    final endTime = normalizeTime(endRaw);
    if (endTime == null) {
      row.error = 'Invalid end time "$endRaw" (use HH:mm, e.g. 09:00).';
      continue;
    }

    if (startTime.compareTo(endTime) >= 0) {
      row.error = 'Start time ($startTime) must be earlier than end time ($endTime).';
      continue;
    }

    final candidate = SchoolTimetableSlot(
      id: '',
      schoolId: schoolId,
      classLevel: classLevel,
      dayOfWeek: day,
      startTime: startTime,
      endTime: endTime,
      subject: subject,
      teacherName: teacher,
      room: (room != null && room.isNotEmpty) ? room : null,
    );

    // Intra-file conflict check
    bool hasFileClash = false;
    for (final seen in seenFileSlots) {
      if (seen.dayOfWeek != candidate.dayOfWeek) continue;
      final timesOverlap = !(candidate.endTime.compareTo(seen.startTime) <= 0 ||
          candidate.startTime.compareTo(seen.endTime) >= 0);
      if (!timesOverlap) continue;

      if (seen.classLevel.toLowerCase() == candidate.classLevel.toLowerCase()) {
        row.error = 'Time clash with line inside this file: ${seen.classLevel} already has ${seen.subject} at ${seen.startTime}–${seen.endTime}.';
        hasFileClash = true;
        break;
      }
      if (candidate.room != null &&
          seen.room != null &&
          seen.room!.toLowerCase() == candidate.room!.toLowerCase()) {
        row.error = 'Room clash with line inside this file: Room "${seen.room}" is double-booked at ${seen.startTime}–${seen.endTime}.';
        hasFileClash = true;
        break;
      }
    }
    if (hasFileClash) continue;

    // Existing school slots clash check (as warning or notice)
    if (existingSchoolSlots != null) {
      for (final exist in existingSchoolSlots) {
        if (exist.dayOfWeek != candidate.dayOfWeek) continue;
        final timesOverlap = !(candidate.endTime.compareTo(exist.startTime) <= 0 ||
            candidate.startTime.compareTo(exist.endTime) >= 0);
        if (!timesOverlap) continue;

        if (exist.classLevel.toLowerCase() == candidate.classLevel.toLowerCase()) {
          row.warning = 'Overlaps existing period: ${exist.classLevel} already has ${exist.subject} (${exist.startTime}–${exist.endTime}).';
        } else if (candidate.room != null &&
            exist.room != null &&
            exist.room!.toLowerCase() == candidate.room!.toLowerCase()) {
          row.warning = 'Room ${exist.room} already booked by ${exist.classLevel} at this time.';
        }
      }
    }

    seenFileSlots.add(candidate);
    row.resolved = candidate;
  }

  return (fileError: null, rows: out);
}

/// Generates a sample CSV template string for Timetables.
String generateTimetableCsvTemplate() {
  final rows = <List<String>>[
    kTimetableCsvColumns,
    ['Form 2', 'Monday', '08:00', '09:00', 'Mathematics', 'Mr. Fon', 'Room 12'],
    ['Form 2', 'Monday', '09:00', '10:00', 'English Language', 'Mrs. Bih', 'Room 12'],
    ['Form 2', 'Monday', '10:30', '11:30', 'Physics', 'Dr. Taku', 'Lab 2'],
    ['Form 2', 'Tuesday', '08:00', '09:00', 'Chemistry', 'Dr. Taku', 'Lab 1'],
    ['Form 2', 'Tuesday', '09:00', '10:00', 'Biology', 'Mrs. Bih', 'Room 12'],
  ];
  return encodeCsv(rows);
}

/// Exports a list of timetable slots to CSV string.
String exportTimetableCsv(List<SchoolTimetableSlot> slots) {
  final rows = <List<String>>[kTimetableCsvColumns];
  final sorted = slots.toList()
    ..sort((a, b) {
      final byClass = a.classLevel.compareTo(b.classLevel);
      if (byClass != 0) return byClass;
      final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (byDay != 0) return byDay;
      return a.startTime.compareTo(b.startTime);
    });

  for (final s in sorted) {
    rows.add([
      s.classLevel,
      dayNameFromInt(s.dayOfWeek),
      s.startTime,
      s.endTime,
      s.subject,
      s.teacherName,
      s.room ?? '',
    ]);
  }

  return encodeCsv(rows);
}

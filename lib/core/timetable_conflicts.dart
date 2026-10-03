// lib/core/timetable_conflicts.dart
// Pure timetable validation + conflict detection, unit-tested in
// test/timetable_conflicts_test.dart. Used by the timetable manager both
// before saving a period and to badge existing periods.
//
// Errors block saving (the timetable would be physically impossible);
// warnings are shown and need an explicit "Save anyway" (data that's
// probably a mistake but may be intentional, e.g. a cover teacher).

import '../models/school_timetable_slot.dart';
import '../models/teaching_assignment.dart';

enum ConflictSeverity { error, warning }

class TimetableConflict {
  final ConflictSeverity severity;
  final String message;
  /// The other period involved, when there is one.
  final SchoolTimetableSlot? other;
  const TimetableConflict(this.severity, this.message, [this.other]);
  bool get isError => severity == ConflictSeverity.error;
  @override
  String toString() => '${severity.name}: $message';
}

/// Staff as the checker needs them.
class TimetableStaff {
  final String name;
  final List<TeachingAssignment> assignments;
  final String? classMasterOf;
  const TimetableStaff({required this.name, this.assignments = const [], this.classMasterOf});
}

/// "8:00", "08:00", "8h00", "8.00" -> "08:00". Null when not a real time.
String? normalizeTime(String raw) {
  final m = RegExp(r'^\s*(\d{1,2})\s*[:h.]\s*(\d{2})\s*$').firstMatch(raw);
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

int _minutes(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _overlaps(SchoolTimetableSlot a, SchoolTimetableSlot b) {
  if (a.dayOfWeek != b.dayOfWeek) return false;
  final as = normalizeTime(a.startTime), ae = normalizeTime(a.endTime);
  final bs = normalizeTime(b.startTime), be = normalizeTime(b.endTime);
  if (as == null || ae == null || bs == null || be == null) return false;
  return _minutes(as) < _minutes(be) && _minutes(bs) < _minutes(ae);
}

/// Validates the period itself (times, subject) -- independent of others.
List<TimetableConflict> validateSlot(SchoolTimetableSlot s) {
  final out = <TimetableConflict>[];
  final start = normalizeTime(s.startTime), end = normalizeTime(s.endTime);
  if (start == null) out.add(const TimetableConflict(ConflictSeverity.error, 'Start time must look like 08:00.'));
  if (end == null) out.add(const TimetableConflict(ConflictSeverity.error, 'End time must look like 09:00.'));
  if (start != null && end != null && _minutes(end) <= _minutes(start)) {
    out.add(const TimetableConflict(ConflictSeverity.error, 'The period must end after it starts.'));
  }
  if (s.subject.trim().isEmpty) out.add(const TimetableConflict(ConflictSeverity.error, 'Choose a subject.'));
  if (s.dayOfWeek < 1 || s.dayOfWeek > 6) {
    out.add(const TimetableConflict(ConflictSeverity.error, 'Pick a school day (Mon–Sat).'));
  }
  return out;
}

/// Conflicts between [candidate] and the rest of the school's timetable
/// ([schoolSlots] -- every class; the candidate's own id is ignored, so
/// editing a period doesn't clash with itself). [staff] is the school's
/// current staff list, or null when it couldn't be loaded (staff checks
/// are then skipped rather than reported as false alarms).
List<TimetableConflict> findConflicts(
  SchoolTimetableSlot candidate,
  List<SchoolTimetableSlot> schoolSlots, {
  List<TimetableStaff>? staff,
}) {
  final out = <TimetableConflict>[...validateSlot(candidate)];
  if (out.any((c) => c.isError)) return out;

  final others = schoolSlots.where((s) => s.id.isEmpty || s.id != candidate.id);
  final teacher = _norm(candidate.teacherName);
  final room = _norm(candidate.room ?? '');

  for (final o in others) {
    if (!_overlaps(candidate, o)) continue;
    final when = '${o.dayName} ${o.startTime}–${o.endTime}';
    if (o.classLevel == candidate.classLevel) {
      out.add(TimetableConflict(ConflictSeverity.error,
          '${candidate.classLevel} already has ${o.subject} on $when.', o));
    }
    if (teacher.isNotEmpty && _norm(o.teacherName) == teacher && o.classLevel != candidate.classLevel) {
      out.add(TimetableConflict(ConflictSeverity.error,
          '${o.teacherName} is already teaching ${o.subject} to ${o.classLevel} on $when.', o));
    }
    if (room.isNotEmpty && _norm(o.room ?? '') == room && o.classLevel != candidate.classLevel) {
      out.add(TimetableConflict(ConflictSeverity.error,
          'Room ${candidate.room} is already used by ${o.classLevel} (${o.subject}) on $when.', o));
    }
  }

  if (teacher.isEmpty) {
    out.add(const TimetableConflict(ConflictSeverity.warning, 'No teacher assigned to this period.'));
  } else if (staff != null) {
    final match = staff.where((t) => _norm(t.name) == teacher).toList();
    if (match.isEmpty) {
      out.add(TimetableConflict(ConflictSeverity.warning,
          '${candidate.teacherName} isn\'t on this school\'s staff list (removed, or name misspelt?).'));
    } else {
      final t = match.first;
      final assigned = t.classMasterOf == candidate.classLevel ||
          t.assignments.any((a) => _norm(a.subject) == _norm(candidate.subject) && a.classLevel == candidate.classLevel);
      if (!assigned) {
        out.add(TimetableConflict(ConflictSeverity.warning,
            '${t.name} isn\'t assigned to teach ${candidate.subject} in ${candidate.classLevel} '
            '(Teacher Management) — they won\'t be able to enter marks for it.'));
      }
    }
  }
  return out;
}

/// Every conflict in a whole school timetable, keyed by slot id -- for
/// badging existing periods. Each pair is reported on both periods.
Map<String, List<TimetableConflict>> auditTimetable(List<SchoolTimetableSlot> slots, {List<TimetableStaff>? staff}) {
  return {
    for (final s in slots)
      if (findConflicts(s, slots, staff: staff).isNotEmpty) s.id: findConflicts(s, slots, staff: staff),
  };
}

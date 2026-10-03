import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/timetable_conflicts.dart';
import 'package:academia_app/models/school_timetable_slot.dart';
import 'package:academia_app/models/teaching_assignment.dart';

SchoolTimetableSlot slot(String id, String cls, int day, String start, String end, String subject,
        {String teacher = '', String? room}) =>
    SchoolTimetableSlot(
      id: id, schoolId: 'lb', classLevel: cls, dayOfWeek: day, startTime: start, endTime: end,
      subject: subject, teacherName: teacher, room: room,
    );

const staff = [
  TimetableStaff(name: 'Paul Mbarga', assignments: [TeachingAssignment(subject: 'Mathematics', classLevel: 'Form 5')]),
  TimetableStaff(name: 'Grace Fon', assignments: [TeachingAssignment(subject: 'Languages', classLevel: 'Form 4')]),
  TimetableStaff(name: 'Joseph Ekane', classMasterOf: 'Form 5'),
];

final existing = [
  slot('a', 'Form 5', 1, '07:30', '08:25', 'Mathematics', teacher: 'Paul Mbarga', room: 'B12'),
  slot('b', 'Form 4', 1, '07:30', '08:25', 'Languages', teacher: 'Grace Fon', room: 'A04'),
];

List<String> msgs(List<TimetableConflict> c) => c.map((e) => e.toString()).toList();

void main() {
  test('normalizeTime', () {
    expect(normalizeTime('8:00'), '08:00');
    expect(normalizeTime('8h05'), '08:05');
    expect(normalizeTime(' 13.30 '), '13:30');
    expect(normalizeTime('25:00'), isNull);
    expect(normalizeTime('8'), isNull);
    expect(normalizeTime('08:7'), isNull);
  });

  test('clean period has no conflicts', () {
    final c = findConflicts(slot('', 'Form 5', 1, '08:25', '09:20', 'Mathematics', teacher: 'Paul Mbarga', room: 'B12'),
        existing, staff: staff);
    expect(c, isEmpty);
  });

  test('back-to-back periods do not overlap', () {
    final c = findConflicts(slot('', 'Form 5', 1, '08:25', '09:20', 'Mathematics', teacher: 'Paul Mbarga'), existing);
    expect(c.where((e) => e.isError), isEmpty);
  });

  test('same class double-booked is an error', () {
    final c = findConflicts(slot('', 'Form 5', 1, '08:00', '09:00', 'Science', teacher: 'Joseph Ekane'), existing, staff: staff);
    expect(msgs(c), contains(startsWith('error: Form 5 already has Mathematics on Mon 07:30–08:25')));
  });

  test('one teacher in two classes at the same time is an error', () {
    final c = findConflicts(slot('', 'Form 4', 1, '08:00', '09:00', 'Mathematics', teacher: 'paul  mbarga'),
        [existing.first], staff: staff);
    expect(msgs(c), contains(contains('Paul Mbarga is already teaching Mathematics to Form 5')));
  });

  test('room double-booked is an error', () {
    final c = findConflicts(slot('', 'Form 3', 1, '07:45', '08:15', 'Arts & Literature', teacher: 'Joseph Ekane', room: 'b12'),
        existing, staff: staff);
    expect(msgs(c), contains(contains('Room b12 is already used by Form 5')));
  });

  test('different day never conflicts', () {
    final c = findConflicts(slot('', 'Form 5', 2, '07:30', '08:25', 'Science', teacher: 'Paul Mbarga', room: 'B12'),
        existing, staff: staff);
    expect(c.where((e) => e.isError), isEmpty);
  });

  test('editing a period does not conflict with itself', () {
    final edited = slot('a', 'Form 5', 1, '07:30', '08:30', 'Mathematics', teacher: 'Paul Mbarga', room: 'B12');
    expect(findConflicts(edited, existing, staff: staff), isEmpty);
  });

  test('empty period / missing teacher / removed teacher / unassigned subject are warnings', () {
    expect(msgs(findConflicts(slot('', 'Form 5', 3, '07:30', '08:25', 'Science'), existing, staff: staff)),
        ['warning: No teacher assigned to this period.']);
    expect(msgs(findConflicts(slot('', 'Form 5', 3, '07:30', '08:25', 'Science', teacher: 'Old Teacher'), existing, staff: staff)).single,
        contains('isn\'t on this school\'s staff list'));
    expect(msgs(findConflicts(slot('', 'Form 4', 3, '07:30', '08:25', 'Mathematics', teacher: 'Paul Mbarga'), existing, staff: staff)).single,
        contains('isn\'t assigned to teach Mathematics in Form 4'));
  });

  test('class master may teach any subject in their own class', () {
    expect(findConflicts(slot('', 'Form 5', 3, '07:30', '08:25', 'Business', teacher: 'Joseph Ekane'), existing, staff: staff), isEmpty);
  });

  test('staff checks are skipped when staff list is unavailable', () {
    expect(findConflicts(slot('', 'Form 5', 3, '07:30', '08:25', 'Science', teacher: 'Anyone'), existing), isEmpty);
  });

  test('invalid times and empty subject are errors and short-circuit', () {
    expect(msgs(findConflicts(slot('', 'Form 5', 1, '9:00', '8:00', 'Maths'), existing)),
        ['error: The period must end after it starts.']);
    expect(msgs(findConflicts(slot('', 'Form 5', 1, 'nine', '10:00', ''), existing)),
        containsAll(['error: Start time must look like 08:00.', 'error: Choose a subject.']));
    expect(msgs(findConflicts(slot('', 'Form 5', 7, '09:00', '10:00', 'Maths'), existing)),
        ['error: Pick a school day (Mon–Sat).']);
  });

  test('audit badges both sides of a clash', () {
    final slots = [...existing, slot('c', 'Form 3', 1, '08:00', '09:00', 'Mathematics', teacher: 'Paul Mbarga')];
    final audit = auditTimetable(slots);
    expect(audit.keys, containsAll(['a', 'c']));
    expect(audit.containsKey('b'), isFalse);
  });
}

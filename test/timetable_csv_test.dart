import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/timetable_csv.dart';
import 'package:academia_app/models/school_timetable_slot.dart';

void main() {
  group('Timetable CSV Helpers', () {
    test('parseDayOfWeek parses name and integer formats', () {
      expect(parseDayOfWeek('Monday'), 1);
      expect(parseDayOfWeek('mon'), 1);
      expect(parseDayOfWeek('1'), 1);
      expect(parseDayOfWeek('Tuesday'), 2);
      expect(parseDayOfWeek('wed'), 3);
      expect(parseDayOfWeek('Thursday'), 4);
      expect(parseDayOfWeek('Fri'), 5);
      expect(parseDayOfWeek('Saturday'), 6);
      expect(parseDayOfWeek('Sunday'), 7);
      expect(parseDayOfWeek('InvalidDay'), isNull);
    });

    test('normalizeTime normalizes various time formats to HH:mm', () {
      expect(normalizeTime('8:00'), '08:00');
      expect(normalizeTime('08:00'), '08:00');
      expect(normalizeTime('8'), '08:00');
      expect(normalizeTime('14:30'), '14:30');
      expect(normalizeTime('2:30 pm'), '14:30');
      expect(normalizeTime('8:30 am'), '08:30');
      expect(normalizeTime('12:00 pm'), '12:00');
      expect(normalizeTime('12:00 am'), '00:00');
      expect(normalizeTime('invalid'), isNull);
    });
  });

  group('Timetable CSV Parsing and Validation', () {
    test('rejects empty or whitespace file', () {
      final res = parseTimetableCsv('   ', 'school-1');
      expect(res.fileError, isNotNull);
      expect(res.rows, isEmpty);
    });

    test('rejects missing columns', () {
      final res = parseTimetableCsv('classLevel,dayOfWeek\nForm 1,Monday', 'school-1');
      expect(res.fileError, contains('Missing required column(s)'));
    });

    test('parses valid timetable rows cleanly', () {
      const csv = '''classLevel,dayOfWeek,startTime,endTime,subject,teacherName,room
Form 4,Monday,08:00,09:30,Mathematics,Mr. Nfor,Room 12
Form 4,Monday,09:30,10:30,Physics,Dr. Eto,Lab 2
Form 5,Tuesday,10:00,11:30,Chemistry,Mrs. Muna,Lab 1''';

      final res = parseTimetableCsv(csv, 'school-1');
      expect(res.fileError, isNull);
      expect(res.rows.length, 3);
      expect(res.rows.every((r) => r.isValid), isTrue);

      final r1 = res.rows[0].resolved!;
      expect(r1.classLevel, 'Form 4');
      expect(r1.dayOfWeek, 1);
      expect(r1.startTime, '08:00');
      expect(r1.endTime, '09:30');
      expect(r1.subject, 'Mathematics');
      expect(r1.teacherName, 'Mr. Nfor');
      expect(r1.room, 'Room 12');
    });

    test('handles BOM header and CRLF line endings', () {
      const csv = '\uFEFFclassLevel,dayOfWeek,startTime,endTime,subject,teacherName,room\r\nForm 3,Wednesday,08:00,09:00,English,Ms. Fru,Room 5\r\n';
      final res = parseTimetableCsv(csv, 'school-1');
      expect(res.fileError, isNull);
      expect(res.rows.length, 1);
      expect(res.rows.first.isValid, isTrue);
      expect(res.rows.first.resolved!.subject, 'English');
    });

    test('flags intra-file class overlap conflict', () {
      const csv = '''classLevel,dayOfWeek,startTime,endTime,subject,teacherName,room
Form 4,Monday,08:00,09:30,Mathematics,Mr. Nfor,Room 12
Form 4,Monday,09:00,10:30,Biology,Mrs. Tabi,Room 14''';

      final res = parseTimetableCsv(csv, 'school-1');
      expect(res.fileError, isNull);
      expect(res.rows.length, 2);
      expect(res.rows[1].error, contains('Time clash with line inside this file'));
    });

    test('flags intra-file room overlap conflict', () {
      const csv = '''classLevel,dayOfWeek,startTime,endTime,subject,teacherName,room
Form 4,Monday,08:00,09:30,Mathematics,Mr. Nfor,Room 12
Form 5,Monday,08:30,10:00,English,Mrs. Tabi,Room 12''';

      final res = parseTimetableCsv(csv, 'school-1');
      expect(res.fileError, isNull);
      expect(res.rows.length, 2);
      expect(res.rows[1].error, contains('Room clash with line inside this file'));
    });

    test('flags conflict against existing school slots as warning', () {
      final existing = [
        const SchoolTimetableSlot(
          id: 'slot-1',
          schoolId: 'school-1',
          classLevel: 'Form 4',
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '09:30',
          subject: 'Existing History',
          teacherName: 'Mr. Old',
          room: 'Room 1',
        ),
      ];

      const csv = '''classLevel,dayOfWeek,startTime,endTime,subject,teacherName,room
Form 4,Monday,08:30,10:00,Mathematics,Mr. Nfor,Room 12''';

      final res = parseTimetableCsv(csv, 'school-1', existingSchoolSlots: existing);
      expect(res.fileError, isNull);
      expect(res.rows.length, 1);
      expect(res.rows[0].warning, contains('Overlaps existing period'));
    });

    test('template generation and export round-trip', () {
      final template = generateTimetableCsvTemplate();
      expect(template, contains('classLevel,dayOfWeek,startTime,endTime,subject,teacherName,room'));
      expect(template, contains('Form 2,Monday,08:00,09:00,Mathematics'));

      final slots = [
        const SchoolTimetableSlot(
          id: 's1',
          schoolId: 'sch1',
          classLevel: 'Form 3',
          dayOfWeek: 2,
          startTime: '10:00',
          endTime: '11:30',
          subject: 'Physics',
          teacherName: 'Dr. John',
          room: 'Lab 1',
        ),
      ];

      final exported = exportTimetableCsv(slots);
      expect(exported, contains('Form 3,Tuesday,10:00,11:30,Physics,Dr. John,Lab 1'));

      final reParsed = parseTimetableCsv(exported, 'sch1');
      expect(reParsed.fileError, isNull);
      expect(reParsed.rows.length, 1);
      expect(reParsed.rows.first.resolved!.subject, 'Physics');
      expect(reParsed.rows.first.resolved!.dayOfWeek, 2);
    });
  });
}

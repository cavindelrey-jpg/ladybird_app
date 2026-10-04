import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/student_roster_csv.dart';
import 'package:academia_app/models/student_record.dart';

void main() {
  group('Student Roster CSV Parsing & Validation', () {
    test('rejects empty file', () {
      final plan = parseStudentRosterCsv('', 'school-1');
      expect(plan.fileError, isNotNull);
      expect(plan.rows, isEmpty);
    });

    test('rejects missing studentName or classLevel columns', () {
      final plan = parseStudentRosterCsv('matricule,parentContact\n123,456', 'school-1');
      expect(plan.fileError, contains('Missing required column(s)'));
    });

    test('parses valid student rows cleanly', () {
      const csv = '''studentName,classLevel,matricule,parentContact,gender
Brice Ngono,Form 4,LBS-2026-001,+237 670001122,M
Clarisse Tchakounte,Form 4,LBS-2026-002,+237 671112233,F
Yannick Ebanda,Form 5,LBS-2026-015,+237 690223344,M''';

      final plan = parseStudentRosterCsv(csv, 'school-1');
      expect(plan.fileError, isNull);
      expect(plan.rows.length, 3);
      expect(plan.valid.length, 3);

      final r1 = plan.rows[0].resolved!;
      expect(r1.name, 'Brice Ngono');
      expect(r1.classLevel, 'Form 4');
      expect(r1.matricule, 'LBS-2026-001');
      expect(r1.parentContact, '+237 670001122');
      expect(r1.gender, 'M');
    });

    test('flags intra-file duplicate matricules', () {
      const csv = '''studentName,classLevel,matricule,parentContact,gender
Brice Ngono,Form 4,LBS-2026-001,+237 670001122,M
Paul Mbarga,Form 4,LBS-2026-001,+237 679998877,M''';

      final plan = parseStudentRosterCsv(csv, 'school-1');
      expect(plan.rows.length, 2);
      expect(plan.rows[1].error, contains('Duplicate matricule "LBS-2026-001" on line 2'));
    });

    test('flags unknown class level with error', () {
      const csv = '''studentName,classLevel,matricule
Brice Ngono,Grade 9,LBS-2026-001''';

      final plan = parseStudentRosterCsv(csv, 'school-1');
      expect(plan.rows.first.error, contains('Unknown class "Grade 9"'));
    });

    test('template generation and export round-trip', () {
      final template = generateStudentRosterCsvTemplate();
      expect(template, contains('studentName,classLevel,matricule,parentContact,gender'));
      expect(template, contains('Brice Ngono,Form 4,LBS-2026-001'));

      final students = [
        const StudentRecord(
          id: 's1',
          schoolId: 'school-1',
          name: 'Clarisse Tchakounte',
          classLevel: 'Form 4',
          matricule: 'LBS-002',
          parentContact: '+237 671234567',
          gender: 'F',
        ),
      ];

      final exported = exportStudentRosterCsv(students);
      expect(exported, contains('Clarisse Tchakounte,Form 4,LBS-002,+237 671234567,F'));

      final reParsed = parseStudentRosterCsv(exported, 'school-1');
      expect(reParsed.fileError, isNull);
      expect(reParsed.rows.length, 1);
      expect(reParsed.rows.first.resolved!.name, 'Clarisse Tchakounte');
    });
  });
}

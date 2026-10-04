import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/teacher_csv.dart';
import 'package:academia_app/models/app_user.dart';
import 'package:academia_app/models/teaching_assignment.dart';

void main() {
  final staffList = [
    const AppUser(
      id: 'staff-1',
      name: 'John Fon',
      email: 'john.fon@school.cm',
      role: UserRole.lecturer,
    ),
    const AppUser(
      id: 'staff-2',
      name: 'Marie Bih',
      email: 'marie.bih@school.cm',
      role: UserRole.lecturer,
    ),
  ];

  group('Teacher Assignments CSV Parsing & Validation', () {
    test('rejects empty content', () {
      final plan = parseTeacherAssignmentsCsv('', existingStaff: staffList);
      expect(plan.fileError, isNotNull);
      expect(plan.rows, isEmpty);
    });

    test('rejects missing header', () {
      final plan = parseTeacherAssignmentsCsv('randomCol1,randomCol2\na,b', existingStaff: staffList);
      expect(plan.fileError, contains('Missing required teacher name or email column'));
    });

    test('parses and matches staff by email and name', () {
      const csv = '''teacherName,teacherEmail,subjects,classes,classMasterOf
John Fon,john.fon@school.cm,"Mathematics, Further Mathematics","Form 4, Form 5",Form 5
Marie Bih,,English Language,Form 2,''';

      final plan = parseTeacherAssignmentsCsv(csv, existingStaff: staffList);
      expect(plan.fileError, isNull);
      expect(plan.rows.length, 2);
      expect(plan.valid.length, 2);

      final row1 = plan.rows[0];
      expect(row1.resolvedTeacherId, 'staff-1');
      expect(row1.classMasterOf, 'Form 5');
      expect(row1.assignments.length, 4); // 2 subjects x 2 classes

      final row2 = plan.rows[1];
      expect(row2.resolvedTeacherId, 'staff-2');
      expect(row2.assignments.length, 1);
      expect(row2.assignments.first, const TeachingAssignment(subject: 'English Language', classLevel: 'Form 2'));
    });

    test('merges multiple rows for same teacher', () {
      const csv = '''teacherName,teacherEmail,subjects,classes,classMasterOf
John Fon,john.fon@school.cm,Mathematics,Form 4,Form 4
John Fon,john.fon@school.cm,Physics,Form 5,''';

      final plan = parseTeacherAssignmentsCsv(csv, existingStaff: staffList);
      expect(plan.fileError, isNull);
      expect(plan.teacherUpdates.length, 1);
      final update = plan.teacherUpdates['staff-1']!;
      expect(update.assignments.length, 2);
      expect(update.classMasterOf, 'Form 4');
    });

    test('flags unknown staff with helpful error', () {
      const csv = '''teacherName,teacherEmail,subjects,classes,classMasterOf
Unknown Teacher,unknown@school.cm,Mathematics,Form 4,''';

      final plan = parseTeacherAssignmentsCsv(csv, existingStaff: staffList);
      expect(plan.rows.first.error, contains('No staff member found'));
    });

    test('generates template and exports existing assignments', () {
      final template = generateTeacherCsvTemplate();
      expect(template, contains('teacherName,teacherEmail,subjects,classes,classMasterOf'));
      expect(template, contains('John Fon'));

      final staffWithAssignments = [
        const AppUser(
          id: 'staff-1',
          name: 'John Fon',
          email: 'john.fon@school.cm',
          role: UserRole.lecturer,
          teachingAssignments: [
            TeachingAssignment(subject: 'Mathematics', classLevel: 'Form 5'),
          ],
          classMasterOfClass: 'Form 5',
        ),
      ];

      final exported = exportTeacherAssignmentsCsv(staffWithAssignments);
      expect(exported, contains('John Fon,john.fon@school.cm,Mathematics,Form 5,Form 5'));
    });
  });
}

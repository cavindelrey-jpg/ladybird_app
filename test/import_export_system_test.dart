// test/import_export_system_test.dart
// Comprehensive tests for the platform-wide Import/Export system across Academia:
// - School Calendar / Activities CSV parsing, export, and templates
// - School Timetables CSV parsing, export, and templates
// - Student Class Rosters CSV parsing, export, and 13-student bulk persistence fix
// - Teachers & Assignments CSV parsing, auto-registration, and templates
// - Marks Broadsheets CSV template and export
// - Production-quality PDF & Word (.docx) document generation

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:academia_app/core/result.dart';
import 'package:academia_app/core/school_calendar_csv.dart';
import 'package:academia_app/core/timetable_csv.dart';
import 'package:academia_app/core/student_roster_csv.dart';
import 'package:academia_app/core/teacher_csv.dart';
import 'package:academia_app/core/marks_csv.dart';
import 'package:academia_app/models/app_user.dart';
import 'package:academia_app/models/school_calendar_event.dart';
import 'package:academia_app/models/school_timetable_slot.dart';
import 'package:academia_app/models/student_record.dart';
import 'package:academia_app/models/school_mark.dart';
import 'package:academia_app/models/teaching_assignment.dart';
import 'package:academia_app/repositories/student_roster_repository.dart';
import 'package:academia_app/services/school_document_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. School Calendar / Program of Activities CSV', () {
    test('generateSchoolCalendarCsvTemplate generates valid CSV template', () {
      final template = generateSchoolCalendarCsvTemplate();
      expect(template, contains('date'));
      expect(template, contains('activity'));
      expect(template, contains('description'));
      expect(template, contains('category'));
      expect(template, contains('responsiblePerson'));
      expect(template, contains('General Assembly'));
    });

    test('parseSchoolCalendarCsv correctly parses valid rows and reports errors', () {
      final year = DateTime.now().year;
      final csv = '''Date,Activity,Description,Category,Responsible Person,Location,Target Group,Status
$year-09-08,School Reopening,First day of academic year,academic,Principal,Main Hall,All Students,scheduled
$year-10-15,Mid-Term Examinations,First term assessments,exam,HOD Exams,Classrooms,All Classes,scheduled
invalid-date,Invalid Event,Bad date test,academic,Admin,Campus,All,scheduled
$year-11-20,Inter-School Football,Friendly match,sports,Sports Master,Sports Field,Athletes,completed''';

      final plan = parseSchoolCalendarCsv(csv, 'school-test-1');
      expect(plan.fileError, isNull);
      expect(plan.rows.length, 4);
      expect(plan.valid.length, 3);
      expect(plan.errors.length, 1);
      expect(plan.errors.first.error, contains('Invalid date format'));

      final firstEvent = plan.valid.first.resolved!;
      expect(firstEvent.title, 'School Reopening');
      expect(firstEvent.category, SchoolEventCategory.academic);
      expect(firstEvent.location, 'Main Hall');
    });

    test('exportSchoolCalendarCsv produces importable CSV from event list', () {
      final now = DateTime.now();
      final List<SchoolCalendarEvent> events = [
        SchoolCalendarEvent(
          id: 'ev-1',
          schoolId: 'school-test-1',
          title: 'Annual Science Fair',
          description: 'Students present STEM projects',
          startDate: DateTime(now.year, 11, 15, 9, 0),
          endDate: DateTime(now.year, 11, 15, 16, 0),
          category: SchoolEventCategory.academic,
          location: 'Science Lab',
        ),
      ];

      final csv = exportSchoolCalendarCsv(events);
      expect(csv, contains('Annual Science Fair'));
      expect(csv, contains('Students present STEM projects'));
      expect(csv, contains('Science Lab'));

      // Re-parse exported CSV
      final plan = parseSchoolCalendarCsv(csv, 'school-test-1');
      expect(plan.valid.length, 1);
      expect(plan.valid.first.resolved!.title, 'Annual Science Fair');
    });
  });

  group('2. Timetable CSV & Templates', () {
    test('generateTimetableCsvTemplate generates valid timetable CSV', () {
      final template = generateTimetableCsvTemplate();
      expect(template, contains('classLevel,dayOfWeek,startTime,endTime,subject,teacherName,room'));
      expect(template, contains('Form 2,Monday,08:00,09:00'));
    });

    test('parseTimetableCsv parses periods and exports cleanly', () {
      const csv = '''classLevel,dayOfWeek,startTime,endTime,subject,teacherName,room
Form 3,Monday,08:00,08:50,Mathematics,Mr. Che,Room 12
Form 3,Monday,08:50,09:40,English Language,Mrs. Ngono,Room 12''';

      final plan = parseTimetableCsv(csv, 'school-test-1');
      expect(plan.fileError, isNull);
      expect(plan.rows.length, 2);
      final validRows = plan.rows.where((r) => r.isValid).toList();
      expect(validRows.length, 2);

      final exported = exportTimetableCsv(validRows.map((r) => r.resolved!).toList());
      expect(exported, contains('Form 3'));
      expect(exported, contains('Mathematics'));
      expect(exported, contains('English Language'));
    });
  });

  group('3. Student Roster CSV & Bulk Upload 13-Record Display Bug Fix', () {
    test('generateStudentRosterCsvTemplate generates valid student CSV template', () {
      final template = generateStudentRosterCsvTemplate();
      expect(template, contains('studentName,classLevel,matricule,parentContact,gender'));
      expect(template, contains('Brice Ngono'));
    });

    test('parse 13 students and verify all 13 are valid and persist without being dropped', () async {
      // Build a CSV with 13 students (matching user problem description)
      final rows = <String>['studentName,classLevel,matricule,parentContact,gender'];
      for (int i = 1; i <= 13; i++) {
        rows.add('Student $i,Form 2,MAT-2026-${i.toString().padLeft(3, '0')},+237 67000${i.toString().padLeft(4, '0')},${i.isEven ? 'F' : 'M'}');
      }
      final csv = rows.join('\n');

      final plan = parseStudentRosterCsv(csv, 'school-test-1');
      expect(plan.fileError, isNull);
      expect(plan.rows.length, 13);
      expect(plan.valid.length, 13, reason: 'All 13 students must be valid');

      final students = plan.valid.map((r) => r.resolved!).toList();
      expect(students.length, 13);

      // Verify StudentRosterRepository batchUpsert and cache retention:
      // Ingest all 13 students via batchUpsert
      await StudentRosterRepository.instance.batchUpsert('school-test-1', students);

      // Read back via getStudents
      final result = await StudentRosterRepository.instance.getStudents(
        'school-test-1',
        classLevel: 'Form 2',
      );

      expect(result, isA<Success<List<StudentRecord>>>());
      final retrieved = (result as Success<List<StudentRecord>>).value;

      // The critical assertion for the bulk upload bug:
      // Must return all 13 students, not 1!
      expect(retrieved.length, 13, reason: 'All 13 uploaded students must appear and not be reduced to 1');
      expect(retrieved.map((s) => s.name).toSet().length, 13);
    });
  });

  group('4. Teacher Management CSV & Auto-Registration', () {
    test('generateTeacherCsvTemplate produces valid CSV template', () {
      final template = generateTeacherCsvTemplate();
      expect(template, contains('teacherName,teacherEmail,subjects,classes,classMasterOf'));
      expect(template, contains('John Fon'));
    });

    test('parseTeacherAssignmentsCsv handles multiple teachers including auto-provisioning new staff', () {
      const csv = '''teacherName,teacherEmail,subjects,classes,classMasterOf
Dr. Kamga,kamga@example.com,Physics,Form 5,Form 5
Mrs. Amina,amina@example.com,Chemistry,Form 5,none
Mr. Fon,fon@example.com,Biology,Form 4,none''';

      final plan = parseTeacherAssignmentsCsv(csv, existingStaff: [], allowNewTeachers: true);
      expect(plan.fileError, isNull);
      expect(plan.rows.length, 3);
      final validRows = plan.rows.where((r) => r.isValid).toList();
      expect(validRows.length, 3);

      expect(plan.teacherUpdates.length, 3);
      final kamgaUpdate = plan.teacherUpdates.values.firstWhere((u) => u.teacherName == 'Dr. Kamga');
      expect(kamgaUpdate.classMasterOf, 'Form 5');
      expect(kamgaUpdate.isNewTeacher, isTrue);

      final exported = exportTeacherAssignmentsCsv([
        AppUser(
          id: 'u-1',
          name: 'Dr. Kamga',
          email: 'kamga@example.com',
          role: UserRole.lecturer,
          teachingAssignments: [
            const TeachingAssignment(subject: 'Physics', classLevel: 'Form 5'),
          ],
          classMasterOfClass: 'Form 5',
        ),
      ]);
      expect(exported, contains('Dr. Kamga'));
      expect(exported, contains('Physics'));
    });
  });

  group('5. Marks Broadsheet CSV', () {
    test('generateMarksCsvTemplate produces valid CSV template', () {
      final template = generateMarksCsvTemplate();
      expect(template, contains('studentName,classLevel,subject,sequence,academicYear,score,maxScore'));
      expect(template, contains('Brice Ngono,Form 5,Mathematics'));
    });

    test('exportMarksCsv exports marks cleanly and accurately', () {
      final roster = [
        const RosterStudent(id: 's-1', name: 'Alice Mbi', classLevel: 'Form 5'),
        const RosterStudent(id: 's-2', name: 'Bob Tabe', classLevel: 'Form 5'),
      ];
      final marks = {
        's-1': const SchoolMark(
          id: 'm-1',
          studentId: 's-1',
          studentName: 'Alice Mbi',
          classLevel: 'Form 5',
          subject: 'Physics',
          sequence: AcademicSequence.t1s1,
          score: 18.5,
          maxScore: 20,
          academicYear: '2026/2027',
          schoolId: 'school-test-1',
        ),
      };

      final csv = exportMarksCsv(
        roster: roster,
        marksByStudentId: marks,
        classLevel: 'Form 5',
        subject: 'Physics',
        sequence: AcademicSequence.t1s1,
        academicYear: '2026/2027',
      );

      expect(csv, contains('Alice Mbi,Form 5,Physics,t1s1,2026/2027,18.5,20'));
      expect(csv, contains('Bob Tabe,Form 5,Physics,t1s1,2026/2027,,20'));
    });
  });

  group('6. Production-Quality PDF & Word (.docx) Document Exports', () {
    test('exportTimetablePdf and exportTimetableDocx generate valid non-empty files', () async {
      final List<SchoolTimetableSlot> slots = [
        const SchoolTimetableSlot(
          id: 'slot-1',
          schoolId: 'school-test-1',
          classLevel: 'Form 4',
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '08:50',
          subject: 'Mathematics',
          teacherName: 'Mr. Che',
          room: 'Room 12',
        ),
        const SchoolTimetableSlot(
          id: 'slot-2',
          schoolId: 'school-test-1',
          classLevel: 'Form 4',
          dayOfWeek: 1,
          startTime: '08:50',
          endTime: '09:40',
          subject: 'English',
          teacherName: 'Mrs. Ngono',
          room: 'Room 12',
        ),
      ];

      final pdfFile = await SchoolDocumentExportService.instance.exportTimetablePdf(
        schoolName: 'Ladybird International School',
        classLevel: 'Form 4',
        slots: slots,
      );
      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(500));

      final docxFile = await SchoolDocumentExportService.instance.exportTimetableDocx(
        schoolName: 'Ladybird International School',
        classLevel: 'Form 4',
        slots: slots,
      );
      expect(docxFile.existsSync(), isTrue);
      expect(docxFile.lengthSync(), greaterThan(500));
    });

    test('exportActivitiesPdf and exportActivitiesDocx generate valid files', () async {
      final List<SchoolCalendarEvent> events = [
        SchoolCalendarEvent(
          id: 'ev-1',
          schoolId: 'school-test-1',
          title: 'Science Fair',
          description: 'Science Fair Exhibition',
          startDate: DateTime(2026, 11, 15),
          endDate: DateTime(2026, 11, 15),
          category: SchoolEventCategory.academic,
          location: 'Lab 1',
        ),
      ];

      final pdfFile = await SchoolDocumentExportService.instance.exportActivitiesPdf(
        schoolName: 'Ladybird International School',
        events: events,
      );
      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(500));

      final docxFile = await SchoolDocumentExportService.instance.exportActivitiesDocx(
        schoolName: 'Ladybird International School',
        events: events,
      );
      expect(docxFile.existsSync(), isTrue);
      expect(docxFile.lengthSync(), greaterThan(500));
    });

    test('exportStudentRosterPdf and exportStudentRosterDocx generate valid files for 13 students', () async {
      final List<StudentRecord> students = List.generate(
        13,
        (i) => StudentRecord(
          id: 'st-$i',
          schoolId: 'school-test-1',
          name: 'Student ${i + 1}',
          classLevel: 'Form 3',
          matricule: 'MAT-${2026 + i}',
          parentContact: '+237 67000${1000 + i}',
          gender: i.isEven ? 'F' : 'M',
        ),
      );

      final pdfFile = await SchoolDocumentExportService.instance.exportStudentRosterPdf(
        schoolName: 'Ladybird International School',
        classLevel: 'Form 3',
        students: students,
      );
      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(500));

      final docxFile = await SchoolDocumentExportService.instance.exportStudentRosterDocx(
        schoolName: 'Ladybird International School',
        classLevel: 'Form 3',
        students: students,
      );
      expect(docxFile.existsSync(), isTrue);
      expect(docxFile.lengthSync(), greaterThan(500));
    });

    test('exportStaffDirectoryPdf and exportStaffDirectoryDocx generate valid files', () async {
      final List<AppUser> staff = [
        AppUser(
          id: 't-1',
          name: 'Dr. Kamga',
          email: 'kamga@example.com',
          schoolId: 'school-test-1',
          schoolName: 'Ladybird International School',
          role: UserRole.lecturer,
          teachingAssignments: [
            const TeachingAssignment(subject: 'Physics', classLevel: 'Form 5'),
          ],
          classMasterOfClass: 'Form 5',
        ),
      ];

      final pdfFile = await SchoolDocumentExportService.instance.exportStaffDirectoryPdf(
        schoolName: 'Ladybird International School',
        staff: staff,
      );
      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(500));

      final docxFile = await SchoolDocumentExportService.instance.exportStaffDirectoryDocx(
        schoolName: 'Ladybird International School',
        staff: staff,
      );
      expect(docxFile.existsSync(), isTrue);
      expect(docxFile.lengthSync(), greaterThan(500));
    });

    test('exportMarksPdf and exportMarksDocx generate valid files', () async {
      final List<SchoolMark> marks = [
        const SchoolMark(
          id: 'm-1',
          studentId: 'st-1',
          studentName: 'Brice Ngono',
          classLevel: 'Form 5',
          subject: 'Mathematics',
          sequence: AcademicSequence.t1s1,
          score: 17.5,
          maxScore: 20,
          academicYear: '2026/2027',
          schoolId: 'school-test-1',
        ),
      ];

      final pdfFile = await SchoolDocumentExportService.instance.exportMarksPdf(
        schoolName: 'Ladybird International School',
        classLevel: 'Form 5',
        subject: 'Mathematics',
        sequenceName: 'Term 1 Sequence 1',
        marks: marks,
      );
      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(500));

      final docxFile = await SchoolDocumentExportService.instance.exportMarksDocx(
        schoolName: 'Ladybird International School',
        classLevel: 'Form 5',
        subject: 'Mathematics',
        sequenceName: 'Term 1 Sequence 1',
        marks: marks,
      );
      expect(docxFile.existsSync(), isTrue);
      expect(docxFile.lengthSync(), greaterThan(500));
    });
  });
}

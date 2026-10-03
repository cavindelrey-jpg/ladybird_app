import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/marks_csv.dart';
import 'package:academia_app/models/school_mark.dart';

const _given = ['Brice', 'Ange', 'Clarisse', 'Yannick', 'Prisca', 'Arnaud', 'Vanessa', 'Loïc', 'Murielle', 'Franck'];
const _family = ['Ngono', 'Tchakounte', 'Ebanda', 'Fomba', 'Nkwenti', 'Abena'];

List<RosterStudent> _form5() => [
      for (var i = 0; i < 60; i++)
        RosterStudent(
          id: 'stu-$i',
          name: '${_given[i % _given.length]} ${_family[i ~/ _given.length]}',
          classLevel: 'Form 5',
        ),
    ];

MarksImportPlan _plan(String csv, {List<RosterStudent>? roster, bool Function(String, String)? canRecord}) =>
    planMarksImport(
      table: decodeCsv(csv),
      rosters: {'Form 5': roster ?? _form5()},
      canRecord: canRecord ?? (s, c) => s == 'Mathematics' && c == 'Form 5',
      schoolId: 'school-1',
      teacherName: 'Paul Mbarga',
      gradedBy: 'teacher-1',
      defaultYear: '2026',
    );

String _row(String name, String score, {String subject = 'Mathematics', String seq = 't1s1', String max = '20'}) =>
    '$name,Form 5,$subject,$seq,2026,$score,$max';

void main() {
  final header = kMarksCsvColumns.join(',');

  test('roster fixture really is 60 distinct students', () {
    expect(_form5().map((s) => s.name).toSet().length, 60);
  });

  test('imports all 60 students with correct student/score mapping', () {
    final roster = _form5();
    final lines = [header, for (var i = 0; i < 60; i++) _row(roster[i].name, '${(i % 21)}')];
    final plan = _plan(lines.join('\n'));
    expect(plan.fileError, isNull);
    expect(plan.valid.length, 60);
    for (var i = 0; i < 60; i++) {
      final m = plan.rows[i].resolved!;
      expect(m.studentId, 'stu-$i');
      expect(m.score, (i % 21).toDouble());
      expect(m.subject, 'Mathematics');
      expect(m.classLevel, 'Form 5');
      expect(m.sequence, AcademicSequence.t1s1);
    }
  });

  test('Excel UTF-8 BOM and CRLF line endings are accepted', () {
    final csv = '﻿$header\r\n${_row('Brice Ngono', '15')}\r\n';
    final plan = _plan(csv);
    expect(plan.fileError, isNull);
    expect(plan.valid.single.resolved!.studentId, 'stu-0');
  });

  test('name matching ignores case and extra spaces, keeps accents', () {
    final plan = _plan('$header\n${_row('  loïc   NGONO ', '12')}');
    expect(plan.valid.single.resolved!.studentId, 'stu-7');
  });

  test('decimal marks, including French comma decimals in quotes', () {
    final plan = _plan('$header\n${_row('Brice Ngono', '13.5')}\n${_row('Ange Ngono', '"14,25"')}');
    expect(plan.valid.map((r) => r.resolved!.score), [13.5, 14.25]);
  });

  test('invalid rows are reported per line, valid rows still import', () {
    final csv = [
      header,
      _row('Brice Ngono', '15'), // ok (line 2)
      _row('Ange Ngono', '25'), // > max
      _row('Clarisse Ngono', '-1'), // negative
      _row('Yannick Ngono', 'abc'), // not a number
      _row('Prisca Ngono', ''), // blank
      _row('Nobody Atall', '10'), // not in class
      _row('Arnaud Ngono', '10', seq: 't9s9'), // bad sequence
      _row('Vanessa Ngono', '10', subject: 'Science'), // not authorized
      _row('Murielle Ngono', '10', max: '0'), // bad max
      ',Form 5,Mathematics,t1s1,2026,10,20', // missing name
    ].join('\n');
    final plan = _plan(csv);
    expect(plan.valid.length, 1);
    final errs = {for (final r in plan.invalid) r.lineNumber: r.error!};
    expect(errs[3], contains('between 0 and 20'));
    expect(errs[4], contains('between 0 and 20'));
    expect(errs[5], contains('must be numbers'));
    expect(errs[6], contains('No score'));
    expect(errs[7], contains('No student named "Nobody Atall"'));
    expect(errs[8], contains('Unknown sequence'));
    expect(errs[9], contains('not assigned to teach Science'));
    expect(errs[10], contains('greater than 0'));
    expect(errs[11], contains('required'));
  });

  test('duplicate student rows are both rejected, not silently last-wins', () {
    final plan = _plan('$header\n${_row('Brice Ngono', '15')}\n${_row('Ange Ngono', '9')}\n${_row('brice ngono', '3')}');
    expect(plan.valid.single.studentName, 'Ange Ngono');
    expect(plan.invalid.map((r) => r.lineNumber), [2, 4]);
    expect(plan.invalid.first.error, contains('Duplicate'));
  });

  test('same student, different sequences is NOT a duplicate', () {
    final plan = _plan('$header\n${_row('Brice Ngono', '15')}\n${_row('Brice Ngono', '11', seq: 't1s2')}');
    expect(plan.valid.length, 2);
  });

  test('two students sharing a name are flagged as ambiguous', () {
    final roster = [..._form5(), const RosterStudent(id: 'dup', name: 'Brice Ngono', classLevel: 'Form 5')];
    final plan = _plan('$header\n${_row('Brice Ngono', '15')}', roster: roster);
    expect(plan.invalid.single.error, contains('2 students named'));
  });

  test('empty, header-only, wrong header and semicolon files give clear file errors', () {
    expect(_plan('').fileError, 'The file is empty.');
    expect(_plan('\n\n').fileError, 'The file is empty.');
    expect(_plan(header).rows, isEmpty);
    expect(_plan('name,score\nBrice,12').fileError, contains('Missing column(s): studentName'));
    expect(_plan(kMarksCsvColumns.join(';')).fileError, contains('";"'));
  });

  test('corrupted quoting does not throw', () {
    expect(() => _plan('$header\n"Brice Ngono,Form 5,Mathematics'), returnsNormally);
  });

  test('export contains all 60 students once, correct headers, round-trips through import', () {
    final roster = _form5();
    final marks = {
      for (var i = 0; i < 60; i++)
        if (i != 13) // one student not yet marked
          'stu-$i': SchoolMark(
            id: 'm$i', schoolId: 'school-1', studentId: 'stu-$i', classLevel: 'Form 5',
            subject: 'Mathematics', sequence: AcademicSequence.t1s1, academicYear: '2026',
            score: (i % 20) + 0.5, maxScore: 20,
          ),
    };
    final csv = exportMarksCsv(
      roster: roster, marksByStudentId: marks, classLevel: 'Form 5',
      subject: 'Mathematics', sequence: AcademicSequence.t1s1, academicYear: '2026',
    );
    final table = decodeCsv(csv);
    expect(table.first, kMarksCsvColumns);
    expect(table.length, 61);
    final names = table.skip(1).map((r) => r[0]).toList();
    expect(names.toSet().length, 60, reason: 'no duplicates, nobody missing');

    final plan = _plan(csv);
    expect(plan.valid.length, 59);
    expect(plan.invalid.single.error, contains('No score'), reason: 'the unmarked student');
    for (final r in plan.valid) {
      final original = marks[r.resolved!.studentId]!;
      expect(r.resolved!.score, original.score);
      expect(r.resolved!.maxScore, original.maxScore);
    }
  });

  test('names with commas and quotes survive encode/decode', () {
    final rows = [
      ['Ngono, Brice "BB"', 'x'],
      ['multi\nline', 'y'],
    ];
    expect(decodeCsv(encodeCsv(rows)), rows);
  });

  group('parseScoreInput', () {
    test('blank means no mark', () => expect(parseScoreInput('  ', 20).value, isNull));
    test('valid', () => expect(parseScoreInput('12,5', 20).value, 12.5));
    test('too high', () => expect(parseScoreInput('21', 20).error, 'Max 20'));
    test('negative', () => expect(parseScoreInput('-1', 20).error, 'Min 0'));
    test('garbage', () => expect(parseScoreInput('1O', 20).error, 'Not a number'));
    test('too precise', () => expect(parseScoreInput('12.345', 20).error, '2 decimals max'));
    test('out of 100', () => expect(parseScoreInput('87', 100).value, 87));
  });

  test('formatMark never rounds a mark', () {
    expect(formatMark(6.5), '6.5');
    expect(formatMark(14), '14');
    expect(formatMark(12.25), '12.25');
    expect(formatMark(19.5), '19.5');
  });
}

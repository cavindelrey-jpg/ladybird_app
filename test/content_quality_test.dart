import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/content_quality.dart';
import 'package:academia_app/models/test.dart';

Test _fromFixture(String path) {
  final d = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return Test(
    id: path, subject: d['subject'] ?? '', title: d['title'] ?? '', topic: d['topic'] ?? '',
    createdBy: '', createdAt: DateTime(2026),
    questions: [for (final q in d['questions'] as List) TestQuestion.fromMap(Map<String, dynamic>.from(q))],
  );
}

TestQuestion _mcq(String prompt, List<String> options, [int correct = 0]) =>
    TestQuestion(id: prompt, type: QuestionType.mcq, prompt: prompt, options: options, correctIndex: correct);

Test _quiz(List<TestQuestion> qs, {String title = 'Cell Biology'}) =>
    Test(id: 'x', subject: 'Biology', title: title, topic: 'Cells', createdBy: '', createdAt: DateTime(2026), questions: qs);

void main() {
  group('quizzes', () {
    test('a generated filler quiz from the content pipeline is caught', () {
      expect(isPlaceholderQuiz(_fromFixture('test/fixtures/quiz_filler_generated.json')), isTrue);
    });

    test('a genuine quiz from the same pipeline is kept', () {
      expect(isPlaceholderQuiz(_fromFixture('test/fixtures/quiz_real_biology.json')), isFalse);
    });

    test('"This is question 1" with A/B/C/T options is filler', () {
      final q = _quiz([for (var i = 1; i <= 5; i++) _mcq('This is question $i', ['A', 'B', 'C', 'T'])]);
      expect(isPlaceholderQuiz(q), isTrue);
    });

    test('duplicated options and "what day of the course" are filler', () {
      expect(isPlaceholderQuestion(_mcq('What day of the course is this?', ['Day 1', 'Day 1', 'Day 2', 'Day 3'], 1)), isTrue);
      expect(isPlaceholderQuestion(_mcq('Which organelle makes ATP?', ['Ribosome', 'Ribosome', 'Nucleus', 'Vacuole'])), isTrue);
    });

    test('same template with only the number changing is filler', () {
      final q = _quiz([for (var i = 1; i <= 4; i++) _mcq('Define key term number $i of the chapter', ['alpha', 'beta', 'gamma', 'delta'])]);
      expect(isPlaceholderQuiz(q), isTrue);
    });

    test('empty quiz is filler; one weak question in a real quiz is tolerated', () {
      expect(isPlaceholderQuiz(_quiz([])), isTrue);
      final q = _quiz([
        _mcq('Which organelle releases energy from glucose?', ['Mitochondrion', 'Ribosome', 'Golgi body', 'Vacuole']),
        _mcq('Which structure controls what enters a cell?', ['Cell membrane', 'Cell wall', 'Nucleus', 'Chloroplast']),
        _mcq('Plant cells store sap in the…', ['Large vacuole', 'Nucleus', 'Ribosome', 'Centriole']),
        _mcq('Question 4', ['Option A', 'Option B', 'Option C', 'Option D']),
      ]);
      expect(isPlaceholderQuiz(q), isFalse);
    });

    test('displayQuizTitle replaces bare numbered titles', () {
      final q = _quiz([], title: 'Biology Quiz 694');
      expect(displayQuizTitle(q), 'Biology · Cells');
      expect(displayQuizTitle(_quiz([], title: '')), 'Biology · Cells');
      expect(displayQuizTitle(_quiz([], title: 'Photosynthesis and Respiration')), 'Photosynthesis and Respiration');
    });
  });

  group('courses', () {
    const realBody = 'Biology is the scientific study of life. It encompasses the investigation of living '
        'organisms, their vital processes, and their interactions with each other and the environment. '
        'Characteristics of living things include movement, respiration, sensitivity, growth, reproduction, '
        'excretion and nutrition.';

    test('stubs and templates found in production are caught', () {
      expect(isPlaceholderCourse(title: 'The Effects of the War', body: 'TO BE UPLOADED'), isTrue);
      expect(isPlaceholderCourse(title: 'yiugv', body: '', description: 'hshshd'), isTrue);
      expect(isPlaceholderCourse(title: 'Exploring Topic 555', body: '$realBody Topic 555 emerged as a literary movement.'), isTrue);
      expect(isPlaceholderCourse(title: 'Introduction to the Cell', body: 'Welcome to Topic 420 in Biology. $realBody'), isTrue);
      expect(isPlaceholderCourse(
          title: 'Market Forces',
          body: 'Welcome to this lesson on Market Forces. This covers the foundational aspects of Demand and Supply. '
              'Key Concepts. Understanding these basics is essential for mastering Economics. Summary. '
              'This concludes the introduction to Market Forces.'),
          isTrue);
    });

    test('short but genuine courses are kept', () {
      expect(isPlaceholderCourse(title: 'Introduction to General Biology', body: realBody), isFalse);
      expect(isPlaceholderCourse(
          title: 'Advanced Organic Synthesis',
          body: 'This lesson covers fundamental reaction mechanisms that govern advanced organic synthesis. $realBody'),
          isFalse);
    });

    test('dedupeBest keeps one copy per key, the most complete, in original order', () {
      final items = [('Matter', 300), ('Cell', 500), ('Matter', 900), ('Matter', 100), ('Atoms', 50)];
      final out = dedupeBest(items, keyOf: (i) => i.$1, scoreOf: (i) => i.$2);
      expect(out, [('Matter', 900), ('Cell', 500), ('Atoms', 50)]);
    });
  });

  test('the shipped replacement quizzes are real: 10 questions, 4 distinct options, not filler', () {
    final files = Directory('supabase/content/quizzes').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(files, hasLength(10));
    for (final f in files) {
      final t = _fromFixture(f.path);
      expect(isPlaceholderQuiz(t), isFalse, reason: f.path);
      expect(t.questions, hasLength(10), reason: f.path);
      for (final q in t.questions) {
        expect(q.options.toSet(), hasLength(4), reason: '${f.path}: ${q.prompt}');
        expect(isPlaceholderQuestion(q), isFalse, reason: '${f.path}: ${q.prompt}');
      }
    }
  });
}

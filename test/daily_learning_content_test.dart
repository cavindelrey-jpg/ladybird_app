import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/data/daily_learning_courses.dart';

void main() {
  test('every course has 30 real lessons with unique ids', () {
    final ids = <String>{};
    for (final c in dailyLearningCourses) {
      expect(c.lessons.length, 30, reason: c.id);
      for (final (i, l) in c.lessons.indexed) {
        expect(l.id, '${c.id}_${i + 1}', reason: 'stored progress keys on this id scheme');
        expect(ids.add(l.id), isTrue, reason: 'duplicate id ${l.id}');
        expect(l.teachingPoints, hasLength(3));
        expect(l.teachingPoints.any((p) => p.contains('fundamental principles')), isFalse, reason: 'placeholder text');
      }
    }
  });

  test('every question has 4 distinct options and a valid answer', () {
    for (final c in dailyLearningCourses) {
      for (final l in c.lessons) {
        for (final q in l.questions) {
          expect(q.options.toSet(), hasLength(4), reason: '${l.id}: "${q.prompt}" has duplicate options');
          expect(q.correctIndex, inInclusiveRange(0, 3), reason: l.id);
          expect(q.explanation.trim(), isNotEmpty, reason: l.id);
        }
      }
    }
  });

  test('correct answers are spread across positions (no always-B pattern)', () {
    final counts = List.filled(4, 0);
    for (final c in dailyLearningCourses) {
      for (final l in c.lessons) {
        for (final q in l.questions) {
          counts[q.correctIndex]++;
        }
      }
    }
    final total = counts.reduce((a, b) => a + b);
    for (final n in counts) {
      expect(n / total, inInclusiveRange(0.15, 0.35));
    }
  });

  test('60 days x 15 questions = 900 questions across Etymology and Fallacies', () {
    expect(etymologyCourse.lessons.length, 30);
    expect(fallaciesCourse.lessons.length, 30);
    for (final l in etymologyCourse.lessons) {
      expect(l.questions.length, 15, reason: 'Etymology lesson ${l.id} must have 15 questions');
    }
    for (final l in fallaciesCourse.lessons) {
      expect(l.questions.length, 15, reason: 'Fallacies lesson ${l.id} must have 15 questions');
    }
    final totalQuestions = etymologyCourse.lessons.fold<int>(0, (sum, l) => sum + l.questions.length) +
        fallaciesCourse.lessons.fold<int>(0, (sum, l) => sum + l.questions.length);
    expect(totalQuestions, 900);
  });
}

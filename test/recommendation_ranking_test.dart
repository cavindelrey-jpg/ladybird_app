// test/recommendation_ranking_test.dart
// Unit tests for RecommendationRepository.rankSubjectsByUsage
// (lib/repositories/recommendation_repository.dart, production_plan.md
// §5's usage signal: "Mathematics + Physics → ... → frequently completes
// Physics quizzes" should outrank a favorite subject the user only
// starred and never engages with).
//
// This is the one piece of new §5 logic with real branching (tie-breaks,
// missing-subject handling, all-zero no-op) worth pinning down with tests
// rather than trusting by inspection — everything else this session added
// (forQuizzes, the usage-count queries) is a direct, low-branching mirror
// of an already-shipped, already-trusted pattern (forCourses).

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/repositories/recommendation_repository.dart';

void main() {
  group('rankSubjectsByUsage', () {
    test('reorders favorites by descending completion count', () {
      final ranked = RecommendationRepository.rankSubjectsByUsage(
        ['Mathematics', 'Physics', 'Chemistry'],
        {'Physics': 12, 'Mathematics': 3, 'Chemistry': 0},
      );
      expect(ranked, ['Physics', 'Mathematics', 'Chemistry']);
    });

    test('an all-zero / empty usage map is a true no-op — keeps original order', () {
      const favorites = ['Mathematics', 'Physics', 'Chemistry'];
      expect(RecommendationRepository.rankSubjectsByUsage(favorites, const {}),
          favorites);
      expect(
          RecommendationRepository.rankSubjectsByUsage(
              favorites, {'Mathematics': 0, 'Physics': 0, 'Chemistry': 0}),
          favorites);
    });

    test('ties keep original relative order (explicit index tie-break, not '
        'List.sort\'s unstable default)', () {
      final ranked = RecommendationRepository.rankSubjectsByUsage(
        ['Biology', 'Physics', 'Mathematics', 'Chemistry'],
        {'Physics': 5, 'Chemistry': 5}, // Biology/Mathematics untouched -> 0
      );
      // Physics and Chemistry are tied at 5, but Physics appeared first in
      // the input, so it must still lead. Biology and Mathematics are
      // tied at 0 and must keep their original relative order too.
      expect(ranked, ['Physics', 'Chemistry', 'Biology', 'Mathematics']);
    });

    test('a subject with usage data that is not a favorite is ignored', () {
      final ranked = RecommendationRepository.rankSubjectsByUsage(
        ['Mathematics', 'Physics'],
        {'Chemistry': 99, 'Physics': 1}, // Chemistry isn't a favorite
      );
      expect(ranked, ['Physics', 'Mathematics']);
    });

    test('empty favorites list returns empty', () {
      expect(RecommendationRepository.rankSubjectsByUsage(const [], {'Physics': 5}),
          isEmpty);
    });
  });
}

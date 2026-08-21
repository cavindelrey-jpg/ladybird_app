// test/home_recommendation_ranking_test.dart
// Unit tests for the Homepage's OWN "Recommended for You" ranking helper
// (lib/features/dashboard/universal_home_page.dart: rankHomeSubjectsByUsage).
//
// production_plan.md §1 requires the homepage's "Recommended for You" to
// remain a SEPARATE, independently-evolvable computation from the §7B
// contextual recommendations in RecommendationRepository -- this pure
// function is that computation, and this file pins down its real
// branching (tie-breaks, no-signal no-ops) the same way
// test/recommendation_ranking_test.dart already does for
// RecommendationRepository.rankSubjectsByUsage.

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/features/dashboard/universal_home_page.dart';

void main() {
  group('rankHomeSubjectsByUsage', () {
    test('reorders favorites by descending completion count', () {
      final ranked = rankHomeSubjectsByUsage(
        ['Mathematics', 'Physics', 'Chemistry'],
        {'Physics': 12, 'Mathematics': 3, 'Chemistry': 0},
      );
      expect(ranked, ['Physics', 'Mathematics', 'Chemistry']);
    });

    test('an all-zero / empty usage map is a true no-op -- keeps original order', () {
      const favorites = ['Mathematics', 'Physics', 'Chemistry'];
      expect(rankHomeSubjectsByUsage(favorites, const {}), favorites);
      expect(
          rankHomeSubjectsByUsage(
              favorites, {'Mathematics': 0, 'Physics': 0, 'Chemistry': 0}),
          favorites);
    });

    test('ties keep original relative order (explicit index tie-break, not '
        "List.sort's unstable default)", () {
      final ranked = rankHomeSubjectsByUsage(
        ['Biology', 'Physics', 'Mathematics', 'Chemistry'],
        {'Physics': 5, 'Chemistry': 5}, // Biology/Mathematics untouched -> 0
      );
      expect(ranked, ['Physics', 'Chemistry', 'Biology', 'Mathematics']);
    });

    test('a subject with usage data that is not a favorite is ignored', () {
      final ranked = rankHomeSubjectsByUsage(
        ['Mathematics', 'Physics'],
        {'Chemistry': 99, 'Physics': 1}, // Chemistry isn't a favorite
      );
      expect(ranked, ['Physics', 'Mathematics']);
    });

    test('empty favorites list returns empty', () {
      expect(rankHomeSubjectsByUsage(const [], {'Physics': 5}), isEmpty);
    });
  });
}

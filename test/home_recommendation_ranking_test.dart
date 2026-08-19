// test/home_recommendation_ranking_test.dart
// Unit tests for the Homepage's OWN "Recommended for You" ranking helpers
// (lib/features/dashboard/universal_home_page.dart:
// rankHomeSubjectsByUsage/rankHomeCoursesByEnrollment).
//
// production_plan.md §1 requires the homepage's "Recommended for You" to
// remain a SEPARATE, independently-evolvable computation from the §7B
// contextual recommendations in RecommendationRepository -- these two pure
// functions are that computation, and this file pins down their real
// branching (tie-breaks, no-signal no-ops, stable partitioning) the same
// way test/recommendation_ranking_test.dart already does for
// RecommendationRepository.rankSubjectsByUsage.

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/features/dashboard/universal_home_page.dart';
import 'package:academia_app/models/course.dart';

Course _course(String id, String name) => Course(
      id: id,
      schoolId: 'school1',
      code: id.toUpperCase(),
      name: name,
      lecturerId: 'lecturer1',
      lecturerName: 'Mr. Lecturer',
      currentYear: 2026,
    );

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

  group('rankHomeCoursesByEnrollment', () {
    test('enrolled courses surface first, both halves keep original order', () {
      final courses = [
        _course('c1', 'Algebra'),
        _course('c2', 'Biology'),
        _course('c3', 'Chemistry'),
        _course('c4', 'Drama'),
      ];
      final ranked = rankHomeCoursesByEnrollment(courses, {'c3', 'c1'});
      // Enrolled (c1, c3) keep their relative order, then the rest (c2, c4)
      // keep theirs -- a stable partition, not a re-sort.
      expect(ranked.map((c) => c.id).toList(), ['c1', 'c3', 'c2', 'c4']);
    });

    test('no enrollments is a true no-op -- original order preserved', () {
      final courses = [_course('c1', 'Algebra'), _course('c2', 'Biology')];
      final ranked = rankHomeCoursesByEnrollment(courses, {});
      expect(ranked.map((c) => c.id).toList(), ['c1', 'c2']);
    });

    test('every course enrolled is also a no-op', () {
      final courses = [_course('c1', 'Algebra'), _course('c2', 'Biology')];
      final ranked = rankHomeCoursesByEnrollment(courses, {'c1', 'c2'});
      expect(ranked.map((c) => c.id).toList(), ['c1', 'c2']);
    });

    test('empty course list returns empty', () {
      expect(rankHomeCoursesByEnrollment(const [], {'c1'}), isEmpty);
    });

    test('an enrolled id not present in the course list is simply ignored', () {
      final courses = [_course('c1', 'Algebra')];
      final ranked = rankHomeCoursesByEnrollment(courses, {'ghost-id'});
      expect(ranked.map((c) => c.id).toList(), ['c1']);
    });
  });
}

// test/services/course_offline_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/models/public_course.dart';
import 'package:academia_app/models/course_lesson.dart';
import 'package:academia_app/services/course_offline_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CourseOfflineService', () {
    final testCourse = PublicCourse(
      id: 'course_test_101',
      creatorId: 'user_1',
      creatorName: 'Professor Jane',
      title: 'Intro to Quantum Computing',
      description: 'Foundations of quantum logic and qubits',
      body: 'Overview of quantum systems',
      category: 'Computer Science',
      subject: 'Physics',
      level: 'Advanced',
      topic: 'Quantum Mechanics',
      difficulty: 'Advanced',
      tags: ['Physics', 'Computing'],
    );

    test('initial state: course is not downloaded and completed lessons empty', () async {
      final downloaded = await CourseOfflineService.instance.isCourseDownloaded(testCourse.id);
      expect(downloaded, isFalse);

      final completed = await CourseOfflineService.instance.getCompletedLessonIds('user_123', testCourse.id);
      expect(completed, isEmpty);

      final list = await CourseOfflineService.instance.getDownloadedCourses();
      expect(list, isEmpty);
    });

    test('tracks and toggles lesson completion status with progress percentage', () async {
      const uid = 'student_42';
      final isNowDone = await CourseOfflineService.instance.toggleLessonCompleted(uid, testCourse.id, 'lesson_1');
      expect(isNowDone, isTrue);

      var completed = await CourseOfflineService.instance.getCompletedLessonIds(uid, testCourse.id);
      expect(completed.contains('lesson_1'), isTrue);
      expect(completed.length, 1);

      // Check progress metrics for 4 total lessons
      var progress = await CourseOfflineService.instance.getProgress(uid, testCourse.id, totalLessons: 4);
      expect(progress.completed, 1);
      expect(progress.total, 4);
      expect(progress.percent, 0.25);

      // Complete second lesson
      await CourseOfflineService.instance.toggleLessonCompleted(uid, testCourse.id, 'lesson_2');
      progress = await CourseOfflineService.instance.getProgress(uid, testCourse.id, totalLessons: 4);
      expect(progress.completed, 2);
      expect(progress.percent, 0.50);

      // Toggle first lesson off
      final isStillDone = await CourseOfflineService.instance.toggleLessonCompleted(uid, testCourse.id, 'lesson_1');
      expect(isStillDone, isFalse);
      progress = await CourseOfflineService.instance.getProgress(uid, testCourse.id, totalLessons: 4);
      expect(progress.completed, 1);
      expect(progress.percent, 0.25);
    });

    test('manages downloaded courses list and deletion cleanly', () async {
      final prefs = await SharedPreferences.getInstance();
      // Simulate downloaded course and lessons
      final courseMap = testCourse.toSupabase();
      courseMap['id'] = testCourse.id;
      await prefs.setString('offline_course_meta_${testCourse.id}', '{"id":"${testCourse.id}","title":"${testCourse.title}","category":"Computer Science"}');
      await prefs.setStringList('offline_downloaded_course_ids', [testCourse.id]);

      final downloaded = await CourseOfflineService.instance.isCourseDownloaded(testCourse.id);
      expect(downloaded, isTrue);

      final courses = await CourseOfflineService.instance.getDownloadedCourses();
      expect(courses.length, 1);
      expect(courses.first.id, testCourse.id);

      // Delete course
      await CourseOfflineService.instance.deleteDownloadedCourse(testCourse.id);
      final remaining = await CourseOfflineService.instance.getDownloadedCourses();
      expect(remaining, isEmpty);
      expect(await CourseOfflineService.instance.isCourseDownloaded(testCourse.id), isFalse);
    });
  });
}

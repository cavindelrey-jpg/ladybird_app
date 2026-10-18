import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/routes/app_routes.dart';
import 'package:academia_app/widgets/application_shell.dart';

void main() {
  group('AppRoutes URL Mapping', () {
    test('pathForDestination maps each destination to correct route URL', () {
      expect(AppRoutes.pathForDestination(AppNavDestination.home), AppRoutes.home);
      expect(AppRoutes.pathForDestination(AppNavDestination.academicCourses), AppRoutes.courses);
      expect(AppRoutes.pathForDestination(AppNavDestination.academicLibrary), AppRoutes.library);
      expect(AppRoutes.pathForDestination(AppNavDestination.pastQuestions), AppRoutes.pastQuestions);
      expect(AppRoutes.pathForDestination(AppNavDestination.testsAndQuizzes), AppRoutes.quizzes);
      expect(AppRoutes.pathForDestination(AppNavDestination.schoolConnect), AppRoutes.schoolConnect);
      expect(AppRoutes.pathForDestination(AppNavDestination.marks), AppRoutes.marks);
      expect(AppRoutes.pathForDestination(AppNavDestination.homework), AppRoutes.homework);
      expect(AppRoutes.pathForDestination(AppNavDestination.timetable), AppRoutes.timetable);
      expect(AppRoutes.pathForDestination(AppNavDestination.attendance), AppRoutes.attendance);
      expect(AppRoutes.pathForDestination(AppNavDestination.fees), AppRoutes.fees);
      expect(AppRoutes.pathForDestination(AppNavDestination.classroom), AppRoutes.classroom);
      expect(AppRoutes.pathForDestination(AppNavDestination.messages), AppRoutes.messages);
      expect(AppRoutes.pathForDestination(AppNavDestination.announcements), AppRoutes.announcements);
      expect(AppRoutes.pathForDestination(AppNavDestination.settings), AppRoutes.settings);
      expect(AppRoutes.pathForDestination(AppNavDestination.help), AppRoutes.help);
    });

    test('destinationForPath maps URL routes back to AppNavDestination', () {
      expect(AppRoutes.destinationForPath('/home'), AppNavDestination.home);
      expect(AppRoutes.destinationForPath('/courses'), AppNavDestination.academicCourses);
      expect(AppRoutes.destinationForPath('/library'), AppNavDestination.academicLibrary);
      expect(AppRoutes.destinationForPath('/past-questions'), AppNavDestination.pastQuestions);
      expect(AppRoutes.destinationForPath('/quizzes'), AppNavDestination.testsAndQuizzes);
      expect(AppRoutes.destinationForPath('/school-connect'), AppNavDestination.schoolConnect);
      expect(AppRoutes.destinationForPath('/marks'), AppNavDestination.marks);
      expect(AppRoutes.destinationForPath('/homework'), AppNavDestination.homework);
      expect(AppRoutes.destinationForPath('/timetable'), AppNavDestination.timetable);
      expect(AppRoutes.destinationForPath('/attendance'), AppNavDestination.attendance);
      expect(AppRoutes.destinationForPath('/fees'), AppNavDestination.fees);
      expect(AppRoutes.destinationForPath('/classroom'), AppNavDestination.classroom);
      expect(AppRoutes.destinationForPath('/messages'), AppNavDestination.messages);
      expect(AppRoutes.destinationForPath('/messages/requests'), AppNavDestination.messages);
      expect(AppRoutes.destinationForPath('/messages/conv_123'), AppNavDestination.messages);
      expect(AppRoutes.destinationForPath('/announcements'), AppNavDestination.announcements);
      expect(AppRoutes.destinationForPath('/settings'), AppNavDestination.settings);
      expect(AppRoutes.destinationForPath('/help'), AppNavDestination.help);
    });

    test('onGenerateRoute resolves every expected route name', () {
      final routesToTest = [
        '/',
        '/home',
        '/courses',
        '/library',
        '/past-questions',
        '/quizzes',
        '/school-connect',
        '/marks',
        '/homework',
        '/timetable',
        '/attendance',
        '/fees',
        '/classroom',
        '/messages',
        '/messages/requests',
        '/messages/conv_test_123',
        '/announcements',
        '/settings',
        '/help',
        '/notifications',
        '/profile',
        '/search',
        '/unknown-random-route',
      ];

      for (final r in routesToTest) {
        final route = AppRouteRegistry.onGenerateRoute(RouteSettings(name: r));
        expect(route, isNotNull, reason: 'Route $r should resolve to a valid PageRoute');
      }
    });

    test('conversation route helper generates valid parameterized route', () {
      expect(AppRoutes.conversation('c_abc'), '/messages/c_abc');
    });
  });
}

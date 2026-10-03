// lib/services/notification_router.dart
// Where tapping a notification goes. Server-generated notifications carry
// a typed deep_link_id (see supabase/migrations/
// 20261002010000_scheduled_notifications_hardening.sql):
//   program:YYYY-MM-DD[:class] | course:<id> | content:<id> | test:<id>
//   | challenge:YYYY-MM-DD | article:<id>
// Older rows may hold a bare id; those fall back on the notification
// type. Every path ends somewhere real: the destination, or a short
// message saying why it can't open (removed / offline) -- never a dead
// tap, a blank page, or an endless spinner.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/academic_content/content_details_page.dart';
import '../features/courses_marketplace/course_lessons_page.dart';
import '../features/daily_learning/daily_learning_hub_page.dart';
import '../features/magazine/article_reader_page.dart';
import '../features/messages/messages_home_page.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/timetable_page.dart';
import '../features/testing/test_taking_page.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../repositories/magazine_repository.dart';
import '../repositories/public_course_repository.dart';
import '../repositories/test_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart' show showToast;

/// Parsed form of a deep_link_id: `kind:value`, or kind '' for a bare id.
({String kind, String value}) parseDeepLink(String? raw) {
  final s = raw ?? '';
  final i = s.indexOf(':');
  const kinds = {'program', 'course', 'content', 'test', 'challenge', 'article'};
  if (i > 0 && kinds.contains(s.substring(0, i))) {
    return (kind: s.substring(0, i), value: s.substring(i + 1));
  }
  return (kind: '', value: s);
}

class NotificationRouter {
  NotificationRouter._();

  static const _lookupTimeout = Duration(seconds: 8);

  static Future<void> open(BuildContext context, AppUser user, AppNotification n) async {
    final link = parseDeepLink(n.deepLinkId);
    final nav = Navigator.of(context);
    void push(Widget page) => nav.push(MaterialPageRoute(builder: (_) => page));

    switch (n.type) {
      case NotificationType.message:
        return push(MessagesHomePage(user: user));
      case NotificationType.dailyProgram:
        return _showProgram(context, user, n);
      case NotificationType.announcement:
      case NotificationType.homework:
        return push(DailyNoticesPage(user: user));
      case NotificationType.comment:
      case NotificationType.reply:
      case NotificationType.articlePublished:
        return _openArticle(context, user, link.value);
      case NotificationType.recommendation:
        switch (link.kind) {
          case 'course':
            return _openCourse(context, user, link.value);
          case 'content':
            return push(ContentDetailsPage(contentId: link.value, user: user));
          case 'test':
            return _openTest(context, user, link.value);
          case 'challenge':
            return push(DailyLearningHubPage(user: user));
        }
        // Legacy rows: bare id, kind only recoverable from the title.
        final t = n.title.toLowerCase();
        if (link.value.isNotEmpty && t.contains('course')) return _openCourse(context, user, link.value);
        if (link.value.isNotEmpty && t.contains('quiz')) return _openTest(context, user, link.value);
        if (link.value.isNotEmpty && t.contains('library')) {
          return push(ContentDetailsPage(contentId: link.value, user: user));
        }
        if (t.contains('challenge')) return push(DailyLearningHubPage(user: user));
        return _showDetails(context, n);
      case NotificationType.system:
        return _showDetails(context, n);
    }
  }

  static Future<T?> _lookup<T>(BuildContext context, Future<T?> future) async {
    try {
      return await future.timeout(_lookupTimeout);
    } on TimeoutException {
      if (context.mounted) showToast(context, 'You\'re offline — this opens once you\'re back online.', isError: true);
    } catch (_) {
      if (context.mounted) showToast(context, 'Couldn\'t open this right now. Try again in a moment.', isError: true);
    }
    return null;
  }

  static void _gone(BuildContext context, String what) {
    if (context.mounted) showToast(context, 'This $what is no longer available.', isError: true);
  }

  static Future<void> _openCourse(BuildContext context, AppUser user, String id) async {
    final course = await _lookup(context, PublicCourseRepository.instance.watchOne(id).first);
    if (!context.mounted) return;
    if (course == null) return _gone(context, 'course');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseLessonsPage(course: course, currentUser: user)));
  }

  static Future<void> _openTest(BuildContext context, AppUser user, String id) async {
    final test = await _lookup(context, TestRepository.instance.watchTest(id).first);
    if (!context.mounted) return;
    if (test == null || !test.published) return _gone(context, 'quiz');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestTakingPage(user: user, test: test)));
  }

  static Future<void> _openArticle(BuildContext context, AppUser user, String id) async {
    if (id.isEmpty) return;
    final article = await _lookup(context, MagazineRepository.instance.getById(id));
    if (!context.mounted) return;
    if (article == null) return _gone(context, 'article');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleReaderPage(article: article, currentUser: user)));
  }

  /// The programme text IS the content (generated at 7 PM from the
  /// timetable, homework and calendar) -- show it in full, offline too,
  /// with the live timetable one tap away.
  static Future<void> _showProgram(BuildContext context, AppUser user, AppNotification n) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final ac = AppColors.of(ctx);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(n.title, style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: ac.txt)),
                const SizedBox(height: 14),
                SelectableText(n.body, style: GoogleFonts.inter(fontSize: 13.5, height: 1.6, color: ac.txt)),
                if (user.isSchoolMember) ...[
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TimetablePage(user: user)));
                    },
                    icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
                    label: const Text('Open full timetable'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _showDetails(BuildContext context, AppNotification n) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(n.title),
          content: SingleChildScrollView(child: SelectableText(n.body)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
}

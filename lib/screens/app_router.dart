// lib/screens/app_router.dart
// Root navigator. 2026-09 correction: a fresh install (no session) shows
// VoucherEntryScreen FIRST — activate with a code or log in to an
// existing (already-activated) account — with guest browsing one tap
// away, not the default. Once signed in (including after a code is
// redeemed once), reopening the app skips straight to HomeShell — this
// screen only ever appears when authStateChanges reports signed-out, so
// a returning user with a live session, or one who reinstalls and logs
// back into their existing account, never sees it again. School
// membership (schoolId/schoolRole on AppUser) is orthogonal to the
// 6-role UserRole permission system, which still governs content
// moderation/authoring privilege independent of any school.

import 'dart:async';
import '../features/daily_learning/daily_challenge_gate.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../repositories/magazine_repository.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_content_sheet.dart';
import 'first_login_screen.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/school/parent_dashboard_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/courses_marketplace/course_composer_page.dart';
import '../features/academic_content/library_home_page.dart';
import '../features/academic_content/library_folder_page.dart';
import '../features/academic_content/content_details_page.dart';
import '../features/academic_content/content_upload_page.dart';
import '../features/academic_content/bulk_past_paper_upload_page.dart';
import '../features/testing/quiz_categories_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../features/clubs/clubs_page.dart';
import '../features/clubs/create_club_page.dart';
import '../features/messages/messages_home_page.dart';
import '../features/messages/chat_conversation_page.dart';
import '../features/messages/find_people_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/marks_entry_page.dart';
import '../features/school/marks_csv_import_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/timetable_page.dart';
import '../features/school/timetable_manager_page.dart';
import '../features/school/timetable_csv_import_page.dart';
import '../features/school/attendance_page.dart';
import '../features/school/attendance_summary_page.dart';
import '../features/school/fees_page.dart';
import '../features/school/classroom_page.dart';
import '../features/classroom/classroom_teacher_page.dart';
import '../features/classroom/classroom_display_page.dart';
import '../features/classroom/student_classroom_page.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/daily_notices/compose_daily_notice_page.dart';
import '../features/school/class_management_page.dart';
import '../features/school/student_roster_page.dart';
import '../features/school/student_roster_csv_import_page.dart';
import '../features/school/teacher_management_page.dart';
import '../features/school/teacher_csv_import_page.dart';
import '../features/school/school_calendar_page.dart';
import '../features/school/school_calendar_manager_page.dart';
import '../features/school/school_calendar_csv_import_page.dart';
import '../features/school/exam_composer/exam_list_page.dart';
import '../features/onboarding/voucher_entry_screen.dart';
import '../pages/settings_page.dart';
import '../pages/change_password_page.dart';
import '../pages/notifications_page.dart';
import '../pages/profile_page.dart';
import '../pages/profile_edit_page.dart';
import '../pages/privacy_policy_page.dart';
import '../pages/about_academia_page.dart';
import '../pages/delete_account_page.dart';
import '../pages/notification_preferences_page.dart';
import '../features/onboarding/school_admin_page.dart';
import '../pages/not_found_page.dart';
import '../widgets/application_shell.dart';
import '../pages/help_support_page.dart';
import '../pages/bookmarks_page.dart';
import '../features/timetable/personal_study_page.dart';
import 'dictionary_screen.dart';
import 'login_screen.dart';
import '../widgets/widgets.dart';

// ────────────────────────────────────────────────────────────────────────────
// AppRouter — watches Firebase auth state only.
//
//  1. Nobody signed in → VoucherEntryScreen (the front door: activate
//     with a code, log in, or "continue browsing without a code" ->
//     _GuestShell).
//  2. Somebody IS signed in → HomeShell (via _AppUserGate).
// ────────────────────────────────────────────────────────────────────────────

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  /// Deeply-layered hierarchical route generator comparable to modern platforms (Facebook).
  /// Parses multi-segment paths, nested resources, and query parameters cleanly.
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final rawName = settings.name;
    if (rawName == null || rawName.isEmpty) return null;

    final uri = Uri.tryParse(rawName);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      return null;
    }

    final user = AuthService.instance.lastKnownUser ?? AppUser.guest();
    final q = uri.queryParameters;

    Widget? page;
    final root = segments[0];

    switch (root) {
      case 'home':
        page = user.isParent ? ParentDashboardPage(user: user) : UniversalHomePage(user: user);
        break;

      case 'login':
      case 'signin':
      case 'sign-in':
        page = const LoginScreen();
        break;

      case 'register':
      case 'voucher':
        page = VoucherEntryScreen(onBrowseAsGuest: () {});
        break;

      // ── Academia Hub Hierarchy ────────────────────────────
      case 'academia':
        if (segments.length == 1) {
          page = user.isParent ? ParentDashboardPage(user: user) : UniversalHomePage(user: user);
        } else {
          final sub = segments[1];
          switch (sub) {
            case 'library':
              if (segments.length == 2) {
                page = LibraryHomePage(user: user);
              } else if (segments[2] == 'past-papers') {
                if (segments.length >= 4) {
                  page = ContentDetailsPage(contentId: segments[3], user: user);
                } else {
                  page = LibraryHomePage(
                    user: user,
                    initialCollectionFilter: 'past_papers',
                    navDestination: AppNavDestination.pastQuestions,
                  );
                }
              } else if (segments[2] == 'books') {
                if (segments.length >= 4) {
                  page = ContentDetailsPage(contentId: segments[3], user: user);
                } else {
                  page = LibraryHomePage(user: user);
                }
              } else if (segments[2] == 'folders' && segments.length >= 4) {
                page = LibraryFolderPage(
                  folderId: segments[3],
                  folderName: q['name'] ?? 'Folder',
                  user: user,
                  navDestination: AppNavDestination.academicLibrary,
                );
              } else {
                page = LibraryHomePage(user: user);
              }
              break;

            case 'courses':
              if (segments.length == 2) {
                page = CoursesHomePage(user: user);
              } else if (segments.length >= 3 && segments[2] == 'create') {
                page = CourseComposerPage(user: user);
              } else {
                page = CoursesHomePage(user: user);
              }
              break;

            case 'tests':
            case 'quizzes':
              page = QuizCategoriesPage(user: user);
              break;

            case 'exam-composer':
            case 'set-exam':
              page = ExamListPage(user: user);
              break;

            default:
              page = LibraryHomePage(user: user);
          }
        }
        break;

      // ── Settings Hierarchy ────────────────────────────────
      case 'settings':
        if (segments.length == 1) {
          page = SettingsPage(user: user);
        } else {
          final sub = segments[1];
          switch (sub) {
            case 'privacy':
              page = PrivacyPolicyPage(user: user);
              break;
            case 'security':
            case 'password':
              page = const ChangePasswordPage();
              break;
            case 'notifications':
              page = NotificationPreferencesPage(userId: user.id);
              break;
            case 'account':
            case 'profile':
              page = ProfileEditPage(user: user);
              break;
            case 'about':
              page = const AboutAcademiaPage();
              break;
            case 'help':
              page = HelpSupportPage(user: user);
              break;
            case 'delete-account':
              page = DeleteAccountPage(user: user);
              break;
            default:
              page = SettingsPage(user: user);
          }
        }
        break;

      // ── Academic Library & Past Questions Hierarchy ──
      case 'library':
        if (segments.length == 1) {
          page = LibraryHomePage(user: user);
        } else if (segments.length >= 3 && segments[1] == 'folders') {
          final folderId = segments[2];
          page = LibraryFolderPage(
            folderId: folderId,
            folderName: q['name'] ?? 'Folder',
            user: user,
            navDestination: AppNavDestination.academicLibrary,
          );
        } else if (segments.length >= 3 && (segments[1] == 'item' || segments[1] == 'books')) {
          page = ContentDetailsPage(contentId: segments[2], user: user);
        } else if (segments.length >= 2 && segments[1] == 'upload') {
          page = ContentUploadPage(user: user);
        } else {
          page = LibraryHomePage(user: user);
        }
        break;

      case 'past-questions':
      case 'past-papers':
        if (segments.length >= 2 && segments[1] == 'upload') {
          page = BulkPastPaperUploadPage(user: user);
        } else if (segments.length >= 2 && segments[1] != 'upload') {
          page = ContentDetailsPage(contentId: segments[1], user: user);
        } else {
          page = LibraryHomePage(
            user: user,
            initialCollectionFilter: 'past_papers',
            navDestination: AppNavDestination.pastQuestions,
          );
        }
        break;

      // ── Academic Courses Hierarchy ───────────────────
      case 'courses':
        if (segments.length == 1) {
          page = CoursesHomePage(user: user);
        } else if (segments.length >= 2 && (segments[1] == 'create' || segments[1] == 'composer')) {
          page = CourseComposerPage(user: user);
        } else {
          page = CoursesHomePage(user: user);
        }
        break;

      // ── Groups & Clubs Hierarchy ─────────────────────
      case 'groups':
      case 'clubs':
        if (segments.length == 1) {
          page = ClubsPage(user: user);
        } else if (segments.length >= 2 && segments[1] == 'create') {
          page = CreateClubPage(user: user);
        } else {
          page = ClubsPage(user: user);
        }
        break;

      // ── Messaging Hierarchy ──────────────────────────
      case 'messages':
        if (segments.length >= 3 && segments[1] == 't') {
          final convId = segments[2];
          final otherId = q['u'] ?? '';
          final otherName = q['name'] ?? 'Chat';
          page = ChatConversationPage(
            conversationId: convId,
            currentUser: user,
            otherUserId: otherId,
            otherUserName: otherName,
          );
        } else if (segments.length >= 2 && segments[1] != 'find' && segments[1] != 'people') {
          final convId = segments[1];
          final otherId = q['u'] ?? '';
          final otherName = q['name'] ?? 'Conversation';
          page = ChatConversationPage(
            conversationId: convId,
            currentUser: user,
            otherUserId: otherId,
            otherUserName: otherName,
          );
        } else if (segments.length >= 2 && (segments[1] == 'find' || segments[1] == 'people')) {
          page = FindPeoplePage(user: user);
        } else {
          page = MessagesHomePage(user: user);
        }
        break;

      // ── Live Classroom & Projector Hierarchy ─────────
      case 'classroom':
        if (segments.length == 1) {
          page = ClassroomPage(user: user);
        } else if (segments[1] == 'teacher') {
          page = ClassroomTeacherPage(user: user);
        } else if (segments[1] == 'student') {
          page = StudentClassroomPage(user: user);
        } else {
          final targetId = segments[1];
          if (segments.length >= 3) {
            final action = segments[2];
            if (action == 'presentation' || action == 'projector' || action == 'display') {
              page = ClassroomDisplayPage(sessionId: targetId);
            } else if (action == 'resources') {
              page = StudentClassroomPage(user: user);
            } else if (action == 'teacher') {
              page = ClassroomControlPage(user: user, sessionId: targetId);
            } else {
              page = user.isStaff
                  ? ClassroomControlPage(user: user, sessionId: targetId)
                  : StudentClassroomPage(user: user);
            }
          } else {
            page = user.isStaff
                ? ClassroomControlPage(user: user, sessionId: targetId)
                : StudentClassroomPage(user: user);
          }
        }
        break;

      // ── Tests, Quizzes & Exam Composer ───────────────
      case 'tests':
      case 'quizzes':
        page = QuizCategoriesPage(user: user);
        break;

      case 'set-exam':
      case 'exam-composer':
        page = ExamListPage(user: user);
        break;

      // ── School Hub & Hierarchical Sub-routes ──────────
      case 'school':
        if (segments.length == 1) {
          page = SchoolConnectPage(user: user);
        } else {
          final sub = segments[1];
          switch (sub) {
            case 'classes':
              if (segments.length >= 4 && segments[3] == 'attendance') {
                page = AttendancePage(user: user, initialClass: Uri.decodeComponent(segments[2]));
              } else if (segments.length >= 4 && segments[3] == 'marks') {
                page = MarksPage(user: user);
              } else if (segments.length >= 4 && segments[3] == 'students') {
                page = StudentRosterPage(user: user, initialClass: Uri.decodeComponent(segments[2]));
              } else if (segments.length >= 4 && segments[3] == 'timetable') {
                page = TimetablePage(user: user, initialClass: Uri.decodeComponent(segments[2]));
              } else if (segments.length >= 3) {
                page = StudentRosterPage(user: user, initialClass: Uri.decodeComponent(segments[2]));
              } else {
                page = ClassManagementPage(user: user);
              }
              break;
            case 'students':
              if (segments.length >= 3 && segments[2] == 'import') {
                page = StudentRosterCsvImportPage(staff: user, targetClass: q['class']);
              } else if (segments.length >= 3) {
                page = StudentRosterPage(user: user);
              } else {
                page = StudentRosterPage(user: user, initialClass: q['class']);
              }
              break;
            case 'teachers':
              if (segments.length >= 3 && segments[2] == 'import') {
                page = TeacherCsvImportPage(admin: user);
              } else {
                page = TeacherManagementPage(admin: user);
              }
              break;
            case 'timetable':
              if (segments.length >= 3 && segments[2] == 'manage') {
                page = TimetableManagerPage(user: user);
              } else if (segments.length >= 3 && segments[2] == 'import') {
                page = TimetableCsvImportPage(user: user);
              } else {
                page = TimetablePage(user: user);
              }
              break;
            case 'attendance':
              if (segments.length >= 3 && segments[2] == 'summary') {
                page = AttendanceSummaryPage(user: user);
              } else {
                page = AttendancePage(user: user);
              }
              break;
            case 'marks':
              if (segments.length >= 3 && segments[2] == 'import') {
                page = MarksCsvImportPage(staff: user);
              } else if (segments.length >= 3 && segments[2] == 'entry') {
                page = MarksEntryPage(staff: user);
              } else {
                page = MarksPage(user: user);
              }
              break;
            case 'homework':
              page = HomeworkPage(user: user);
              break;
            case 'fees':
              page = FeesPage(user: user);
              break;
            case 'calendar':
              if (segments.length >= 3 && segments[2] == 'manage') {
                page = SchoolCalendarManagerPage(user: user);
              } else if (segments.length >= 3 && segments[2] == 'import') {
                page = SchoolCalendarCsvImportPage(staff: user);
              } else {
                page = SchoolCalendarPage(user: user);
              }
              break;
            case 'announcements':
              if (segments.length >= 3 && segments[2] == 'compose') {
                page = ComposeDailyNoticePage(user: user);
              } else {
                page = DailyNoticesPage(user: user);
              }
              break;
            case 'admin':
              page = SchoolAdminPage(user: user);
              break;
            default:
              page = SchoolConnectPage(user: user);
          }
        }
        break;

      // Direct Top-Level Aliases
      case 'classes':
        page = ClassManagementPage(user: user);
        break;
      case 'students':
        if (segments.length >= 2 && segments[1] == 'import') {
          page = StudentRosterCsvImportPage(staff: user, targetClass: q['class']);
        } else {
          page = StudentRosterPage(user: user, initialClass: q['class']);
        }
        break;
      case 'teachers':
        if (segments.length >= 2 && segments[1] == 'import') {
          page = TeacherCsvImportPage(admin: user);
        } else {
          page = TeacherManagementPage(admin: user);
        }
        break;
      case 'timetable':
        if (segments.length >= 2 && segments[1] == 'manage') {
          page = TimetableManagerPage(user: user);
        } else if (segments.length >= 2 && segments[1] == 'personal') {
          page = PersonalStudyPage(user: user);
        } else {
          page = TimetablePage(user: user);
        }
        break;
      case 'attendance':
        page = AttendancePage(user: user);
        break;
      case 'marks':
        if (segments.length >= 2 && segments[1] == 'import') {
          page = MarksCsvImportPage(staff: user);
        } else {
          page = MarksPage(user: user);
        }
        break;
      case 'homework':
        page = HomeworkPage(user: user);
        break;
      case 'fees':
        page = FeesPage(user: user);
        break;
      case 'announcements':
        page = DailyNoticesPage(user: user);
        break;
      case 'calendar':
        page = SchoolCalendarPage(user: user);
        break;
      case 'study-plan':
        page = PersonalStudyPage(user: user);
        break;
      case 'school-connect':
        page = SchoolConnectPage(user: user);
        break;

      // ── Profile, Notifications, Magazine, Dictionary ──────
      case 'magazine':
        page = MagazineFeedPage(user: user);
        break;
      case 'dictionary':
        page = DictionaryScreen(user: user);
        break;
      case 'bookmarks':
        page = BookmarksPage(user: user);
        break;
      case 'notifications':
        page = NotificationsPage(user: user);
        break;
      case 'profile':
        if (segments.length >= 2 && segments[1] == 'edit') {
          page = ProfileEditPage(user: user);
        } else {
          page = ProfilePage(user: user);
        }
        break;
      case 'help':
        page = HelpSupportPage(user: user);
        break;

      default:
        page = NotFoundPage(user: user, attemptedPath: rawName);
    }

    page ??= NotFoundPage(user: user, attemptedPath: rawName);

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page!,
      transitionDuration: Duration.zero,
    );
  }

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService.instance.authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      initialData: AuthService.instance.firebaseUser,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const _LaunchPageSkeleton();
        }
        if (snap.data == null) {
          return HomeShell(user: AppUser.guest());
        }
        return const _AppUserGate();
      },
    );
  }
}


/// Gate for signed-in users — resolves the account (suspended / first-login
/// / normal) and lands on HomeShell.
class _AppUserGate extends StatefulWidget {
  const _AppUserGate();

  @override
  State<_AppUserGate> createState() => _AppUserGateState();
}

class _AppUserGateState extends State<_AppUserGate> {
  late Stream<AppUser?> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = AuthService.instance.currentAppUserStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userStream,
      initialData: AuthService.instance.lastKnownUser,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const _LaunchPageSkeleton();
        }
        final user = snap.data;
        if (user == null) {
          AuthService.instance.signOut();
          return HomeShell(user: AppUser.guest());
        }
        if (user.status == AccountStatus.suspended) return _SuspendedScreen(user: user);
        if (user.isFirstLogin) return FirstLoginScreen(user: user);
        return DailyChallengeGate(user: user, child: HomeShell(user: user));
      },
    );
  }
}

/// Full-page launch skeleton sketch for seamless startup transitions without spinners.
class _LaunchPageSkeleton extends StatelessWidget {
  const _LaunchPageSkeleton();

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar Skeleton: Avatar + Greetings + Notification Icon
              Row(
                children: [
                  const ShimmerCircle(size: 44),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLine(width: 140, height: 16),
                        SizedBox(height: 6),
                        ShimmerLine(width: 90, height: 12),
                      ],
                    ),
                  ),
                  const ShimmerCircle(size: 36),
                ],
              ),
              const SizedBox(height: 24),

              // Search Bar Skeleton
              const ShimmerBlock(height: 48),
              const SizedBox(height: 24),

              // Hero Command Center Card Skeleton
              const ShimmerBlock(height: 160),
              const SizedBox(height: 24),

              // Quick Actions / Metrics Strip Skeleton
              Row(
                children: const [
                  Expanded(child: ShimmerBlock(height: 72)),
                  SizedBox(width: 10),
                  Expanded(child: ShimmerBlock(height: 72)),
                  SizedBox(width: 10),
                  Expanded(child: ShimmerBlock(height: 72)),
                ],
              ),
              const SizedBox(height: 24),

              // Section Header Skeleton
              const ShimmerLine(width: 160, height: 18),
              const SizedBox(height: 14),

              // Hub Grid Skeleton
              Row(
                children: const [
                  Expanded(child: ShimmerBlock(height: 120)),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerBlock(height: 120)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: ShimmerBlock(height: 120)),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerBlock(height: 120)),
                ],
              ),
              const SizedBox(height: 24),

              // Schedule / List Skeleton
              const ShimmerLine(width: 180, height: 18),
              const SizedBox(height: 14),
              const ShimmerBlock(height: 80),
              const SizedBox(height: 10),
              const ShimmerBlock(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuspendedScreen extends StatelessWidget {
  final AppUser user;
  const _SuspendedScreen({required this.user});
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block_outlined, size: 64, color: ac.red),
          const SizedBox(height: 16),
          Text('Account Suspended',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 8),
          Text('Please contact support.',
              style: GoogleFonts.inter(color: ac.txt2), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton(
              onPressed: () => AuthService.instance.performSignOut(context),
              child: const Text('Sign Out')),
        ]),
      )),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HomeShell — primary authenticated/guest landing
// Desktop (>= 900px): Persistent ApplicationShell workspaces.
// Mobile (< 900px): Native mobile shell with capsule NavigationBar,
// AppDrawer, and gold FAB.
// ────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    unawaited(MagazineRepository.instance.settlePendingXp(widget.user.id));
  }

  List<_NavDef> _buildNav() {
    final u = widget.user;
    final nav = <_NavDef>[
      const _NavDef('Home', Icons.home_rounded, Icons.home_outlined, UserRole.guest),
      const _NavDef('Groups', Icons.groups_rounded, Icons.groups_outlined, UserRole.guest),
      const _NavDef('Library', Icons.menu_book_rounded, Icons.menu_book_outlined, UserRole.guest),
      const _NavDef('Magazine', Icons.auto_stories_rounded, Icons.auto_stories_outlined, UserRole.guest),
      const _NavDef('Courses', Icons.school_rounded, Icons.school_outlined, UserRole.guest),
      const _NavDef('Profile', Icons.person_rounded, Icons.person_outlined, UserRole.guest),
    ];
    return nav.where((n) => u.hasMinRole(n.minRole)).toList();
  }

  Widget _buildPage(AppColors ac, _NavDef def) {
    final u = widget.user;
    if (!u.hasMinRole(def.minRole)) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: ac.muted),
              const SizedBox(height: 12),
              Text(
                'Access Restricted',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }
    switch (def.label) {
      case 'Home':
        return u.isParent ? ParentDashboardPage(user: u) : UniversalHomePage(user: u, embedded: true);
      case 'Groups':
        return ClubsPage(user: u, embedded: true);
      case 'Library':
        return LibraryHomePage(user: u, embedded: true);
      case 'Magazine':
        return MagazineFeedPage(user: u, embedded: true);
      case 'Courses':
        return CoursesHomePage(user: u, embedded: true);
      case 'Profile':
        return ProfilePage(user: u, embedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) {
      if (widget.user.isParent) {
        return ParentDashboardPage(user: widget.user);
      }
      return UniversalHomePage(user: widget.user);
    }

    final ac = AppColors.of(context);
    final nav = _buildNav();
    final safeTab = _tab.clamp(0, nav.length - 1);
    _visitedTabs.add(safeTab);

    return Scaffold(
      drawer: AppDrawer(
        user: widget.user,
        onHomeTap: () => setState(() => _tab = 0),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _OfflineBanner(),
            Expanded(
              child: IndexedStack(
                index: safeTab,
                children: List.generate(
                  nav.length,
                  (i) => _visitedTabs.contains(i)
                      ? _buildPage(ac, nav[i])
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ac.gold,
        onPressed: () => showCreateContentSheet(context, widget.user),
        child: Icon(Icons.add_rounded, color: ac.navy),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
          boxShadow: Shad.lg,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
          child: NavigationBar(
            selectedIndex: safeTab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: nav
                .map((n) => NavigationDestination(
                      icon: Icon(n.outlinedIcon),
                      selectedIcon: Icon(n.filledIcon),
                      label: n.label,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final String label;
  final IconData filledIcon, outlinedIcon;
  final UserRole minRole;
  const _NavDef(this.label, this.filledIcon, this.outlinedIcon, this.minRole);
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<bool>(
      stream: ConnectivityService().watchOffline(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: ac.orgBg,
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 16, color: ac.org),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline — saved downloads & dictionary open.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ac.org,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ac.org.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Dictionary',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ac.org,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LibraryHomePage(user: AppUser.guest()),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ac.org.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Downloads',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ac.org,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}




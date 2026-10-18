import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../theme/app_colors.dart';
import '../widgets/application_shell.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/academic_content/library_home_page.dart';
import '../features/academic_content/library_folder_page.dart';
import '../repositories/library_folder_repository.dart';
import '../features/testing/quiz_categories_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/timetable_page.dart';
import '../features/school/attendance_page.dart';
import '../features/school/fees_page.dart';
import '../features/school/classroom_page.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/parent_dashboard_page.dart';
import '../features/messages/messages_home_page.dart';
import '../pages/settings_page.dart';
import '../pages/help_support_page.dart';
import '../pages/notifications_page.dart';
import '../pages/profile_page.dart';
import '../pages/search_page.dart';
import '../screens/first_login_screen.dart';
import '../screens/login_screen.dart';
import '../features/daily_learning/daily_challenge_gate.dart';

class AppRoutes {
  static const String root = '/';
  static const String home = '/home';
  static const String courses = '/courses';
  static const String library = '/library';
  static const String pastQuestions = '/past-questions';
  static const String quizzes = '/quizzes';
  static const String schoolConnect = '/school-connect';
  static const String marks = '/marks';
  static const String homework = '/homework';
  static const String timetable = '/timetable';
  static const String attendance = '/attendance';
  static const String fees = '/fees';
  static const String classroom = '/classroom';
  static const String messages = '/messages';
  static const String messageRequests = '/messages/requests';
  static const String announcements = '/announcements';
  static const String settings = '/settings';
  static const String help = '/help';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String search = '/search';

  static String conversation(String id) => '/messages/$id';

  /// Maps an [AppNavDestination] to its corresponding URL path.
  static String pathForDestination(AppNavDestination dest) {
    switch (dest) {
      case AppNavDestination.home:
        return home;
      case AppNavDestination.academicCourses:
        return courses;
      case AppNavDestination.academicLibrary:
        return library;
      case AppNavDestination.pastQuestions:
        return pastQuestions;
      case AppNavDestination.testsAndQuizzes:
        return quizzes;
      case AppNavDestination.schoolConnect:
        return schoolConnect;
      case AppNavDestination.marks:
        return marks;
      case AppNavDestination.homework:
        return homework;
      case AppNavDestination.timetable:
        return timetable;
      case AppNavDestination.attendance:
        return attendance;
      case AppNavDestination.fees:
        return fees;
      case AppNavDestination.classroom:
        return classroom;
      case AppNavDestination.messages:
        return messages;
      case AppNavDestination.announcements:
        return announcements;
      case AppNavDestination.settings:
        return settings;
      case AppNavDestination.help:
        return help;
      case AppNavDestination.none:
        return home;
    }
  }

  /// Maps a URL path to its corresponding [AppNavDestination].
  static AppNavDestination destinationForPath(String path) {
    final cleanPath = path.split('?').first;
    switch (cleanPath) {
      case home:
      case root:
        return AppNavDestination.home;
      case courses:
        return AppNavDestination.academicCourses;
      case library:
        return AppNavDestination.academicLibrary;
      case pastQuestions:
        return AppNavDestination.pastQuestions;
      case quizzes:
        return AppNavDestination.testsAndQuizzes;
      case schoolConnect:
        return AppNavDestination.schoolConnect;
      case marks:
        return AppNavDestination.marks;
      case homework:
        return AppNavDestination.homework;
      case timetable:
        return AppNavDestination.timetable;
      case attendance:
        return AppNavDestination.attendance;
      case fees:
        return AppNavDestination.fees;
      case classroom:
        return AppNavDestination.classroom;
      case messages:
      case messageRequests:
        return AppNavDestination.messages;
      case announcements:
        return AppNavDestination.announcements;
      case settings:
        return AppNavDestination.settings;
      case help:
        return AppNavDestination.help;
      default:
        if (cleanPath.startsWith('/messages/')) {
          return AppNavDestination.messages;
        }
        return AppNavDestination.none;
    }
  }

  /// Updates the browser address bar without triggering a Flutter route rebuild.
  static void updateBrowserUrl(String path) {
    try {
      SystemNavigator.routeInformationUpdated(uri: Uri.parse(path));
    } catch (_) {}
  }
}

class AppRouteRegistry {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? AppRoutes.home;
    final uri = Uri.parse(rawName);
    final path = uri.path.isEmpty || uri.path == '/' ? AppRoutes.home : uri.path;

    // 1. Static routes
    switch (path) {
      case AppRoutes.home:
      case AppRoutes.root:
        return _buildRoute(
          settings: settings,
          builder: (context, user) {
            if (user.isParent) {
              return ParentDashboardPage(user: user);
            }
            final homeWidget = UniversalHomePage(user: user);
            if (!user.isGuest) {
              return DailyChallengeGate(user: user, child: homeWidget);
            }
            return homeWidget;
          },
        );

      case AppRoutes.courses:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => CoursesHomePage(user: user),
        );

      case AppRoutes.library:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => LibraryHomePage(user: user),
        );

      case AppRoutes.pastQuestions:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => _PastQuestionsRoute(user: user),
        );

      case AppRoutes.quizzes:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => QuizCategoriesPage(user: user),
        );

      case AppRoutes.schoolConnect:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => SchoolConnectPage(user: user),
        );

      case AppRoutes.marks:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => MarksPage(user: user),
        );

      case AppRoutes.homework:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => HomeworkPage(user: user),
        );

      case AppRoutes.timetable:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => TimetablePage(user: user),
        );

      case AppRoutes.attendance:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => AttendancePage(user: user),
        );

      case AppRoutes.fees:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => FeesPage(user: user),
        );

      case AppRoutes.classroom:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => ClassroomPage(user: user),
        );

      case AppRoutes.messages:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => MessagesHomePage(user: user),
        );

      case AppRoutes.messageRequests:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => MessagesHomePage(user: user, initialTab: 1),
        );

      case AppRoutes.announcements:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => DailyNoticesPage(user: user),
        );

      case AppRoutes.settings:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => SettingsPage(user: user),
        );

      case AppRoutes.help:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => HelpSupportPage(user: user),
        );

      case AppRoutes.notifications:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => NotificationsPage(user: user),
        );

      case AppRoutes.profile:
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => ProfilePage(user: user),
        );

      case AppRoutes.search:
        return _buildRoute(
          settings: settings,
          builder: (context, user) => SearchPage(user: user),
        );
    }

    // 2. Dynamic routes: /messages/:conversationId
    if (path.startsWith('/messages/')) {
      final conversationId = path.substring('/messages/'.length).trim();
      if (conversationId.isNotEmpty && conversationId != 'requests') {
        return _buildRoute(
          settings: settings,
          requiresAuth: true,
          builder: (context, user) => MessagesHomePage(
            user: user,
            initialConversationId: conversationId,
          ),
        );
      }
    }

    // Default fallback
    return onUnknownRoute(settings);
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return _buildRoute(
      settings: settings,
      builder: (context, user) => UniversalHomePage(user: user),
    );
  }

  static Route<dynamic> _buildRoute({
    required RouteSettings settings,
    required Widget Function(BuildContext context, AppUser user) builder,
    bool requiresAuth = false,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _RouteGate(
          routeName: settings.name ?? AppRoutes.home,
          requiresAuth: requiresAuth,
          builder: builder,
        );
      },
    );
  }
}

class _RouteGate extends StatelessWidget {
  final String routeName;
  final bool requiresAuth;
  final Widget Function(BuildContext context, AppUser user) builder;

  const _RouteGate({
    required this.routeName,
    required this.builder,
    this.requiresAuth = false,
  });

  @override
  Widget build(BuildContext context) {
    if (ConfigService.instance.isMaintenanceMode) {
      return _MaintenanceScreen(message: ConfigService.instance.maintenanceMessage);
    }

    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.currentAppUserStream(),
      initialData: AuthService.instance.lastKnownUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService.instance.lastKnownUser ?? AppUser.guest();

        if (user.status == AccountStatus.suspended) {
          return _SuspendedScreen(user: user);
        }

        if (user.isFirstLogin && !user.isGuest) {
          return FirstLoginScreen(user: user);
        }

        if (requiresAuth && user.isGuest) {
          return _AuthRequiredPage(user: user, pageName: routeName);
        }

        return builder(context, user);
      },
    );
  }
}

class _AuthRequiredPage extends StatelessWidget {
  final AppUser user;
  final String pageName;

  const _AuthRequiredPage({required this.user, required this.pageName});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cleanTitle = pageName.replaceAll('/', '').toUpperCase();

    return ApplicationShell(
      user: user,
      currentTitle: cleanTitle.isEmpty ? 'Authentication Required' : cleanTitle,
      currentDestination: AppNavDestination.none,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: ac.surf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ac.bdr),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFFE5A93C)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sign In Required',
                    style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold, color: ac.txt),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You need an active student, staff, or parent account to access this page. Please enter your activation voucher or sign in to continue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF081630),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Sign In or Redeem Code', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PastQuestionsRoute extends StatefulWidget {
  final AppUser user;
  const _PastQuestionsRoute({required this.user});

  @override
  State<_PastQuestionsRoute> createState() => _PastQuestionsRouteState();
}

class _PastQuestionsRouteState extends State<_PastQuestionsRoute> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final rootFolder = await LibraryFolderRepository.instance.rootFolderByName('Past Papers');
    if (!mounted) return;
    if (rootFolder != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.pastQuestions),
          builder: (_) => LibraryFolderPage(
            user: widget.user,
            folderId: rootFolder.id,
            folderName: rootFolder.name,
          ),
        ),
      );
      return;
    }

    try {
      final folders = await LibraryFolderRepository.instance.watchRootFolders().first;
      final match = folders.where((f) => f.name.toLowerCase().contains('past')).firstOrNull;
      if (!mounted) return;
      if (match != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: AppRoutes.pastQuestions),
            builder: (_) => LibraryFolderPage(
              user: widget.user,
              folderId: match.id,
              folderName: match.name,
            ),
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.library),
        builder: (_) => LibraryHomePage(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF081630),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFE5A93C))),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_outlined, size: 64, color: ac.red),
              const SizedBox(height: 16),
              Text(
                'Account Suspended',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt),
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact school administration support.',
                style: GoogleFonts.inter(color: ac.txt2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => AuthService.instance.performSignOut(context),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  final String message;
  const _MaintenanceScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081630),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.construction_rounded, size: 64, color: Color(0xFFE5A93C)),
                const SizedBox(height: 20),
                const Text(
                  'Under Maintenance',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

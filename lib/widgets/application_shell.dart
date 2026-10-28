// lib/widgets/application_shell.dart
//
// Persistent Application Shell & Global Design System.
// Implements the 3-column desktop web architecture across the entire application:
// 1. Persistent Left Navigation Rail:
//    - Default collapsed state (72px icons-only) to maximize workspace width.
//    - Smooth hover expansion (240px with labels) via overlay Stack so the central
//      workspace never jumps, distorts, or reflows.
//    - Click/keyboard pin support via the top bar menu toggle.
//    - Independent vertical scrolling via dedicated ScrollController.
// 2. Central Workspace:
//    - Supports optional breadcrumbs, back navigation, subtitle, header actions,
//      and sub-header bars while preserving full responsive width.
// 3. Contextual Right Sidebar:
//    - Dynamically adapts to the active page, domain, and selected item using real
//      data streams and honest empty/loading states.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/branding.dart';
import '../core/result.dart';
import '../models/academic_content.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/course_lesson.dart';
import '../models/homework.dart';
import '../models/messaging.dart';
import '../models/personal_study_slot.dart';
import '../models/public_course.dart';
import '../models/school_calendar_event.dart';
import '../models/school_timetable_slot.dart';
import '../models/test_attempt.dart';
import '../pages/bookmarks_page.dart';
import '../pages/help_support_page.dart';
import '../pages/notifications_page.dart';
import '../pages/profile_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';
import '../providers/theme_provider.dart';
import 'compact_sign_in_dialog.dart';
import '../repositories/academic_content_repository.dart';
import '../repositories/announcement_repository.dart';
import '../repositories/course_lesson_repository.dart';
import '../repositories/homework_repository.dart';
import '../repositories/library_folder_repository.dart';
import '../repositories/messaging_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/personal_study_repository.dart';
import '../repositories/public_course_repository.dart';
import '../repositories/school_calendar_repository.dart';
import '../repositories/school_timetable_repository.dart';
import '../repositories/test_repository.dart';
import '../screens/dictionary_screen.dart';
import '../services/auth_service.dart';
import '../services/course_offline_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'create_content_sheet.dart';
import 'widgets.dart';

// Core feature destinations
import '../features/academic_content/content_viewer_page.dart';
import '../features/academic_content/library_folder_page.dart';
import '../features/academic_content/library_home_page.dart';
import '../features/clubs/clubs_page.dart';
import '../features/courses_marketplace/course_lessons_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/courses_marketplace/lesson_reader_page.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../features/messages/chat_conversation_page.dart';
import '../features/messages/find_people_page.dart';
import '../features/messages/messages_home_page.dart';
import '../features/school/attendance_page.dart';
import '../features/school/classroom_page.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/fees_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/timetable_page.dart';
import '../features/school/exam_composer/exam_list_page.dart';
import '../features/testing/leaderboard_page.dart';
import '../features/testing/quiz_categories_page.dart';
import '../features/testing/xp_dashboard_page.dart';
import '../features/timetable/personal_study_page.dart';

import 'skeleton_spinner.dart';
enum AppNavDestination {
  home,
  academicCourses,
  academicLibrary,
  pastQuestions,
  testsAndQuizzes,
  magazine,
  clubs,
  messages,
  dictionary,
  bookmarks,
  studyPlan,
  schoolConnect,
  marks,
  homework,
  timetable,
  attendance,
  fees,
  classroom,
  announcements,
  examComposer,
  settings,
  help,
  none,
}

extension AppNavDestinationRouting on AppNavDestination {
  String get routePath => switch (this) {
    AppNavDestination.home => '/',
    AppNavDestination.academicCourses => '/courses',
    AppNavDestination.academicLibrary => '/library',
    AppNavDestination.pastQuestions => '/past-questions',
    AppNavDestination.testsAndQuizzes => '/tests',
    AppNavDestination.magazine => '/magazine',
    AppNavDestination.clubs => '/clubs',
    AppNavDestination.messages => '/messages',
    AppNavDestination.dictionary => '/dictionary',
    AppNavDestination.bookmarks => '/bookmarks',
    AppNavDestination.studyPlan => '/study-plan',
    AppNavDestination.schoolConnect => '/school-connect',
    AppNavDestination.marks => '/marks',
    AppNavDestination.homework => '/homework',
    AppNavDestination.timetable => '/timetable',
    AppNavDestination.attendance => '/attendance',
    AppNavDestination.fees => '/fees',
    AppNavDestination.classroom => '/classroom',
    AppNavDestination.announcements => '/announcements',
    AppNavDestination.examComposer => '/set-exam',
    AppNavDestination.settings => '/settings',
    AppNavDestination.help => '/help',
    AppNavDestination.none => '/',
  };
}

class ShellBreadcrumb {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const ShellBreadcrumb({
    required this.label,
    this.onTap,
    this.icon,
  });
}

class ApplicationShell extends StatefulWidget {
  final AppUser? user;
  final String? currentTitle;
  final String? title;
  final String? subtitle;
  final AppNavDestination currentDestination;
  final Widget child;
  final Widget? contextualPanel;
  final Widget? rightPanel;
  final bool showRightPanel;
  final double rightPanelWidth;
  final Widget? floatingActionButton;
  final bool? showBackButton;
  final VoidCallback? onBack;
  final List<ShellBreadcrumb>? breadcrumbs;
  final List<Widget>? headerActions;
  final Widget? bottomHeader;

  const ApplicationShell({
    super.key,
    this.user,
    this.currentTitle,
    this.title,
    required this.currentDestination,
    required this.child,
    this.subtitle,
    this.contextualPanel,
    this.rightPanel,
    this.showRightPanel = true,
    this.rightPanelWidth = 340,
    this.floatingActionButton,
    this.showBackButton,
    this.onBack,
    this.breadcrumbs,
    this.headerActions,
    this.bottomHeader,
  });

  @override
  State<ApplicationShell> createState() => _ApplicationShellState();
}

class _ApplicationShellState extends State<ApplicationShell> {
  static const double _collapsedRailWidth = 72.0;
  static const double _expandedRailWidth = 244.0;

  /// The left bar is permanent, not a menu. By default, it displays only
  /// navigation icons. On mouse hover, it expands smoothly to reveal labels.
  /// On touch devices, tapping the toggle icon at top of the rail toggles expansion.
  bool _sidebarHovered = false;
  bool _touchExpanded = false;
  final FocusNode _contentFocusNode = FocusNode();
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    try {
      _authSub = AuthService.instance.authStateChanges.listen((_) {
        if (mounted) setState(() {});
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _contentFocusNode.dispose();
    super.dispose();
  }

  AppUser get _user {
    if (widget.user != null && !widget.user!.isGuest) {
      return widget.user!;
    }
    final active = AuthService.instance.lastKnownUser;
    if (active != null && !active.isGuest) {
      return active;
    }
    return widget.user ?? AppUser.guest();
  }

  String get _pageTitle {
    if (widget.currentTitle != null && widget.currentTitle!.isNotEmpty) {
      return widget.currentTitle!;
    }
    if (widget.title != null && widget.title!.isNotEmpty) {
      return widget.title!;
    }
    switch (widget.currentDestination) {
      case AppNavDestination.home:
        return 'Home';
      case AppNavDestination.academicCourses:
        return 'Academic Courses';
      case AppNavDestination.academicLibrary:
        return 'Academia Library';
      case AppNavDestination.pastQuestions:
        return 'Academia Past Questions';
      case AppNavDestination.testsAndQuizzes:
        return 'Tests and Quizzes';
      case AppNavDestination.marks:
        return 'Marks and Report Cards';
      case AppNavDestination.classroom:
        return 'Live Classroom';
      case AppNavDestination.messages:
        return 'Messages';
      case AppNavDestination.homework:
        return 'Homework';
      case AppNavDestination.timetable:
        return 'Timetable';
      case AppNavDestination.attendance:
        return 'Attendance';
      case AppNavDestination.fees:
        return 'Fees & Ledger';
      case AppNavDestination.announcements:
        return 'Daily Notices';
      case AppNavDestination.examComposer:
        return 'Exam Composer';
      case AppNavDestination.magazine:
        return 'Magazine';
      case AppNavDestination.clubs:
        return 'Student Clubs';
      case AppNavDestination.dictionary:
        return 'Dictionary';
      case AppNavDestination.bookmarks:
        return 'Bookmarks';
      case AppNavDestination.studyPlan:
        return 'Study Plan';
      case AppNavDestination.schoolConnect:
        return 'School Connect';
      case AppNavDestination.settings:
        return 'Settings';
      case AppNavDestination.help:
        return 'Help & Support';
      case AppNavDestination.none:
        return 'Home';
    }
  }

  Widget? get _effectiveContextualPanel =>
      widget.contextualPanel ?? widget.rightPanel;

  bool get _isExpanded => _sidebarHovered || _touchExpanded;

  void _navigateTo(BuildContext context, AppNavDestination dest) {
    if (dest == widget.currentDestination && !Navigator.of(context).canPop()) {
      return;
    }

    Widget page;
    switch (dest) {
      case AppNavDestination.home:
        page = UniversalHomePage(user: _user);
        break;
      case AppNavDestination.academicCourses:
        page = CoursesHomePage(user: _user);
        break;
      case AppNavDestination.academicLibrary:
        page = LibraryHomePage(user: _user);
        break;
      case AppNavDestination.pastQuestions:
        page = _PastQuestionsRedirector(user: _user);
        break;
      case AppNavDestination.testsAndQuizzes:
        page = QuizCategoriesPage(user: _user);
        break;
      case AppNavDestination.magazine:
        page = MagazineFeedPage(user: _user);
        break;
      case AppNavDestination.clubs:
        page = ClubsPage(user: _user);
        break;
      case AppNavDestination.messages:
        page = MessagesHomePage(user: _user);
        break;
      case AppNavDestination.dictionary:
        page = DictionaryScreen(user: _user);
        break;
      case AppNavDestination.bookmarks:
        page = BookmarksPage(user: _user);
        break;
      case AppNavDestination.studyPlan:
        page = PersonalStudyPage(user: _user);
        break;
      case AppNavDestination.schoolConnect:
        page = SchoolConnectPage(user: _user);
        break;
      case AppNavDestination.marks:
        page = MarksPage(user: _user);
        break;
      case AppNavDestination.homework:
        page = HomeworkPage(user: _user);
        break;
      case AppNavDestination.timetable:
        page = TimetablePage(user: _user);
        break;
      case AppNavDestination.attendance:
        page = AttendancePage(user: _user);
        break;
      case AppNavDestination.fees:
        page = FeesPage(user: _user);
        break;
      case AppNavDestination.classroom:
        page = ClassroomPage(user: _user);
        break;
      case AppNavDestination.announcements:
        page = DailyNoticesPage(user: _user);
        break;
      case AppNavDestination.examComposer:
        page = ExamListPage(user: _user);
        break;
      case AppNavDestination.settings:
        page = SettingsPage(user: _user);
        break;
      case AppNavDestination.help:
        page = HelpSupportPage(user: _user);
        break;
      case AppNavDestination.none:
        return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: RouteSettings(name: dest.routePath),
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
      ),
    );
  }

  Widget _resolveContextualPanel() {
    if (_effectiveContextualPanel != null) return _effectiveContextualPanel!;
    switch (widget.currentDestination) {
      case AppNavDestination.academicLibrary:
      case AppNavDestination.pastQuestions:
      case AppNavDestination.bookmarks:
        return LibraryContextualPanel(
          user: _user,
          isPastQuestions:
              widget.currentDestination == AppNavDestination.pastQuestions,
        );
      case AppNavDestination.academicCourses:
        return CoursesContextualPanel(user: _user);
      case AppNavDestination.testsAndQuizzes:
        return QuizzesContextualPanel(user: _user);
      case AppNavDestination.messages:
        return MessagesContextualPanel(user: _user);
      case AppNavDestination.schoolConnect:
      case AppNavDestination.marks:
      case AppNavDestination.homework:
      case AppNavDestination.timetable:
      case AppNavDestination.attendance:
      case AppNavDestination.fees:
      case AppNavDestination.classroom:
      case AppNavDestination.announcements:
        return SchoolContextualPanel(user: _user);
      default:
        return DefaultAcademicRightPanel(user: _user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final showRightSidebar = width >= 1180 && widget.showRightPanel;
    final canPop = Navigator.of(context).canPop();
    final showBack = widget.showBackButton ?? canPop;

    final hasSubHeader =
        (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) ||
            (widget.headerActions != null && widget.headerActions!.isNotEmpty) ||
            widget.bottomHeader != null;

    return Scaffold(
      backgroundColor: ac.bg,
      floatingActionButton: widget.floatingActionButton,
      body: SafeArea(
        child: Column(
          children: [
            // ── Global Top Bar (Consistent Across Every Page) ───────────
            _GlobalTopBar(
              user: _user,
              pageTitle: _pageTitle,
              subtitle: widget.subtitle,
              showBackButton: showBack,
              onBack: widget.onBack ??
                  () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).maybePop();
                    }
                  },
              onNavigateHome: () => _navigateTo(context, AppNavDestination.home),
            ),

            // ── Main 3-Column Body (Permanent Left Rail + Workspace + Right Sidebar) ──
            Expanded(
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Permanent Left Rail Reserved Space
                      // Permanent left boundary: uses expanded navigation rail width (244px on desktop)
                      // so when the rail expands on hover, it never covers the workspace or right sidebar,
                      // and when collapsed, the empty margin is intentional.
                      if (isDesktop)
                        const SizedBox(width: _expandedRailWidth)
                      else
                        const SizedBox(width: _collapsedRailWidth),

                      // 2. Central Workspace (constrained width)
                      Expanded(
                        child: Container(
                          color: ac.bg,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (hasSubHeader)
                                _WorkspaceSubHeader(
                                  breadcrumbs: widget.breadcrumbs,
                                  actions: widget.headerActions,
                                  bottom: widget.bottomHeader,
                                ),
                              Expanded(
                                child: Focus(
                                  focusNode: _contentFocusNode,
                                  child: widget.child,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Contextual Right Sidebar
                      if (showRightSidebar)
                        SizedBox(
                          width: widget.rightPanelWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ac.surf,
                              border: Border(left: BorderSide(color: ac.bdr)),
                            ),
                            child: _resolveContextualPanel(),
                          ),
                        ),
                    ],
                  ),

                  // 1b. Permanent Left Rail (Smooth Hover/Tap Expansion Overlay)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: MouseRegion(
                      onEnter: (_) {
                        if (!_sidebarHovered) {
                          setState(() => _sidebarHovered = true);
                        }
                      },
                      onExit: (_) {
                        if (_sidebarHovered) {
                          setState(() => _sidebarHovered = false);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: _isExpanded
                            ? _expandedRailWidth
                            : _collapsedRailWidth,
                        decoration: BoxDecoration(
                          color: const Color(0xFF081630),
                          border: const Border(
                            right: BorderSide(
                              color: Color(0xFF162544),
                              width: 1,
                            ),
                          ),
                          boxShadow: _isExpanded
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(6, 0),
                                  ),
                                ]
                              : null,
                        ),
                        child: _GlobalSidebarContent(
                          user: _user,
                          currentDestination: widget.currentDestination,
                          collapsed: !_isExpanded,
                          onTouchToggle: () {
                            setState(() => _touchExpanded = !_touchExpanded);
                          },
                          onSelectDestination: (dest) {
                            if (_isExpanded) {
                              setState(() {
                                _sidebarHovered = false;
                                _touchExpanded = false;
                              });
                            }
                            _navigateTo(context, dest);
                          },
                        ),
                      ),
                    ),
                  ),

                  // 4. "Skip to content" keyboard accessibility button (WCAG standard)
                  Positioned(
                    top: 8,
                    left: 80,
                    child: Focus(
                      child: Builder(
                        builder: (fCtx) {
                          final hasFocus = Focus.of(fCtx).hasFocus;
                          if (!hasFocus) {
                            return const SizedBox.shrink();
                          }
                          return ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5A93C),
                              foregroundColor: const Color(0xFF081630),
                              elevation: 6,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                            label: const Text('Skip to content', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () {
                              _contentFocusNode.requestFocus();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Workspace Sub-Header (Breadcrumbs + Actions + Filter/Toolbar slot)
// ────────────────────────────────────────────────────────────────────────────

class _WorkspaceSubHeader extends StatelessWidget {
  final List<ShellBreadcrumb>? breadcrumbs;
  final List<Widget>? actions;
  final Widget? bottom;

  const _WorkspaceSubHeader({
    this.breadcrumbs,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hasTopRow = (breadcrumbs != null && breadcrumbs!.isNotEmpty) ||
        (actions != null && actions!.isNotEmpty);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        return Container(
          decoration: BoxDecoration(
            color: ac.surf,
            border: Border(bottom: BorderSide(color: ac.bdr)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 20,
            vertical: isCompact ? 8 : 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTopRow)
                Row(
                  children: [
                    if (breadcrumbs != null && breadcrumbs!.isNotEmpty)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (int i = 0; i < breadcrumbs!.length; i++) ...[
                                if (i > 0)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: ac.muted,
                                    ),
                                  ),
                                _BreadcrumbChip(
                                  crumb: breadcrumbs![i],
                                  isLast: i == breadcrumbs!.length - 1,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (actions != null && actions!.isNotEmpty) ...[
                      if (breadcrumbs != null && breadcrumbs!.isNotEmpty)
                        const SizedBox(width: 8)
                      else
                        const Spacer(),
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions!,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              if (bottom != null) ...[
                if (hasTopRow) const SizedBox(height: 10),
                bottom!,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final ShellBreadcrumb crumb;
  final bool isLast;

  const _BreadcrumbChip({required this.crumb, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final clickable = crumb.onTap != null && !isLast;

    return InkWell(
      onTap: clickable ? crumb.onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (crumb.icon != null) ...[
              Icon(
                crumb.icon,
                size: 15,
                color: isLast ? ac.primary : ac.txt2,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              crumb.label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                color: isLast ? ac.txt : ac.txt2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Global Top Bar
// ────────────────────────────────────────────────────────────────────────────

class _GlobalTopBar extends StatelessWidget {
  final AppUser? user;
  final String pageTitle;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onNavigateHome;

  const _GlobalTopBar({
    required this.user,
    required this.pageTitle,
    this.subtitle,
    required this.showBackButton,
    required this.onBack,
    required this.onNavigateHome,
  });

  bool get _isSupabaseReady {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<int> _safeWatchNotificationCount(String uid) {
    if (!_isSupabaseReady || uid.isEmpty) {
      return Stream.value(0);
    }
    try {
      return NotificationRepository.instance.watchUnreadCount(uid);
    } catch (_) {
      return Stream.value(0);
    }
  }

  Stream<List<Conversation>> _safeWatchConversations(String uid) {
    if (!_isSupabaseReady || uid.isEmpty) {
      return Stream.value(const <Conversation>[]);
    }
    try {
      return MessagingRepository.instance.watchConversations(uid);
    } catch (_) {
      return Stream.value(const <Conversation>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeProvider? themeProvider;
    try {
      themeProvider = Provider.of<ThemeProvider>(context);
    } catch (_) {
      themeProvider = null;
    }
    final isDark = themeProvider?.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final uid = user?.id ?? '';
    final isGuest = user == null || user!.isGuest || uid.isEmpty;
    final screenW = MediaQuery.of(context).size.width;
    final isCompact = screenW < 760;

    return LayoutBuilder(
      builder: (context, constraints) {
        final topBarW = constraints.maxWidth;
        final isCompact = topBarW < 780;
        final isNarrow = topBarW < 520;
        final isUltraNarrow = topBarW < 380;

        return Container(
          height: 60,
          padding: EdgeInsets.symmetric(
            horizontal: isUltraNarrow ? 8 : (isNarrow ? 10 : 14),
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF081630),
            border: Border(bottom: BorderSide(color: Color(0xFF162544), width: 1)),
          ),
          child: Row(
            children: [
              // Optional Back Button for nested pages
              if (showBackButton) ...[
                IconButton(
                  constraints: isNarrow
                      ? const BoxConstraints(minWidth: 32, minHeight: 32)
                      : const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: isNarrow
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.all(8),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFFC0D2F0),
                    size: 20,
                  ),
                  tooltip: 'Back',
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
              ],

              // Current Page Title only (no Academia branding, no logo, no app name, no subtitle)
              Expanded(
                child: Text(
                  pageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: isUltraNarrow ? 14 : (isCompact ? 16 : 18),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Center/Right: Global Search Bar
              if (!isCompact)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SearchPage(user: user ?? AppUser.guest()),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF102142),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF203666)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                size: 17,
                                color: Color(0xFF8CA3CF),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Search courses, books, past papers, topics...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: const Color(0xFF8CA3CF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (!isUltraNarrow)
                IconButton(
                  constraints: isNarrow
                      ? const BoxConstraints(minWidth: 32, minHeight: 32)
                      : const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: isNarrow
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.all(8),
                  icon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFC0D2F0),
                    size: 20,
                  ),
                  tooltip: 'Search',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SearchPage(user: user ?? AppUser.guest()),
                      ),
                    );
                  },
                ),

              if (!isNarrow) ...[
                const SizedBox(width: 4),
                // Light/Dark Mode Toggle
                IconButton(
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: const EdgeInsets.all(8),
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: const Color(0xFFC0D2F0),
                    size: 20,
                  ),
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  onPressed: () => themeProvider?.toggle(),
                ),
              ],

              // Signed-in only actions: Notifications, Messages, Bookmarks, and Upload Content
              if (!isGuest) ...[
                // Real Notifications Icon + Live Unread Count Badge
                StreamBuilder<int>(
                  stream: _safeWatchNotificationCount(uid),
                  builder: (context, snap) {
                    final unread = snap.data ?? 0;
                    return _TopBarBadgeIcon(
                      icon: Icons.notifications_outlined,
                      tooltip: 'Notifications',
                      badgeCount: unread,
                      compact: isNarrow,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/notifications'),
                            builder: (_) =>
                                NotificationsPage(user: user ?? AppUser.guest()),
                          ),
                        );
                      },
                    );
                  },
                ),

                // Real Messages Icon + Live Unread Count Badge
                if (!isUltraNarrow)
                  StreamBuilder<List<Conversation>>(
                    stream: _safeWatchConversations(uid),
                    builder: (context, snap) {
                      final convs = snap.data ?? const <Conversation>[];
                      int unread = 0;
                      for (final c in convs) {
                        unread += c.unreadCount[uid] ?? 0;
                      }
                      return _TopBarBadgeIcon(
                        icon: Icons.chat_bubble_outline_rounded,
                        tooltip: 'Messages',
                        badgeCount: unread,
                        compact: isNarrow,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              settings: const RouteSettings(name: '/messages'),
                              builder: (_) =>
                                  MessagesHomePage(user: user ?? AppUser.guest()),
                            ),
                          );
                        },
                      );
                    },
                  ),

                // Bookmarks & Saved Content shortcut
                if (!isCompact)
                  IconButton(
                    icon: const Icon(
                      Icons.bookmark_border_rounded,
                      color: Color(0xFFC0D2F0),
                      size: 20,
                    ),
                    tooltip: 'Bookmarks & Saved Items',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/bookmarks'),
                          builder: (_) =>
                              BookmarksPage(user: user ?? AppUser.guest()),
                        ),
                      );
                    },
                  ),

                // Create / Upload Content Button
                if ((user?.canUploadContent ?? false) && !isNarrow)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B3260),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Create or Upload Content',
                      onPressed: () {
                        if (user != null) {
                          showCreateContentSheet(context, user!);
                        }
                      },
                    ),
                  ),
              ],

              // Prominent Sign In button for signed-out guests (always visible)
              if (isGuest)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton.icon(
                    onPressed: () => showCompactSignInDialog(context),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: Text(
                      'Sign In',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A93C),
                      foregroundColor: const Color(0xFF081630),
                      elevation: 2,
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 10 : 16,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),

              SizedBox(width: isUltraNarrow ? 2 : 4),

              // User Profile Chip (real user data, never hardcoded fallback)
              _UserProfileChip(user: user, compact: isCompact),
            ],
          ),
        );
      },
    );
  }
}

class _TopBarBadgeIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final int badgeCount;
  final VoidCallback onTap;
  final bool compact;

  const _TopBarBadgeIcon({
    required this.icon,
    required this.tooltip,
    required this.badgeCount,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          constraints: compact
              ? const BoxConstraints(minWidth: 32, minHeight: 32)
              : const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: compact ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
          icon: Icon(icon, color: const Color(0xFFC0D2F0), size: compact ? 18 : 20),
          tooltip: tooltip,
          onPressed: onTap,
        ),
        if (badgeCount > 0)
          Positioned(
            right: compact ? 2 : 6,
            top: compact ? 2 : 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4B400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF081630),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserProfileChip extends StatelessWidget {
  final AppUser? user;
  final bool compact;

  const _UserProfileChip({required this.user, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isGuest = user == null || user!.isGuest || user!.id.isEmpty;
    final name = isGuest
        ? 'Guest'
        : (user!.name.trim().isNotEmpty
            ? user!.name.trim()
            : (user!.email.isNotEmpty ? user!.email.split('@').first : 'Student'));
    final role = isGuest
        ? 'Tap to Sign In'
        : (user!.roleLabel.isNotEmpty ? user!.roleLabel : 'Student');
    final initials = isGuest ? 'G' : user!.initials;

    return InkWell(
      onTap: () {
        if (isGuest) {
          showCompactSignInDialog(context);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(user: user ?? AppUser.guest()),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: compact ? 13 : 15,
              backgroundColor: const Color(0xFFE5A93C),
              backgroundImage: (!isGuest &&
                      user?.photoUrl != null &&
                      user!.photoUrl!.isNotEmpty)
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: (isGuest ||
                      user?.photoUrl == null ||
                      user!.photoUrl!.isEmpty)
                  ? Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF081630),
                      ),
                    )
                  : null,
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF8CA3CF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Color(0xFF8CA3CF),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Persistent Left Navigation Rail Content (Independent Scroll + Hover Expand)
// ────────────────────────────────────────────────────────────────────────────

class _GlobalSidebarContent extends StatefulWidget {
  final AppUser? user;
  final AppNavDestination currentDestination;
  final bool collapsed;
  final VoidCallback? onTouchToggle;
  final ValueChanged<AppNavDestination> onSelectDestination;

  const _GlobalSidebarContent({
    required this.user,
    required this.currentDestination,
    required this.collapsed,
    this.onTouchToggle,
    required this.onSelectDestination,
  });

  @override
  State<_GlobalSidebarContent> createState() => _GlobalSidebarContentState();
}

class _GlobalSidebarContentState extends State<_GlobalSidebarContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onTouchToggle != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 10 : 14,
              vertical: 8,
            ),
            child: InkWell(
              onTap: widget.onTouchToggle,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 32,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      collapsed
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      color: const Color(0xFF8CA3CF),
                      size: 20,
                    ),
                    if (!collapsed)
                      Text(
                        'COLLAPSE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: const Color(0xFF647D9E),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 8),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: !collapsed,
            thickness: 4,
            radius: const Radius.circular(4),
            child: ListView(
              controller: _scrollController,
              primary: false,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 10 : 12,
                vertical: 4,
              ),
              children: [
                if (!collapsed) _sectionHeader(Branding.current.appName.toUpperCase()),
                _item(AppNavDestination.home, Icons.home_rounded, 'Home'),
                _item(
                  AppNavDestination.academicCourses,
                  Icons.menu_book_rounded,
                  'Courses',
                ),
                _item(
                  AppNavDestination.academicLibrary,
                  Icons.folder_copy_rounded,
                  'Library',
                ),
                _item(
                  AppNavDestination.pastQuestions,
                  Icons.description_rounded,
                  'Past Questions',
                ),
                _item(
                  AppNavDestination.testsAndQuizzes,
                  Icons.fact_check_rounded,
                  'Tests & Quizzes',
                ),
                _item(
                  AppNavDestination.magazine,
                  Icons.newspaper_rounded,
                  'Magazine',
                ),
                _item(
                  AppNavDestination.clubs,
                  Icons.groups_rounded,
                  'Clubs & Groups',
                ),
                _item(
                  AppNavDestination.messages,
                  Icons.chat_bubble_outline_rounded,
                  'Messages',
                ),
                _item(
                  AppNavDestination.dictionary,
                  Icons.translate_rounded,
                  'Dictionary',
                ),
                _item(
                  AppNavDestination.bookmarks,
                  Icons.bookmark_outline_rounded,
                  'Saved & Bookmarks',
                ),
                _item(
                  AppNavDestination.studyPlan,
                  Icons.schedule_rounded,
                  'Study Planner',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Color(0xFF162544), height: 1),
                ),
                if (!collapsed) _sectionHeader('SCHOOL & CAMPUS'),
                _item(
                  AppNavDestination.schoolConnect,
                  Icons.forum_rounded,
                  'School Connect',
                ),
                _item(
                  AppNavDestination.classroom,
                  Icons.desktop_windows_rounded,
                  'Classroom',
                ),
                _item(
                  AppNavDestination.marks,
                  Icons.bar_chart_rounded,
                  'Marks & Grades',
                ),
                _item(
                  AppNavDestination.homework,
                  Icons.edit_note_rounded,
                  'Homework',
                ),
                _item(
                  AppNavDestination.timetable,
                  Icons.calendar_today_rounded,
                  'Timetable',
                ),
                _item(
                  AppNavDestination.attendance,
                  Icons.check_circle_outline_rounded,
                  'Attendance',
                ),
                _item(
                  AppNavDestination.fees,
                  Icons.account_balance_wallet_rounded,
                  'Fees & Ledger',
                ),
                _item(
                  AppNavDestination.announcements,
                  Icons.campaign_rounded,
                  'Announcements',
                ),
                if (widget.user != null && widget.user!.canComposeExam)
                  _item(
                    AppNavDestination.examComposer,
                    Icons.assignment_outlined,
                    'Exam Composer',
                  ),
              ],
            ),
          ),
        ),
        const Divider(color: Color(0xFF162544), height: 1),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 10 : 12,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _item(
                AppNavDestination.settings,
                Icons.settings_outlined,
                'Settings',
              ),
              _item(
                AppNavDestination.help,
                Icons.help_outline_rounded,
                'Help & Support',
              ),
              if (widget.user == null || widget.user!.isGuest) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: collapsed
                      ? Tooltip(
                          message: 'Sign In',
                          child: InkWell(
                            onTap: () => showCompactSignInDialog(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5A93C).withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5A93C), width: 1.2),
                              ),
                              child: const Icon(
                                Icons.login_rounded,
                                color: Color(0xFFE5A93C),
                                size: 19,
                              ),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => showCompactSignInDialog(context),
                          icon: const Icon(Icons.login_rounded, size: 16),
                          label: Text(
                            'Sign In',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5A93C),
                            foregroundColor: const Color(0xFF081630),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: const Color(0xFF647D9E),
        ),
      ),
    );
  }

  Widget _item(AppNavDestination dest, IconData icon, String label) {
    final active = widget.currentDestination == dest;
    final collapsed = widget.collapsed;

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 250),
          child: InkWell(
            onTap: () => widget.onSelectDestination(dest),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFE5A93C)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: active
                      ? const Color(0xFF081630)
                      : const Color(0xFFC0D2F0),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => widget.onSelectDestination(dest),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE5A93C) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: active
                    ? const Color(0xFF081630)
                    : const Color(0xFFC0D2F0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? const Color(0xFF081630)
                        : const Color(0xFFC0D2F0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 1. Home & School Contextual Right Sidebar (Real User Progress & Activity)
// ────────────────────────────────────────────────────────────────────────────

class DefaultAcademicRightPanel extends StatefulWidget {
  final AppUser? user;
  const DefaultAcademicRightPanel({super.key, required this.user});

  @override
  State<DefaultAcademicRightPanel> createState() =>
      _DefaultAcademicRightPanelState();
}

class _DefaultAcademicRightPanelState extends State<DefaultAcademicRightPanel> {
  late DateTime _calendarMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month, 1);
  }

  AppUser get _user => widget.user ?? AppUser.guest();
  bool get _isGuest =>
      widget.user == null || widget.user!.isGuest || widget.user!.id.isEmpty;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRealProgressCard(context, ac),
        const SizedBox(height: 16),
        if (_user.continueReadingItemId != null &&
            _user.continueReadingItemId!.isNotEmpty) ...[
          _buildContinueReadingCard(context, ac),
          const SizedBox(height: 16),
        ],
        _buildRealScheduleCard(context, ac),
        const SizedBox(height: 16),
        _buildRealTasksCard(context, ac),
        const SizedBox(height: 16),
        _buildRealAnnouncementsCard(context, ac),
        const SizedBox(height: 16),
        _buildRealCalendarCard(context, ac),
      ],
    );
  }

  Widget _buildRealProgressCard(BuildContext context, AppColors ac) {
    final uid = _user.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: Color(0xFFE5A93C),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'YOUR PROGRESS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: ac.txt,
                    ),
                  ),
                ],
              ),
              if (!_isGuest)
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => XpDashboardPage(user: _user),
                      ),
                    );
                  },
                  child: Text(
                    'XP Details',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: ac.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isGuest)
            Text(
              'Sign in to track your course completion, quiz scores, and daily learning streak.',
              style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
            )
          else ...[
            StreamBuilder<
                ({
                  int completedLessons,
                  int totalLessons,
                  int activeCourses,
                  double percent
                })>(
              stream: CourseOfflineService.instance.watchOverallProgress(
                uid,
                enrolledCourseIds: _user.courseIds,
              ),
              builder: (context, snap) {
                final data = snap.data;
                final hasCourses = data != null && data.activeCourses > 0;
                final pct = hasCourses ? (data.percent * 100).round() : 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ac.surf2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      AcademicCircularProgressRing(
                        percent: hasCourses ? data.percent : 0.0,
                        size: 54,
                        strokeWidth: 4.5,
                        color: const Color(0xFFE5A93C),
                        backgroundColor: ac.bdr,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Course Progress',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ac.txt,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasCourses
                                  ? '${data.completedLessons} of ${data.totalLessons} lessons across ${data.activeCourses} course${data.activeCourses == 1 ? '' : 's'}'
                                  : 'Start any course lesson to track progress automatically',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: ac.txt2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<TestAttempt>>(
              stream: TestRepository.instance.watchAttemptHistory(uid, limit: 50),
              builder: (context, snap) {
                final attempts = snap.data ?? const <TestAttempt>[];
                final quizzesDone = attempts.length;

                return Row(
                  children: [
                    Expanded(
                      child: _metricBox(
                        ac: ac,
                        value: '${_user.xpTotal}',
                        label: 'Total XP',
                        icon: Icons.bolt_rounded,
                        iconColor: const Color(0xFFE5A93C),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        ac: ac,
                        value: '${_user.streakDays}d',
                        label: 'Streak',
                        icon: Icons.local_fire_department_rounded,
                        iconColor: const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        ac: ac,
                        value: '$quizzesDone',
                        label: 'Quizzes',
                        icon: Icons.fact_check_rounded,
                        iconColor: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricBox({
    required AppColors ac,
    required String value,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: ac.surf2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: ac.txt,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: ac.txt2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueReadingCard(BuildContext context, AppColors ac) {
    final title = _user.continueReadingTitle ?? 'Recent Document';
    final page = _user.continueReadingPage;
    final total = _user.continueReadingTotalPages;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: 16,
                color: Color(0xFFE5A93C),
              ),
              const SizedBox(width: 8),
              Text(
                'CONTINUE READING',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ac.txt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ac.txt,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total != null && total > 0
                ? 'Page $page of $total'
                : 'Last stopped at page $page',
            style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2),
          ),
        ],
      ),
    );
  }

  Widget _buildRealScheduleCard(BuildContext context, AppColors ac) {
    final schoolId = _user.schoolId ?? '';
    final classLevel = _user.classLevel;
    final todayWeekday = DateTime.now().weekday; // 1 = Mon .. 7 = Sun

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Schedule",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TimetablePage(user: _user),
                    ),
                  );
                },
                child: Text(
                  'Timetable',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ac.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isGuest)
            Text(
              'Sign in to view your personal study blocks and class timetable.',
              style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
            )
          else if (schoolId.isNotEmpty && classLevel.isNotEmpty)
            StreamBuilder<List<SchoolTimetableSlot>>(
              stream: SchoolTimetableRepository.instance
                  .watchForClass(schoolId, classLevel),
              builder: (context, snap) {
                final todaySlots = (snap.data ?? const <SchoolTimetableSlot>[])
                    .where((s) => s.dayOfWeek == todayWeekday)
                    .take(4)
                    .toList();
                if (todaySlots.isEmpty) {
                  return _buildPersonalStudyFallback(context, ac, todayWeekday);
                }
                return Column(
                  children: todaySlots
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _scheduleRow(
                            ac: ac,
                            time: '${s.startTime} - ${s.endTime}',
                            title: s.subject,
                            subtitle: (s.room != null && s.room!.isNotEmpty)
                                ? 'Room ${s.room}'
                                : s.teacherName,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            )
          else
            _buildPersonalStudyFallback(context, ac, todayWeekday),
        ],
      ),
    );
  }

  Widget _buildPersonalStudyFallback(
    BuildContext context,
    AppColors ac,
    int todayWeekday,
  ) {
    return StreamBuilder<List<PersonalStudySlot>>(
      stream: PersonalStudyRepository.instance.watchAll(_user.id),
      builder: (context, snap) {
        final slots = (snap.data ?? const <PersonalStudySlot>[])
            .where((s) => s.dayOfWeek == todayWeekday)
            .take(4)
            .toList();
        if (slots.isEmpty) {
          return Text(
            'No classes or personal study blocks scheduled for today.',
            style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
          );
        }
        return Column(
          children: slots
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _scheduleRow(
                    ac: ac,
                    time: '${s.startTime} - ${s.endTime}',
                    title: s.activity,
                    subtitle: (s.subject != null && s.subject!.isNotEmpty)
                        ? s.subject!
                        : 'Personal Study',
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _scheduleRow({
    required AppColors ac,
    required String time,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ac.surf2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE5A93C),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ac.txt,
                  ),
                ),
                Text(
                  '$time${subtitle.isNotEmpty ? ' • $subtitle' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: ac.txt2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTasksCard(BuildContext context, AppColors ac) {
    final schoolId = _user.schoolId ?? '';
    final classLevel = _user.classLevel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Homework & Tasks',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HomeworkPage(user: _user),
                    ),
                  );
                },
                child: Text(
                  'Open All',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ac.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isGuest || schoolId.isEmpty || classLevel.isEmpty)
            Text(
              'Connect to your school class to see assigned homework and deadlines.',
              style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
            )
          else
            StreamBuilder<List<Homework>>(
              stream: HomeworkRepository.instance
                  .watchForClass(schoolId, classLevel),
              builder: (context, snap) {
                final items = (snap.data ?? const <Homework>[]).take(4).toList();
                if (items.isEmpty) {
                  return Text(
                    'No pending homework assignments for $classLevel.',
                    style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                  );
                }
                return Column(
                  children: items.map((hw) {
                    final overdue = hw.dueAt.isBefore(DateTime.now());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HomeworkPage(user: _user),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ac.surf2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                overdue
                                    ? Icons.warning_amber_rounded
                                    : Icons.assignment_outlined,
                                size: 16,
                                color: overdue
                                    ? const Color(0xFFEF4444)
                                    : ac.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hw.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: ac.txt,
                                      ),
                                    ),
                                    Text(
                                      '${hw.subject} • Due ${hw.dueAt.day}/${hw.dueAt.month}/${hw.dueAt.year}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: ac.txt2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRealAnnouncementsCard(BuildContext context, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Announcements',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyNoticesPage(user: _user),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ac.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Announcement>>(
            stream: AnnouncementRepository.instance.watchAnnouncements(
              schoolId: _user.schoolId,
            ),
            builder: (context, snap) {
              final items =
                  (snap.data ?? const <Announcement>[]).take(3).toList();
              if (items.isEmpty) {
                return Text(
                  'No recent announcements posted.',
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                );
              }
              return Column(
                children: items.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DailyNoticesPage(user: _user),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5A93C),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: ac.txt,
                                  ),
                                ),
                                Text(
                                  a.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: ac.txt2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRealCalendarCard(BuildContext context, AppColors ac) {
    final now = DateTime.now();
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Mon .. 7 = Sun
    final leadingBlanks = firstWeekday % 7; // Sunday-start grid (0..6)

    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    final cells = <int?>[
      for (int i = 0; i < leadingBlanks; i++) null,
      for (int d = 1; d <= daysInMonth; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${monthNames[month - 1]} $year',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.chevron_left_rounded, size: 18, color: ac.txt2),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(year, month - 1, 1);
                      });
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.chevron_right_rounded, size: 18, color: ac.txt2),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(year, month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (d) => SizedBox(
                    width: 28,
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          for (int row = 0; row < cells.length ~/ 7; row++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int col = 0; col < 7; col++)
                    Builder(
                      builder: (context) {
                        final day = cells[row * 7 + col];
                        final isToday = day != null &&
                            year == now.year &&
                            month == now.month &&
                            day == now.day;
                        return Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFFE5A93C)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              day?.toString() ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isToday
                                    ? const Color(0xFF081630)
                                    : ac.txt,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 2. Library & Past Questions Contextual Right Sidebar
// ────────────────────────────────────────────────────────────────────────────

class LibraryContextualPanel extends StatelessWidget {
  final AppUser user;
  final bool isPastQuestions;
  final String? currentFolderName;
  final String? filterSubject;

  const LibraryContextualPanel({
    super.key,
    required this.user,
    this.isPastQuestions = false,
    this.currentFolderName,
    this.filterSubject,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Continue Reading (if user has an active book/paper)
        if (user.continueReadingItemId != null &&
            user.continueReadingItemId!.isNotEmpty) ...[
          _buildContinueReadingSection(context, ac),
          const SizedBox(height: 16),
        ],

        // 2. Offline / Downloaded Materials
        _buildOfflineMaterialsSection(context, ac),
        const SizedBox(height: 16),

        // 3. Recently Published Books or Past Questions
        _buildRecentMaterialsSection(context, ac),
      ],
    );
  }

  Widget _buildContinueReadingSection(BuildContext context, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bookmark_added_rounded,
                size: 17,
                color: Color(0xFFE5A93C),
              ),
              const SizedBox(width: 8),
              Text(
                'RECENTLY OPENED',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: ac.txt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            user.continueReadingTitle ?? 'Last Opened Document',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ac.txt,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.continueReadingTotalPages != null
                ? 'Page ${user.continueReadingPage} of ${user.continueReadingTotalPages}'
                : 'Stopped at page ${user.continueReadingPage}',
            style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMaterialsSection(BuildContext context, AppColors ac) {
    return FutureBuilder<List<AcademicContent>>(
      future: AcademicContentRepository.instance.getOfflineContent(),
      builder: (context, snap) {
        final offline = snap.data ?? const <AcademicContent>[];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.offline_pin_rounded,
                    size: 17,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SAVED FOR OFFLINE (${offline.length})',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: ac.txt,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (offline.isEmpty)
                Text(
                  'Download books or examination papers to access them without an internet connection.',
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                )
              else
                ...offline.take(4).map(
                      (item) => _resourceTile(context, ac, item),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentMaterialsSection(BuildContext context, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPastQuestions
                    ? Icons.description_rounded
                    : Icons.auto_awesome_rounded,
                size: 17,
                color: const Color(0xFFE5A93C),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPastQuestions
                      ? 'RECENT PAST PAPERS'
                      : 'RECENTLY PUBLISHED',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: ac.txt,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<AcademicContent>>(
            stream: AcademicContentRepository.instance.watch(
              contentType: isPastQuestions ? ContentType.pastPaper : null,
              subject: filterSubject,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: SkeletonSpinner(strokeWidth: 2),
                    ),
                  ),
                );
              }
              var items = snap.data ?? const <AcademicContent>[];
              if (user.favoriteSubjects.isNotEmpty && filterSubject == null) {
                final favs =
                    user.favoriteSubjects.map((s) => s.toLowerCase()).toSet();
                final sorted = List<AcademicContent>.from(items);
                sorted.sort((a, b) {
                  final aFav = favs.contains(a.subject.toLowerCase()) ? 0 : 1;
                  final bFav = favs.contains(b.subject.toLowerCase()) ? 0 : 1;
                  return aFav.compareTo(bFav);
                });
                items = sorted;
              }

              final top = items.take(6).toList();
              if (top.isEmpty) {
                return Text(
                  'No published materials found.',
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                );
              }
              return Column(
                children: top
                    .map((item) => _resourceTile(context, ac, item))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _resourceTile(
    BuildContext context,
    AppColors ac,
    AcademicContent item,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ContentViewerPage(content: item, user: user),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ac.surf2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                item.contentType == ContentType.pastPaper
                    ? Icons.quiz_outlined
                    : Icons.menu_book_rounded,
                size: 18,
                color: ac.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ac.txt,
                      ),
                    ),
                    Text(
                      [
                        if (item.subject.isNotEmpty) item.subject,
                        if (item.level.isNotEmpty) item.level,
                        if (item.year != null) '${item.year}',
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11, color: ac.txt2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: ac.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 3. Individual Book / Past Paper Details Contextual Right Sidebar
// ────────────────────────────────────────────────────────────────────────────

class BookDetailsContextualPanel extends StatelessWidget {
  final AcademicContent content;
  final AppUser user;
  final List<Widget>? extraActions;

  const BookDetailsContextualPanel({
    super.key,
    required this.content,
    required this.user,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Document Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ac.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      content.contentType == ContentType.pastPaper
                          ? Icons.description_rounded
                          : Icons.menu_book_rounded,
                      color: ac.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.contentType.label.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: const Color(0xFFE5A93C),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          content.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ac.txt,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (content.description.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  content.description.trim(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: ac.txt2,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _metaRow(ac, 'Subject', content.subject),
              if (content.level.isNotEmpty)
                _metaRow(ac, 'Level', content.level),
              if (content.examBoard != null && content.examBoard!.isNotEmpty)
                _metaRow(ac, 'Exam Board', content.examBoard!),
              if (content.year != null)
                _metaRow(ac, 'Exam Year', '${content.year}'),
              if (content.uploaderName.isNotEmpty)
                _metaRow(ac, 'Contributor', content.uploaderName),
              _metaRow(ac, 'Downloads', '${content.downloads}'),
              if (extraActions != null && extraActions!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...extraActions!,
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Related Resources in the Same Subject
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RELATED MATERIALS',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<AcademicContent>>(
                stream: AcademicContentRepository.instance.watch(
                  subject: content.subject.isNotEmpty ? content.subject : null,
                ),
                builder: (context, snap) {
                  final related = (snap.data ?? const <AcademicContent>[])
                      .where((i) => i.id != content.id)
                      .take(6)
                      .toList();
                  if (related.isEmpty) {
                    return Text(
                      'No other materials in ${content.subject.isNotEmpty ? content.subject : "this collection"} yet.',
                      style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                    );
                  }
                  return Column(
                    children: related.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => ContentViewerPage(
                                  content: item,
                                  user: user,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ac.surf2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.contentType == ContentType.pastPaper
                                      ? Icons.description_outlined
                                      : Icons.menu_book_outlined,
                                  size: 17,
                                  color: ac.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: ac.txt,
                                        ),
                                      ),
                                      Text(
                                        item.contentType.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: ac.txt2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaRow(AppColors ac, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ac.txt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 4. Courses & Individual Course / Lesson Contextual Right Sidebar
// ────────────────────────────────────────────────────────────────────────────

class CoursesContextualPanel extends StatelessWidget {
  final AppUser user;
  final PublicCourse? activeCourse;
  final String? activeLessonId;

  const CoursesContextualPanel({
    super.key,
    required this.user,
    this.activeCourse,
    this.activeLessonId,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (activeCourse != null) {
      return _buildActiveCoursePanel(context, ac, activeCourse!);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Overall Course Progress
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 18,
                    color: Color(0xFFE5A93C),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LEARNING PROGRESS',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: ac.txt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<
                  ({
                    int completedLessons,
                    int totalLessons,
                    int activeCourses,
                    double percent
                  })>(
                stream: CourseOfflineService.instance.watchOverallProgress(
                  user.id,
                  enrolledCourseIds: user.courseIds,
                ),
                builder: (context, snap) {
                  final d = snap.data;
                  final hasData = d != null && d.activeCourses > 0;
                  final pct = hasData ? (d.percent * 100).round() : 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            hasData
                                ? '${d.completedLessons}/${d.totalLessons} Lessons Completed'
                                : 'No lessons completed yet',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ac.txt,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE5A93C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: hasData ? d.percent : 0.0,
                          minHeight: 7,
                          backgroundColor: ac.surf2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE5A93C),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Offline / Downloaded Courses
        StreamBuilder<List<PublicCourse>>(
          stream: CourseOfflineService.instance.watchDownloadedCourses(),
          builder: (context, snap) {
            final downloaded = snap.data ?? const <PublicCourse>[];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ac.surf,
                borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: ac.bdr),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DOWNLOADED COURSES (${downloaded.length})',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: ac.txt,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (downloaded.isEmpty)
                    Text(
                      'Save courses for offline study to read lessons anytime.',
                      style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                    )
                  else
                    ...downloaded.take(4).map(
                          (c) => _courseTile(context, ac, c),
                        ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // 3. Recommended Courses
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECOMMENDED COURSES',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<PublicCourse>>(
                stream: PublicCourseRepository.instance.watchLatest(limit: 8),
                builder: (context, snap) {
                  final list = snap.data ?? const <PublicCourse>[];
                  if (list.isEmpty) {
                    return Text(
                      'No courses available right now.',
                      style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                    );
                  }
                  return Column(
                    children: list
                        .take(5)
                        .map((c) => _courseTile(context, ac, c))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCoursePanel(
    BuildContext context,
    AppColors ac,
    PublicCourse course,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Course Details + Live Progress
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.subject.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: const Color(0xFFE5A93C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                course.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<({int completed, int total, double percent})>(
                stream: CourseOfflineService.instance
                    .watchProgress(user.id, course.id),
                builder: (context, snap) {
                  final p = snap.data ??
                      (completed: 0, total: 0, percent: 0.0);
                  final pct = (p.percent * 100).round();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${p.completed} of ${p.total} lessons completed',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ac.txt2,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE5A93C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: p.percent,
                          minHeight: 7,
                          backgroundColor: ac.surf2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE5A93C),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Course Lessons Outline / Table of Contents
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COURSE LESSONS',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<CourseLesson>>(
                stream: CourseLessonRepository.instance.watchLessons(course.id),
                builder: (context, lessonSnap) {
                  final lessons = lessonSnap.data ?? const <CourseLesson>[];
                  if (lessons.isEmpty) {
                    return Text(
                      'Single-document course overview.',
                      style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                    );
                  }
                  return StreamBuilder<Set<String>>(
                    stream: CourseOfflineService.instance
                        .watchCompletedLessonIds(user.id, course.id),
                    builder: (context, doneSnap) {
                      final doneIds = doneSnap.data ?? const <String>{};
                      return Column(
                        children: [
                          for (int i = 0; i < lessons.length; i++)
                            Builder(
                              builder: (context) {
                                final lesson = lessons[i];
                                final isDone = doneIds.contains(lesson.id);
                                final isCurrent = lesson.id == activeLessonId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    onTap: isCurrent
                                        ? null
                                        : () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => LessonReaderPage(
                                                  course: course,
                                                  lesson: lesson,
                                                  currentUser: user,
                                                ),
                                              ),
                                            );
                                          },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? ac.primary.withValues(alpha: 0.12)
                                            : ac.surf2,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isCurrent
                                            ? Border.all(color: ac.primary)
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isDone
                                                ? Icons.check_circle_rounded
                                                : Icons.radio_button_unchecked_rounded,
                                            size: 16,
                                            color: isDone
                                                ? const Color(0xFF10B981)
                                                : ac.muted,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${i + 1}. ${lesson.title}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: isCurrent
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: ac.txt,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _courseTile(BuildContext context, AppColors ac, PublicCourse course) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CourseLessonsPage(course: course, currentUser: user),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ac.surf2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 17, color: ac.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ac.txt,
                      ),
                    ),
                    Text(
                      '${course.subject} • ${course.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11, color: ac.txt2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: ac.muted),
            ],
          ),
        ),
      ),
    );
  }
}

extension _CourseIconExt on Icons {
  static const IconData WorkspacePremiumIconOrDefault =
      Icons.workspace_premium_rounded;
}

// ────────────────────────────────────────────────────────────────────────────
// 5. Quizzes & Tests Contextual Right Sidebar
// ────────────────────────────────────────────────────────────────────────────

class QuizzesContextualPanel extends StatelessWidget {
  final AppUser user;
  const QuizzesContextualPanel({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QUIZ PERFORMANCE',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: ac.txt,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LeaderboardPage(user: user),
                        ),
                      );
                    },
                    child: Text(
                      'Leaderboard',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ac.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (user.isGuest || user.id.isEmpty)
                Text(
                  'Sign in to save quiz attempts and compete on the leaderboard.',
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                )
              else
                StreamBuilder<List<TestAttempt>>(
                  stream: TestRepository.instance
                      .watchAttemptHistory(user.id, limit: 50),
                  builder: (context, snap) {
                    final attempts = snap.data ?? const <TestAttempt>[];
                    double avgPct = 0;
                    if (attempts.isNotEmpty) {
                      double sum = 0;
                      for (final a in attempts) {
                        if (a.maxScore > 0) {
                          sum += (a.totalScore / a.maxScore) * 100;
                        }
                      }
                      avgPct = sum / attempts.length;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _statBox(
                                ac,
                                '${attempts.length}',
                                'Completed',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statBox(
                                ac,
                                attempts.isEmpty
                                    ? '—'
                                    : '${avgPct.round()}%',
                                'Avg Score',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statBox(
                                ac,
                                '${user.xpTotal}',
                                'Total XP',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'RECENT ATTEMPTS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ac.txt2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (attempts.isEmpty)
                          Text(
                            'No quizzes attempted yet. Pick a subject to start!',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: ac.txt2,
                            ),
                          )
                        else
                          ...attempts.take(6).map((a) {
                            final pct = a.maxScore > 0
                                ? ((a.totalScore / a.maxScore) * 100).round()
                                : 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: ac.surf2,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.testTitle.isNotEmpty
                                                ? a.testTitle
                                                : a.subject,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: ac.txt,
                                            ),
                                          ),
                                          Text(
                                            '${a.subject} • +${a.totalXpEarned} XP',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: ac.txt2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pct >= 50
                                            ? const Color(0xFF10B981)
                                                .withValues(alpha: 0.15)
                                            : const Color(0xFFEF4444)
                                                .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$pct%',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: pct >= 50
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(AppColors ac, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: ac.surf2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ac.txt,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10.5, color: ac.txt2),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 6. Messages Overview Contextual Right Sidebar (Message Requests & Directory)
// ────────────────────────────────────────────────────────────────────────────

class MessagesContextualPanel extends StatelessWidget {
  final AppUser user;
  const MessagesContextualPanel({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isGuest = user.isGuest || user.id.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Start New Conversation / Find People Action
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONNECT WITH PEERS',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Find classmates, study partners, and lecturers across Academia.',
                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isGuest
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FindPeoplePage(user: user),
                            ),
                          );
                        },
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text('Find People'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF081630),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Incoming Message Requests (Live Stream)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.mark_chat_unread_outlined,
                    size: 17,
                    color: Color(0xFFE5A93C),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MESSAGE REQUESTS',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: ac.txt,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isGuest)
                Text(
                  'Sign in to manage incoming message requests.',
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                )
              else
                StreamBuilder<List<FriendRequest>>(
                  stream:
                      MessagingRepository.instance.watchIncomingRequests(user.id),
                  builder: (context, snap) {
                    final reqs = snap.data ?? const <FriendRequest>[];
                    if (reqs.isEmpty) {
                      return Text(
                        'No pending message requests.',
                        style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                      );
                    }
                    return Column(
                      children: reqs.map((r) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ac.surf2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ac.bdr),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.fromUserName.isNotEmpty
                                    ? r.fromUserName
                                    : 'Student',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ac.txt,
                                ),
                              ),
                              if (r.fromUserRoleLabel.isNotEmpty)
                                Text(
                                  r.fromUserRoleLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: ac.txt2,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await MessagingRepository.instance
                                            .declineRequest(r.id);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final res = await MessagingRepository
                                            .instance
                                            .acceptRequest(
                                              r,
                                              user.name,
                                              user.photoUrl,
                                            );
                                        if (!context.mounted) return;
                                        if (res.isSuccess) {
                                          final convRes =
                                              await MessagingRepository.instance
                                                  .getOrCreateConversation(
                                            userAId: user.id,
                                            userAName: user.name,
                                            userAPhoto: user.photoUrl,
                                            userBId: r.fromUserId,
                                            userBName: r.fromUserName,
                                            userBPhoto: r.fromUserPhotoUrl,
                                          );
                                          if (!context.mounted) return;
                                          final convId = convRes.valueOrNull;
                                          if (convId != null) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ChatConversationPage(
                                                  conversationId: convId,
                                                  currentUser: user,
                                                  otherUserId: r.fromUserId,
                                                  otherUserName: r.fromUserName,
                                                  otherUserPhoto:
                                                      r.fromUserPhotoUrl,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE5A93C),
                                        foregroundColor: const Color(0xFF081630),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 7. Active Conversation Contextual Right Sidebar (Conversation Switcher)
// ────────────────────────────────────────────────────────────────────────────

class ChatConversationsSidebar extends StatelessWidget {
  final AppUser me;
  final String activeConversationId;

  const ChatConversationsSidebar({
    super.key,
    required this.me,
    required this.activeConversationId,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ac.bdr)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONVERSATIONS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: ac.txt,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => MessagesHomePage(user: me),
                    ),
                  );
                },
                child: Text(
                  'All Chats',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ac.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Conversation>>(
            stream: MessagingRepository.instance.watchConversations(me.id),
            builder: (context, snap) {
              final convs = snap.data ?? const <Conversation>[];
              if (convs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No other conversations yet.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: convs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final c = convs[index];
                  final otherId = c.otherParticipantId(me.id);
                  final otherName = c.participantNames[otherId] ?? 'User';
                  final otherPhoto = c.participantPhotos[otherId];
                  final unread = c.unreadCount[me.id] ?? 0;
                  final isCurrent = c.id == activeConversationId;

                  return InkWell(
                    onTap: isCurrent
                        ? null
                        : () {
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    ChatConversationPage(
                                  conversationId: c.id,
                                  currentUser: me,
                                  otherUserId: otherId,
                                  otherUserName: otherName,
                                  otherUserPhoto: otherPhoto,
                                ),
                                transitionDuration: Duration.zero,
                              ),
                            );
                          },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFFE5A93C).withValues(alpha: 0.14)
                            : ac.surf2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFE5A93C)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF081630),
                            backgroundImage:
                                (otherPhoto != null && otherPhoto.isNotEmpty)
                                    ? NetworkImage(otherPhoto)
                                    : null,
                            child: (otherPhoto == null || otherPhoto.isEmpty)
                                ? Text(
                                    otherName.isNotEmpty
                                        ? otherName[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFE5A93C),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isCurrent || unread > 0
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: ac.txt,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c.lastMessageText.isNotEmpty
                                      ? c.lastMessageText
                                      : 'Start chatting',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: unread > 0 ? ac.txt : ac.txt2,
                                    fontWeight: unread > 0
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (unread > 0 && !isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5A93C),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unread',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF081630),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 7. School Operations Contextual Right Sidebar
// ────────────────────────────────────────────────────────────────────────────

class SchoolContextualPanel extends StatelessWidget {
  final AppUser user;
  const SchoolContextualPanel({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = user.schoolId ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. School & Student Identity Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF081630),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 20,
                      color: Color(0xFFE5A93C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.schoolName ?? 'School Operations',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ac.txt,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.classLevel.isNotEmpty
                              ? 'Class: ${user.classLevel}'
                              : user.roleLabel,
                          style: GoogleFonts.inter(fontSize: 11, color: ac.txt2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (user.id.isNotEmpty && !user.isGuest) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ac.surf2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ID: ${user.id.length > 8 ? user.id.substring(0, 8) : user.id}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ac.txt,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. School Operations Fast Switcher
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCHOOL NAVIGATION',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ac.txt2,
                ),
              ),
              const SizedBox(height: 12),
              _buildNavRow(
                context,
                ac,
                icon: Icons.grading_rounded,
                label: 'Marks & Report Cards',
                color: const Color(0xFF2563EB),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MarksPage(user: user)),
                ),
              ),
              _buildNavRow(
                context,
                ac,
                icon: Icons.calendar_view_week_rounded,
                label: 'Official Timetable',
                color: const Color(0xFF0D9488),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TimetablePage(user: user)),
                ),
              ),
              _buildNavRow(
                context,
                ac,
                icon: Icons.assignment_rounded,
                label: 'Homework & Tasks',
                color: const Color(0xFFD97706),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HomeworkPage(user: user)),
                ),
              ),
              _buildNavRow(
                context,
                ac,
                icon: Icons.how_to_reg_rounded,
                label: 'Daily Attendance',
                color: const Color(0xFF16A34A),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AttendancePage(user: user)),
                ),
              ),
              _buildNavRow(
                context,
                ac,
                icon: Icons.receipt_long_rounded,
                label: 'Fees & Bank Ledger',
                color: const Color(0xFF9333EA),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FeesPage(user: user)),
                ),
              ),
              _buildNavRow(
                context,
                ac,
                icon: Icons.campaign_rounded,
                label: 'Daily School Notices',
                color: const Color(0xFFE11D48),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DailyNoticesPage(user: user)),
                ),
              ),
              _buildNavRow(
                context,
                ac,
                icon: Icons.meeting_room_rounded,
                label: 'Live Classrooms',
                color: const Color(0xFF0284C7),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ClassroomPage(user: user)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Upcoming School Events (Real Stream)
        if (schoolId.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_available_rounded, size: 16, color: ac.primary),
                    const SizedBox(width: 8),
                    Text(
                      'ACADEMIC CALENDAR',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: ac.txt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<SchoolCalendarEvent>>(
                  stream: SchoolCalendarRepository.instance.watchUpcoming(schoolId, limit: 3),
                  builder: (context, snap) {
                    final events = snap.data ?? const [];
                    if (snap.connectionState == ConnectionState.waiting && events.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: SkeletonSpinner(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    if (events.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'No upcoming school events scheduled.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2),
                        ),
                      );
                    }
                    return Column(
                      children: events.map((ev) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: ac.surf2,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: ac.bdr),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${ev.startDate.day}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: ac.txt,
                                      ),
                                    ),
                                    Text(
                                      _monthShort(ev.startDate.month),
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: ac.txt2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ev.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: ac.txt,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ev.category.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        color: ac.txt2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _buildNavRow(
    BuildContext context,
    AppColors ac, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ac.txt,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: ac.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _monthShort(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Past Questions Redirector (Stays inside ApplicationShell without flickering)
// ────────────────────────────────────────────────────────────────────────────

class _PastQuestionsRedirector extends StatefulWidget {
  final AppUser user;
  const _PastQuestionsRedirector({required this.user});

  @override
  State<_PastQuestionsRedirector> createState() =>
      _PastQuestionsRedirectorState();
}

class _PastQuestionsRedirectorState extends State<_PastQuestionsRedirector> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final rootFolder =
        await LibraryFolderRepository.instance.rootFolderByName('Past Papers');
    if (!mounted) return;
    if (rootFolder != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LibraryFolderPage(
            user: widget.user,
            folderId: rootFolder.id,
            folderName: rootFolder.name,
            navDestination: AppNavDestination.pastQuestions,
          ),
          transitionDuration: Duration.zero,
        ),
      );
      return;
    }

    try {
      final folders =
          await LibraryFolderRepository.instance.watchRootFolders().first;
      final match = folders
          .where((f) => f.name.toLowerCase().contains('past'))
          .firstOrNull;
      if (!mounted) return;
      if (match != null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => LibraryFolderPage(
              user: widget.user,
              folderId: match.id,
              folderName: match.name,
              navDestination: AppNavDestination.pastQuestions,
            ),
            transitionDuration: Duration.zero,
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LibraryHomePage(
          user: widget.user,
          initialCollectionFilter: 'Past Papers',
          navDestination: AppNavDestination.pastQuestions,
        ),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Past Questions',
      currentDestination: AppNavDestination.pastQuestions,
      child: const Center(child: SkeletonSpinner()),
    );
  }
}

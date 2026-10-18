// lib/widgets/application_shell.dart
//
// Persistent Application Shell & Global Design System.
// Implements the approved 3-column reference architecture across the entire app:
// 1. GlobalTopBar: Page title, search bar, and right-to-left utility controls.
// 2. GlobalSidebar: Single unified left navigation bar with active gold pill.
// 3. MainWorkspace: Primary page tasks.
// 4. ContextualPanel: Supplementary contextual info (progress, schedule, announcements, tasks, calendar).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../pages/help_support_page.dart';
import '../pages/notifications_page.dart';
import '../pages/profile_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';
import '../providers/theme_provider.dart';
import '../repositories/library_folder_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'create_content_sheet.dart';

// Core pages
import '../features/academic_content/library_home_page.dart';
import '../features/academic_content/library_folder_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/messages/messages_home_page.dart';
import '../features/school/attendance_page.dart';
import '../features/school/classroom_page.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/fees_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/timetable_page.dart';
import '../features/testing/quiz_categories_page.dart';
import '../features/testing/xp_dashboard_page.dart';

enum AppNavDestination {
  home,
  academicCourses,
  academicLibrary,
  pastQuestions,
  testsAndQuizzes,
  schoolConnect,
  marks,
  homework,
  timetable,
  attendance,
  fees,
  classroom,
  announcements,
  settings,
  help,
  none,
}

class ApplicationShell extends StatefulWidget {
  final AppUser? user;
  final String currentTitle;
  final AppNavDestination currentDestination;
  final Widget child;
  final Widget? contextualPanel;
  final bool showRightPanel;
  final Widget? floatingActionButton;

  const ApplicationShell({
    super.key,
    required this.user,
    required this.currentTitle,
    required this.currentDestination,
    required this.child,
    this.contextualPanel,
    this.showRightPanel = true,
    this.floatingActionButton,
  });

  @override
  State<ApplicationShell> createState() => _ApplicationShellState();
}

class _ApplicationShellState extends State<ApplicationShell> {
  bool _sidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  AppUser get _user => widget.user ?? AppUser.guest();

  void _navigateTo(BuildContext context, AppNavDestination dest) {
    if (dest == widget.currentDestination) return;

    Widget page;
    switch (dest) {
      case AppNavDestination.home:
        page = UniversalHomePage(user: _user);
        break;
      case AppNavDestination.academicCourses:
        page = CoursesHomePage(user: widget.user);
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
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ac.bg,
      floatingActionButton: widget.floatingActionButton,
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: const Color(0xFF081630),
              child: SafeArea(
                child: _GlobalSidebarContent(
                  user: widget.user,
                  currentDestination: widget.currentDestination,
                  collapsed: false,
                  onSelectDestination: (dest) {
                    Navigator.of(context).pop();
                    _navigateTo(context, dest);
                  },
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────
            _GlobalTopBar(
              user: widget.user,
              pageTitle: widget.currentTitle,
              onToggleSidebar: () {
                if (isDesktop) {
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed);
                } else {
                  _scaffoldKey.currentState?.openDrawer();
                }
              },
            ),

            // ── Main Body: Sidebar + Main Workspace + Contextual Panel ──
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Global Left Sidebar (Desktop)
                  if (isDesktop)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _sidebarCollapsed ? 76 : 240,
                      color: const Color(0xFF081630),
                      child: _GlobalSidebarContent(
                        user: widget.user,
                        currentDestination: widget.currentDestination,
                        collapsed: _sidebarCollapsed,
                        onSelectDestination: (dest) => _navigateTo(context, dest),
                      ),
                    ),

                  // 2. Center Main Workspace
                  Expanded(
                    child: Container(
                      color: ac.bg,
                      child: widget.child,
                    ),
                  ),

                  // 3. Right Contextual Information Panel (Desktop only)
                  if (isDesktop && widget.showRightPanel)
                    SizedBox(
                      width: 360,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ac.surf,
                          border: Border(left: BorderSide(color: ac.bdr)),
                        ),
                        child: widget.contextualPanel ??
                            DefaultAcademicRightPanel(user: widget.user),
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
// Global Top Bar
// ────────────────────────────────────────────────────────────────────────────

class _GlobalTopBar extends StatelessWidget {
  final AppUser? user;
  final String pageTitle;
  final VoidCallback onToggleSidebar;

  const _GlobalTopBar({
    required this.user,
    required this.pageTitle,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF081630),
        border: Border(bottom: BorderSide(color: Color(0xFF162544), width: 1)),
      ),
      child: Row(
        children: [
          // Left: Hamburger button
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
            onPressed: onToggleSidebar,
            tooltip: 'Navigation Menu',
          ),
          const SizedBox(width: 8),

          // Left: Current Page Title
          Text(
            pageTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 24),

          // Center/Right: Search field
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SearchPage(user: user ?? AppUser.guest()),
                    ));
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102142),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF203666)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            size: 18, color: Color(0xFF8CA3CF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search courses, topics, subjects...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
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
          ),

          const SizedBox(width: 16),

          // Controls ordered from right going left into the page:
          // [Search field] -> [Toggle] -> [Notifications] -> [Messages] -> [Notes] -> [Action +] -> [Settings] -> [Profile]
          // Light/Dark mode toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFFC0D2F0),
              size: 20,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => themeProvider.toggle(),
          ),

          // Notifications with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Color(0xFFC0D2F0), size: 21),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        NotificationsPage(user: user ?? AppUser.guest()),
                  ));
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4B400),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '3',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1F4D),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Messages with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded,
                    color: Color(0xFFC0D2F0), size: 20),
                tooltip: 'Messages',
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        MessagesHomePage(user: user ?? AppUser.guest()),
                  ));
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4B400),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '2',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1F4D),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Notes / comment icon
          IconButton(
            icon: const Icon(Icons.comment_outlined,
                color: Color(0xFFC0D2F0), size: 20),
            tooltip: 'Quick Notes',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MessagesHomePage(user: user ?? AppUser.guest()),
              ));
            },
          ),

          // Action + button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF1B3260),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              tooltip: 'Create Content',
              onPressed: () {
                if (user != null) {
                  showCreateContentSheet(context, user!);
                }
              },
            ),
          ),

          // Settings shortcut
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Color(0xFFC0D2F0), size: 20),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsPage(user: user ?? AppUser.guest()),
              ));
            },
          ),

          const SizedBox(width: 8),

          // User Profile (far right)
          _UserProfileChip(user: user),
        ],
      ),
    );
  }
}

class _UserProfileChip extends StatelessWidget {
  final AppUser? user;
  const _UserProfileChip({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user != null && user!.name.isNotEmpty) ? user!.name : 'Nso Dylan';
    final role = (user != null && user!.roleLabel.isNotEmpty)
        ? user!.roleLabel
        : 'Super Admin';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfilePage(user: user ?? AppUser.guest()),
        ));
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE5A93C),
              backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                  ? Text(
                      user?.initials ?? 'ND',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF081630),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  role,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8CA3CF),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: Color(0xFF8CA3CF)),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Global Sidebar Content
// ────────────────────────────────────────────────────────────────────────────

class _GlobalSidebarContent extends StatelessWidget {
  final AppUser? user;
  final AppNavDestination currentDestination;
  final bool collapsed;
  final ValueChanged<AppNavDestination> onSelectDestination;

  const _GlobalSidebarContent({
    required this.user,
    required this.currentDestination,
    required this.collapsed,
    required this.onSelectDestination,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12),
            children: [
              _item(AppNavDestination.home, Icons.home_rounded, 'Home'),
              _item(AppNavDestination.academicCourses, Icons.menu_book_rounded,
                  'Academic Courses'),
              _item(AppNavDestination.academicLibrary, Icons.folder_copy_rounded,
                  'Academic Library'),
              _item(AppNavDestination.pastQuestions, Icons.description_rounded,
                  'Past Questions'),
              _item(AppNavDestination.testsAndQuizzes, Icons.fact_check_rounded,
                  'Tests & Quizzes'),
              _item(AppNavDestination.schoolConnect, Icons.forum_rounded,
                  'School Connect'),
              _item(AppNavDestination.marks, Icons.bar_chart_rounded, 'Marks'),
              _item(AppNavDestination.homework, Icons.edit_note_rounded,
                  'Homework'),
              _item(AppNavDestination.timetable, Icons.calendar_today_rounded,
                  'Timetable'),
              _item(AppNavDestination.attendance,
                  Icons.check_circle_outline_rounded, 'Attendance'),
              _item(AppNavDestination.fees, Icons.account_balance_wallet_rounded,
                  'Fees'),
              _item(AppNavDestination.classroom, Icons.desktop_windows_rounded,
                  'Classroom'),
              _item(AppNavDestination.announcements, Icons.campaign_rounded,
                  'Announcements'),
            ],
          ),
        ),
        const Divider(color: Color(0xFF162544), height: 1),
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 8 : 12, vertical: 10),
          child: Column(
            children: [
              _item(AppNavDestination.settings, Icons.settings_outlined,
                  'Settings'),
              _item(AppNavDestination.help, Icons.help_outline_rounded,
                  'Help'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _item(AppNavDestination dest, IconData icon, String label) {
    final active = currentDestination == dest;
    final color = active ? const Color(0xFFE5A93C) : const Color(0xFF94A3B8);

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => onSelectDestination(dest),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE5A93C).withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: active ? const Color(0xFFE5A93C) : color, size: 22),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => onSelectDestination(dest),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE5A93C) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? const Color(0xFF081630) : const Color(0xFFC0D2F0),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? const Color(0xFF081630) : const Color(0xFFC0D2F0),
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
// Default Academic Right Panel (Contextual Panel for Desktop)
// ────────────────────────────────────────────────────────────────────────────

class DefaultAcademicRightPanel extends StatefulWidget {
  final AppUser? user;
  const DefaultAcademicRightPanel({super.key, required this.user});

  @override
  State<DefaultAcademicRightPanel> createState() =>
      _DefaultAcademicRightPanelState();
}

class _DefaultAcademicRightPanelState extends State<DefaultAcademicRightPanel> {
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. YOUR PROGRESS
        _progressCard(context, ac),
        const SizedBox(height: 16),

        // 2. Today's Schedule
        _scheduleCard(context, ac),
        const SizedBox(height: 16),

        // 3. Announcements
        _announcementsCard(context, ac),
        const SizedBox(height: 16),

        // 4. Tasks
        _tasksCard(context, ac),
        const SizedBox(height: 16),

        // 5. Calendar
        _calendarCard(context, ac),
      ],
    );
  }

  Widget _progressCard(BuildContext context, AppColors ac) {
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
                  const Icon(Icons.insights_rounded, size: 18, color: Color(0xFFE5A93C)),
                  const SizedBox(width: 8),
                  Text('YOUR PROGRESS',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: ac.txt)),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => XpDashboardPage(user: widget.user ?? AppUser.guest()),
                  ));
                },
                child: Row(
                  children: [
                    Text('View Details',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: ac.primary)),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded, size: 13, color: ac.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: 0.57,
                        strokeWidth: 7,
                        backgroundColor: ac.bdr2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE5A93C)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('57%',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: ac.txt)),
                        Text('Course Progress',
                            style: GoogleFonts.inter(
                                fontSize: 8.5, color: ac.txt2)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // 3 stats
              Expanded(
                child: Row(
                  children: [
                    _statPill(Icons.star_rounded, '1069', 'XP Points',
                        const Color(0xFFE5A93C), ac),
                    const SizedBox(width: 6),
                    _statPill(Icons.local_fire_department_rounded, '0',
                        'Day Streak', Colors.deepOrange, ac),
                    const SizedBox(width: 6),
                    _statPill(Icons.emoji_events_rounded, '10', 'Quizzes Done',
                        const Color(0xFFE5A93C), ac),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String val, String label, Color iconCol,
      AppColors ac) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: ac.surf2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ac.bdr2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: iconCol),
            const SizedBox(height: 3),
            Text(val,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ac.txt)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 8.5, color: ac.txt2)),
          ],
        ),
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, AppColors ac) {
    final schedule = [
      ('08:00', 'Mathematics Class', 'Classroom A1'),
      ('10:00', 'Physics Class', 'Classroom B2'),
      ('14:00', 'Chemistry Class', 'Laboratory 1'),
      ('16:00', 'Study Slot', 'Personal Study'),
    ];

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
                  Icon(Icons.calendar_today_rounded,
                      size: 16, color: ac.primary),
                  const SizedBox(width: 8),
                  Text("Today's Schedule",
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ac.txt)),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        TimetablePage(user: widget.user ?? AppUser.guest()),
                  ));
                },
                child: Row(
                  children: [
                    Text('View All',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ac.primary)),
                    Icon(Icons.arrow_forward_rounded,
                        size: 13, color: ac.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (time, subject, room) in schedule)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: ac.grn,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(time,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ac.txt)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ac.txt)),
                        Text(room,
                            style: GoogleFonts.inter(
                                fontSize: 10.5, color: ac.txt2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _announcementsCard(BuildContext context, AppColors ac) {
    final announcements = [
      ('New Past Papers Available', 'GCE & A-level (2019-2023) • 24 Oct 2025', true),
      ('Holiday Revision Program', 'Starts on 3rd November 2025 • 22 Oct 2025', false),
      ('School Fees Reminder', 'Due date: 31st October 2025 • 20 Oct 2025', false),
      ('Science Club Meeting', 'This Friday at 3 PM • 18 Oct 2025', false),
    ];

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
                  const Icon(Icons.campaign_rounded, size: 17, color: Color(0xFFE5A93C)),
                  const SizedBox(width: 8),
                  Text('Announcements',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ac.txt)),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        DailyNoticesPage(user: widget.user ?? AppUser.guest()),
                  ));
                },
                child: Row(
                  children: [
                    Text('View All',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ac.primary)),
                    Icon(Icons.arrow_forward_rounded,
                        size: 13, color: ac.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (title, subtitle, isNew) in announcements)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 14, color: ac.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ac.txt)),
                            ),
                            if (isNew) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5A93C).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('New',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFE5A93C))),
                              ),
                            ],
                          ],
                        ),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 10, color: ac.txt2)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: ac.muted),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tasksCard(BuildContext context, AppColors ac) {
    final tasks = [
      ('Complete Mathematics Exercise 4', 'Due today • Mathematics', true),
      ('Read Chapter 3 – Organic Chemistry', 'Due tomorrow • Chemistry', false),
      ('Submit Geography Assignment', 'Due 30 Oct • Geography', false),
      ('Prepare for Physics Quiz', 'Due 2 Nov • Physics', false),
    ];

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
                  Icon(Icons.fact_check_rounded, size: 16, color: ac.primary),
                  const SizedBox(width: 8),
                  Text('Tasks',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ac.txt)),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        HomeworkPage(user: widget.user ?? AppUser.guest()),
                  ));
                },
                child: Row(
                  children: [
                    Text('View All',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ac.primary)),
                    Icon(Icons.arrow_forward_rounded,
                        size: 13, color: ac.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (title, meta, done) in tasks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 17,
                    color: done ? ac.primary : ac.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ac.txt)),
                        Text(meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 10.5, color: ac.txt2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _calendarCard(BuildContext context, AppColors ac) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
                  Icon(Icons.calendar_month_rounded,
                      size: 16, color: ac.primary),
                  const SizedBox(width: 8),
                  Text('Calendar',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ac.txt)),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        TimetablePage(user: widget.user ?? AppUser.guest()),
                  ));
                },
                child: Row(
                  children: [
                    Text('View All',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ac.primary)),
                    Icon(Icons.arrow_forward_rounded,
                        size: 13, color: ac.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('October 2025',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ac.txt)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in days)
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: ac.muted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Sample rows
          _calendarRow(['', '', '1', '2', '3', '4', '5'], ac),
          _calendarRow(['6', '7', '8', '9', '10', '11', '12'], ac),
          _calendarRow(['13', '14', '15', '16', '17', '18', '19'], ac),
          _calendarRow(['20', '21', '22', '23', '24', '25', '26'], ac),
          _calendarRow(['27*', '28', '29', '30', '31', '', ''], ac),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendDot('Classes', const Color(0xFF1E6FEB)),
              _legendDot('Assignments', const Color(0xFFE5A93C)),
              _legendDot('Quizzes', const Color(0xFF16A34A)),
              _legendDot('Events', const Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarRow(List<String> items, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final raw in items)
            Expanded(
              child: Center(
                child: raw.isEmpty
                    ? const SizedBox(height: 22)
                    : Container(
                        width: 24,
                        height: 24,
                        decoration: raw.contains('*')
                            ? const BoxDecoration(
                                color: Color(0xFFE5A93C),
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Center(
                          child: Text(
                            raw.replaceAll('*', ''),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: raw.contains('*')
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: raw.contains('*')
                                  ? const Color(0xFF081630)
                                  : ac.txt,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color col) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: col, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B))),
      ],
    );
  }
}

// Redirector helper for Past Questions
class _PastQuestionsRedirector extends StatefulWidget {
  final AppUser user;
  const _PastQuestionsRedirector({required this.user});

  @override
  State<_PastQuestionsRedirector> createState() => _PastQuestionsRedirectorState();
}

class _PastQuestionsRedirectorState extends State<_PastQuestionsRedirector> {
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
        builder: (_) => LibraryHomePage(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

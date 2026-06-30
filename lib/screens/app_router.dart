// lib/screens/app_router.dart
// Root navigator with 6-role permission system and feature-flag gated HomeShell.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/institution_provider.dart';
import '../models/models.dart';
import '../theme/institution_theme_engine.dart';
import '../theme/app_theme.dart';
import '../features/institution/school_code_page.dart';
import '../features/institution/institution_splash_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
// pages
import '../features/dashboard/dashboard_page.dart';
import '../features/announcements/announcements_page.dart';
import '../features/library/library_page.dart';
import '../features/timetable/timetable_page.dart';
import '../features/attendance/attendance_page.dart';
import '../features/assignments/assignments_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/courses/courses_page.dart';
import '../features/admin/admin_panel_page.dart';
import '../pages/marks_page.dart';
import '../pages/profile_page.dart';

// ────────────────────────────────────────────────────────────────────────────
// AppRouter — watches InstitutionProvider + Firebase auth
// ────────────────────────────────────────────────────────────────────────────

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});
  @override State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _splashDone = false;
  Institution? _splashInst;

  @override
  Widget build(BuildContext context) {
    final instProv = context.watch<InstitutionProvider>();

    if (!instProv.isLoaded) {
      _splashDone = false; _splashInst = null;
      if (instProv.isValidating) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const SchoolCodePage();
    }

    final inst = instProv.effectiveInstitution;

    if (!_splashDone || _splashInst?.institutionId != inst.institutionId) {
      return InstitutionSplashScreen(
        institution: inst,
        onContinue: () => setState(() { _splashDone = true; _splashInst = inst; }),
      );
    }

    return Theme(data: InstitutionThemeEngine.build(inst), child: _AuthGate(institution: inst));
  }
}

class _AuthGate extends StatelessWidget {
  final Institution institution;
  const _AuthGate({required this.institution});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) {
          return LoginScreen(school: SchoolConfig(
            id: institution.institutionId,
            name: institution.schoolName,
            motto: institution.tagline ?? 'Powered by Academia',
            academicYear: '', logoUrl: institution.logoUrl,
          ));
        }
        return _AppUserGate(institution: institution);
      },
    );
  }
}

class _AppUserGate extends StatelessWidget {
  final Institution institution;
  const _AppUserGate({required this.institution});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.currentAppUserStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          FirebaseAuth.instance.signOut();
          return const Scaffold(body: Center(child: Text('Account not found.')));
        }
        if (user.status == AccountStatus.suspended) return _SuspendedScreen(user: user);
        return HomeShell(user: user, institution: institution);
      },
    );
  }
}

class _SuspendedScreen extends StatelessWidget {
  final AppUser user;
  const _SuspendedScreen({required this.user});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.block_outlined, size: 64, color: C.red),
          const SizedBox(height: 16),
          Text('Account Suspended',
              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: C.txt)),
          const SizedBox(height: 8),
          Text('Please contact your school administration.',
              style: GoogleFonts.inter(color: C.txt2), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton(
              onPressed: () => AuthService.instance.signOut(),
              child: const Text('Sign Out')),
        ]),
      )),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HomeShell — role-gated bottom navigation
// ────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  final AppUser user;
  final Institution institution;
  const HomeShell({super.key, required this.user, required this.institution});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  List<_NavDef> _buildNav() {
    final u = widget.user;
    final i = widget.institution;
    final nav = <_NavDef>[];

    // Dashboard — always
    nav.add(const _NavDef('Home', Icons.home_rounded, Icons.home_outlined, UserRole.guest));

    // Announcements
    if (i.hasFeature(InstitutionFeature.announcements)) {
      nav.add(const _NavDef('Notices', Icons.campaign_rounded, Icons.campaign_outlined, UserRole.student));
    }

    // Calendar / Events
    if (i.hasFeature(InstitutionFeature.events)) {
      nav.add(const _NavDef('Calendar', Icons.calendar_month_rounded, Icons.calendar_month_outlined, UserRole.student));
    }

    // Courses — students, lecturers, admins
    nav.add(const _NavDef('Courses', Icons.school_rounded, Icons.school_outlined, UserRole.student));

    // Timetable
    if (i.hasFeature(InstitutionFeature.timetable)) {
      nav.add(const _NavDef('Timetable', Icons.schedule_rounded, Icons.schedule_outlined, UserRole.student));
    }

    // Assignments — students and above
    if (i.hasFeature(InstitutionFeature.assignments)) {
      nav.add(const _NavDef('Assignments', Icons.assignment_rounded, Icons.assignment_outlined, UserRole.student));
    }

    // Marks / Grades
    if (i.hasFeature(InstitutionFeature.marks)) {
      nav.add(const _NavDef('Grades', Icons.grade_rounded, Icons.grade_outlined, UserRole.student));
    }

    // Attendance — lecturers and students
    if (i.hasFeature(InstitutionFeature.attendance) && (u.isLecturer || u.isStudent || u.isAdmin)) {
      nav.add(const _NavDef('Attendance', Icons.fact_check_rounded, Icons.fact_check_outlined, UserRole.student));
    }

    // Library
    if (i.hasFeature(InstitutionFeature.library)) {
      nav.add(const _NavDef('Library', Icons.menu_book_rounded, Icons.menu_book_outlined, UserRole.student));
    }

    // Admin — dept admin and above
    if (u.canManageUsers) {
      nav.add(const _NavDef('Admin', Icons.admin_panel_settings_rounded,
          Icons.admin_panel_settings_outlined, UserRole.departmentAdmin));
    }

    // Profile — always last
    nav.add(const _NavDef('Profile', Icons.person_rounded, Icons.person_outlined, UserRole.guest));

    // Filter by minimum role (privilege gate)
    return nav.where((n) => widget.user.hasMinRole(n.minRole)).toList();
  }

  Widget _buildPage(_NavDef def) {
    final u = widget.user;
    // Guard check
    if (!u.hasMinRole(def.minRole)) {
      return Scaffold(body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: C.muted),
            const SizedBox(height: 12),
            Text('Access Restricted',
                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          ])));
    }
    switch (def.label) {
      case 'Home':        return DashboardPage(user: u);
      case 'Notices':     return AnnouncementsPage(user: u, canPost: u.canPostAnnouncement);
      case 'Calendar':    return CalendarPage(user: u);
      case 'Courses':     return CoursesPage(user: u);
      case 'Timetable':   return TimetablePage(user: u);
      case 'Assignments': return AssignmentsPage(user: u);
      case 'Grades':      return MarksPage(user: u);
      case 'Attendance':  return AttendancePage(user: u);
      case 'Library':     return LibraryPage(user: u);
      case 'Admin':       return AdminPanelPage(user: u);
      case 'Profile':     return ProfilePage(user: u, institution: widget.institution);
      default:            return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav     = _buildNav();
    final safeTab = _tab.clamp(0, nav.length - 1);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: safeTab,
          children: nav.map(_buildPage).toList(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeTab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: nav.map((n) => NavigationDestination(
          icon: Icon(n.outlinedIcon), selectedIcon: Icon(n.filledIcon), label: n.label,
        )).toList(),
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

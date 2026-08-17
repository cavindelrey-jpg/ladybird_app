// lib/features/school_management/school_management_page.dart
// production_plan.md §7C — the single protected door into the school-
// management system, which §7A removed from ordinary Academia navigation.
//
// Why this exists at all: §7A's instruction is to stop *exposing* school
// management in the normal app, explicitly NOT to delete it ("Do not
// necessarily delete the underlying school-management functionality...
// preserve the school-management system for the School Edition"). So the
// pages themselves (AttendancePage, MarksPage, TimetablePage, ...) are
// untouched and fully intact — they simply have exactly one entry point
// now, and that entry point is role-gated.
//
// Security model — three independent layers, because the plan is explicit
// that "the route must not be secured merely by hiding its URL":
//
//   1. Discoverability: the drawer only renders the entry for a user whose
//      AppUser.canManageSchool is true. This is convenience, NOT security,
//      and is deliberately not relied on.
//   2. Client-side guard: [SchoolManagementPage] re-checks canManageSchool
//      in its own build(). Constructing this route directly — a stray
//      Navigator.push from anywhere, a future deep link, a hot-reload
//      shortcut — still lands on the access-denied screen rather than the
//      hub. The guard lives on the page, not on the caller.
//   3. Backend authorization: every collection reachable from here is
//      role-gated in firestore.rules (canManageSchool()/canUploadContent()
//      for writes, own-school scoping for reads). That is the only layer
//      that actually protects the DATA — layers 1 and 2 only protect the
//      UI. A hostile client that skips this page entirely still cannot
//      read or write another school's records.
//
// Route naming: this app has no named-route table (MaterialApp uses
// `home:` plus direct Navigator.push everywhere — see main.dart), so
// [routeName] is a documented identifier for analytics/deep-linking
// rather than something registered in a routes map. The plan explicitly
// allows the exact route to change during implementation.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../announcements/announcements_page.dart';
import '../assignments/assignments_page.dart';
import '../attendance/attendance_page.dart';
import '../calendar/calendar_page.dart';
import '../timetable/timetable_page.dart';
import '../admin/admin_panel_page.dart';
import '../../pages/admin_accounts_page.dart';
import '../../pages/marks_page.dart';

class SchoolManagementPage extends StatelessWidget {
  /// Documented route identifier (see the file header on why this is a
  /// constant rather than an entry in a routes map).
  static const String routeName = '/school-management';

  final AppUser user;
  const SchoolManagementPage({super.key, required this.user});

  /// Guarded entry point. Callers should use this rather than pushing
  /// [SchoolManagementPage] directly, so an unauthorized tap never even
  /// builds the route — but note the page guards itself too, so this is
  /// convenience, not the security boundary.
  static void open(BuildContext context, AppUser user) {
    if (!user.canManageSchool) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SchoolManagementPage(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    // Layer 2 — see the file header. Deliberately re-checked here and not
    // assumed from the caller.
    if (!user.canManageSchool) return _AccessDenied(user: user);

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        title: Text('School Management',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ac.primaryBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ac.primary.withValues(alpha: .3)),
              ),
              child: Row(children: [
                Icon(Icons.shield_outlined, size: 18, color: ac.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Signed in as ${user.roleLabel}. These tools are limited to '
                    'your school and are not part of the normal Academia app.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: ac.txt2, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),

            _sectionLabel(ac, 'Students'),
            _Tile(Icons.fact_check_outlined, 'Attendance',
                'Daily attendance registers',
                onTap: () => _push(context, AttendancePage(user: user))),
            _Tile(Icons.grade_outlined, 'Marks & Results',
                'Sequence marks and report cards',
                onTap: () => _push(context, MarksPage(user: user))),
            _Tile(Icons.badge_outlined, 'Student Records',
                'Accounts, classes, roles and suspensions',
                onTap: () => _push(context, AdminAccountsPage(user: user))),

            const SizedBox(height: 18),
            _sectionLabel(ac, 'Academics'),
            _Tile(Icons.schedule_outlined, 'Timetable',
                'Class and lecturer scheduling',
                onTap: () => _push(context, TimetablePage(user: user))),
            _Tile(Icons.assignment_outlined, 'Assignments',
                'Set work and review submissions',
                onTap: () => _push(context, AssignmentsPage(user: user))),
            _Tile(Icons.calendar_month_outlined, 'Academic Calendar',
                'Terms, holidays and school events',
                onTap: () => _push(context, CalendarPage(user: user))),

            const SizedBox(height: 18),
            _sectionLabel(ac, 'Administration'),
            _Tile(Icons.campaign_outlined, 'Notices',
                'Post announcements to the school',
                onTap: () => _push(context,
                    AnnouncementsPage(user: user, canPost: user.canPostAnnouncement))),
            _Tile(Icons.admin_panel_settings_outlined, 'School Administration',
                'Users, roles and enrollment seats',
                onTap: () => _push(context, AdminPanelPage(user: user))),

            const SizedBox(height: 24),
            // Honesty note, same standard the rest of this codebase holds
            // itself to: §7C also lists "Student follow-up", "Performance
            // tracking" and "Reports". No page, repository or model for
            // any of those exists in this codebase (verified by grep), so
            // they are deliberately absent rather than represented by a
            // tile that opens a placeholder or fabricated dashboard.
            Text(
              'Student follow-up, performance tracking and reporting are not '
              'built yet — they will appear here once they exist.',
              style: GoogleFonts.inter(
                  fontSize: 11.5, color: ac.muted, fontStyle: FontStyle.italic, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _sectionLabel(AppColors ac, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: GoogleFonts.sora(
                fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt2)),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Tile(this.icon, this.title, this.subtitle, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: ac.surf,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ac.bdr)),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: ac.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: ac.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ac.txt)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted)),
                    ]),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Shown when someone reaches this route without the school-admin role.
/// Deliberately a real screen rather than a silent pop: a silent pop is
/// indistinguishable from a broken button, and this state should be
/// legible if it ever happens to a real user.
class _AccessDenied extends StatelessWidget {
  final AppUser user;
  const _AccessDenied({required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(backgroundColor: ac.bg),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: ac.muted),
            const SizedBox(height: 16),
            Text('Access Restricted',
                style: GoogleFonts.sora(
                    fontSize: 18, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 8),
            Text(
              'School Management requires a school administrator account. '
              'You are signed in as ${user.roleLabel}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }
}

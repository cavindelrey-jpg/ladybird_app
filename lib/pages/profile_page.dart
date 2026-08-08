// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../providers/institution_provider.dart';
import '../features/announcements/announcements_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/timetable/timetable_page.dart';
import '../features/assignments/assignments_page.dart';
import '../features/attendance/attendance_page.dart';
import '../pages/marks_page.dart';
import 'profile_edit_page.dart';
import 'bookmarks_page.dart';
import 'settings_page.dart';

import '../widgets/app_background.dart';
class ProfilePage extends StatelessWidget {
  final AppUser user;
  final Institution? institution;
  const ProfilePage({super.key, required this.user, this.institution});

  static Color _roleColor(AppColors ac, UserRole r) {
    switch (r) {
      case UserRole.superAdmin:     return ac.pur;
      case UserRole.schoolAdmin:    return ac.primary;
      case UserRole.departmentAdmin:return ac.blu;
      case UserRole.lecturer:       return ac.gold;
      case UserRole.student:        return ac.grn;
      case UserRole.guest:          return ac.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final inst = institution;
    final rc   = _roleColor(ac, user.role);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        title: Text('Profile', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: ac.txt)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsPage(user: user))),
            icon: Icon(Icons.settings_outlined, color: ac.txt2),
            tooltip: 'Settings',
          ),
          TextButton.icon(
            onPressed: () async {
              await AuthService.instance.signOut();
              if (context.mounted) context.read<InstitutionProvider>().clear();
            },
            icon: Icon(Icons.logout_rounded, size: 18, color: ac.red),
            label: Text('Sign Out',
                style: GoogleFonts.inter(fontSize: 13, color: ac.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: AppBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Institution banner
          if (inst != null) ...[
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [inst.primary, inst.secondary]),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(
                    inst.schoolName.isNotEmpty ? inst.schoolName[0].toUpperCase() : 'A',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(inst.schoolName, style: GoogleFonts.sora(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (inst.tagline != null)
                    Text(inst.tagline!, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Avatar
          user.photoUrl != null && user.photoUrl!.isNotEmpty
              ? CircleAvatar(radius: 40, backgroundImage: NetworkImage(user.photoUrl!))
              : Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rc.withValues(alpha: .1),
                      border: Border.all(color: rc.withValues(alpha: .3), width: 2)),
                  child: Center(child: Text(user.initials,
                      style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: rc))),
                ),
          const SizedBox(height: 12),
          Text(user.name, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: rc.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
            child: Text(user.roleLabel,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: rc))),
          const SizedBox(height: 14),
          if (user.bio.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(user.bio, textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.5)),
            )
          else
            Text('No bio yet — tell people a bit about yourself.',
                style: GoogleFonts.inter(fontSize: 12, color: ac.muted, fontStyle: FontStyle.italic)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileEditPage(user: user))),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit Profile'),
          ),
          const SizedBox(height: 24),

          // Info rows
          _InfoRow(Icons.email_outlined, 'Email', user.email.isEmpty ? '—' : user.email),
          _InfoRow(Icons.school_outlined, 'Class / Level',
              user.classLevel.isEmpty ? '—' : user.classLevel),
          _InfoRow(
            Icons.grade_outlined,
            'Education Level',
            user.educationLevel.isEmpty ? 'Tap to set' : user.educationLevel,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileEditPage(user: user))),
          ),
          if (user.subject != null && user.subject!.isNotEmpty)
            _InfoRow(Icons.subject_rounded, 'Subject', user.subject!),
          _InfoRow(Icons.account_circle_outlined, 'Account Type', user.accountTypeLabel),
          _InfoRow(Icons.security_outlined, 'Privilege Level',
              'Level ${user.privilegeLevel} — ${user.roleLabel}'),
          if (user.courseIds.isNotEmpty)
            _InfoRow(Icons.auto_stories_outlined, 'Courses',
                '${user.courseIds.length} course(s) enrolled'),

          const SizedBox(height: 10),
          _InfoRow(Icons.bookmark_border_rounded, 'My Bookmarks', '',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BookmarksPage(user: user)))),

          if (inst != null) ...[
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('School', style: GoogleFonts.sora(
                  fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt2)),
            ),
            const SizedBox(height: 10),
            // These used to each be their own bottom-nav tab — a school
            // with every feature enabled ended up with 8-10 crowded tabs.
            // Same features, same role/feature gating, just reachable
            // from Profile now instead of the nav bar.
            if (inst.hasFeature(InstitutionFeature.announcements))
              _InfoRow(Icons.campaign_outlined, 'Notices', '',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AnnouncementsPage(
                          user: user, canPost: user.canPostAnnouncement)))),
            if (inst.hasFeature(InstitutionFeature.events))
              _InfoRow(Icons.calendar_month_outlined, 'Calendar', '',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CalendarPage(user: user)))),
            if (inst.hasFeature(InstitutionFeature.timetable))
              _InfoRow(Icons.schedule_outlined, 'Timetable', '',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TimetablePage(user: user)))),
            if (inst.hasFeature(InstitutionFeature.assignments))
              _InfoRow(Icons.assignment_outlined, 'Assignments', '',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AssignmentsPage(user: user)))),
            if (inst.hasFeature(InstitutionFeature.marks))
              _InfoRow(Icons.grade_outlined, 'Grades', '',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MarksPage(user: user)))),
            if (inst.hasFeature(InstitutionFeature.attendance) &&
                (user.isLecturer || user.isStudent || user.isAdmin))
              _InfoRow(Icons.fact_check_outlined, 'Attendance', '',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AttendancePage(user: user)))),
          ],

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<InstitutionProvider>().clear(),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Switch School')),
        ]),
      )),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  const _InfoRow(this.icon, this.label, this.value, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final row = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.bdr)),
      child: Row(children: [
        Icon(icon, size: 18, color: ac.primary),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: ac.txt2)),
        if (value.isNotEmpty) ...[
          const Spacer(),
          Flexible(child: Text(value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ac.txt),
              textAlign: TextAlign.end)),
        ] else
          const Spacer(),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 16, color: ac.muted),
        ],
      ]),
    );
    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, child: row);
  }
}

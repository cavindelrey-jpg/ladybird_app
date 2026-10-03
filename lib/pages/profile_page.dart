// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/branding.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../features/timetable/personal_study_page.dart';
import '../features/testing/xp_dashboard_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/timetable_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/entitlements/entitlements.dart';
import 'profile_edit_page.dart';
import 'bookmarks_page.dart';
import 'settings_page.dart';

import '../widgets/app_background.dart';
class ProfilePage extends StatelessWidget {
  final AppUser user;
  const ProfilePage({super.key, required this.user});

  /// Entitlement label plus its real remaining days, e.g.
  /// "Gifted Premium · 118 days left". Falls back to the bare label for a
  /// free account or a perpetual grant that has no expiry to report.
  static String _membershipValue(AppUser user) {
    final days = user.entitlement.daysRemaining;
    if (days == null) return user.entitlementLabel;
    return '${user.entitlementLabel} · $days days left';
  }

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
            onPressed: () => AuthService.instance.performSignOut(context),
            icon: Icon(Icons.logout_rounded, size: 18, color: ac.red),
            label: Text('Sign Out',
                style: GoogleFonts.inter(fontSize: 13, color: ac.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: AppBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
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

          // ── Section 1: Contact / Account Information ──────────────────
          _SectionHeader('Contact / Account Information'),
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
          // Sales desk — staff only. Same gate as the page itself
          // (AppUser.canManageUsers, i.e. departmentAdmin and above).
          if (user.canManageUsers)
            _InfoRow(Icons.point_of_sale_outlined, 'Sales Desk', '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SalesDeskPage(user: user)))),

          // ── Section 2: School Navigation ───────────────────────────────
          // Gated on isSchoolMember (a redeemed school voucher), NOT on
          // !isGuest -- holding any signed-in Academia account must never
          // by itself surface a school's private features (architecture
          // brief item 2). No "Connect Your School" fallback for a non-
          // member anymore -- school membership is established once, at
          // first launch, by voucher_signup_screen.dart; there's no
          // second code to enter later, so this section simply doesn't
          // show until membership already exists.
          if (user.isSchoolMember || Branding.current.brandId != 'academia') ...[
            const SizedBox(height: 8),
            _SectionHeader('School Navigation'),
            _InfoRow(Icons.forum_outlined, 'School Connect', '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SchoolConnectPage(user: user)))),
            _InfoRow(Icons.assessment_outlined, 'Marks', '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MarksPage(user: user)))),
            _InfoRow(Icons.menu_book_outlined, 'Homework', '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HomeworkPage(user: user)))),
            _InfoRow(Icons.calendar_month_outlined, 'Timetable', '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TimetablePage(user: user)))),
          ],

          // ── Section 3: My Learning & Membership ─────────────────────────
          if (!user.isGuest) ...[
            const SizedBox(height: 8),
            _SectionHeader('My Learning & Membership'),
            _InfoRow(Icons.emoji_events_outlined, 'My Progress', '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => XpDashboardPage(user: user)))),
            _InfoRow(Icons.bookmark_border_rounded, 'My Bookmarks', '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BookmarksPage(user: user)))),
            // Personal Study Plan (production_plan.md §5) — self-authored,
            // distinct from the official school Timetable above. Renamed
            // from "My Study Timetable" to "My Study Plan" specifically
            // to stop the two being confused now that a real school
            // Timetable also exists.
            _InfoRow(Icons.event_note_outlined, 'My Study Plan', '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PersonalStudyPage(user: user)))),
            // ── Membership (production_plan.md §8/§9) ────────────────────
            // Real entitlement state off the user document — 'Free',
            // 'Premium' or 'Gifted Premium', plus the genuine expiry when
            // there is one. Never a hardcoded tier label.
            _InfoRow(
              user.isPremium
                  ? Icons.workspace_premium_rounded
                  : Icons.workspace_premium_outlined,
              'Membership',
              _membershipValue(user),
            ),
            _InfoRow(Icons.card_giftcard_outlined, 'Redeem a Voucher', '',
                onTap: () => openRedeemVoucher(context, user)),
          ],
        ]),
      )),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title.toUpperCase(), style: AppText.label.copyWith(color: ac.muted, fontSize: 11)),
      ),
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

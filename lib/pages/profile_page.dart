// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../providers/institution_provider.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  final AppUser user;
  final Institution? institution;
  const ProfilePage({super.key, required this.user, this.institution});

  static Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.superAdmin:     return C.pur;
      case UserRole.schoolAdmin:    return C.primary;
      case UserRole.departmentAdmin:return C.blu;
      case UserRole.lecturer:       return C.gold;
      case UserRole.student:        return C.grn;
      case UserRole.guest:          return C.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inst = institution;
    final rc   = _roleColor(user.role);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsPage(user: user))),
            icon: const Icon(Icons.settings_outlined, color: C.txt2),
            tooltip: 'Settings',
          ),
          TextButton.icon(
            onPressed: () async {
              await AuthService.instance.signOut();
              if (context.mounted) context.read<InstitutionProvider>().clear();
            },
            icon: const Icon(Icons.logout_rounded, size: 18, color: C.red),
            label: Text('Sign Out',
                style: GoogleFonts.inter(fontSize: 13, color: C.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
          Text(user.name, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700)),
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
                  style: GoogleFonts.inter(fontSize: 13, color: C.txt2, height: 1.5)),
            )
          else
            Text('No bio yet — tell people a bit about yourself.',
                style: GoogleFonts.inter(fontSize: 12, color: C.muted, fontStyle: FontStyle.italic)),
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
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<InstitutionProvider>().clear(),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Switch School')),
        ]),
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
    final row = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bdr)),
      child: Row(children: [
        Icon(icon, size: 18, color: C.primary),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: C.txt2)),
        const Spacer(),
        Flexible(child: Text(value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: C.txt),
            textAlign: TextAlign.end)),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 16, color: C.muted),
        ],
      ]),
    );
    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, child: row);
  }
}

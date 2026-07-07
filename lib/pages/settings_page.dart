// lib/pages/settings_page.dart
// One Settings screen, reachable from both the drawer ("Settings") and
// the Profile page, so they never drift into two different UIs.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../providers/institution_provider.dart';
import 'profile_edit_page.dart';
import 'change_password_page.dart';
import 'notification_preferences_page.dart';
import 'help_support_page.dart';
import 'about_academia_page.dart';

class SettingsPage extends StatelessWidget {
  final AppUser user;
  const SettingsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Settings', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel('Account'),
          _tile(context, Icons.person_outline_rounded, 'Edit Profile',
              'Photo, bio, and education level',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileEditPage(user: user)))),
          _tile(context, Icons.lock_outline_rounded, 'Change Password',
              'Update your sign-in password',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ChangePasswordPage()))),
          if (user.accountType == AccountType.linked)
            _tile(context, Icons.swap_horiz_rounded, 'Switch School', 'Leave this institution',
                () => context.read<InstitutionProvider>().clear()),

          const SizedBox(height: 24),
          _sectionLabel('Notifications'),
          _tile(context, Icons.notifications_outlined, 'Notification Preferences',
              'Announcements, comments, replies',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NotificationPreferencesPage(userId: user.id)))),

          const SizedBox(height: 24),
          _sectionLabel('Support'),
          _tile(context, Icons.help_outline_rounded, 'Help & Support', 'FAQs and contact',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const HelpSupportPage()))),
          _tile(context, Icons.info_outline_rounded, 'About Academia', 'Version 2.0.0',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AboutAcademiaPage()))),

          const SizedBox(height: 24),
          _tile(context, Icons.logout_rounded, 'Sign Out', null, () async {
            await AuthService.instance.signOut();
            if (context.mounted) context.read<InstitutionProvider>().clear();
          }, color: C.red),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text, style: GoogleFonts.sora(
            fontSize: 12, fontWeight: FontWeight.w800, color: C.txt2, letterSpacing: .4)),
      );

  Widget _tile(BuildContext context, IconData icon, String title, String? subtitle,
      VoidCallback onTap, {Color? color}) {
    final c = color ?? C.txt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
      child: ListTile(
        leading: Icon(icon, color: c, size: 20),
        title: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c)),
        subtitle: subtitle != null
            ? Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: C.txt2))
            : null,
        trailing: color == null ? const Icon(Icons.chevron_right_rounded, color: C.muted) : null,
        onTap: onTap,
      ),
    );
  }
}

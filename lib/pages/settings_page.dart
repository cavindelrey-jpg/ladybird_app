// lib/pages/settings_page.dart
// One Settings screen, reachable from both the drawer ("Settings") and
// the Profile page, so they never drift into two different UIs.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'profile_edit_page.dart';
import 'change_password_page.dart';
import 'notification_preferences_page.dart';
import 'help_support_page.dart';
import 'about_academia_page.dart';
import '../features/onboarding/school_admin_page.dart';

import '../widgets/app_background.dart';
class SettingsPage extends StatelessWidget {
  final AppUser user;
  const SettingsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Settings', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel(context, 'Appearance'),
          _themeToggleTile(context),
          const SizedBox(height: 16),
          _sectionLabel(context, 'App Language'),
          _languageToggleTile(context),

          const SizedBox(height: 24),
          _sectionLabel(context, 'Account'),
          _tile(context, Icons.person_outline_rounded, 'Edit Profile',
              'Photo, bio, and education level',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileEditPage(user: user)))),
          _tile(context, Icons.lock_outline_rounded, 'Change Password',
              'Update your sign-in password',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ChangePasswordPage()))),

          const SizedBox(height: 24),
          _sectionLabel(context, 'Notifications'),
          _tile(context, Icons.notifications_outlined, 'Notification Preferences',
              "Tomorrow's programme, reminders, comments",
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NotificationPreferencesPage(userId: user.id)))),

          if (user.canManageUsers) ...[
            const SizedBox(height: 24),
            _sectionLabel(context, 'School Administration'),
            _tile(context, Icons.badge_outlined, 'School Access Admin',
                'Register schools, issue voucher codes',
                () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SchoolAdminPage(user: user)))),
          ],

          const SizedBox(height: 24),
          _sectionLabel(context, 'Support'),
          _tile(context, Icons.help_outline_rounded, 'Help & Support', 'FAQs and contact',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const HelpSupportPage()))),
          _tile(context, Icons.info_outline_rounded, 'About', 'Version 2.0.0',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AboutAcademiaPage()))),

          const SizedBox(height: 24),
          _tile(context, Icons.logout_rounded, 'Sign Out', null,
              () => AuthService.instance.performSignOut(context), color: ac.red),
        ],
      )),
    );
  }

  /// Three-way Light / Dark / System control rather than a plain on-off
  /// switch — a binary switch can't represent "follow the OS", which is
  /// what most people actually want once dark mode exists at all.
  Widget _themeToggleTile(BuildContext context) {
    final ac = AppColors.of(context);
    final mode = context.watch<ThemeProvider>().mode;
    Widget seg(ThemeMode m, IconData icon, String label) {
      final selected = mode == m;
      return Expanded(
        child: Material(
          color: selected ? ac.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.read<ThemeProvider>().setMode(m),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: selected ? Colors.white : ac.txt2),
                const SizedBox(height: 4),
                Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : ac.txt2)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Row(children: [
        seg(ThemeMode.light, Icons.light_mode_rounded, 'Light'),
        const SizedBox(width: 6),
        seg(ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
        const SizedBox(width: 6),
        seg(ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
      ]),
    );
  }

  Widget _languageToggleTile(BuildContext context) {
    final ac = AppColors.of(context);
    final lang = context.watch<LocaleProvider>().language;
    Widget seg(AppLanguage l, IconData icon, String label) {
      final selected = lang == l;
      return Expanded(
        child: Material(
          color: selected ? ac.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.read<LocaleProvider>().setLanguage(l),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: selected ? Colors.white : ac.txt2),
                const SizedBox(height: 4),
                Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : ac.txt2)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Row(children: [
        seg(AppLanguage.system, Icons.settings_suggest_rounded, 'System'),
        const SizedBox(width: 6),
        seg(AppLanguage.english, Icons.language_rounded, 'English'),
        const SizedBox(width: 6),
        seg(AppLanguage.french, Icons.translate_rounded, 'Français'),
      ]),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text, style: GoogleFonts.sora(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.of(context).txt2, letterSpacing: .4)),
      );

  Widget _tile(BuildContext context, IconData icon, String title, String? subtitle,
      VoidCallback onTap, {Color? color}) {
    final ac = AppColors.of(context);
    final c = color ?? ac.txt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: ListTile(
        leading: Icon(icon, color: c, size: 20),
        title: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c)),
        subtitle: subtitle != null
            ? Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: ac.txt2))
            : null,
        trailing: color == null ? Icon(Icons.chevron_right_rounded, color: ac.muted) : null,
        onTap: onTap,
      ),
    );
  }
}

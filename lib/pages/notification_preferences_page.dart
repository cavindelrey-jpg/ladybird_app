// lib/pages/notification_preferences_page.dart
// Replaces the ComingSoonPage stub. Reads/writes users/{uid}/settings/notifications.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../widgets/widgets.dart';
import '../widgets/app_background.dart';

class NotificationPreferencesPage extends StatefulWidget {
  final String userId;
  const NotificationPreferencesPage({super.key, required this.userId});

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  NotificationPreferences? _prefs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    NotificationRepository.instance.getPreferences(widget.userId).then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  Future<void> _update(NotificationPreferences next) async {
    setState(() { _prefs = next; _saving = true; });
    await NotificationRepository.instance.updatePreferences(widget.userId, next);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Notification Preferences', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: AppBackground(child: _prefs == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Choose what you get notified about',
                    style: GoogleFonts.inter(fontSize: 13, color: ac.txt2)),
                const SizedBox(height: 20),
                _toggle(
                  ac: ac,
                  icon: Icons.campaign_outlined,
                  title: 'Announcements',
                  subtitle: 'School and platform announcements',
                  value: _prefs!.announcements,
                  onChanged: (v) => _update(_prefs!.copyWith(announcements: v)),
                ),
                _toggle(
                  ac: ac,
                  icon: Icons.mode_comment_outlined,
                  title: 'Comments',
                  subtitle: 'When someone comments on your article',
                  value: _prefs!.comments,
                  onChanged: (v) => _update(_prefs!.copyWith(comments: v)),
                ),
                _toggle(
                  ac: ac,
                  icon: Icons.reply_outlined,
                  title: 'Replies',
                  subtitle: 'When someone replies to your comment',
                  value: _prefs!.replies,
                  onChanged: (v) => _update(_prefs!.copyWith(replies: v)),
                ),
                _toggle(
                  ac: ac,
                  icon: Icons.auto_stories_outlined,
                  title: 'New Articles',
                  subtitle: 'When writers you follow publish',
                  value: _prefs!.newArticles,
                  onChanged: (v) => _update(_prefs!.copyWith(newArticles: v)),
                ),
                _toggle(
                  ac: ac,
                  icon: Icons.today_rounded,
                  title: 'Tomorrow\'s Programme',
                  subtitle: 'Every evening at 7 PM: classes, homework and school events',
                  value: _prefs!.dailyProgram,
                  onChanged: (v) => _update(_prefs!.copyWith(dailyProgram: v)),
                ),
                _toggle(
                  ac: ac,
                  icon: Icons.auto_awesome_outlined,
                  title: 'Daily Challenge & Recommendations',
                  subtitle: 'A morning reminder plus a course and book picked for you',
                  value: _prefs!.recommendations,
                  onChanged: (v) => _update(_prefs!.copyWith(recommendations: v)),
                ),
              ],
            ),
      ),
    );
  }

  Widget _toggle({
    required AppColors ac,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
          color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: SwitchListTile(
        secondary: Icon(icon, color: ac.txt2, size: 20),
        title: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ac.txt)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
        value: value,
        activeThumbColor: ac.gold,
        onChanged: onChanged,
      ),
    );
  }
}

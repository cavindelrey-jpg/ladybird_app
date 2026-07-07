// lib/pages/notification_preferences_page.dart
// Replaces the ComingSoonPage stub. Reads/writes users/{uid}/settings/notifications.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../widgets/widgets.dart';

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
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Notification Preferences', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
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
      body: _prefs == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Choose what you get notified about',
                    style: GoogleFonts.inter(fontSize: 13, color: C.txt2)),
                const SizedBox(height: 20),
                _toggle(
                  icon: Icons.campaign_outlined,
                  title: 'Announcements',
                  subtitle: 'School and platform announcements',
                  value: _prefs!.announcements,
                  onChanged: (v) => _update(_prefs!.copyWith(announcements: v)),
                ),
                _toggle(
                  icon: Icons.mode_comment_outlined,
                  title: 'Comments',
                  subtitle: 'When someone comments on your article',
                  value: _prefs!.comments,
                  onChanged: (v) => _update(_prefs!.copyWith(comments: v)),
                ),
                _toggle(
                  icon: Icons.reply_outlined,
                  title: 'Replies',
                  subtitle: 'When someone replies to your comment',
                  value: _prefs!.replies,
                  onChanged: (v) => _update(_prefs!.copyWith(replies: v)),
                ),
                _toggle(
                  icon: Icons.auto_stories_outlined,
                  title: 'New Articles',
                  subtitle: 'When writers you follow publish',
                  value: _prefs!.newArticles,
                  onChanged: (v) => _update(_prefs!.copyWith(newArticles: v)),
                ),
              ],
            ),
    );
  }

  Widget _toggle({
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
          color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
      child: SwitchListTile(
        secondary: Icon(icon, color: C.txt2, size: 20),
        title: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: C.txt)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: C.txt2)),
        value: value,
        activeColor: C.gold,
        onChanged: onChanged,
      ),
    );
  }
}

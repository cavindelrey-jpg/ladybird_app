// lib/pages/notifications_page.dart
// Replaces the ComingSoonPage stub behind the Home bell icon and drawer
// entry. Simple Firestore-backed feed, scoped to the signed-in user.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../widgets/widgets.dart';

class NotificationsPage extends StatelessWidget {
  final String userId;
  const NotificationsPage({super.key, required this.userId});

  IconData _iconFor(NotificationType t) {
    switch (t) {
      case NotificationType.announcement:     return Icons.campaign_outlined;
      case NotificationType.comment:          return Icons.mode_comment_outlined;
      case NotificationType.reply:            return Icons.reply_outlined;
      case NotificationType.articlePublished: return Icons.auto_stories_outlined;
      case NotificationType.system:           return Icons.info_outline_rounded;
    }
  }

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${_months[dt.month - 1]} ${dt.day}, $h:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Notifications', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
        actions: [
          TextButton(
            onPressed: () => NotificationRepository.instance.markAllRead(userId),
            child: Text('Mark all read', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: C.primary)),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationRepository.instance.watchFeed(userId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final items = snap.data ?? const <AppNotification>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              subtitle: "Announcements, comments, and replies will show up here.",
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => NotificationRepository.instance.delete(userId, n.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(Rad.md)),
                  child: const Icon(Icons.delete_outline_rounded, color: C.red),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.read ? C.surf : C.primaryBg,
                    borderRadius: BorderRadius.circular(Rad.md),
                    border: Border.all(color: C.bdr),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.md),
                    onTap: () => NotificationRepository.instance.markRead(userId, n.id),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: C.surf3, shape: BoxShape.circle),
                        child: Icon(_iconFor(n.type), size: 18, color: C.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: GoogleFonts.inter(
                              fontSize: 13.5, fontWeight: FontWeight.w700, color: C.txt)),
                          const SizedBox(height: 3),
                          Text(n.body, style: GoogleFonts.inter(fontSize: 12.5, color: C.txt2, height: 1.4)),
                          const SizedBox(height: 6),
                          Text(_formatTimestamp(n.createdAt),
                              style: GoogleFonts.inter(fontSize: 10.5, color: C.muted)),
                        ]),
                      ),
                      if (!n.read)
                        Container(width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle)),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

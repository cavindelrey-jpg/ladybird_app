// lib/pages/notifications_page.dart
// Replaces the ComingSoonPage stub behind the Home bell icon and drawer
// entry. Simple Firestore-backed feed, scoped to the signed-in user.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../widgets/widgets.dart';
import '../models/app_user.dart';
import '../services/notification_router.dart';

import '../widgets/app_background.dart';
class NotificationsPage extends StatelessWidget {
  final AppUser user;
  const NotificationsPage({super.key, required this.user});

  IconData _iconFor(NotificationType t) {
    switch (t) {
      case NotificationType.announcement:     return Icons.campaign_outlined;
      case NotificationType.comment:          return Icons.mode_comment_outlined;
      case NotificationType.reply:            return Icons.reply_outlined;
      case NotificationType.articlePublished: return Icons.auto_stories_outlined;
      case NotificationType.system:           return Icons.info_outline_rounded;
      case NotificationType.homework:         return Icons.menu_book_rounded;
      case NotificationType.dailyProgram:     return Icons.today_rounded;
      case NotificationType.message:          return Icons.chat_bubble_outline_rounded;
      case NotificationType.recommendation:   return Icons.auto_awesome_outlined;
      default:                                return Icons.notifications_none_rounded;
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Notifications', style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
        actions: [
          TextButton(
            onPressed: () => NotificationRepository.instance.markAllRead(user.id),
            child: Text('Mark all read', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: ac.primary)),
          ),
        ],
      ),
      body: AppBackground(child: StreamBuilder<List<AppNotification>>(
        stream: NotificationRepository.instance.watchFeed(user.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError && !snap.hasData) {
            return const EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Can\'t load notifications',
              subtitle: 'Check your connection — they\'ll appear here when you\'re back online.',
            );
          }
          final items = snap.data ?? const <AppNotification>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              subtitle: 'Tomorrow\'s programme, recommendations, comments and replies will show up here.',
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
                onDismissed: (_) => NotificationRepository.instance.delete(user.id, n.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(Rad.md)),
                  child: Icon(Icons.delete_outline_rounded, color: ac.red),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.read ? ac.surf : ac.primaryBg,
                    borderRadius: BorderRadius.circular(Rad.md),
                    border: Border.all(color: ac.bdr),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.md),
                    onTap: () {
                      NotificationRepository.instance.markRead(user.id, n.id);
                      NotificationRouter.open(context, user, n);
                    },
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: ac.surf3, shape: BoxShape.circle),
                        child: Icon(_iconFor(n.type), size: 18, color: ac.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: GoogleFonts.inter(
                              fontSize: 13.5, fontWeight: FontWeight.w700, color: ac.txt)),
                          const SizedBox(height: 3),
                          Text(n.body, maxLines: 4, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2, height: 1.4)),
                          const SizedBox(height: 6),
                          Text(_formatTimestamp(n.createdAt),
                              style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
                        ]),
                      ),
                      if (!n.read)
                        Container(width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(color: ac.gold, shape: BoxShape.circle)),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      )),
    );
  }
}

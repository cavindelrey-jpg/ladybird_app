// lib/features/announcements/announcements_page.dart
// Driven by AnnouncementRepository stream. Teachers/Admins see FAB → ComposeAnnouncementPage.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/announcement_repository.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'compose_announcement_page.dart';
import '../../theme/app_colors.dart';

class AnnouncementsPage extends StatelessWidget {
  final AppUser user;
  final bool canPost;
  const AnnouncementsPage({super.key, required this.user, required this.canPost});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Announcements',
          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: AppBackground(child: StreamBuilder<List<Announcement>>(
        stream: AnnouncementRepository.instance
            .watchAnnouncements(schoolId: user.schoolId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.campaign_outlined, size: 48, color: ac.muted),
                const SizedBox(height: 12),
                Text('No announcements yet',
                  style: GoogleFonts.inter(color: ac.muted, fontSize: 15)),
                if (canPost) ...[
                  const SizedBox(height: 8),
                  Text('Tap + to post the first announcement.',
                    style: GoogleFonts.inter(color: ac.muted, fontSize: 13)),
                ],
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];
              final diff = DateTime.now().difference(a.date);
              final dateStr = diff.inDays == 0
                  ? 'Today'
                  : diff.inDays == 1
                  ? 'Yesterday'
                  : '${diff.inDays}d ago';
              return AnnCard(
                tag: a.tag, title: a.title, body: a.body,
                date: dateStr, accent: a.urgent ? ac.red : ac.navy2,
                urgent: a.urgent, imageUrl: a.imageUrl,
              );
            },
          );
        },
      )),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ComposeAnnouncementPage(user: user))),
              backgroundColor: ac.gold,
              foregroundColor: ac.primary,
              icon: const Icon(Icons.add),
              label: Text('Post Announcement',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

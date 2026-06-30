// lib/features/announcements/announcements_page.dart
// Driven by AnnouncementRepository stream. Teachers/Admins see FAB → ComposeAnnouncementPage.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/announcement_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'compose_announcement_page.dart';

class AnnouncementsPage extends StatelessWidget {
  final AppUser user;
  final bool canPost;
  const AnnouncementsPage({super.key, required this.user, required this.canPost});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Announcements',
          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Announcement>>(
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
                const Icon(Icons.campaign_outlined, size: 48, color: C.muted),
                const SizedBox(height: 12),
                Text('No announcements yet',
                  style: GoogleFonts.inter(color: C.muted, fontSize: 15)),
                if (canPost) ...[
                  const SizedBox(height: 8),
                  Text('Tap + to post the first announcement.',
                    style: GoogleFonts.inter(color: C.muted, fontSize: 13)),
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
                date: dateStr, accent: a.urgent ? C.red : C.navy3,
                urgent: a.urgent,
              );
            },
          );
        },
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ComposeAnnouncementPage(user: user))),
              backgroundColor: C.gold,
              foregroundColor: C.primary,
              icon: const Icon(Icons.add),
              label: Text('Post Announcement',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

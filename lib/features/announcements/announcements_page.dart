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
    return ApplicationShell(
      user: user,
      currentTitle: 'School Announcements',
      subtitle: 'Official broadcasts and school-wide alerts',
      currentDestination: AppNavDestination.announcements,
      contextualPanel: _buildAnnouncementsContextualPanel(context, ac),
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
      child: AppBackground(
        child: StreamBuilder<List<Announcement>>(
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
        ),
      ),
    );
  }

  Widget _buildAnnouncementsContextualPanel(BuildContext context, AppColors ac) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(Icons.campaign_rounded, color: ac.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Broadcast Info',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: ac.txt),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (canPost) ...[
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ComposeAnnouncementPage(user: user)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Channel Guidelines
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Broadcast Policy',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: ac.txt),
              ),
              const SizedBox(height: 8),
              Text(
                'Announcements are visible school-wide to all enrolled students, teachers, and administrators. Urgent notices trigger priority alerts and banner highlights.',
                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Categories
        Text(
          'Notice Categories',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: ac.txt),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _categoryChip(ac, 'Academic', Icons.school_outlined),
            _categoryChip(ac, 'Urgent / Alert', Icons.warning_amber_rounded),
            _categoryChip(ac, 'Administrative', Icons.admin_panel_settings_outlined),
            _categoryChip(ac, 'Events & Sports', Icons.sports_soccer_outlined),
            _categoryChip(ac, 'Health & Safety', Icons.health_and_safety_outlined),
          ],
        ),
      ],
    );
  }

  Widget _categoryChip(AppColors ac, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.bdr),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ac.primary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: ac.txt)),
        ],
      ),
    );
  }
}

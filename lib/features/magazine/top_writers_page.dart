// lib/features/magazine/top_writers_page.dart
// Ranked leaderboard UI over MagazineRepository.topWriters(), which was
// already fully implemented server-round-trip-free — just needed a screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'author_profile_page.dart';

class TopWritersPage extends StatelessWidget {
  const TopWritersPage({super.key});

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:  return C.gold;
      case 2:  return C.muted;
      case 3:  return C.org;
      default: return C.txt2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Top Writers', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: FutureBuilder<List<TopWriterEntry>>(
        future: MagazineRepository.instance.topWriters(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final writers = snap.data ?? const <TopWriterEntry>[];
          if (writers.isEmpty) {
            return const EmptyState(
              icon: Icons.leaderboard_outlined,
              title: 'No ranked writers yet',
              subtitle: 'Publish and get read to appear on the leaderboard.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: writers.length,
            itemBuilder: (context, i) {
              final w = writers[i];
              final rank = i + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ACard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AuthorProfilePage(authorId: w.authorId))),
                  child: Row(children: [
                    SizedBox(
                      width: 28,
                      child: Text('$rank', style: GoogleFonts.sora(
                          fontSize: 16, fontWeight: FontWeight.w800, color: _rankColor(rank))),
                    ),
                    const SizedBox(width: 8),
                    UserAvatar(
                      initials: w.authorName.isEmpty ? '?' : w.authorName[0].toUpperCase(),
                      radius: 18, photoUrl: w.authorPhotoUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(w.authorName, style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: C.txt)),
                        const SizedBox(height: 3),
                        Text('${w.totalReads} reads · ${w.totalComments} comments',
                            style: GoogleFonts.inter(fontSize: 11.5, color: C.txt2)),
                      ]),
                    ),
                    Text(w.score.toStringAsFixed(1), style: GoogleFonts.sora(
                        fontSize: 15, fontWeight: FontWeight.w800, color: C.primary)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

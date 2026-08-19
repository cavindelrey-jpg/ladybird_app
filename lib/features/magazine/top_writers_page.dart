// lib/features/magazine/top_writers_page.dart
// Ranked leaderboard UI over MagazineRepository.topWriters(), which was
// already fully implemented server-round-trip-free — just needed a screen.

import 'package:flutter/material.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'author_profile_page.dart';

class TopWritersPage extends StatelessWidget {
  const TopWritersPage({super.key});

  Color _rankColor(AppColors ac, int rank) {
    switch (rank) {
      case 1:  return ac.gold;
      case 2:  return ac.muted;
      case 3:  return ac.org;
      default: return ac.txt2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Top Writers', style: AppText.title),
      ),
      body: AppBackground(child: FutureBuilder<List<TopWriterEntry>>(
        future: MagazineRepository.instance.topWriters(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _LeaderboardSkeleton();
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
                      child: Text('$rank', style: AppText.h2.copyWith(
                          fontSize: 16, color: _rankColor(ac, rank))),
                    ),
                    const SizedBox(width: 8),
                    UserAvatar(
                      initials: w.authorName.isEmpty ? '?' : w.authorName[0].toUpperCase(),
                      radius: 18, photoUrl: w.authorPhotoUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(w.authorName, style: AppText.title.copyWith(fontSize: 14)),
                        const SizedBox(height: 3),
                        Text('${w.totalReads} reads · ${w.totalComments} comments',
                            style: AppText.bodySm),
                      ]),
                    ),
                    Text(w.score.toStringAsFixed(1), style: AppText.h2.copyWith(
                        fontSize: 15, color: ac.primary)),
                  ]),
                ),
              );
            },
          );
        },
      )),
    );
  }
}

class _LeaderboardSkeleton extends StatelessWidget {
  const _LeaderboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          child: const Row(children: [
            ShimmerCircle(size: 18),
            SizedBox(width: 8),
            ShimmerCircle(size: 36),
            SizedBox(width: 12),
            Expanded(child: ShimmerLine(height: 14)),
          ]),
        ),
      ),
    );
  }
}

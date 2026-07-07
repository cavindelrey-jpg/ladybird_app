// lib/features/magazine/magazine_feed_page.dart
// Substack-style feed for the Academia Magazine. The backend
// (MagazineRepository) was already fully built — this is the missing UI.
//
// Permission note: any signed-in (non-guest) user can write and publish
// their own article. There's no moderation queue yet, so this is an open
// platform rather than a curated one — ranking happens after the fact via
// the Top Writers leaderboard, not via pre-publish review. If Academia's
// "closed intellectual arena" positioning calls for gatekeeping who can
// post at all, tighten `_canCompose` below to `user.canPostAnnouncement`
// (lecturer+) — that's a one-line change, not a rewrite.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'article_reader_page.dart';
import 'article_composer_page.dart';
import 'author_profile_page.dart';
import 'top_writers_page.dart';

class MagazineFeedPage extends StatelessWidget {
  final AppUser? user;
  const MagazineFeedPage({super.key, this.user});

  bool get _canCompose => user != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Academia Magazine', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined, color: C.txt),
            tooltip: 'Top Writers',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TopWritersPage())),
          ),
          if (_canCompose)
            IconButton(
              icon: const Icon(Icons.person_outline_rounded, color: C.txt),
              tooltip: 'Your Articles',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AuthorProfilePage(authorId: user!.id, currentUser: user))),
            ),
        ],
      ),
      floatingActionButton: _canCompose
          ? FloatingActionButton.extended(
              backgroundColor: C.navy,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ArticleComposerPage(user: user!))),
              icon: const Icon(Icons.edit_rounded, color: C.gold),
              label: Text('Write', style: GoogleFonts.sora(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            )
          : null,
      body: StreamBuilder<List<MagazineArticle>>(
        stream: MagazineRepository.instance.watchFeed(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(message: snap.error.toString());
          }
          final articles = snap.data ?? const <MagazineArticle>[];
          if (articles.isEmpty) {
            return EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'No articles yet',
              subtitle: _canCompose
                  ? 'Be the first to write for the Academia Magazine.'
                  : 'Sign in to be the first to write for the Academia Magazine.',
              actionLabel: _canCompose ? 'Write an Article' : null,
              onAction: _canCompose
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArticleComposerPage(user: user!)))
                  : null,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: articles.length,
            itemBuilder: (context, i) => _ArticleCard(
              article: articles[i],
              onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ArticleReaderPage(
                      article: articles[i], currentUser: user))),
              onOpenAuthor: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AuthorProfilePage(
                      authorId: articles[i].authorId, currentUser: user))),
            ),
          );
        },
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final MagazineArticle article;
  final VoidCallback onOpen, onOpenAuthor;
  const _ArticleCard({required this.article, required this.onOpen, required this.onOpenAuthor});

  String _readTime(String body) {
    final words = body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final mins = (words / 200).ceil().clamp(1, 999);
    return '$mins min read';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ACard(
        onTap: onOpen,
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((article.thumbnailUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.md)),
              child: Image.network(article.thumbnailUrl!, height: 160, width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 160, color: C.surf3)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(article.title, style: GoogleFonts.sora(
                  fontSize: 16, fontWeight: FontWeight.w800, color: C.txt),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(article.body.replaceAll('\n', ' '),
                  style: GoogleFonts.inter(fontSize: 13, color: C.txt2, height: 1.5),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Row(children: [
                GestureDetector(
                  onTap: onOpenAuthor,
                  child: Row(children: [
                    UserAvatar(
                      initials: article.authorName.isEmpty ? '?' : article.authorName[0].toUpperCase(),
                      radius: 12, photoUrl: article.authorPhotoUrl,
                    ),
                    const SizedBox(width: 8),
                    Text(article.authorName, style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600, color: C.txt)),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('· ${_readTime(article.body)}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: C.muted)),
                const Spacer(),
                Icon(Icons.visibility_outlined, size: 14, color: C.muted),
                const SizedBox(width: 3),
                Text('${article.readCount}', style: GoogleFonts.inter(fontSize: 11.5, color: C.muted)),
                const SizedBox(width: 10),
                Icon(Icons.mode_comment_outlined, size: 14, color: C.muted),
                const SizedBox(width: 3),
                Text('${article.commentCount}', style: GoogleFonts.inter(fontSize: 11.5, color: C.muted)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

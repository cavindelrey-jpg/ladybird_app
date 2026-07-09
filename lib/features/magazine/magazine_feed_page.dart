// lib/features/magazine/magazine_feed_page.dart
// Substack-style feed for the Academia Magazine. The backend
// (MagazineRepository) was already fully built — this pass is the design
// upgrade: named type scale instead of ad-hoc font sizes, a feed-shaped
// skeleton instead of a bare spinner while the stream connects, and a
// short staggered fade-in on first load instead of everything popping in
// at once.
//
// Permission note: any signed-in (non-guest) user can write and publish
// their own article. There's no moderation queue yet, so this is an open
// platform rather than a curated one — ranking happens after the fact via
// the Top Writers leaderboard, not via pre-publish review. If Academia's
// "closed intellectual arena" positioning calls for gatekeeping who can
// post at all, tighten `_canCompose` below to `user.canPostAnnouncement`
// (lecturer+) — that's a one-line change, not a rewrite.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        title: Text('Academia Magazine', style: AppText.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined, color: C.txt),
            tooltip: 'Top Writers',
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TopWritersPage()));
            },
          ),
          if (_canCompose)
            IconButton(
              icon: const Icon(Icons.person_outline_rounded, color: C.txt),
              tooltip: 'Your Articles',
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AuthorProfilePage(authorId: user!.id, currentUser: user)));
              },
            ),
        ],
      ),
      floatingActionButton: _canCompose
          ? FloatingActionButton.extended(
              backgroundColor: C.navy,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArticleComposerPage(user: user!)));
              },
              icon: const Icon(Icons.edit_rounded, color: C.gold),
              label: Text('Write', style: AppText.button.copyWith(fontSize: 13)),
            )
          : null,
      body: StreamBuilder<List<MagazineArticle>>(
        stream: MagazineRepository.instance.watchFeed(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _FeedSkeleton();
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
            itemBuilder: (context, i) => _StaggeredFadeIn(
              index: i,
              child: _ArticleCard(
                article: articles[i],
                onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArticleReaderPage(
                        article: articles[i], currentUser: user))),
                onOpenAuthor: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AuthorProfilePage(
                        authorId: articles[i].authorId, currentUser: user))),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A short fade + rise-in on first appearance, staggered by list position.
/// Capped so long feeds don't end up with a multi-second cascade — only
/// the first screenful staggers, everything past that fades in together.
class _StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredFadeIn({required this.index, required this.child});

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.06), end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delayMs = widget.index.clamp(0, 6) * 60;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _rise, child: widget.child),
    );
  }
}

/// Feed-shaped skeleton shown while the stream connects — same silhouette
/// as a real article card (thumbnail, title lines, byline row) so the
/// swap to real content doesn't jump around.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          decoration: BoxDecoration(
            color: C.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: C.bdr),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const ShimmerBlock(height: 160, borderRadius: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const ShimmerLine(height: 16),
                const SizedBox(height: 8),
                const ShimmerLine(width: 180, height: 16),
                const SizedBox(height: 14),
                Row(children: [
                  const ShimmerCircle(size: 24),
                  const SizedBox(width: 8),
                  const ShimmerLine(width: 90, height: 12),
                ]),
              ]),
            ),
          ]),
        ),
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
              Text(article.title, style: AppText.h2,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(article.body.replaceAll('\n', ' '),
                  style: AppText.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Row(children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.xs),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onOpenAuthor();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(children: [
                        UserAvatar(
                          initials: article.authorName.isEmpty ? '?' : article.authorName[0].toUpperCase(),
                          radius: 12, photoUrl: article.authorPhotoUrl,
                        ),
                        const SizedBox(width: 8),
                        Text(article.authorName, style: AppText.subtitle.copyWith(color: C.txt)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('· ${_readTime(article.body)}', style: AppText.caption),
                const Spacer(),
                Icon(Icons.visibility_outlined, size: 14, color: C.muted),
                const SizedBox(width: 3),
                Text('${article.readCount}', style: AppText.caption),
                const SizedBox(width: 10),
                Icon(Icons.mode_comment_outlined, size: 14, color: C.muted),
                const SizedBox(width: 3),
                Text('${article.commentCount}', style: AppText.caption),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

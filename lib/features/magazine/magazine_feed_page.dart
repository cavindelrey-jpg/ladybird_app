// lib/features/magazine/magazine_feed_page.dart
// Full Magazine home: header with tagline, 4-tab feed switcher, a
// computed Featured carousel, category-tagged article cards with real
// like/comment counts, and a Write a Post CTA. Navy/gold throughout —
// matches Academia's system rather than a one-off accent for this screen.
//
// Tab semantics (each backed by a real query, nothing faked):
//   For You    — same as Global for now; there's no personalization
//                signal yet, so this is honestly "everything," not a
//                recommendation engine wearing that label.
//   Following  — articles from writers you follow (FollowRepository).
//   Local Feed — articles from writers at your own school. Independent
//                (no-school) users get an explanatory empty state instead
//                of a broken query.
//   Global Feed — every published article, newest first.
//
// "Featured" is computed (most-read in the last 14 days), not manually
// curated — labeling it that way without a human editor picking it would
// be dishonest the same way a fake stat card would be.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../core/constants.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/follow_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/category_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'article_reader_page.dart';
import 'article_composer_page.dart';
import 'author_profile_page.dart';
import 'top_writers_page.dart';
import '../../pages/notifications_page.dart';
import '../../repositories/notification_repository.dart';

enum _FeedTab { forYou, trending, following, local, global }

const _kCategoryColors = CategoryColorMap({
  'Essay':            C.pur,
  'Opinion':          C.blu,
  'Story':            C.grn,
  'Creative Writing': C.gold,
  'News':             C.org,
  'Guide':            C.primary,
  'Interview':        C.red,
  'Review':           C.navy,
});

Color _categoryColor(String cat) => _kCategoryColors.of(cat);

class MagazineFeedPage extends StatefulWidget {
  final AppUser? user;
  const MagazineFeedPage({super.key, this.user});

  @override
  State<MagazineFeedPage> createState() => _MagazineFeedPageState();
}

class _MagazineFeedPageState extends State<MagazineFeedPage> {
  _FeedTab _tab = _FeedTab.forYou;
  String _sort = 'Newest';

  bool get _canCompose => widget.user != null && !widget.user!.isGuest;
  bool get _isGuest => widget.user == null || widget.user!.isGuest;
  bool get _hasSchool => (widget.user?.schoolId ?? '').isNotEmpty;

  Stream<List<MagazineArticle>> _streamForTab() {
    final repo = MagazineRepository.instance;
    switch (_tab) {
      case _FeedTab.forYou:
      case _FeedTab.global:
        return repo.watchFeed();
      case _FeedTab.trending:
        return Stream.fromFuture(repo.watchTrendingOnce(limit: 15));
      case _FeedTab.following:
        if (widget.user == null || widget.user!.isGuest) return Stream.value(const []);
        return FollowRepository.instance.watchFollowingIds(widget.user!.id)
            .asyncExpand((ids) => repo.watchFeedFromAuthors(ids));
      case _FeedTab.local:
        return repo.watchLocalFeed(widget.user?.schoolId ?? '');
    }
  }

  String get _sectionTitle {
    switch (_tab) {
      case _FeedTab.forYou:    return 'Latest Articles';
      case _FeedTab.trending:  return 'Trending Now';
      case _FeedTab.following: return 'New Posts from Your Network';
      case _FeedTab.local:     return 'From Your School';
      case _FeedTab.global:    return 'Latest from Everyone';
    }
  }

  List<MagazineArticle> _applySort(List<MagazineArticle> items) {
    final sorted = List<MagazineArticle>.from(items);
    switch (_sort) {
      case 'Most liked':
        sorted.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
      case 'Most discussed':
        sorted.sort((a, b) => b.commentCount.compareTo(a.commentCount));
        break;
      default:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  void _showSortSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Text('Sort by', style: AppText.title.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          for (final opt in ['Newest', 'Most liked', 'Most discussed'])
            ListTile(
              title: Text(opt, style: AppText.bodySm.copyWith(color: C.txt)),
              trailing: _sort == opt ? const Icon(Icons.check_rounded, color: C.gold) : null,
              onTap: () {
                setState(() => _sort = opt);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: AppBackground(child: SafeArea(
        child: Column(children: [
          _header(context),
          const SizedBox(height: 8),
          _tabRow(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<MagazineArticle>>(
              stream: _streamForTab(),
              builder: (context, snap) {
                if (_tab == _FeedTab.local && !_hasSchool) {
                  return _localFeedEmptyState();
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _FeedSkeleton();
                }
                if (snap.hasError) {
                  return ErrorView(message: snap.error.toString());
                }
                final articles = _tab == _FeedTab.trending
                    ? (snap.data ?? const <MagazineArticle>[]) // already engagement-sorted server-repo-side
                    : _applySort(snap.data ?? const <MagazineArticle>[]);
                if (articles.isEmpty) return _emptyState();

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (_tab == _FeedTab.forYou || _tab == _FeedTab.global)
                      _FeaturedCarousel(user: widget.user),
                    if (_tab == _FeedTab.following && !_isGuest)
                      _FollowingAuthorsSection(userId: widget.user!.id, currentUser: widget.user),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Expanded(child: Text(_sectionTitle, style: AppText.h2.copyWith(fontSize: 16))),
                        Text('See all', style: AppText.subtitle.copyWith(
                            color: C.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    ...articles.map((a) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ArticleListCard(
                        article: a,
                        currentUser: widget.user,
                        onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ArticleReaderPage(article: a, currentUser: widget.user))),
                        onOpenAuthor: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AuthorProfilePage(authorId: a.authorId, currentUser: widget.user))),
                      ),
                    )),
                    if (_tab == _FeedTab.trending && !_isGuest)
                      _PopularInNetworkSection(userId: widget.user!.id, currentUser: widget.user),
                    if (_canCompose) _writeCta(context),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 8),
      child: Row(children: [
        if (canPop)
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: C.txt),
            onPressed: () => Navigator.of(context).pop(),
          )
        else
          const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Academia Magazine', style: AppText.h1.copyWith(fontSize: 20)),
            Text('Write. Share. Inspire.', style: AppText.caption.copyWith(fontSize: 12)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: C.txt2),
          onPressed: () => showToast(context, 'Search is coming soon.'),
        ),
        if (_canCompose)
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined, color: C.txt2),
            tooltip: 'Top Writers',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TopWritersPage())),
          ),
        widget.user == null || widget.user!.isGuest
            ? IconButton(
                icon: const Icon(Icons.notifications_outlined, color: C.txt2),
                onPressed: () => showToast(context, 'Sign in to see notifications'),
              )
            : StreamBuilder<int>(
                stream: NotificationRepository.instance.watchUnreadCount(widget.user!.id),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return Stack(clipBehavior: Clip.none, children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: C.txt2),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => NotificationsPage(userId: widget.user!.id))),
                    ),
                    if (count > 0)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(8)),
                          child: Text(count > 9 ? '9+' : '$count', textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ]);
                },
              ),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _canCompose
                ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AuthorProfilePage(authorId: widget.user!.id, currentUser: widget.user)))
                : null,
            child: UserAvatar(
              initials: (widget.user?.name.isNotEmpty ?? false) ? widget.user!.name[0].toUpperCase() : '?',
              radius: 18, photoUrl: widget.user?.photoUrl,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tabRow() {
    final tabs = [
      (_FeedTab.forYou, 'For You'),
      (_FeedTab.trending, 'Trending'),
      (_FeedTab.following, 'Following'),
      (_FeedTab.local, 'Local Feed'),
      (_FeedTab.global, 'Global Feed'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (tab, label) = tabs[i];
                final active = tab == _tab;
                final needsUser = tab == _FeedTab.following;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (needsUser && (widget.user == null || widget.user!.isGuest)) {
                        showToast(context, 'Sign in to see who you follow');
                        return;
                      }
                      HapticFeedback.selectionClick();
                      setState(() => _tab = tab);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? C.navy : C.surf2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? C.navy : C.bdr),
                      ),
                      child: Text(label, style: AppText.caption.copyWith(
                          fontSize: 12.5, fontWeight: FontWeight.w700,
                          color: active ? C.gold : C.txt2)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: C.surf2,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _showSortSheet,
            child: const Padding(
              padding: EdgeInsets.all(9),
              child: Icon(Icons.tune_rounded, size: 18, color: C.txt2),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _writeCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(Rad.lg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.edit_rounded, color: C.gold, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Share your voice with the world',
                    style: AppText.title.copyWith(fontSize: 13.5),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('Write and publish your ideas today.',
                    style: AppText.caption.copyWith(fontSize: 11.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArticleComposerPage(user: widget.user!)));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: C.navy, foregroundColor: C.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Write a Post', style: AppText.caption.copyWith(
                  fontSize: 12, fontWeight: FontWeight.w700, color: C.gold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _localFeedEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.school_outlined, size: 44, color: C.muted),
          const SizedBox(height: 12),
          Text('No school linked', style: AppText.title.copyWith(fontSize: 15), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text("Local Feed shows articles from your school's writers — "
              'try Global Feed instead.', style: AppText.bodySm, textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    String subtitle;
    switch (_tab) {
      case _FeedTab.trending:  subtitle = 'Nothing trending yet — check back soon.'; break;
      case _FeedTab.following: subtitle = 'Follow a writer to see their articles here.'; break;
      case _FeedTab.local:     subtitle = 'No articles from your school yet.'; break;
      default:                 subtitle = _canCompose
          ? 'Be the first to write for the Academia Magazine.'
          : 'Sign in to be the first to write for the Academia Magazine.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_stories_outlined, size: 44, color: C.muted),
          const SizedBox(height: 12),
          Text('No articles yet', style: AppText.title.copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          Text(subtitle, style: AppText.bodySm, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

/// Computed "Featured" — most-read in the last 14 days, not manual
/// curation. Real signal, honestly labeled.
class _FeaturedCarousel extends StatefulWidget {
  final AppUser? user;
  const _FeaturedCarousel({this.user});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _pageCtrl = PageController();
  int _index = 0;

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MagazineArticle>>(
      future: MagazineRepository.instance.watchFeaturedOnce(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerBlock(height: 220),
          );
        }
        final items = snap.data ?? const <MagazineArticle>[];
        if (items.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 236,
          child: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: items.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FeaturedCard(
                    article: items[i],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ArticleReaderPage(article: items[i], currentUser: widget.user))),
                    onOpenAuthor: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AuthorProfilePage(authorId: items[i].authorId, currentUser: widget.user))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(
              items.length,
              (i) => Container(
                width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: i == _index ? C.gold : C.bdr),
              ),
            )),
          ]),
        );
      },
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final MagazineArticle article;
  final VoidCallback onTap;
  final VoidCallback onOpenAuthor;
  const _FeaturedCard({required this.article, required this.onTap, required this.onOpenAuthor});

  String _excerpt(String body) {
    final clean = body.replaceAll('\n', ' ').trim();
    return clean.length > 110 ? '${clean.substring(0, 110)}…' : clean;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.lg),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [C.navy, C.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(Rad.lg),
            boxShadow: Shad.md,
            image: (article.thumbnailUrl ?? '').isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(article.thumbnailUrl!), fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .45), BlendMode.darken))
                : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(20)),
              child: Text('FEATURED', style: AppText.label.copyWith(fontSize: 9.5, color: C.navy)),
            ),
            const Spacer(),
            Text(article.title, style: AppText.h2.copyWith(color: Colors.white),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(article.description.isNotEmpty ? article.description : _excerpt(article.body),
                style: AppText.bodySm.copyWith(color: Colors.white.withValues(alpha: .8), height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Row(children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.xs),
                  onTap: () { HapticFeedback.selectionClick(); onOpenAuthor(); },
                  child: Row(children: [
                    UserAvatar(initials: article.authorName.isEmpty ? '?' : article.authorName[0].toUpperCase(),
                        radius: 13, photoUrl: article.authorPhotoUrl),
                    const SizedBox(width: 8),
                    Text(article.authorName, style: AppText.subtitle.copyWith(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ),
              Text(' · ${(article.body.split(RegExp(r"\s+")).length / 200).ceil().clamp(1, 999)} min read',
                  style: AppText.caption.copyWith(color: Colors.white60, fontSize: 11)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ArticleListCard extends StatelessWidget {
  final MagazineArticle article;
  final AppUser? currentUser;
  final VoidCallback onOpen, onOpenAuthor;
  const _ArticleListCard({
    required this.article, required this.currentUser,
    required this.onOpen, required this.onOpenAuthor,
  });

  String _readTime(String body) {
    final words = body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return '${(words / 200).ceil().clamp(1, 999)} min read';
  }

  bool get _isOwn => currentUser?.id == article.authorId;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(article.category);
    return ACard(
      onTap: onOpen,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 84, height: 84,
            child: (article.thumbnailUrl ?? '').isNotEmpty
                ? Image.network(article.thumbnailUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: C.surf3))
                : Container(color: color.withValues(alpha: .12),
                    child: Icon(Icons.article_rounded, color: color, size: 26)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: StatusBadge(label: article.category.toUpperCase(), color: color)),
              if (_isOwn)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz_rounded, size: 18, color: C.muted),
                  onSelected: (v) {
                    if (v == 'edit') {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ArticleComposerPage(user: currentUser!, existing: article)));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                  ],
                ),
            ]),
            const SizedBox(height: 4),
            Text(article.title, style: AppText.title.copyWith(fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
                article.description.isNotEmpty
                    ? article.description
                    : article.body.replaceAll('\n', ' '),
                style: AppText.bodySm.copyWith(fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.xs),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onOpenAuthor();
                  },
                  child: Row(children: [
                    UserAvatar(initials: article.authorName.isEmpty ? '?' : article.authorName[0].toUpperCase(),
                        radius: 10, photoUrl: article.authorPhotoUrl),
                    const SizedBox(width: 6),
                    Text(article.authorName, style: AppText.caption.copyWith(fontSize: 11, color: C.txt)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Text('· ${_readTime(article.body)}', style: AppText.caption.copyWith(fontSize: 10.5)),
              const Spacer(),
              _LikeButton(article: article, currentUser: currentUser),
              const SizedBox(width: 10),
              const Icon(Icons.mode_comment_outlined, size: 14, color: C.muted),
              const SizedBox(width: 3),
              Text('${article.commentCount}', style: AppText.caption.copyWith(fontSize: 10.5)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final MagazineArticle article;
  final AppUser? currentUser;
  const _LikeButton({required this.article, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    if (currentUser == null || currentUser!.isGuest) {
      return Row(children: [
        const Icon(Icons.favorite_border_rounded, size: 14, color: C.muted),
        const SizedBox(width: 3),
        Text('${article.likeCount}', style: AppText.caption.copyWith(fontSize: 10.5)),
      ]);
    }
    return StreamBuilder<bool>(
      stream: MagazineRepository.instance.watchIsLiked(article.id, currentUser!.id),
      builder: (context, snap) {
        final liked = snap.data ?? false;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.xs),
            onTap: () {
              HapticFeedback.lightImpact();
              MagazineRepository.instance.toggleLike(article.id, currentUser!.id);
            },
            child: Row(children: [
              Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 14, color: liked ? C.red : C.muted),
              const SizedBox(width: 3),
              Text('${article.likeCount}', style: AppText.caption.copyWith(fontSize: 10.5)),
            ]),
          ),
        );
      },
    );
  }
}

/// The Following tab's author list (mockup's "Following" section) — real
/// followed-author profiles with live follower counts, sitting above the
/// existing article list ("New Posts from Your Network" below it is that
/// same, already-real _streamForTab() data, just relabeled — not a
/// second fabricated data source).
class _FollowingAuthorsSection extends StatelessWidget {
  final String userId;
  final AppUser? currentUser;
  const _FollowingAuthorsSection({required this.userId, required this.currentUser});

  Future<List<AppUser>> _loadAuthors(List<String> ids) async {
    if (ids.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 30) {
      chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
    }
    final users = <AppUser>[];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      users.addAll(snap.docs.map((d) => AppUser.fromFirestore(d.id, d.data())));
    }
    return users;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FollowRepository.instance.watchFollowingIds(userId),
      builder: (context, idsSnap) {
        final ids = idsSnap.data ?? const <String>[];
        if (ids.isEmpty) return const SizedBox.shrink();
        return FutureBuilder<List<AppUser>>(
          future: _loadAuthors(ids),
          builder: (context, snap) {
            final authors = snap.data ?? const <AppUser>[];
            if (authors.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Following', style: AppText.h2.copyWith(fontSize: 16)),
                const SizedBox(height: 12),
                ...authors.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Rad.md),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AuthorProfilePage(authorId: a.id, currentUser: currentUser))),
                      child: Row(children: [
                        UserAvatar(initials: a.name.isEmpty ? '?' : a.name[0].toUpperCase(),
                            radius: 18, photoUrl: a.photoUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.name, style: AppText.title.copyWith(fontSize: 13.5)),
                            StreamBuilder<int>(
                              stream: FollowRepository.instance.watchFollowerCount(a.id),
                              builder: (context, countSnap) => Text('${countSnap.data ?? 0} followers',
                                  style: AppText.caption.copyWith(fontSize: 11)),
                            ),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bdr)),
                          child: Text('Following', style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: C.txt2)),
                        ),
                      ]),
                    ),
                  ),
                )),
              ]),
            );
          },
        );
      },
    );
  }
}

/// The Trending tab's "Popular in Your Network" section — the same
/// engagement-computed pool as the main Trending Now list, filtered down
/// to authors the user actually follows, not a separately invented ranking.
class _PopularInNetworkSection extends StatelessWidget {
  final String userId;
  final AppUser? currentUser;
  const _PopularInNetworkSection({required this.userId, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FollowRepository.instance.watchFollowingIds(userId),
      builder: (context, idsSnap) {
        final ids = (idsSnap.data ?? const <String>[]).toSet();
        if (ids.isEmpty) return const SizedBox.shrink();
        return FutureBuilder<List<MagazineArticle>>(
          future: MagazineRepository.instance.watchTrendingOnce(limit: 40),
          builder: (context, snap) {
            final items = (snap.data ?? const <MagazineArticle>[])
                .where((a) => ids.contains(a.authorId)).take(6).toList();
            if (items.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Popular in Your Network', style: AppText.h2.copyWith(fontSize: 16)),
                ),
                const SizedBox(height: 12),
                ...items.map((a) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _ArticleListCard(
                    article: a, currentUser: currentUser,
                    onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ArticleReaderPage(article: a, currentUser: currentUser))),
                    onOpenAuthor: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AuthorProfilePage(authorId: a.authorId, currentUser: currentUser))),
                  ),
                )),
              ]),
            );
          },
        );
      },
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ShimmerBlock(height: 200),
        const SizedBox(height: 20),
        for (int i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(children: [
              ShimmerBlock(width: 84, height: 84, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ShimmerLine(width: 60, height: 12),
                  SizedBox(height: 8),
                  ShimmerLine(height: 14),
                  SizedBox(height: 6),
                  ShimmerLine(width: 120, height: 12),
                ]),
              ),
            ]),
          ),
      ],
    );
  }
}


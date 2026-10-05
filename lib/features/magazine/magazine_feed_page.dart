// lib/features/magazine/magazine_feed_page.dart
// Full Magazine home: header with tagline, 5-tab feed switcher, a
// computed Featured carousel, category-tagged article cards with real
// like/comment counts, and a Write a Post CTA. Navy/gold throughout —
// matches Academia's system rather than a one-off accent for this screen.
//
// Tab semantics (each backed by a real query, nothing faked):
//   For You    — the same "everything, newest first" feed as Global,
//                PLUS a "Recommended for You" block above it for users
//                who have set favorite subjects (production_plan.md §7B,
//                RecommendationRepository.forMagazine). The underlying
//                list is still honestly everything — the personalized
//                part is the clearly-labeled block, not a silent
//                reordering of the whole feed. Users with no favorite
//                subjects set see exactly what they saw before.
//   Following  — articles from writers you follow (FollowRepository).
//   Local Feed — articles from writers at your own school. Independent
//                (no-school) users get an explanatory empty state instead
//                of a broken query.
//   Global Feed — every published article, newest first.
//
// "Featured" is computed (most-read in the last 14 days), not manually
// curated — labeling it that way without a human editor picking it would
// be dishonest the same way a fake stat card would be.
//
// ── Magazine remake changes ──────────────────────────────────────────────
// - The sort control (Newest / Most liked / Most discussed) silently did
//   nothing on the Trending tab — that tab's data was always shown in its
//   pre-computed engagement order regardless of what the person picked in
//   the sort sheet. _applySort now runs on every tab; "Newest" no longer
//   means "re-sort by createdAt" (which would have clobbered Trending's
//   real ranking the moment sort ran unconditionally) — it means "leave
//   the tab's natural order alone," which already IS newest-first for
//   every other tab's query.
// - Every section's "See all" was either missing or, on the main list,
//   present but wired to nothing (plain Text, no tap handler). Added
//   real destinations: the main list gets _AllArticlesPage, Student
//   Gallery gets _AllGalleryPage, Latest Videos gets _AllVideosPage, and
//   Recommended Clubs reuses the AllClubsPage already built for Clubs'
//   own Discover section.
// - _FollowingAuthorsSection's "Following" pill was a plain Container —
//   no InkWell, no onTap, couldn't actually unfollow from the list. Now
//   a real toggle mirroring author_profile_page.dart's _FollowButton
//   (which already did this correctly — the working pattern just hadn't
//   made it to this second, later-added surface).
// - _RecommendedClubsSection rendered `club.emoji` as a raw character —
//   the exact "random emoji instead of a real club logo" issue already
//   fixed everywhere else in Clubs; this surface just predated/missed
//   that fix. Now uses ClubLogo. It also didn't scope to the viewer's
//   school or exclude clubs they'd already joined — the same
//   "recommends things you can't act on" bug already fixed twice this
//   session in Clubs' own recommendation rails, now fixed a third time
//   here.
// - The header's search icon showed an honest "coming soon" toast. Real,
//   bounded search now backs it (MagazineRepository.searchArticles) —
//   see that method's doc comment for the honest scope of what it
//   actually searches.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../models/magazine_gallery_post.dart';
import '../../models/magazine_video_post.dart';
import '../../models/club.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/follow_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../repositories/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/category_colors.dart';
import '../../theme/club_visuals.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'article_reader_page.dart';
import 'article_composer_page.dart';
import 'author_profile_page.dart';
import 'top_writers_page.dart';
import 'gallery_viewer_page.dart';
import 'magazine_video_player_page.dart';
import '../clubs/clubs_page.dart';
import '../../pages/notifications_page.dart';
import '../../repositories/notification_repository.dart';
import 'magazine_search_page.dart';

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

  /// production_plan.md §7B — "Magazine → recommends relevant Articles".
  /// Same gate as the Library and Courses rails: only offered to a
  /// signed-in user who has actually set favorite subjects, so the
  /// "Recommended for You" label is backed by a real signal.
  bool get _showRecommended =>
      !_isGuest && widget.user!.favoriteSubjects.isNotEmpty;

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

  /// "Newest" deliberately does NOT re-sort by createdAt — every tab's
  /// underlying query is already in its own correct natural order
  /// (createdAt-descending for every feed except Trending, which is in
  /// real engagement order), so "Newest" means "leave that order alone."
  /// Re-sorting unconditionally here previously meant this control did
  /// nothing at all on the Trending tab (the caller special-cased that
  /// tab to skip this method entirely) — now it runs on every tab, and
  /// picking "Most liked"/"Most discussed" actually re-ranks Trending's
  /// results too instead of being silently ignored there.
  List<MagazineArticle> _applySort(List<MagazineArticle> items) {
    switch (_sort) {
      case 'Most liked':
        final sorted = List<MagazineArticle>.from(items);
        sorted.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        return sorted;
      case 'Most discussed':
        final sorted = List<MagazineArticle>.from(items);
        sorted.sort((a, b) => b.commentCount.compareTo(a.commentCount));
        return sorted;
      default:
        return items;
    }
  }

  void _showSortSheet() {
    HapticFeedback.selectionClick();
    final ac = AppColors.of(context);
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
              title: Text(opt, style: AppText.bodySm.copyWith(color: ac.txt)),
              trailing: _sort == opt ? Icon(Icons.check_rounded, color: ac.gold) : null,
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
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
                final articles = _applySort(snap.data ?? const <MagazineArticle>[]);
                if (articles.isEmpty) return _emptyState();

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (_tab == _FeedTab.forYou || _tab == _FeedTab.global)
                      _FeaturedCarousel(user: widget.user),
                    if (_tab == _FeedTab.forYou && _showRecommended)
                      _RecommendedSection(user: widget.user!),
                    if (_tab == _FeedTab.forYou) ...[
                      const SizedBox(height: 20),
                      _StudentGallerySection(user: widget.user),
                      const SizedBox(height: 20),
                      _LatestVideosSection(user: widget.user),
                    ],
                    if (_tab == _FeedTab.trending) ...[
                      const SizedBox(height: 20),
                      _RecommendedClubsSection(user: widget.user),
                    ],
                    if (_tab == _FeedTab.following && !_isGuest)
                      _FollowingAuthorsSection(userId: widget.user!.id, currentUser: widget.user),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Expanded(child: Text(_sectionTitle, style: AppText.h2.copyWith(fontSize: 16))),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(Rad.xs),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => _AllArticlesPage(
                                      title: _sectionTitle, stream: _streamForTab(), user: widget.user)));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: Text('See all', style: AppText.subtitle.copyWith(
                                  color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    ...articles.map((a) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: ArticleListCard(
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
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 8),
      child: Row(children: [
        if (canPop)
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: ac.txt),
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
          icon: Icon(Icons.search_rounded, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MagazineSearchPage(user: widget.user))),
        ),
        if (_canCompose)
          IconButton(
            icon: Icon(Icons.leaderboard_outlined, color: ac.txt2),
            tooltip: 'Top Writers',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TopWritersPage())),
          ),
        widget.user == null || widget.user!.isGuest
            ? IconButton(
                icon: Icon(Icons.notifications_outlined, color: ac.txt2),
                onPressed: () => showToast(context, 'Sign in to see notifications'),
              )
            : StreamBuilder<int>(
                stream: NotificationRepository.instance.watchUnreadCount(widget.user!.id),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return Stack(clipBehavior: Clip.none, children: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined, color: ac.txt2),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => NotificationsPage(user: widget.user!))),
                    ),
                    if (count > 0)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(color: ac.red, borderRadius: BorderRadius.circular(8)),
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
    final ac = AppColors.of(context);
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
                        color: active ? ac.navy : ac.surf2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? ac.navy : ac.bdr),
                      ),
                      child: Text(label, style: AppText.caption.copyWith(
                          fontSize: 12.5, fontWeight: FontWeight.w700,
                          color: active ? ac.gold : ac.txt2)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: ac.surf2,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _showSortSheet,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(Icons.tune_rounded, size: 18, color: ac.txt2),
            ),
          ),
        ),
      ]),
    );
  }


  Widget _localFeedEmptyState() {
    final ac = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.school_outlined, size: 44, color: ac.muted),
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
    final ac = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_stories_outlined, size: 44, color: ac.muted),
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

class ArticleListCard extends StatelessWidget {
  final MagazineArticle article;
  final AppUser? currentUser;
  final VoidCallback onOpen, onOpenAuthor;
  const ArticleListCard({
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
    final ac = AppColors.of(context);
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
                    errorBuilder: (_, __, ___) => Container(color: ac.surf3))
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
                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: ac.muted),
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
                    Text(article.authorName, style: AppText.caption.copyWith(fontSize: 11, color: ac.txt)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Text('· ${_readTime(article.body)}', style: AppText.caption.copyWith(fontSize: 10.5)),
              const Spacer(),
              _LikeButton(article: article, currentUser: currentUser),
              const SizedBox(width: 10),
              Icon(Icons.mode_comment_outlined, size: 14, color: ac.muted),
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
    final ac = AppColors.of(context);
    if (currentUser == null || currentUser!.isGuest) {
      return Row(children: [
        Icon(Icons.favorite_border_rounded, size: 14, color: ac.muted),
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
                  size: 14, color: liked ? ac.red : ac.muted),
              const SizedBox(width: 3),
              Text('${article.likeCount}', style: AppText.caption.copyWith(fontSize: 10.5)),
            ]),
          ),
        );
      },
    );
  }
}

/// production_plan.md §7B — "Magazine → recommends relevant Articles".
/// Favorite-subject-driven picks from RecommendationRepository.forMagazine
/// (real query, real signal), rendered with the same ArticleListCard the
/// rest of the feed uses rather than a bespoke card, so a recommended
/// article looks and behaves identically to any other article.
///
/// Stateful purely to hold the Future: the parent rebuilds on every feed
/// snapshot and on every sort-sheet setState, and an inline Future would
/// re-query Firestore and flash the skeleton each time.
class _RecommendedSection extends StatefulWidget {
  final AppUser user;
  const _RecommendedSection({required this.user});

  @override
  State<_RecommendedSection> createState() => _RecommendedSectionState();
}

class _RecommendedSectionState extends State<_RecommendedSection> {
  late final Future<List<MagazineArticle>> _future =
      RecommendationRepository.instance
          .forMagazine(favoriteSubjects: widget.user.favoriteSubjects);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MagazineArticle>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: ShimmerBlock(height: 96),
          );
        }
        final items = snap.data ?? const <MagazineArticle>[];
        // Hidden entirely when empty rather than shown as an empty state —
        // an empty "Recommended for You" block is worse than no block.
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Recommended for You', style: AppText.h2.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            ...items.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ArticleListCard(
                article: a,
                currentUser: widget.user,
                onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArticleReaderPage(article: a, currentUser: widget.user))),
                onOpenAuthor: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AuthorProfilePage(authorId: a.authorId, currentUser: widget.user))),
              ),
            )),
          ]),
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
    final rows = await Supabase.instance.client.from('users').select().inFilter('id', ids);
    return rows.map(AppUser.fromSupabase).toList();
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
                        _FollowPill(currentUserId: userId, authorId: a.id),
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

/// The compact "Following"/"Follow" pill for a list row — was a static,
/// non-interactive Container before (no InkWell, no onTap: tapping it
/// did nothing, and it always read "Following" regardless of live
/// state). Mirrors author_profile_page.dart's _FollowButton, which
/// already did this correctly on that screen; this is the same real
/// toggle, just sized for a compact list row instead of a profile header.
class _FollowPill extends StatelessWidget {
  final String currentUserId;
  final String authorId;
  const _FollowPill({required this.currentUserId, required this.authorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FollowRepository.instance.watchIsFollowing(currentUserId, authorId),
      builder: (context, snap) {
        final following = snap.data ?? false;
        final ac = AppColors.of(context);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              if (following) {
                FollowRepository.instance.unfollow(currentUserId, authorId);
              } else {
                FollowRepository.instance.follow(currentUserId, authorId);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: following ? ac.surf2 : ac.primary,
                borderRadius: BorderRadius.circular(20),
                border: following ? Border.all(color: ac.bdr) : null,
              ),
              child: Text(following ? 'Following' : 'Follow', style: AppText.caption.copyWith(
                  fontSize: 11, fontWeight: FontWeight.w700, color: following ? ac.txt2 : Colors.white)),
            ),
          ),
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
                  child: ArticleListCard(
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

/// "Student Gallery" — the academia_fix Magazine mockup's photo-post
/// section on the For You tab. Real magazine_gallery/{id} documents,
/// hidden entirely when empty (a fresh install has no photos yet).
class _StudentGallerySection extends StatelessWidget {
  final AppUser? user;
  const _StudentGallerySection({this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<MagazineGalleryPost>>(
      stream: MagazineRepository.instance.watchGalleryPosts(limit: 8),
      builder: (context, snap) {
        final posts = snap.data ?? const <MagazineGalleryPost>[];
        if (posts.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text('Student Gallery', style: AppText.h2.copyWith(fontSize: 16))),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.xs),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _AllGalleryPage(user: user))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text('See all', style: AppText.subtitle.copyWith(
                        color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final post = posts[i];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.sm),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GalleryViewerPage(post: post, currentUser: user))),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Rad.sm),
                        child: Image.network(post.imageUrls.first, width: 90, height: 90, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 90, height: 90, color: ac.surf3)),
                      ),
                      if (post.imageUrls.length > 1)
                        Positioned(
                          right: 4, bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                            child: Text('${post.imageUrls.length} Photos',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

/// "Latest Videos" — the Magazine mockup's video-post section, right
/// after Student Gallery on the For You tab.
class _LatestVideosSection extends StatelessWidget {
  final AppUser? user;
  const _LatestVideosSection({this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<MagazineVideoPost>>(
      stream: MagazineRepository.instance.watchVideoPosts(limit: 8),
      builder: (context, snap) {
        final videos = snap.data ?? const <MagazineVideoPost>[];
        if (videos.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text('Latest Videos', style: AppText.h2.copyWith(fontSize: 16))),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.xs),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _AllVideosPage(user: user))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text('See all', style: AppText.subtitle.copyWith(
                        color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final v = videos[i];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.sm),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MagazineVideoPlayerPage(video: v))),
                    child: SizedBox(
                      width: 150,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(Rad.sm),
                            child: (v.thumbnailUrl ?? '').isNotEmpty
                                ? Image.network(v.thumbnailUrl!, width: 150, height: 90, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 150, height: 90, color: ac.surf3))
                                : Container(width: 150, height: 90, color: ac.surf3,
                                    child: Icon(Icons.videocam_outlined, color: ac.muted)),
                          ),
                          const Positioned.fill(child: Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32))),
                          if (v.durationSeconds > 0)
                            Positioned(
                              right: 4, bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                child: Text(v.durationLabel, style: const TextStyle(color: Colors.white, fontSize: 9)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Text(v.title, style: AppText.title.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${v.authorName} · ${v.viewCount} views', style: AppText.caption.copyWith(fontSize: 10)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

/// "Recommended Podcasts" in the mockup — but the mockup's actual card
/// content (colored icon tile, tagline, "N members") is the same shape
/// as a Club card, not any real podcast/audio feature. There's no audio
/// pipeline anywhere in this codebase and building a fake one just to
/// match a label would be exactly the dishonest-placeholder pattern this
/// project avoids elsewhere — so this section reuses REAL Club data and
/// is honestly labeled "Recommended Clubs" instead of claiming to be
/// podcasts it isn't.
///
/// ── Magazine remake fixes ────────────────────────────────────────────
/// - Used a raw `club.emoji` character instead of ClubLogo — the exact
///   "random emoji instead of a real club logo" issue already fixed
///   everywhere else in Clubs (see theme/club_visuals.dart); this
///   section just predated that fix.
/// - Queried every club on the platform with no school scope and no
///   exclusion of clubs the viewer had already joined — recommending
///   something the person can't act on (they're either not eligible to
///   see it, per Clubs' own school-scoping convention, or have nothing
///   left to do but open a club they're already in). Same bug already
///   fixed twice this session in Clubs' own recommendation rails.
class _RecommendedClubsSection extends StatelessWidget {
  final AppUser? user;
  const _RecommendedClubsSection({this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Club>>(
      stream: ClubRepository.instance.watchClubs(user: user),
      builder: (context, snap) {
        final allClubs = snap.data ?? const <Club>[];
        if (allClubs.isEmpty) return const SizedBox.shrink();
        if (user == null || user!.isGuest) {
          return _section(context, allClubs.take(6).toList(), allClubs);
        }
        return StreamBuilder<List<String>>(
          stream: ClubRepository.instance.watchMyClubIds(user!.id),
          builder: (context, joinedSnap) {
            final joinedIds = (joinedSnap.data ?? const <String>[]).toSet();
            final eligible = allClubs.where((c) => !joinedIds.contains(c.id)).toList();
            if (eligible.isEmpty) return const SizedBox.shrink();
            return _section(context, eligible.take(6).toList(), eligible);
          },
        );
      },
    );
  }

  Widget _section(BuildContext context, List<Club> preview, List<Club> seeAllList) {
    final ac = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: Text('Recommended Groups', style: AppText.h2.copyWith(fontSize: 16))),
          if (seeAllList.length > preview.length)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.xs),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AllClubsPage(clubs: seeAllList, user: user ?? AppUser.guest()))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text('See all', style: AppText.subtitle.copyWith(
                      color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: preview.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final club = preview[i];
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(Rad.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.md),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClubDetailPage(club: club, user: user ?? AppUser.guest()))),
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      ClubLogo(club: club, size: 28, borderRadius: BorderRadius.circular(8)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(club.name, style: AppText.title.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 6),
                    Text(club.description, style: AppText.caption.copyWith(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10, color: ac.muted)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
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

/// "See all" destination for a tab's main article list — was previously
/// a plain, non-interactive Text label. Reuses the exact stream the tab
/// itself uses (so it's honestly "the same list, full screen" rather
/// than promising something more comprehensive) and the same
/// ArticleListCard every other article list in this file uses.
class _AllArticlesPage extends StatelessWidget {
  final String title;
  final Stream<List<MagazineArticle>> stream;
  final AppUser? user;
  const _AllArticlesPage({required this.title, required this.stream, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(title, style: AppText.title),
      ),
      body: AppBackground(child: StreamBuilder<List<MagazineArticle>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _FeedSkeleton();
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final articles = snap.data ?? const <MagazineArticle>[];
          if (articles.isEmpty) {
            return const EmptyState(icon: Icons.auto_stories_outlined, title: 'No articles here yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: articles.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ArticleListCard(
                article: articles[i],
                currentUser: user,
                onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArticleReaderPage(article: articles[i], currentUser: user))),
                onOpenAuthor: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AuthorProfilePage(authorId: articles[i].authorId, currentUser: user))),
              ),
            ),
          );
        },
      )),
    );
  }
}

/// "See all" destination for Student Gallery — a scrollable grid of
/// every post's cover image (same per-post preview the horizontal strip
/// already used), tapping into the same real GalleryViewerPage.
class _AllGalleryPage extends StatelessWidget {
  final AppUser? user;
  const _AllGalleryPage({this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Student Gallery', style: AppText.title),
      ),
      body: AppBackground(child: StreamBuilder<List<MagazineGalleryPost>>(
        stream: MagazineRepository.instance.watchGalleryPosts(limit: 150),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(16), child: ShimmerBlock(height: 400));
          }
          final posts = snap.data ?? const <MagazineGalleryPost>[];
          if (posts.isEmpty) {
            return const EmptyState(icon: Icons.photo_library_outlined, title: 'No photos yet',
                subtitle: 'Be the first to share a photo with the school.');
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: posts.length,
            itemBuilder: (_, i) {
              final post = posts[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.sm),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GalleryViewerPage(post: post, currentUser: user))),
                  child: Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Rad.sm),
                      child: Image.network(post.imageUrls.first, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: ac.surf3)),
                    ),
                    if (post.imageUrls.length > 1)
                      Positioned(
                        right: 4, bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                          child: Text('${post.imageUrls.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ),
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

/// "See all" destination for Latest Videos — a vertical list (thumbnail,
/// title, author, views) instead of the horizontal strip, tapping into
/// the same real MagazineVideoPlayerPage.
class _AllVideosPage extends StatelessWidget {
  final AppUser? user;
  const _AllVideosPage({this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Latest Videos', style: AppText.title),
      ),
      body: AppBackground(child: StreamBuilder<List<MagazineVideoPost>>(
        stream: MagazineRepository.instance.watchVideoPosts(limit: 150),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(16), child: ShimmerBlock(height: 400));
          }
          final videos = snap.data ?? const <MagazineVideoPost>[];
          if (videos.isEmpty) {
            return const EmptyState(icon: Icons.videocam_outlined, title: 'No videos yet',
                subtitle: 'Be the first to share a video with the school.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final v = videos[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.md),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MagazineVideoPlayerPage(video: v))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Rad.sm),
                        child: (v.thumbnailUrl ?? '').isNotEmpty
                            ? Image.network(v.thumbnailUrl!, width: 120, height: 72, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 120, height: 72, color: ac.surf3))
                            : Container(width: 120, height: 72, color: ac.surf3,
                                child: Icon(Icons.videocam_outlined, color: ac.muted)),
                      ),
                      const Positioned.fill(child: Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28))),
                      if (v.durationSeconds > 0)
                        Positioned(
                          right: 4, bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                            child: Text(v.durationLabel, style: const TextStyle(color: Colors.white, fontSize: 9)),
                          ),
                        ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v.title, style: AppText.title.copyWith(fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${v.authorName} · ${v.viewCount} views', style: AppText.caption.copyWith(fontSize: 11)),
                      ]),
                    ),
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


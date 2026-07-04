// lib/features/dashboard/universal_home_page.dart
// The one dashboard layout shared across Guest, Normal, Premium, and
// Student accounts — matches the reference design (greeting block, stat
// card, banner carousel, Quick Access grid, Top Writers/Announcements
// split, Recommended row) but themed to Academia's navy/gold system
// instead of generic purple.
//
// user == null            -> Guest (NPC placeholder, no stats, read-only)
// user.photoUrl == null   -> signed in, no photo -> NPC placeholder, real name
// user.photoUrl != null   -> real avatar
//
// Hero carousel, Quick Access ranking, Top Writers, and Announcements are
// ALL live Firestore data now — no hardcoded rows. Each section renders an
// honest empty state until real content/usage exists.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/hero_slide.dart';
import '../../models/announcement.dart';
import '../../models/magazine_article.dart';
import '../../models/quick_access_feature.dart';
import '../../repositories/hero_slide_repository.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/magazine_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/coming_soon_page.dart';
import '../../pages/marks_page.dart';
import '../library/library_page.dart';
import '../timetable/timetable_page.dart';
import '../assignments/assignments_page.dart';

class UniversalHomePage extends StatefulWidget {
  final AppUser? user;
  const UniversalHomePage({super.key, this.user});

  @override
  State<UniversalHomePage> createState() => _UniversalHomePageState();
}

class _UniversalHomePageState extends State<UniversalHomePage> {
  final _bannerCtrl = PageController();
  int _bannerIndex = 0;

  bool get _isGuest => widget.user == null;
  AppUser? get _u => widget.user;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _topBar(context),
            const SizedBox(height: 18),
            _greetingRow(),
            const SizedBox(height: 20),
            _bannerCarousel(),
            const SizedBox(height: 24),
            _sectionHeader('Quick Access', onViewAll: () {}),
            const SizedBox(height: 12),
            _quickAccessGrid(context),
            const SizedBox(height: 24),
            _upcomingAndAnnouncements(),
            const SizedBox(height: 24),
            _sectionHeader('Recommended for You', onViewAll: () {}),
            const SizedBox(height: 12),
            _recommendedRow(),
          ],
        ),
      ),
    );
  }

  // ── Top bar: menu (drawer), search, notifications ──────────────────────
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Row(children: [
        Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: C.txt),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        const SizedBox(width: 4),
        AcademiaLogo(size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Academia',
                style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: C.txt)),
            Text('Your Complete Smart School Platform',
                style: GoogleFonts.inter(fontSize: 10, color: C.txt2),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: C.txt2),
          onPressed: () {},
        ),
        Stack(clipBehavior: Clip.none, children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: C.txt2),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ComingSoonPage(
                    title: 'Notifications', icon: Icons.notifications_outlined))),
          ),
          if (!_isGuest)
            Positioned(
              top: 8, right: 6,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('3', style: GoogleFonts.sora(
                    fontSize: 9, fontWeight: FontWeight.w800, color: C.navy)),
              ),
            ),
        ]),
      ]),
    );
  }

  // ── Greeting block: avatar + name/status, stat card ─────────────────────
  Widget _greetingRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _avatar(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isGuest ? 'Browsing as' : 'Welcome back,',
                style: GoogleFonts.inter(fontSize: 13, color: C.txt2)),
            Text(_isGuest ? 'Guest' : (_u!.name.isEmpty ? 'Member' : _u!.name),
                style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w800, color: C.txt)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(20)),
              child: Text(_isGuest ? 'Guest' : _u!.roleLabel,
                  style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: C.primary)),
            ),
          ]),
        ),
        if (!_isGuest && _u!.isStudent) _statCard(),
      ]),
    );
  }

  Widget _avatar() {
    if (!_isGuest && (_u!.photoUrl ?? '').isNotEmpty) {
      return CircleAvatar(radius: 32, backgroundImage: NetworkImage(_u!.photoUrl!));
    }
    // NPC placeholder — guest, or signed-in with no profile photo.
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: C.surf3,
        shape: BoxShape.circle,
        border: Border.all(color: C.bdr, width: 1.5),
      ),
      child: Icon(Icons.person_rounded, size: 34, color: C.muted),
    );
  }

  Widget _statCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: C.surf, borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: C.bdr), boxShadow: Shad.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Academic Score', style: GoogleFonts.inter(fontSize: 10, color: C.txt2)),
        const SizedBox(height: 2),
        Row(children: [
          Text('87%', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: C.txt)),
          const SizedBox(width: 4),
          const Icon(Icons.trending_up_rounded, size: 16, color: C.grn),
        ]),
      ]),
    );
  }

  // ── Banner carousel — live Firestore slides, no hardcoded copy ──────────
  Widget _bannerCarousel() {
    return StreamBuilder<List<HeroSlide>>(
      stream: HeroSlideRepository.instance.watchActive(),
      builder: (context, snap) {
        final slides = snap.data ?? const <HeroSlide>[];

        if (slides.isEmpty) {
          // Nothing configured yet. superAdmin gets a nudge to add the
          // first slide via the in-app image manager; everyone else just
          // doesn't see the carousel — no fake placeholder banners.
          if (!_isGuest && _u!.isSuperAdmin) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ComingSoonPage(
                        title: 'Hero Slide Manager',
                        subtitle: 'Add your first Home banner (image + link).',
                        icon: Icons.image_outlined))),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add your first Home banner'),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 190,
          child: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _bannerCtrl,
                onPageChanged: (i) => setState(() => _bannerIndex = i),
                itemCount: slides.length,
                itemBuilder: (_, i) => _bannerCard(slides[i]),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) => Container(
                  width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _bannerIndex ? C.gold : C.bdr,
                  ),
                ))),
          ]),
        );
      },
    );
  }

  Widget _bannerCard(HeroSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GestureDetector(
        onTap: () => _openHeroSlide(slide),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [C.navy, C.navy2],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(Rad.lg),
            boxShadow: Shad.md,
            image: (slide.imageUrl != null && slide.imageUrl!.isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(slide.imageUrl!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: .35), BlendMode.darken),
                  )
                : null,
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(slide.headline, style: GoogleFonts.sora(
                    fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 8),
                Text(slide.subtext, style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withValues(alpha: .75), height: 1.4)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(10)),
                  child: Text(slide.ctaLabel, style: GoogleFonts.sora(
                      fontSize: 12, fontWeight: FontWeight.w700, color: C.navy)),
                ),
              ]),
            ),
            if (slide.imageUrl == null || slide.imageUrl!.isEmpty)
              const Icon(Icons.school_rounded, size: 56, color: Colors.white24),
          ]),
        ),
      ),
    );
  }

  void _openHeroSlide(HeroSlide slide) {
    switch (slide.destination) {
      case HeroDestination.clubs:
        _open(context, const ComingSoonPage(title: 'Clubs', icon: Icons.groups_rounded));
        break;
      case HeroDestination.pastQuestions:
        _open(context, const ComingSoonPage(
            title: 'Past Questions', icon: Icons.description_rounded));
        break;
      case HeroDestination.magazine:
        _open(context, const ComingSoonPage(
            title: 'Magazine', icon: Icons.auto_stories_rounded));
        break;
      case HeroDestination.library:
        _open(context, const _LibraryDest());
        break;
      case HeroDestination.courses:
        _open(context, const ComingSoonPage(title: 'Courses', icon: Icons.school_rounded));
        break;
      case HeroDestination.custom:
        break; // no-op until custom in-app routing is defined
    }
  }

  Widget _sectionHeader(String title, {required VoidCallback onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(children: [
        Expanded(child: Text(title,
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: C.txt))),
        GestureDetector(
          onTap: onViewAll,
          child: Text('View All',
              style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: C.primary)),
        ),
      ]),
    );
  }

  // ── Quick Access grid — exactly 4 tiles, ranked by real tap frequency ───
  // New users (empty usage map) see the QuickAccessRegistry default order:
  // Library, Past Questions, Magazine, Clubs.
  Widget _quickAccessGrid(BuildContext context) {
    final usage = _isGuest ? const <String, int>{} : _u!.quickAccessUsage;
    final top4 = QuickAccessRegistry.topFour(usage);

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: top4.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final feat = top4[i];
          return GestureDetector(
            onTap: () => _openQuickAccess(context, feat),
            child: Container(
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: C.surf, borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: C.bdr),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: feat.bg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(feat.icon, color: feat.fg, size: 19),
                ),
                const SizedBox(height: 8),
                Text(feat.label, textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: C.txt),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _openQuickAccess(BuildContext context, QuickAccessFeature feat) {
    if (!_isGuest) AuthService.instance.recordQuickAccessTap(_u!.id, feat.id);

    switch (feat.id) {
      case 'library':
        _open(context, const _LibraryDest());
        break;
      case 'past_questions':
        _open(context, const ComingSoonPage(
            title: 'Past Questions', icon: Icons.description_rounded));
        break;
      case 'magazine':
        _open(context, const ComingSoonPage(
            title: 'Magazine', icon: Icons.auto_stories_rounded));
        break;
      case 'clubs':
        _open(context, const ComingSoonPage(title: 'Clubs', icon: Icons.groups_rounded));
        break;
      case 'courses':
        _open(context, const ComingSoonPage(title: 'Courses', icon: Icons.school_rounded));
        break;
      case 'lecture_notes':
        _open(context, const ComingSoonPage(
            title: 'Lecture Notes', icon: Icons.sticky_note_2_rounded));
        break;
      case 'assignments':
        _open(context, const _AssignmentsDest());
        break;
      case 'results':
        _open(context, const _MarksDest());
        break;
      case 'timetable':
        _open(context, const _TimetableDest());
        break;
    }
  }

  void _open(BuildContext context, Widget destResolver) {
    // Guests get a read-only nudge instead of pages that require an
    // AppUser (write-capable pages need a real account).
    if (_isGuest) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComingSoonPage(
        title: 'Sign in required',
        subtitle: 'Create a free account to open this section.',
        icon: Icons.lock_outline_rounded,
      )));
      return;
    }
    Widget page;
    if (destResolver is _LibraryDest) {
      page = LibraryPage(user: _u!);
    } else if (destResolver is _AssignmentsDest) {
      page = AssignmentsPage(user: _u!);
    } else if (destResolver is _MarksDest) {
      page = MarksPage(user: _u!);
    } else if (destResolver is _TimetableDest) {
      page = TimetablePage(user: _u!);
    } else {
      page = destResolver;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // ── Top Writers + Announcements split ────────────────────────────────────
  Widget _upcomingAndAnnouncements() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(children: [
        _panelCard(title: 'Top Writers', child: _topWritersPanel()),
        const SizedBox(height: 16),
        _panelCard(title: 'Recent Announcements', child: _announcementsPanel()),
      ]),
    );
  }

  // Ranked by (reads * 0.4) + (comments * 0.6). Empty until real articles
  // exist — no seeded names.
  Widget _topWritersPanel() {
    return FutureBuilder<List<TopWriterEntry>>(
      future: MagazineRepository.instance.topWriters(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final writers = (snap.data ?? const <TopWriterEntry>[]).take(3).toList();
        if (writers.isEmpty) {
          return _emptyPanelRow(
            icon: Icons.auto_stories_outlined,
            text: 'No published articles yet. Be the first to write for the '
                'Academia Magazine.',
          );
        }
        return Column(children: [
          for (var i = 0; i < writers.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: C.bdr2),
            _topWriterRow(rank: i + 1, entry: writers[i]),
          ],
        ]);
      },
    );
  }

  Widget _topWriterRow({required int rank, required TopWriterEntry entry}) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: C.goldp, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text('#$rank', style: GoogleFonts.sora(
            fontSize: 12, fontWeight: FontWeight.w800, color: C.gold)),
      ),
      const SizedBox(width: 12),
      UserAvatar(
        initials: entry.authorName.trim().isEmpty ? '?' : entry.authorName.trim()[0].toUpperCase(),
        photoUrl: entry.authorPhotoUrl,
        radius: 16,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.authorName, style: GoogleFonts.sora(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: C.txt)),
          Text('${entry.totalReads} reads · ${entry.totalComments} comments',
              style: GoogleFonts.inter(fontSize: 11, color: C.txt2)),
        ]),
      ),
    ]);
  }

  // Real Firestore announcements — zero mock rows. Empty state instead.
  Widget _announcementsPanel() {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementRepository.instance.watchAnnouncements(schoolId: _u?.schoolId),
      builder: (context, snap) {
        final items = (snap.data ?? const <Announcement>[]).take(3).toList();
        if (items.isEmpty) {
          return _emptyPanelRow(
            icon: Icons.campaign_outlined,
            text: 'No announcements yet. Magazine posts, paper uploads, and '
                'club news will show up here.',
          );
        }
        return Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _announceRow(
              _iconFor(items[i].sourceType),
              _colorFor(items[i].sourceType),
              _bgFor(items[i].sourceType),
              items[i].title,
              _timeAgo(items[i].date),
            ),
          ],
        ]);
      },
    );
  }

  Widget _emptyPanelRow({required IconData icon, required String text}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: C.surf3, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: C.muted, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, color: C.txt2, height: 1.4)),
      ),
    ]);
  }

  IconData _iconFor(String sourceType) {
    switch (sourceType) {
      case 'magazinePost':      return Icons.auto_stories_rounded;
      case 'paperUpload':       return Icons.description_rounded;
      case 'clubAnnouncement':  return Icons.groups_rounded;
      default:                  return Icons.campaign_rounded;
    }
  }

  Color _colorFor(String sourceType) {
    switch (sourceType) {
      case 'magazinePost':      return C.pur;
      case 'paperUpload':       return C.grn;
      case 'clubAnnouncement':  return C.blu;
      default:                  return C.primary;
    }
  }

  Color _bgFor(String sourceType) {
    switch (sourceType) {
      case 'magazinePost':      return C.purb;
      case 'paperUpload':       return C.grnb;
      case 'clubAnnouncement':  return C.blub;
      default:                  return C.primaryBg;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _panelCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surf, borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: C.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: GoogleFonts.sora(
              fontSize: 14, fontWeight: FontWeight.w800, color: C.txt))),
          Text('View All', style: GoogleFonts.sora(
              fontSize: 11, fontWeight: FontWeight.w700, color: C.primary)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _announceRow(IconData icon, Color fg, Color bg, String text, String time) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: fg, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: GoogleFonts.inter(fontSize: 12.5, color: C.txt, height: 1.35)),
          const SizedBox(height: 3),
          Text(time, style: GoogleFonts.inter(fontSize: 10.5, color: C.muted)),
        ]),
      ),
    ]);
  }

  // ── Recommended row ──────────────────────────────────────────────────────
  Widget _recommendedRow() {
    final items = [
      ('How to Improve Your Study Habits', 'Article · 5 min read', C.primaryBg, Icons.article_rounded, C.primary),
      ('Introduction to Microeconomics', 'Video · 24 min', C.grnb, Icons.play_circle_fill_rounded, C.grn),
      ('African Legal Systems', 'Note · 12 pages', C.goldp, Icons.balance_rounded, C.gold),
      ('Tips for Debate Prep', 'Article · 4 min read', C.purb, Icons.article_rounded, C.pur),
    ];
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final (title, sub, bg, icon, fg) = items[i];
          return Container(
            width: 160,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.md)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.txt)),
              const Spacer(),
              Row(children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Expanded(child: Text(sub, style: GoogleFonts.inter(fontSize: 10, color: C.txt2))),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

// Marker widgets used only to select which real page to build in _open().
class _LibraryDest extends StatelessWidget {
  const _LibraryDest();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class _AssignmentsDest extends StatelessWidget {
  const _AssignmentsDest();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class _MarksDest extends StatelessWidget {
  const _MarksDest();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class _TimetableDest extends StatelessWidget {
  const _TimetableDest();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

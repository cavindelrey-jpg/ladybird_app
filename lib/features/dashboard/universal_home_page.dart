// lib/features/dashboard/universal_home_page.dart
//
// UI layer is Gamma's mockup, kept as close to verbatim as possible:
//   - avatar/name/role + 3 stat pills (streak/XP/courses) + week dots
//   - single big-image "Library" banner with gradient + CTA + dot indicator
//   - Quick Access: 5 fixed icons (Magazine/Clubs/Library/Past Qs/Quizzes)
//   - Today's Progress + Daily Challenge, side by side
//   - Top Writers + Recent Announcements, side by side
//   - Recommended for You, horizontal cards
// Two requested tweaks from the mockup: tighter avatar<->stat-pill gap, and
// stronger card shadow ("glow") than Gamma's default render.
//
// Every number and card below is wired to real data or a real repository.
// Where the underlying feature doesn't exist yet (daily challenge unseeded,
// no reading in progress, no hero slide configured), the section shows an
// honest empty/locked state instead of Gamma's hardcoded placeholders.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/institution_provider.dart';
import '../institution/institution_header_widget.dart';
import '../../models/app_user.dart';
import '../../models/hero_slide.dart';
import '../../models/announcement.dart';
import '../../models/magazine_article.dart';
import '../../models/daily_challenge.dart';
import '../../models/library_item.dart';
import '../../models/academic_content.dart';
import '../../models/course.dart';
import '../../repositories/hero_slide_repository.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/daily_challenge_repository.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/course_repository.dart';
import '../../services/auth_service.dart';
import '../../repositories/xp_repository.dart';
import '../../widgets/widgets.dart';
import '../../pages/daily_challenge_page.dart';
import '../../pages/search_page.dart';
import '../../pages/notifications_page.dart';
import '../library/library_reader_page.dart';
import '../testing/xp_dashboard_page.dart';
import '../testing/tests_subject_picker_page.dart';
import '../academic_content/academic_content_page.dart';
import '../clubs/clubs_page.dart';
import '../magazine/magazine_feed_page.dart';
import '../magazine/top_writers_page.dart';
import '../announcements/announcements_page.dart';
import '../courses_marketplace/courses_marketplace_page.dart';
import '../courses/course_detail_page.dart';
import '../admin/hero_slide_manager_page.dart';

/// Local, slightly stronger "glow" shadow for this page's cards -- Gamma's
/// own render used a near-invisible shadow (alpha .02-.03); the mockup
/// wants it more present, without touching the app-wide Shad tokens.
const List<BoxShadow> _glow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 6)),
];

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
  void initState() {
    super.initState();
    if (!_isGuest) {
      // Fire-and-forget: decides streak continue/reset/no-op from the
      // user's own last-active date. Never blocks the first frame.
      AuthService.instance.recordDailyActivity(_u!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _topBar(context),
            const SizedBox(height: 16),
            _greetingAndStats(),
            const SizedBox(height: 20),
            _libraryBanner(context),
            const SizedBox(height: 24),
            _sectionHeader('Quick Access'),
            const SizedBox(height: 12),
            _quickAccessRow(context),
            const SizedBox(height: 20),
            _progressAndChallengeRow(context),
            const SizedBox(height: 20),
            _writersAndAnnouncementsRow(context),
            const SizedBox(height: 24),
            _sectionHeader('Recommended for You',
                onViewAll: () => _open(context, AcademicContentPage(user: _u ?? AppUser.guest()))),
            const SizedBox(height: 12),
            _recommendedRow(context),
          ],
        ),
      ),
    );
  }

  // -- Top bar --------------------------------------------------------
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(children: [
        Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: C.txt),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        const SizedBox(width: 4),
        Expanded(child: _brandingBlock(context)),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: C.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SearchPage(user: _u ?? AppUser.guest()))),
        ),
        Stack(clipBehavior: Clip.none, children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: C.txt2),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationsPage(userId: _u?.id ?? ''))),
          ),
          if (!_isGuest)
            Positioned(top: 8, right: 6, child: Container(
              width: 9, height: 9,
              decoration: const BoxDecoration(color: C.red, shape: BoxShape.circle),
            )),
        ]),
      ]),
    );
  }

  // -- Branding: this is THE spot that makes the app "become" a school's
  // own app. Previously this row hardcoded the Academia name + logo no
  // matter who was signed in — so a St. Michael student and a guest saw
  // literally the same header. Now it watches InstitutionProvider: once an
  // institution is actively loaded (i.e. the signed-in account is linked
  // to a school via a claimed serial number), the school's own logo, name,
  // and "Powered by Academia" subline render here instead. Independent /
  // guest accounts keep the plain Academia identity.
  Widget _brandingBlock(BuildContext context) {
    final instProv = context.watch<InstitutionProvider>();
    if (instProv.isLoaded) {
      return const InstitutionHeader(compact: true);
    }
    return Row(children: [
      const AcademiaLogo(size: 34),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Academia', style: GoogleFonts.sora(
              fontSize: 17, fontWeight: FontWeight.w800, color: C.txt)),
          Text('Your Complete Smart School Platform',
              style: GoogleFonts.inter(fontSize: 10, color: C.txt2),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }

  // -- Greeting + Stats + Week dots ------------------------------------
  // Tweak #1: avatar column is a fixed width (not Expanded flex:2), with a
  // small explicit gap before the stats column -- tighter than Gamma's
  // flex-driven spacing.
  Widget _greetingAndStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Left portion (~39% of row, per your spec: avatar 135px + name
        // block 215px out of 945px total) -- avatar and name SIDE BY SIDE,
        // both vertically centered together. Previously these were
        // stacked (avatar on top, name below) -- that was the actual bug.
        Expanded(
          flex: 39,
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _avatar(),
            const SizedBox(width: 8),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_isGuest ? 'Browsing as' : 'Welcome back,',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12.5, color: C.txt2)),
                Text(_isGuest ? 'Guest' : (_u!.name.isEmpty ? 'Member' : _u!.name),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 16.5, fontWeight: FontWeight.w800, color: C.txt)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(_isGuest ? 'Guest' : _u!.roleLabel,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: C.primary)),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        // Right portion (~53% of row, per spec: 505px of 945px) -- merged
        // stat card, week dots directly beneath it.
        Expanded(
          flex: 53,
          child: Column(children: [
            _statCard(),
            const SizedBox(height: 10),
            _weekDots(),
          ]),
        ),
      ]),
    );
  }

  Widget _avatar() {
    if (!_isGuest && (_u!.photoUrl ?? '').isNotEmpty) {
      return CircleAvatar(radius: 30, backgroundImage: NetworkImage(_u!.photoUrl!));
    }
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: C.surf3, shape: BoxShape.circle,
        border: Border.all(color: C.bdr, width: 1.5),
      ),
      child: const Icon(Icons.person_rounded, size: 32, color: C.muted),
    );
  }

  /// One merged card, three segments split by thin dividers -- matches
  /// your spec sheet's "Stats card (whole white card)" instead of three
  /// separate floating pills.
  Widget _statCard() {
    // XP is read live from XpRepository's real ledger (lifetimeXP) —
    // AppUser.xpTotal is now deprecated (see xp_transaction.dart's file
    // comment) and would just show a stale, disconnected number here.
    return StreamBuilder<(int, int)>(
      stream: _isGuest
          ? const Stream<(int, int)>.empty()
          : XpRepository.instance.watchBalance(_u!.id),
      builder: (context, snap) {
        final lifetimeXp = _isGuest ? 0 : (snap.data?.$2 ?? 0);
        final segments = [
          (Icons.local_fire_department_rounded, C.org, _isGuest ? '0' : '${_u!.streakDays}', 'Day Streak'),
          (Icons.star_rounded, C.gold, '$lifetimeXp', 'XP Points'),
          (Icons.menu_book_rounded, C.pur, _isGuest ? '0' : '${_u!.courseIds.length}', 'Courses'),
        ];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isGuest ? null : () => _open(context, XpDashboardPage(user: _u!)),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                  color: C.surf, borderRadius: BorderRadius.circular(16), boxShadow: _glow),
              child: Row(children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) Container(width: 1, height: 36, color: C.bdr2),
                  Expanded(child: _statSegment(segments[i])),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _statSegment((IconData, Color, String, String) segment) {
    final (icon, color, value, label) = segment;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 5),
        Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(fontSize: 14.5, fontWeight: FontWeight.w800, color: C.txt)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 8.5, color: C.txt2)),
          ]),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right_rounded, size: 13, color: C.muted),
      ]),
    );
  }

  /// Real week dots -- driven by AppUser.weekActivityDates, not fabricated.
  Widget _weekDots() {
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final activity = _isGuest ? const <String>{} : _u!.weekActivityDates.toSet();
    final todayIdx = now.weekday - 1;

    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final key = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final done = activity.contains(key);
      final isToday = i == todayIdx;
      return Column(children: [
        done
            ? const Icon(Icons.check_circle_rounded, color: C.gold, size: 19)
            : Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: isToday ? C.bdr : C.bdr2, shape: BoxShape.circle),
              ),
        const SizedBox(height: 3),
        Text(labels[i], style: GoogleFonts.inter(fontSize: 10, color: C.txt2)),
      ]);
    }));
  }

  // -- Library banner -- real, swipeable, admin-editable ---------------
  Widget _libraryBanner(BuildContext context) {
    return StreamBuilder<List<HeroSlide>>(
      stream: HeroSlideRepository.instance.watchActive(),
      builder: (context, snap) {
        final slides = snap.data ?? const <HeroSlide>[];
        if (slides.isEmpty) {
          if (!_isGuest && _u!.isSuperAdmin) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HeroSlideManagerPage(createdByUid: _u!.id))),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add your first Home banner'),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 176,
          child: PageView.builder(
            controller: _bannerCtrl,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemCount: slides.length,
            itemBuilder: (_, i) => _bannerCard(context, slides[i], slides.length),
          ),
        );
      },
    );
  }

  Widget _bannerCard(BuildContext context, HeroSlide slide, int totalSlides) {
    final radius = BorderRadius.circular(Rad.xl);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: C.navy,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _openHeroSlide(context, slide);
          },
          child: Ink(
            height: 160,
            decoration: BoxDecoration(
              image: (slide.imageUrl != null && slide.imageUrl!.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(slide.imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xD1000000), Colors.transparent],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(slide.headline, style: GoogleFonts.sora(
                    fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text(slide.subtext, style: GoogleFonts.inter(
                    fontSize: 12.5, color: Colors.white70, height: 1.3)),
                if (slide.statLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.workspace_premium_outlined, color: Colors.white60, size: 15),
                    const SizedBox(width: 6),
                    Text(slide.statLine,
                        style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white)),
                  ]),
                ],
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(slide.ctaLabel, style: GoogleFonts.sora(
                          fontSize: 12, fontWeight: FontWeight.w700, color: C.navy)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: C.navy),
                    ]),
                  ),
                  if (totalSlides > 1)
                    Row(children: List.generate(totalSlides, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: i == _bannerIndex ? C.gold : Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    ))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _openHeroSlide(BuildContext context, HeroSlide slide) {
    final user = _u ?? AppUser.guest();
    switch (slide.destination) {
      case HeroDestination.library:
        _open(context, AcademicContentPage(user: user));
        break;
      case HeroDestination.clubs:
        _open(context, ClubsPage(user: user));
        break;
      case HeroDestination.pastQuestions:
        _open(context, AcademicContentPage(
            user: user, initialTypeFilter: ContentType.pastPaper));
        break;
      case HeroDestination.magazine:
        _open(context, MagazineFeedPage(user: user));
        break;
      case HeroDestination.courses:
        _open(context, CoursesMarketplacePage(user: user));
        break;
      case HeroDestination.custom:
        break;
    }
  }

  Widget _sectionHeader(String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: C.txt)),
        if (onViewAll != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.xs),
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('View All', style: GoogleFonts.sora(
                    fontSize: 13, fontWeight: FontWeight.w700, color: C.primary)),
              ),
            ),
          ),
      ]),
    );
  }

  // -- Quick Access -- fixed 5, per your call (no "New" badge) ----------
  Widget _quickAccessRow(BuildContext context) {
    final items = <(String, IconData, Color)>[
      ('Magazine', Icons.menu_book_rounded, C.pur),
      ('Clubs', Icons.groups_rounded, C.gold),
      ('Library', Icons.import_contacts_rounded, C.primary),
      ('Past Questions', Icons.description_rounded, C.grn),
      ('Quizzes', Icons.assignment_rounded, C.org),
    ];
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final (label, icon, color) = items[i];
          final radius = BorderRadius.circular(Rad.md);
          return Material(
            color: C.surf,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: () {
                HapticFeedback.selectionClick();
                _openQuickAccess(context, label);
              },
              child: Container(
                width: 80,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(borderRadius: radius, boxShadow: _glow),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: C.txt)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openQuickAccess(BuildContext context, String label) {
    final user = _u ?? AppUser.guest();
    switch (label) {
      case 'Magazine':
        _open(context, MagazineFeedPage(user: user));
        break;
      case 'Clubs':
        _open(context, ClubsPage(user: user));
        break;
      case 'Library':
        _open(context, AcademicContentPage(user: user));
        break;
      case 'Past Questions':
        _open(context, AcademicContentPage(
            user: user, initialTypeFilter: ContentType.pastPaper));
        break;
      case 'Quizzes':
        _open(context, TestsSubjectPickerPage(user: user));
        break;
    }
  }

  void _open(BuildContext context, Widget page) {
    // Guests browse read-only content freely — only actions that WRITE
    // data (liking, commenting, bookmarking, the Daily Challenge) ask for
    // sign-in, and those already do it inline where the action happens
    // rather than blocking navigation here.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // -- Today's Progress + Daily Challenge --------------------------------
  Widget _progressAndChallengeRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _progressCard(context)),
          const SizedBox(width: 12),
          Expanded(child: _challengeCard(context)),
        ]),
      ),
    );
  }

  Widget _progressCard(BuildContext context) {
    final hasReading = !_isGuest && (_u!.continueReadingItemId != null);
    final total = _isGuest ? null : _u!.continueReadingTotalPages;
    final page = _isGuest ? 0 : _u!.continueReadingPage;
    final pct = (hasReading && total != null && total > 0) ? page / total : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.surf, borderRadius: BorderRadius.circular(Rad.md), boxShadow: _glow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.show_chart_rounded, size: 15, color: C.primary),
          const SizedBox(width: 4),
          Expanded(child: Text("Today's Progress", style: GoogleFonts.sora(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: C.txt))),
          if (pct != null)
            Text('${(pct * 100).round()}%', style: GoogleFonts.sora(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: C.txt)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct ?? 0,
            backgroundColor: C.bdr2,
            valueColor: const AlwaysStoppedAnimation(C.primary),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 14),
        if (hasReading)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.xs),
              onTap: () {
                HapticFeedback.lightImpact();
                _reopenContinueReading(context);
              },
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.menu_book_rounded, color: C.primary, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Continue Reading', style: GoogleFonts.inter(fontSize: 9.5, color: C.primary)),
                    Text(_u!.continueReadingTitle ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.txt)),
                    Text(total != null ? 'Page $page of $total' : 'Page $page',
                        style: GoogleFonts.inter(fontSize: 9.5, color: C.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: C.muted, size: 16),
              ]),
            ),
          )
        else
          Text('No reading in progress -- open something from the Library to start.',
              style: GoogleFonts.inter(fontSize: 10.5, color: C.muted, height: 1.3)),
      ]),
    );
  }

  Future<void> _reopenContinueReading(BuildContext context) async {
    if (_isGuest || _u!.continueReadingItemId == null) return;
    final items = await LibraryRepository.instance.recent(schoolId: _u!.schoolId, limit: 60);
    LibraryItem? match;
    for (final it in items) {
      if (it.id == _u!.continueReadingItemId) { match = it; break; }
    }
    match ??= LibraryItem(
      id: _u!.continueReadingItemId!, title: _u!.continueReadingTitle ?? 'Untitled',
      author: '', subject: '', size: '', views: 0, type: ContentType.note,
      totalPages: _u!.continueReadingTotalPages,
    );
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LibraryReaderPage(user: _u!, item: match!)));
  }

  Widget _challengeCard(BuildContext context) {
    if (_isGuest) {
      return _lockedChallengeCard(
          message: 'Sign in to take today\'s challenge.');
    }
    return FutureBuilder<DailyChallenge?>(
      future: DailyChallengeRepository.instance.getToday(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _challengeShell(child: const Center(child: SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))));
        }
        final challenge = snap.data;
        if (challenge == null) {
          return _lockedChallengeCard(message: 'No challenge today -- check back soon.');
        }
        return FutureBuilder<bool>(
          future: DailyChallengeRepository.instance.hasAttempted(challenge.dateKey, _u!.id),
          builder: (context, attemptedSnap) {
            final attempted = attemptedSnap.data ?? false;
            return _challengeShell(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.local_fire_department_rounded, color: C.org, size: 15),
                  const SizedBox(width: 4),
                  Text('Daily Challenge', style: GoogleFonts.sora(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: C.pur)),
                ]),
                const SizedBox(height: 8),
                Text(challenge.title, style: GoogleFonts.sora(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: C.txt)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.assignment_rounded, size: 12, color: C.pur),
                  const SizedBox(width: 4),
                  Text('${challenge.questions.length} Questions',
                      style: GoogleFonts.inter(fontSize: 10, color: C.pur)),
                  const SizedBox(width: 8),
                  const Icon(Icons.star_rounded, size: 12, color: C.gold),
                  const SizedBox(width: 2),
                  Text('+${challenge.xpPerCorrect * challenge.questions.length} XP',
                      style: GoogleFonts.inter(fontSize: 10, color: C.txt2)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: attempted ? null : () async {
                      final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
                          builder: (_) => DailyChallengePage(user: _u!, challenge: challenge)));
                      if (done == true && mounted) setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: attempted ? C.bdr : C.pur,
                      foregroundColor: attempted ? C.txt2 : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (attempted) ...[
                        const Icon(Icons.check_circle_rounded, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Text(attempted ? 'Completed' : 'Start Challenge',
                          style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700)),
                      if (!attempted) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ]),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _challengeShell({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [C.purb, Color(0xFFEDE4FF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(Rad.md),
        ),
        child: child,
      );

  Widget _lockedChallengeCard({required String message}) => _challengeShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: C.org, size: 15),
            const SizedBox(width: 4),
            Text('Daily Challenge', style: GoogleFonts.sora(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: C.pur)),
          ]),
          const SizedBox(height: 10),
          Text(message, style: GoogleFonts.inter(fontSize: 11, color: C.txt2, height: 1.3)),
        ]),
      );

  // -- Top Writers + Recent Announcements --------------------------------
  Widget _writersAndAnnouncementsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _panel(
              title: 'Top Writers',
              onTap: () => _open(context, const TopWritersPage()),
              child: _topWritersContent())),
          const SizedBox(width: 12),
          Expanded(child: _panel(
              title: 'Recent Announcements',
              onTap: () => _open(context, AnnouncementsPage(
                  user: _u ?? AppUser.guest(),
                  canPost: !_isGuest && _u!.canPostAnnouncement)),
              child: _announcementsContent())),
        ]),
      ),
    );
  }

  Widget _panel({required String title, required Widget child, VoidCallback? onTap}) {
    final radius = BorderRadius.circular(Rad.md);
    final inner = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title, style: GoogleFonts.sora(
            fontSize: 12.5, fontWeight: FontWeight.w800, color: C.txt))),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded, size: 16, color: C.muted),
      ]),
      const SizedBox(height: 14),
      child,
    ]);
    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.surf, borderRadius: radius, boxShadow: _glow),
        child: inner,
      );
    }
    return Material(
      color: C.surf,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: radius, boxShadow: _glow),
          child: inner,
        ),
      ),
    );
  }

  Widget _topWritersContent() {
    return FutureBuilder<List<TopWriterEntry>>(
      future: MagazineRepository.instance.topWriters(),
      builder: (context, snap) {
        final writers = (snap.data ?? const <TopWriterEntry>[]);
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (writers.isEmpty) {
          return Text('No published articles yet.',
              style: GoogleFonts.inter(fontSize: 10.5, color: C.muted, height: 1.3));
        }
        final top = writers.first;
        return Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: C.goldp, shape: BoxShape.circle),
            child: Text('#1', style: GoogleFonts.sora(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: C.gold)),
          ),
          const SizedBox(width: 8),
          UserAvatar(
            initials: top.authorName.trim().isEmpty ? '?' : top.authorName.trim()[0].toUpperCase(),
            photoUrl: top.authorPhotoUrl, radius: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(top.authorName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: C.txt)),
              Text('${top.totalReads} reads . ${top.totalComments} comments',
                  style: GoogleFonts.inter(fontSize: 9, color: C.muted)),
            ]),
          ),
          const Icon(Icons.emoji_events_rounded, color: C.gold, size: 16),
        ]);
      },
    );
  }

  Widget _announcementsContent() {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementRepository.instance.watchAnnouncements(schoolId: _u?.schoolId),
      builder: (context, snap) {
        final items = (snap.data ?? const <Announcement>[]);
        if (items.isEmpty) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: C.primaryBg, shape: BoxShape.circle),
              child: const Icon(Icons.campaign_rounded, color: C.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
                'No announcements yet. Magazine posts, paper uploads, and club '
                'news will show up here.',
                style: GoogleFonts.inter(fontSize: 9, color: C.muted, height: 1.3))),
          ]);
        }
        final a = items.first;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: C.primaryBg, shape: BoxShape.circle),
            child: const Icon(Icons.campaign_rounded, color: C.primary, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10.5, color: C.txt, height: 1.3)),
              const SizedBox(height: 3),
              Text(_timeAgo(a.date), style: GoogleFonts.inter(fontSize: 9, color: C.muted)),
            ]),
          ),
        ]);
      },
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  // -- Recommended for You -- mix of Library + Courses --------------------
  Widget _recommendedRow(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: _loadRecommended(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 140,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Nothing to recommend yet -- Library and Courses are still empty.',
                style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
          );
        }
        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final it = items[i];
              if (it is LibraryItem) return _recommendedLibraryCard(context, it);
              if (it is Course) return _recommendedCourseCard(context, it);
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Future<List<Object>> _loadRecommended() async {
    final libraryItems = await LibraryRepository.instance.recent(schoolId: _u?.schoolId, limit: 4);
    List<Course> courses = [];
    if (!_isGuest && _u!.schoolId != null) {
      try {
        courses = await CourseRepository.instance.watchAll(_u!.schoolId!).first
            .timeout(const Duration(seconds: 3));
        courses = courses.take(4).toList();
      } catch (_) {
        courses = [];
      }
    }
    return [...libraryItems, ...courses];
  }

  Widget _recommendedLibraryCard(BuildContext context, LibraryItem item) {
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: C.purb,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.selectionClick();
          _open(context, AcademicContentPage(user: _u ?? AppUser.guest()));
        },
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.description_rounded, size: 12, color: C.pur),
              const SizedBox(width: 4),
              Text(item.type.name, style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: C.pur)),
            ]),
            const SizedBox(height: 8),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(item.size, style: GoogleFonts.inter(fontSize: 10, color: C.txt2))),
              const Icon(Icons.bookmark_outline_rounded, size: 16, color: C.pur),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _recommendedCourseCard(BuildContext context, Course course) {
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: C.blub,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.selectionClick();
          _open(context, CourseDetailPage(course: course, user: _u ?? AppUser.guest()));
        },
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.school_rounded, size: 12, color: C.blu),
              const SizedBox(width: 4),
              Text('Course', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: C.blu)),
            ]),
            const SizedBox(height: 8),
            Text(course.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
            const Spacer(),
            Text(course.code, style: GoogleFonts.inter(fontSize: 10, color: C.txt2)),
          ]),
        ),
      ),
    );
  }
}


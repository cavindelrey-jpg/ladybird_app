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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../config/branding.dart';
import '../../providers/institution_provider.dart';
import '../institution/institution_header_widget.dart';
import '../../models/app_user.dart';
import '../../models/hero_slide.dart';
import '../../models/announcement.dart';
import '../../models/magazine_article.dart';
import '../../models/daily_challenge.dart';
import '../../models/academic_content.dart';
import '../../models/course.dart';
import '../../models/personal_study_slot.dart';
import '../../models/timetable_slot.dart';
import '../../repositories/personal_study_repository.dart';
import '../../repositories/timetable_repository.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/daily_challenge_repository.dart';
import '../../repositories/academic_content_repository.dart';
import '../../repositories/test_repository.dart';
import '../../repositories/course_repository.dart';
import '../../services/auth_service.dart';
import '../../repositories/xp_repository.dart';
import '../../widgets/widgets.dart';
import '../../widgets/hero_banner_carousel.dart';
import '../../pages/daily_challenge_page.dart';
import '../../pages/search_page.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import '../academic_content/content_viewer_page.dart';
import '../academic_content/content_details_page.dart';
import '../testing/xp_dashboard_page.dart';
import '../testing/tests_subject_picker_page.dart';
import '../academic_content/academic_content_page.dart';
import '../clubs/clubs_page.dart';
import '../magazine/magazine_feed_page.dart';
import '../magazine/top_writers_page.dart';
import '../announcements/announcements_page.dart';
import '../courses/course_detail_page.dart';

/// Local, slightly stronger "glow" shadow for this page's cards -- Gamma's
/// own render used a near-invisible shadow (alpha .02-.03); the mockup
/// wants it more present, without touching the app-wide Shad tokens.
const List<BoxShadow> _glow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 6)),
];

// ── Home's own "Recommended for You" ranking helpers ───────────────────
// Pure, top-level, unit-tested (test/home_recommendation_ranking_test.dart)
// -- deliberately independent copies of the same *shape* of logic
// RecommendationRepository.rankSubjectsByUsage uses for §7B's contextual
// recommendations, not a shared call into that class. production_plan.md
// §1 is explicit that "the homepage's 'Recommended for You' system must
// remain separate from contextual recommendations used elsewhere in the
// application" -- these functions are what keeps the two computations able
// to evolve independently while still reading the same underlying real
// signals (favorite subjects, quiz-completion usage counts, course
// enrollment).

/// Reorders [favoriteSubjects] by descending completion count in [usage] --
/// the subject a student actually completes quizzes in most often outranks
/// one they only starred. Ties (most commonly: no usage data yet, all
/// zero) keep their ORIGINAL relative order via an explicit index
/// tie-break, since Dart's `List.sort` is not guaranteed stable -- this is
/// what makes "no usage data" a true no-op.
List<String> rankHomeSubjectsByUsage(
  List<String> favoriteSubjects,
  Map<String, int> usage,
) {
  final indexed = favoriteSubjects.asMap().entries.toList()
    ..sort((a, b) {
      final byUsage = (usage[b.value] ?? 0).compareTo(usage[a.value] ?? 0);
      if (byUsage != 0) return byUsage;
      return a.key.compareTo(b.key);
    });
  return indexed.map((e) => e.value).toList();
}

/// Stable partition of [courses] into ones the student is enrolled in
/// ([enrolledCourseIds]) first, then the rest -- the real "Courses
/// accessed" signal. Both halves keep their original relative order (a
/// partition, not a sort), so this doesn't disturb whatever order the
/// caller's query already returned (typically alphabetical by name, from
/// CourseRepository.watchAll).
List<Course> rankHomeCoursesByEnrollment(
  List<Course> courses,
  Set<String> enrolledCourseIds,
) {
  final enrolled = <Course>[];
  final other = <Course>[];
  for (final c in courses) {
    (enrolledCourseIds.contains(c.id) ? enrolled : other).add(c);
  }
  return [...enrolled, ...other];
}

class UniversalHomePage extends StatefulWidget {
  final AppUser? user;
  const UniversalHomePage({super.key, this.user});

  @override
  State<UniversalHomePage> createState() => _UniversalHomePageState();
}

class _UniversalHomePageState extends State<UniversalHomePage> {
  bool get _isGuest => widget.user == null;
  AppUser? get _u => widget.user;

  // Dark-mode-aware color tokens — every color reference in this file
  // reads from here instead of the static `C.xxx` constants, so this
  // screen actually responds to the theme toggle instead of staying
  // hardcoded light like the rest of the app currently does.
  AppColors get ac => AppColors.of(context);

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
      color: ac.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _topBar(context),
            const SizedBox(height: 16),
            _greetingAndStats(),
            const SizedBox(height: 20),
            HeroBannerCarousel(placement: HeroPlacement.home, user: widget.user),
            const SizedBox(height: 24),
            _sectionHeader('Quick Access'),
            const SizedBox(height: 12),
            _quickAccessRow(context),
            const SizedBox(height: 20),
            _progressAndChallengeRow(context),
            const SizedBox(height: 20),
            if (!_isGuest) ...[
              _todaysStudyProgram(context),
              const SizedBox(height: 20),
            ],
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
          icon: Icon(Icons.menu_rounded, color: ac.txt),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        const SizedBox(width: 4),
        Expanded(child: _brandingBlock(context)),
        IconButton(
          icon: Icon(Icons.search_rounded, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SearchPage(user: _u ?? AppUser.guest()))),
        ),
        Stack(clipBehavior: Clip.none, children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: ac.txt2),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationsPage(userId: _u?.id ?? ''))),
          ),
          if (!_isGuest)
            Positioned(top: 8, right: 6, child: Container(
              width: 9, height: 9,
              decoration: BoxDecoration(color: ac.red, shape: BoxShape.circle),
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
      const BrandLogo(size: 34),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Branding.current.appName, style: GoogleFonts.sora(
              fontSize: 17, fontWeight: FontWeight.w800, color: ac.txt)),
          Text(Branding.current.tagline,
              style: GoogleFonts.inter(fontSize: 10, color: ac.txt2),
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
                    style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
                Text(_isGuest ? 'Guest' : (_u!.name.isEmpty ? 'Member' : _u!.name),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 16.5, fontWeight: FontWeight.w800, color: ac.txt)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(_isGuest ? 'Guest' : _u!.roleLabel,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary)),
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
    return GestureDetector(
      onTap: _isGuest ? null : () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(user: _u!)));
      },
      child: _avatarVisual(),
    );
  }

  Widget _avatarVisual() {
    if (!_isGuest && (_u!.photoUrl ?? '').isNotEmpty) {
      return Container(
        width: 62, height: 62,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [ac.gold, Color(0xFFE8C765)]),
        ),
        child: CircleAvatar(radius: 29, backgroundImage: NetworkImage(_u!.photoUrl!)),
      );
    }
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [ac.gold.withValues(alpha: .18), ac.gold.withValues(alpha: .06)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: ac.gold.withValues(alpha: .35), width: 1.5),
      ),
      child: Icon(Icons.person_rounded, size: 32, color: ac.gold),
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
          (Icons.local_fire_department_rounded, ac.org, _isGuest ? '0' : '${_u!.streakDays}', 'Day Streak'),
          (Icons.star_rounded, ac.gold, '$lifetimeXp', 'XP Points'),
          (Icons.menu_book_rounded, ac.pur, _isGuest ? '0' : '${_u!.courseIds.length}', 'Courses'),
        ];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isGuest ? null : () => _open(context, XpDashboardPage(user: _u!)),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                  color: ac.surf, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ac.bdr2, width: 1), boxShadow: _glow),
              child: Row(children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) Container(width: 1, height: 36, color: ac.bdr2),
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
                style: GoogleFonts.sora(fontSize: 14.5, fontWeight: FontWeight.w800, color: ac.txt)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 8.5, color: ac.txt2)),
          ]),
        ),
        const SizedBox(width: 2),
        Icon(Icons.chevron_right_rounded, size: 13, color: ac.muted),
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
            ? Icon(Icons.check_circle_rounded, color: ac.gold, size: 19)
            : Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: isToday ? ac.bdr : ac.bdr2, shape: BoxShape.circle),
              ),
        const SizedBox(height: 3),
        Text(labels[i], style: GoogleFonts.inter(fontSize: 10, color: ac.txt2)),
      ]);
    }));
  }

  Widget _sectionHeader(String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
        if (onViewAll != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.xs),
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('View All', style: GoogleFonts.sora(
                    fontSize: 13, fontWeight: FontWeight.w700, color: ac.primary)),
              ),
            ),
          ),
      ]),
    );
  }

  // -- Quick Access -- fixed 5, per your call (no "New" badge) ----------
  Widget _quickAccessRow(BuildContext context) {
    final items = <(String, IconData, Color)>[
      ('Magazine', Icons.menu_book_rounded, ac.pur),
      ('Clubs', Icons.groups_rounded, ac.gold),
      ('Library', Icons.import_contacts_rounded, ac.primary),
      ('Past Questions', Icons.description_rounded, ac.grn),
      ('Quizzes', Icons.assignment_rounded, ac.org),
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
            color: ac.surf,
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
                  IconBadge(icon: icon, color: color, size: 46, iconSize: 22),
                  const SizedBox(height: 10),
                  Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.txt)),
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

  // Real Continue Reading position, sourced from
  // AcademicContentRepository's per-user readPositions (recorded by
  // content_viewer_page.dart's in-app PDF viewer -- the one content kind
  // with a real page count). This card used to read
  // AppUser.continueReadingItemId/Title/Page/TotalPages, fields ONLY ever
  // written by lib/features/library/library_reader_page.dart -- a page
  // that turned out to have no other entry point anywhere in the app
  // (nothing pushed it except this card's own "tap to reopen" handler,
  // which only fires once continueReadingItemId is already set). That's a
  // dead loop, not a working feature: those fields could never actually
  // populate for any real user. See docs/AUTOPILOT_LOG.md for the full
  // investigation. Swapped to the real, already-recorded
  // AcademicContentRepository.continueReading() so this card can actually
  // show true data once wired up.
  String? _continueReadingKey;
  Future<({AcademicContent content, int page, int totalPages})?>? _cachedContinueReadingFuture;
  Future<({AcademicContent content, int page, int totalPages})?> get _continueReadingFuture {
    final key = _u?.id ?? '';
    if (_cachedContinueReadingFuture == null || _continueReadingKey != key) {
      _continueReadingKey = key;
      _cachedContinueReadingFuture = _isGuest
          ? Future.value(null)
          : AcademicContentRepository.instance.continueReading(_u!.id);
    }
    return _cachedContinueReadingFuture!;
  }

  Widget _progressCard(BuildContext context) {
    return FutureBuilder<({AcademicContent content, int page, int totalPages})?>(
      future: _continueReadingFuture,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final data = snap.data;
        final hasReading = data != null;
        final total = data?.totalPages;
        final page = data?.page ?? 0;
        final pct = (hasReading && total != null && total > 0) ? page / total : null;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), boxShadow: _glow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.show_chart_rounded, size: 15, color: ac.primary),
              const SizedBox(width: 4),
              Expanded(child: Text("Today's Progress", style: GoogleFonts.sora(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.txt))),
              if (pct != null)
                Text('${(pct * 100).round()}%', style: GoogleFonts.sora(
                    fontSize: 11.5, fontWeight: FontWeight.w800, color: ac.txt)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct ?? 0,
                backgroundColor: ac.bdr2,
                valueColor: AlwaysStoppedAnimation(ac.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const SizedBox(height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (data != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.xs),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _reopenContinueReading(context, data);
                  },
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(9)),
                      child: Icon(Icons.menu_book_rounded, color: ac.primary, size: 18),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Continue Reading', style: GoogleFonts.inter(fontSize: 9.5, color: ac.primary)),
                        Text(data.content.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt)),
                        Text(total != null ? 'Page $page of $total' : 'Page $page',
                            style: GoogleFonts.inter(fontSize: 9.5, color: ac.muted)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: ac.muted, size: 16),
                  ]),
                ),
              )
            else
              Text('No reading in progress -- open something from the Library to start.',
                  style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted, height: 1.3)),
          ]),
        );
      },
    );
  }

  Future<void> _reopenContinueReading(
      BuildContext context, ({AcademicContent content, int page, int totalPages}) data) async {
    final localPath = await AcademicContentRepository.instance.offlineFilePath(data.content.id);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ContentViewerPage(
              fileUrl: data.content.fileUrl ?? '',
              localFilePath: localPath,
              title: data.content.title,
              // Only the in-app PDF viewer records a read position (the
              // one content kind with a real page count -- see
              // AcademicContentRepository's own comment), so anything
              // continueReading() returns is always a PDF.
              kind: ViewableFileKind.pdf,
              contentId: data.content.id,
              userId: _u!.id,
            )));
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
                  Icon(Icons.local_fire_department_rounded, color: ac.org, size: 15),
                  const SizedBox(width: 4),
                  Text('Daily Challenge', style: GoogleFonts.sora(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.pur)),
                ]),
                const SizedBox(height: 8),
                Text(challenge.title, style: GoogleFonts.sora(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.txt)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.assignment_rounded, size: 12, color: ac.pur),
                  const SizedBox(width: 4),
                  Text('${challenge.questions.length} Questions',
                      style: GoogleFonts.inter(fontSize: 10, color: ac.pur)),
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, size: 12, color: ac.gold),
                  const SizedBox(width: 2),
                  Text('+${challenge.xpPerCorrect * challenge.questions.length} XP',
                      style: GoogleFonts.inter(fontSize: 10, color: ac.txt2)),
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
                      backgroundColor: attempted ? ac.bdr : ac.pur,
                      foregroundColor: attempted ? ac.txt2 : Colors.white,
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
          gradient: LinearGradient(colors: [ac.purBg, Color(0xFFEDE4FF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(Rad.md),
        ),
        child: child,
      );

  Widget _lockedChallengeCard({required String message}) => _challengeShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.local_fire_department_rounded, color: ac.org, size: 15),
            const SizedBox(width: 4),
            Text('Daily Challenge', style: GoogleFonts.sora(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.pur)),
          ]),
          const SizedBox(height: 10),
          Text(message, style: GoogleFonts.inter(fontSize: 11, color: ac.txt2, height: 1.3)),
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
            fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.txt))),
        if (onTap != null)
          Icon(Icons.chevron_right_rounded, size: 16, color: ac.muted),
      ]),
      const SizedBox(height: 14),
      child,
    ]);
    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ac.surf, borderRadius: radius, boxShadow: _glow),
        child: inner,
      );
    }
    return Material(
      color: ac.surf,
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
              style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted, height: 1.3));
        }
        final top = writers.first;
        return Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: ac.goldBg, shape: BoxShape.circle),
            child: Text('#1', style: GoogleFonts.sora(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: ac.gold)),
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
                  style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.txt)),
              Text('${top.totalReads} reads . ${top.totalComments} comments',
                  style: GoogleFonts.inter(fontSize: 9, color: ac.muted)),
            ]),
          ),
          Icon(Icons.emoji_events_rounded, color: ac.gold, size: 16),
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
              decoration: BoxDecoration(color: ac.primaryBg, shape: BoxShape.circle),
              child: Icon(Icons.campaign_rounded, color: ac.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
                'No announcements yet. Magazine posts, paper uploads, and club '
                'news will show up here.',
                style: GoogleFonts.inter(fontSize: 9, color: ac.muted, height: 1.3))),
          ]);
        }
        final a = items.first;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: ac.primaryBg, shape: BoxShape.circle),
            child: Icon(Icons.campaign_rounded, color: ac.primary, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10.5, color: ac.txt, height: 1.3)),
              const SizedBox(height: 3),
              Text(_timeAgo(a.date), style: GoogleFonts.inter(fontSize: 9, color: ac.muted)),
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

  // -- Today's Study Program (production_plan.md §5) ----------------------
  // The spec's own worked example ("Today's Study Program: Mathematics —
  // 30 min, Physics Quiz — 15 min, Read: Mechanics — 20 min") merges BOTH
  // timetable concepts §5 defines -- the School Timetable (admin-authored,
  // e.g. "Monday: Mathematics -> Physics -> English") and the Personal
  // Study Timetable (self-authored revision sessions) -- into one ordered
  // list for today. This used to show only Personal Study slots; now
  // merges in today's School Timetable slot too, for students who have
  // one (independent/no-school users still see their personal slots only,
  // same as before). No push/local notification here (no such package is
  // wired into this app yet) -- an honest in-app reminder, not a fake
  // "we'll notify you" promise, matching this section's own prior note.
  Stream<List<TimetableSlot>> _todaysSchoolTimetableStream() {
    final schoolId = _u?.schoolId;
    if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
    final u = _u!;
    final base = u.isLecturer
        ? TimetableRepository.instance.watchForLecturer(schoolId, u.id)
        : u.classLevel.isNotEmpty
            ? TimetableRepository.instance.watchForClass(schoolId, u.classLevel)
            : TimetableRepository.instance.watchAll(schoolId);
    final today = DateTime.now().weekday;
    return base.map((slots) => slots.where((s) => s.dayOfWeek == today).toList());
  }

  Widget _todaysStudyProgram(BuildContext context) {
    return StreamBuilder<List<PersonalStudySlot>>(
      stream: PersonalStudyRepository.instance.watchToday(_u!.id),
      builder: (context, personalSnap) {
        return StreamBuilder<List<TimetableSlot>>(
          stream: _todaysSchoolTimetableStream(),
          builder: (context, schoolSnap) {
            final waiting = personalSnap.connectionState == ConnectionState.waiting ||
                schoolSnap.connectionState == ConnectionState.waiting;
            final personal = personalSnap.data ?? const <PersonalStudySlot>[];
            final school = schoolSnap.data ?? const <TimetableSlot>[];
            if (waiting || (personal.isEmpty && school.isEmpty)) {
              return const SizedBox.shrink();
            }
            // Merge both real sources into one ordered-by-start-time list,
            // each entry tagged with WHERE it came from so a school class
            // and a self-planned revision session read as visibly
            // different things, not one conflated list.
            final entries = <_TodayEntry>[
              ...school.map((s) => _TodayEntry(
                  startTime: s.startTime, endTime: s.endTime,
                  label: s.courseName, isSchool: true)),
              ...personal.map((s) => _TodayEntry(
                  startTime: s.startTime, endTime: s.endTime,
                  label: s.activity, isSchool: false)),
            ]..sort((a, b) => a.startTime.compareTo(b.startTime));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: ac.bdr)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.event_available_rounded, size: 18, color: ac.gold),
                    const SizedBox(width: 8),
                    Expanded(child: Text("Today's Study Program", style: AppText.h2.copyWith(fontSize: 15))),
                  ]),
                  const SizedBox(height: 12),
                  ...entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: e.isSchool ? ac.primary : ac.gold, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.label, style: AppText.bodySm.copyWith(fontSize: 13))),
                      if (e.isSchool) ...[
                        Text('Class · ', style: AppText.caption.copyWith(fontSize: 10, color: ac.primary)),
                      ],
                      Text('${e.startTime}–${e.endTime}', style: AppText.caption.copyWith(fontSize: 11)),
                    ]),
                  )),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // -- Recommended for You -- mix of Library + Courses --------------------
  //
  // This is the Homepage's OWN, independently-computed "Recommended for
  // You" (production_plan.md §1's "Homepage / Recommendations" -- distinct
  // from the plan's own §7B contextual, per-surface recommendations that
  // back the Library/Courses/Magazine/Quizzes/Past Papers rails elsewhere
  // via RecommendationRepository). The plan is explicit: "the homepage's
  // 'Recommended for You' system must remain separate from contextual
  // recommendations used elsewhere in the application" -- so this method
  // does NOT call RecommendationRepository. It legitimately reads some of
  // the SAME underlying real signals (favoriteSubjects,
  // TestRepository.subjectCompletionCountsOnce, course enrollment)
  // RecommendationRepository also reads -- "separate" means a structurally
  // distinct computation that can evolve independently, not that every
  // signal source must be reinvented.
  //
  // Previously this was LibraryRepository.recent() -- the `library`
  // Firestore collection turned out to have ZERO writers anywhere in this
  // app (LibraryRepository.addItem() has no call site at all), so it was a
  // dead, never-populated duplicate of AcademicContentRepository, not a
  // second real system -- plus CourseRepository.watchAll() with no
  // personalization beyond "first 4 alphabetically". That's exactly
  // production_plan.md's "broken 'Recommended for You'" complaint: pure
  // recency dressed up as personalization. See docs/AUTOPILOT_LOG.md for
  // the full two-Library-systems investigation.
  //
  // Cached by (userId, schoolId, guest) rather than called fresh in
  // build() -- unrelated setState() calls elsewhere on this page (e.g.
  // returning from the Daily Challenge) rebuild this whole ListView, and
  // an inline `future: _loadRecommended()` would hand FutureBuilder a new
  // Future identity every time, re-issuing the reads for no reason -- same
  // bug class already fixed for the banner carousel and the Clubs/Courses
  // search streams.
  String? _recommendedKey;
  Future<List<Object>>? _cachedRecommendedFuture;
  Future<List<Object>> get _recommendedFuture {
    final key = '${_u?.id}:${_u?.schoolId}:$_isGuest';
    if (_cachedRecommendedFuture == null || _recommendedKey != key) {
      _recommendedKey = key;
      _cachedRecommendedFuture = _loadRecommended();
    }
    return _cachedRecommendedFuture!;
  }

  Widget _recommendedRow(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: _recommendedFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 140,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text("Couldn't load recommendations -- ${snap.error}",
                style: GoogleFonts.inter(fontSize: 12, color: ac.red)),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Nothing to recommend yet -- Library and Courses are still empty.',
                style: GoogleFonts.inter(fontSize: 12, color: ac.muted)),
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
              if (it is AcademicContent) return _recommendedLibraryCard(context, it);
              if (it is Course) return _recommendedCourseCard(context, it);
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Future<List<Object>> _loadRecommended() async {
    final contentRepo = AcademicContentRepository.instance;
    final schoolId = _u?.schoolId;
    final favSubjects = _u?.favoriteSubjects ?? const <String>[];

    // Real Subjects signal, usage-weighted: favorite subjects, reordered so
    // the one the student actually completes quizzes in most often gets
    // first pick in the round-robin below. Reuses
    // TestRepository.subjectCompletionCountsOnce() as a plain data source
    // (already built for RecommendationRepository's own usage weighting) --
    // not a call into RecommendationRepository itself, keeping this
    // computation structurally independent per the plan's "must remain
    // separate" requirement.
    var libraryItems = <AcademicContent>[];
    if (!_isGuest && favSubjects.isNotEmpty) {
      var usage = const <String, int>{};
      try {
        usage = await TestRepository.instance.subjectCompletionCountsOnce(_u!.id);
      } catch (_) {
        // Usage weighting is a refinement, not the core signal -- fall
        // through to unweighted favorite-subject order rather than failing
        // the whole recommendation load over it.
      }
      final ranked = rankHomeSubjectsByUsage(favSubjects, usage);
      // Round-robin one pass per subject (not draining the top subject's
      // whole quota first) so a student with several favorites sees a mix.
      final perSubject = await Future.wait(ranked.map((s) => contentRepo
          .watch(institutionId: schoolId, subject: s)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const <AcademicContent>[])));
      final seenIds = <String>{};
      var round = 0;
      while (libraryItems.length < 4 && perSubject.any((l) => round < l.length)) {
        for (final list in perSubject) {
          if (round >= list.length) continue;
          final item = list[round];
          if (seenIds.add(item.id)) libraryItems.add(item);
          if (libraryItems.length >= 4) break;
        }
        round++;
      }
    }
    // Honest recent-content fallback -- guests, users with no favorite
    // subjects yet, or a favorite-subject match that came back empty all
    // see real recent Library content instead of an empty rail.
    if (libraryItems.isEmpty) {
      final fallback = await contentRepo
          .watch(institutionId: schoolId)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const <AcademicContent>[]);
      libraryItems = fallback.take(4).toList();
    }

    var courses = <Course>[];
    if (!_isGuest && schoolId != null) {
      try {
        final all = await CourseRepository.instance.watchAll(schoolId).first
            .timeout(const Duration(seconds: 3));
        // Real "Courses accessed" signal: a course the student is actually
        // enrolled in surfaces before ones they aren't.
        courses = rankHomeCoursesByEnrollment(all, _u!.courseIds.toSet()).take(4).toList();
      } catch (_) {
        courses = [];
      }
    }
    return [...libraryItems, ...courses];
  }

  String _formatContentSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  Widget _recommendedLibraryCard(BuildContext context, AcademicContent item) {
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: ac.purBg,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.selectionClick();
          _open(context, ContentDetailsPage(contentId: item.id, user: _u ?? AppUser.guest()));
        },
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.description_rounded, size: 12, color: ac.pur),
              const SizedBox(width: 4),
              Text(item.contentType.label, style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: ac.pur)),
            ]),
            const SizedBox(height: 8),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(_formatContentSize(item.fileSizeBytes),
                  style: GoogleFonts.inter(fontSize: 10, color: ac.txt2))),
              Icon(Icons.bookmark_outline_rounded, size: 16, color: ac.pur),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _recommendedCourseCard(BuildContext context, Course course) {
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: ac.bluBg,
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
              Icon(Icons.school_rounded, size: 12, color: ac.blu),
              const SizedBox(width: 4),
              Text('Course', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: ac.blu)),
            ]),
            const SizedBox(height: 8),
            Text(course.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
            const Spacer(),
            Text(course.code, style: GoogleFonts.inter(fontSize: 10, color: ac.txt2)),
          ]),
        ),
      ),
    );
  }
}

/// One row in the merged "Today's Study Program" list -- either a School
/// Timetable class or a Personal Study Timetable session, tagged so the
/// UI can label which is which rather than presenting both as the same
/// kind of thing. See _UniversalHomePageState._todaysStudyProgram.
class _TodayEntry {
  final String startTime;
  final String endTime;
  final String label;
  final bool isSchool;
  const _TodayEntry({
    required this.startTime,
    required this.endTime,
    required this.label,
    required this.isSchool,
  });
}


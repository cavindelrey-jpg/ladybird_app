// lib/features/dashboard/universal_home_page.dart
//
// Home dashboard, redesigned to match the Green Hills mockup
// (mockup.jpg): branded top bar, a green greeting hero with an
// overlapping 4-stat card (Courses/XP/Progress/Badges), a promo banner
// carousel (real, admin-managed via hero_slide_manager_page.dart --
// kept, just repositioned), Continue Learning, Today's Schedule, a
// 2x5 Quick Access grid, and an Upcoming Events / Announcements row.
//
// Every number and card is wired to real data or a real repository. The
// mockup pictures two things this codebase has no real backing for:
//   - "Today's Schedule" as official class periods with rooms/teachers
//     -- no such admin-authored timetable model exists (see
//     personal_study_slot.dart's own file comment: it's an aspirational
//     "TimetableSlot" that was never built). Uses the real, existing
//     Personal Study Timetable (self-authored revision slots) instead,
//     restyled to match the mockup's card shape.
//   - "Upcoming Events" -- no events/calendar model exists (Calendar was
//     explicitly removed as dead code referencing a deleted Institution
//     model in a recent commit). Shows an honest empty state rather than
//     reintroducing that.
// "School Connect"/"Marks"/"Calendar" Quick Access tiles from the mockup
// pointed at dead or nonexistent pages -- swapped for real destinations
// (Magazine, Daily Challenge, Announcements) that this app actually has.
// See docs/AUTOPILOT_LOG.md for the full mapping.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../config/branding.dart';
import '../../models/app_user.dart';
import '../../models/announcement.dart';
import '../../models/academic_content.dart';
import '../../models/personal_study_slot.dart';
import '../../models/messaging.dart';
import '../../repositories/personal_study_repository.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/daily_challenge_repository.dart';
import '../../repositories/academic_content_repository.dart';
import '../../repositories/test_repository.dart';
import '../../repositories/messaging_repository.dart';
import '../../services/auth_service.dart';
import '../../repositories/xp_repository.dart';
import '../../widgets/widgets.dart';
import '../../widgets/hero_banner_carousel.dart';
import '../../models/hero_slide.dart';
import '../../pages/daily_challenge_page.dart';
import '../../pages/search_page.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import '../academic_content/content_viewer_page.dart';
import '../academic_content/content_details_page.dart';
import '../testing/quiz_categories_page.dart';
import '../academic_content/academic_content_page.dart';
import '../clubs/clubs_page.dart';
import '../magazine/magazine_feed_page.dart';
import '../announcements/announcements_page.dart';
import '../messages/messages_home_page.dart';
import '../timetable/personal_study_page.dart';

/// Card shadow used throughout this page -- a bit more present than the
/// app-wide Shad tokens, matching the mockup's soft-but-visible elevation.
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

class UniversalHomePage extends StatefulWidget {
  final AppUser? user;
  const UniversalHomePage({super.key, this.user});

  @override
  State<UniversalHomePage> createState() => _UniversalHomePageState();
}

class _UniversalHomePageState extends State<UniversalHomePage> {
  bool get _isGuest => widget.user == null;
  AppUser? get _u => widget.user;
  AppUser get _userOrGuest => _u ?? AppUser.guest();

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
            const SizedBox(height: 14),
            _heroAndStats(context),
            const SizedBox(height: 20),
            HeroBannerCarousel(placement: HeroPlacement.home, user: widget.user),
            const SizedBox(height: 24),
            _sectionHeader('Continue Learning',
                onViewAll: () => _open(context, AcademicContentPage(user: _userOrGuest))),
            const SizedBox(height: 12),
            _continueLearningCard(context),
            const SizedBox(height: 24),
            _sectionHeader("Today's Schedule",
                viewAllLabel: 'View timetable',
                onViewAll: _isGuest ? null : () => _open(context, PersonalStudyPage(user: _u!))),
            const SizedBox(height: 12),
            _todaysScheduleRow(context),
            const SizedBox(height: 24),
            _sectionHeader('Quick Access'),
            const SizedBox(height: 12),
            _quickAccessGrid(context),
            const SizedBox(height: 20),
            _eventsAndAnnouncementsRow(context),
            const SizedBox(height: 24),
            _sectionHeader('Recommended for You',
                onViewAll: () => _open(context, AcademicContentPage(user: _userOrGuest))),
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
        const SizedBox(width: 2),
        Expanded(
          child: Text(Branding.current.appName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: ac.primary)),
        ),
        IconButton(
          icon: Icon(Icons.search_rounded, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SearchPage(user: _userOrGuest))),
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
              decoration: BoxDecoration(color: ac.grn, shape: BoxShape.circle),
            )),
        ]),
      ]),
    );
  }

  // -- Greeting hero + overlapping stat card ---------------------------
  String get _timeGreeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _heroAndStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [ac.navy, ac.navy2],
            ),
            borderRadius: BorderRadius.circular(Rad.lg),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$_timeGreeting,',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: .85))),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _isGuest ? 'Guest' : (_u!.name.isEmpty ? 'Member' : _u!.name.split(' ').first)),
                    const TextSpan(text: ' \u{1F44B}'),
                  ]),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text('"${Branding.current.tagline}"',
                    style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: .8), height: 1.3)),
              ]),
            ),
            Icon(Icons.auto_stories_rounded, size: 46, color: Colors.white.withValues(alpha: .18)),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -16),
          child: _statCard(),
        ),
      ]),
    );
  }

  Widget _statCard() {
    return StreamBuilder<(int, int)>(
      stream: _isGuest ? const Stream<(int, int)>.empty() : XpRepository.instance.watchBalance(_u!.id),
      builder: (context, xpSnap) {
        final lifetimeXp = _isGuest ? 0 : (xpSnap.data?.$2 ?? 0);
        return FutureBuilder<Map<String, int>>(
          future: _isGuest ? Future.value(const {}) : TestRepository.instance.subjectCompletionCountsOnce(_u!.id),
          builder: (context, badgeSnap) {
            final badgeCount = (badgeSnap.data ?? const {}).values.where((v) => v > 0).length;
            final weekPct = _isGuest ? 0 : (_weekActivityCount() / 7 * 100).round();
            final segments = [
              (Icons.school_rounded, ac.grn, _isGuest ? '0' : '${_u!.courseIds.length}', 'Courses\nEnrolled'),
              (Icons.star_rounded, ac.gold, '$lifetimeXp', 'XP\nPoints'),
              (Icons.show_chart_rounded, ac.primary, '$weekPct%', 'Progress\nOverall'),
              (Icons.emoji_events_rounded, ac.pur, '$badgeCount', 'Badges\nEarned'),
            ];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                  color: ac.surf, borderRadius: BorderRadius.circular(Rad.lg), boxShadow: _glow),
              child: Row(children: [
                for (final s in segments) Expanded(child: _statSegment(s)),
              ]),
            );
          },
        );
      },
    );
  }

  int _weekActivityCount() {
    if (_isGuest) return 0;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final activity = _u!.weekActivityDates.toSet();
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final key = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (activity.contains(key)) count++;
    }
    return count;
  }

  Widget _statSegment((IconData, Color, String, String) segment) {
    final (icon, color, value, label) = segment;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.sora(fontSize: 14.5, fontWeight: FontWeight.w800, color: ac.txt)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center, maxLines: 2,
          style: GoogleFonts.inter(fontSize: 8.5, color: ac.txt2, height: 1.15)),
    ]);
  }

  Widget _sectionHeader(String title, {VoidCallback? onViewAll, String viewAllLabel = 'View all'}) {
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
                child: Text(viewAllLabel, style: GoogleFonts.sora(
                    fontSize: 13, fontWeight: FontWeight.w700, color: ac.primary)),
              ),
            ),
          ),
      ]),
    );
  }

  void _open(BuildContext context, Widget page) {
    // Guests browse read-only content freely — only actions that WRITE
    // data (liking, commenting, bookmarking, the Daily Challenge) ask for
    // sign-in, and those already do it inline where the action happens
    // rather than blocking navigation here.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // -- Continue Learning -------------------------------------------------
  // Real Continue Reading position, sourced from
  // AcademicContentRepository's per-user readPositions (recorded by
  // content_viewer_page.dart's in-app PDF viewer -- the one content kind
  // with a real page count). See docs/AUTOPILOT_LOG.md for the
  // investigation into why this replaced the old, never-populated
  // AppUser.continueReadingItemId fields.
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

  Widget _continueLearningCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<({AcademicContent content, int page, int totalPages})?>(
        future: _continueReadingFuture,
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final data = snap.data;
          if (loading) {
            return Container(
              height: 96, alignment: Alignment.center,
              decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), boxShadow: _glow),
              child: const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (data == null) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), boxShadow: _glow),
              child: Row(children: [
                Icon(Icons.menu_book_outlined, color: ac.muted, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text('No content in progress -- open something from the Library to start.',
                    style: GoogleFonts.inter(fontSize: 12, color: ac.muted, height: 1.3))),
              ]),
            );
          }
          final isVideo = data.content.contentType == ContentType.video;
          final pct = data.totalPages > 0 ? (data.page / data.totalPages).clamp(0.0, 1.0) : 0.0;
          final radius = BorderRadius.circular(Rad.md);
          return Material(
            color: ac.surf,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: () {
                HapticFeedback.lightImpact();
                _reopenContinueReading(context, data);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(borderRadius: radius, boxShadow: _glow),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Rad.sm),
                    child: SizedBox(
                      width: 96, height: 76,
                      child: Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
                        (data.content.thumbnailUrl ?? '').isNotEmpty
                            ? Image.network(data.content.thumbnailUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: ac.navy))
                            : Container(color: ac.navy,
                                child: Center(child: Text(data.content.contentType.emoji,
                                    style: const TextStyle(fontSize: 26)))),
                        if (isVideo)
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), shape: BoxShape.circle),
                            child: Icon(Icons.play_arrow_rounded, color: ac.navy, size: 20),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data.content.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w800, color: ac.txt)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct, backgroundColor: ac.bdr2,
                          valueColor: AlwaysStoppedAnimation(ac.primary), minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('${(pct * 100).round()}% complete', style: GoogleFonts.inter(
                            fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Page ${data.page} of ${data.totalPages}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10, color: ac.muted))),
                      ]),
                    ]),
                  ),
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: ac.primaryBg, shape: BoxShape.circle),
                    child: Icon(Icons.chevron_right_rounded, color: ac.primary, size: 18),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
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
              kind: ViewableFileKind.pdf,
              contentId: data.content.id,
              userId: _u!.id,
            )));
  }

  // -- Today's Schedule ---------------------------------------------------
  // Real Personal Study Timetable slots for today (self-authored revision
  // sessions) -- see the file header for why this stands in for the
  // mockup's "official class schedule" concept, which has no real backing
  // model in this app.
  Widget _todaysScheduleRow(BuildContext context) {
    if (_isGuest) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _emptyStrip(icon: Icons.event_note_outlined, message: 'Sign in to build your study schedule.'),
      );
    }
    return StreamBuilder<List<PersonalStudySlot>>(
      stream: PersonalStudyRepository.instance.watchToday(_u!.id),
      builder: (context, snap) {
        final slots = snap.data ?? const <PersonalStudySlot>[];
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 84, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (slots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _emptyStrip(
              icon: Icons.event_available_outlined,
              message: 'Nothing scheduled today -- tap "View timetable" to add a study session.',
            ),
          );
        }
        final accents = [ac.grn, ac.gold, ac.primary, ac.pur];
        return SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final s = slots[i];
              final accent = accents[i % accents.length];
              return Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm),
                  border: Border(left: BorderSide(color: accent, width: 3)), boxShadow: _glow,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${s.startTime} - ${s.endTime}', style: GoogleFonts.inter(fontSize: 10, color: ac.txt2)),
                  const SizedBox(height: 4),
                  Text(s.activity, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                ]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _emptyStrip({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), boxShadow: _glow),
      child: Row(children: [
        Icon(icon, color: ac.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: ac.muted, height: 1.3))),
      ]),
    );
  }

  // -- Quick Access -- 2 rows of 5, all real destinations ------------------
  // "School Connect", "Marks", and "Calendar" from the mockup have no
  // real page in this app (School Connect/Calendar were deliberately
  // removed as dead code referencing a deleted Institution model; there's
  // no student "my marks" list, only per-attempt results). Swapped for
  // Magazine, Daily Challenge, and Announcements -- real features that
  // otherwise had no other Home entry point (Daily Challenge in
  // particular has NO other entry point anywhere in the app).
  Widget _quickAccessGrid(BuildContext context) {
    final row1 = <(String, IconData, Color, VoidCallback)>[
      ('Library', Icons.menu_book_rounded, ac.primary,
          () => _open(context, AcademicContentPage(user: _userOrGuest))),
      ('Past Questions', Icons.description_rounded, ac.grn,
          () => _open(context, AcademicContentPage(user: _userOrGuest, initialTypeFilter: ContentType.pastPaper))),
      ('Quizzes', Icons.help_outline_rounded, ac.gold,
          () => _open(context, QuizCategoriesPage(user: _userOrGuest))),
      // Same browse tree as Quizzes -- this codebase doesn't model
      // "Tests" as a separate system from Quizzes (see
      // tests_subject_picker_page.dart's own file comment).
      ('Tests', Icons.assignment_rounded, ac.primary,
          () => _open(context, QuizCategoriesPage(user: _userOrGuest))),
      ('Clubs', Icons.groups_rounded, ac.grn,
          () => _open(context, ClubsPage(user: _userOrGuest))),
    ];
    final row2 = <(String, IconData, Color, VoidCallback)>[
      ('Magazine', Icons.auto_stories_rounded, ac.grn,
          () => _open(context, MagazineFeedPage(user: _userOrGuest))),
      ('Timetable', Icons.calendar_month_rounded, ac.gold,
          _isGuest ? () => showToast(context, 'Sign in to build your study schedule.')
                   : () => _open(context, PersonalStudyPage(user: _u!))),
      ('Challenge', Icons.local_fire_department_rounded, ac.org,
          () => _openDailyChallenge(context)),
      ('Calendar', Icons.event_rounded, ac.pur,
          () => _open(context, AnnouncementsPage(user: _userOrGuest, canPost: !_isGuest && _u!.canPostAnnouncement))),
      ('Messages', Icons.mail_outline_rounded, ac.primary,
          _isGuest ? () => showToast(context, 'Sign in to message other members.')
                   : () => _open(context, MessagesHomePage(user: _u!))),
    ];
    return Column(children: [
      _quickAccessGridRow(context, row1),
      const SizedBox(height: 12),
      _quickAccessGridRow(context, row2, unreadBadgeFor: 'Messages'),
    ]);
  }

  Widget _quickAccessGridRow(BuildContext context, List<(String, IconData, Color, VoidCallback)> items,
      {String? unreadBadgeFor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        for (final it in items) ...[
          Expanded(child: _quickAccessTile(context, it, showUnreadBadge: it.$1 == unreadBadgeFor)),
          if (it != items.last) const SizedBox(width: 8),
        ],
      ]),
    );
  }

  Widget _quickAccessTile(BuildContext context, (String, IconData, Color, VoidCallback) item,
      {bool showUnreadBadge = false}) {
    final (label, icon, color, onTap) = item;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.sm),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(Rad.sm)),
              child: Icon(icon, color: color, size: 22),
            ),
            if (showUnreadBadge && !_isGuest) _messagesUnreadBadge(),
          ]),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: ac.txt2)),
        ]),
      ),
    );
  }

  Widget _messagesUnreadBadge() {
    return StreamBuilder<List<Conversation>>(
      stream: MessagingRepository.instance.watchConversations(_u!.id),
      builder: (context, snap) {
        final total = (snap.data ?? const <Conversation>[])
            .fold<int>(0, (sum, c) => sum + (c.unreadCount[_u!.id] ?? 0));
        if (total <= 0) return const SizedBox.shrink();
        return Positioned(
          top: -4, right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(color: ac.red, borderRadius: BorderRadius.circular(8)),
            child: Text(total > 9 ? '9+' : '$total', textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        );
      },
    );
  }

  Future<void> _openDailyChallenge(BuildContext context) async {
    if (_isGuest) {
      showToast(context, "Sign in to take today's challenge.");
      return;
    }
    final challenge = await DailyChallengeRepository.instance.getToday();
    if (!context.mounted) return;
    if (challenge == null) {
      showToast(context, 'No challenge today -- check back soon.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DailyChallengePage(user: _u!, challenge: challenge)));
  }

  // -- Upcoming Events + Announcements -------------------------------------
  Widget _eventsAndAnnouncementsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _panel(title: 'Upcoming Events', child: _upcomingEventsContent())),
          const SizedBox(width: 12),
          Expanded(child: _panel(
              title: 'Announcements',
              onTap: () => _open(context, AnnouncementsPage(
                  user: _userOrGuest, canPost: !_isGuest && _u!.canPostAnnouncement)),
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
          Text('View all', style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary)),
      ]),
      const SizedBox(height: 12),
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

  // No events/calendar model exists in this app (see file header) --
  // honest empty state rather than fabricated dates.
  Widget _upcomingEventsContent() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.event_busy_rounded, color: ac.muted, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text('No upcoming events yet.',
          style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted, height: 1.3))),
    ]);
  }

  Widget _announcementsContent() {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementRepository.instance.watchAnnouncements(schoolId: _u?.schoolId),
      builder: (context, snap) {
        final items = (snap.data ?? const <Announcement>[]);
        if (items.isEmpty) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.campaign_rounded, color: ac.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('No announcements yet.',
                style: GoogleFonts.inter(fontSize: 9, color: ac.muted, height: 1.3))),
          ]);
        }
        final a = items.first;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 6, height: 6, margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: ac.grn, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.txt, height: 1.3)),
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
  // Cached by (userId, schoolId, guest) rather than called fresh in
  // build() -- unrelated setState() calls elsewhere on this page rebuild
  // this whole ListView, and an inline `future: _loadRecommended()` would
  // hand FutureBuilder a new Future identity every time, re-issuing the
  // reads for no reason.
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
          return const SizedBox(height: 168,
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
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final it = items[i];
              if (it is AcademicContent) return _recommendedLibraryCard(context, it);
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
    if (libraryItems.isEmpty) {
      final fallback = await contentRepo
          .watch(institutionId: schoolId)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const <AcademicContent>[]);
      libraryItems = fallback.take(4).toList();
    }

    return libraryItems;
  }

  String _formatContentSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  Widget _recommendedThumb(AppColors ac, {String? url, required Widget fallback}) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.md)),
      child: SizedBox(
        height: 64,
        width: double.infinity,
        child: (url ?? '').isNotEmpty
            ? Image.network(url!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: ac.surf3, child: fallback))
            : Container(color: ac.surf3, child: fallback),
      ),
    );
  }

  Widget _recommendedLibraryCard(BuildContext context, AcademicContent item) {
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: ac.purBg,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.selectionClick();
          _open(context, ContentDetailsPage(contentId: item.id, user: _userOrGuest));
        },
        child: SizedBox(
          width: 150,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _recommendedThumb(ac, url: item.thumbnailUrl,
                fallback: Center(child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 22)))),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.description_rounded, size: 12, color: ac.pur),
                  const SizedBox(width: 4),
                  Expanded(child: Text(item.contentType.label, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: ac.pur))),
                ]),
                const SizedBox(height: 6),
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(_formatContentSize(item.fileSizeBytes),
                      style: GoogleFonts.inter(fontSize: 10, color: ac.txt2))),
                  Icon(Icons.bookmark_outline_rounded, size: 16, color: ac.pur),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

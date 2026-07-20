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
//
// Design pass: named AppText type scale instead of ad-hoc fontSize; real
// InkWell ripple + haptic on every tap that used to be a silent
// GestureDetector; Quick Access tile height fixed (was overflowing by a
// few px on 2-line labels).
//
// Two real bugs fixed in this pass, not just cosmetic ones:
//   1. The "Academic Score" stat card was hardcoded to a literal '87%' —
//      a fabricated number shown to real students as if it were their
//      actual grade average. Removed rather than left in, since showing
//      a fake number is worse than showing nothing. MarksRepository has
//      no aggregate/average method yet (only per-sequence subject
//      reports), so wiring a real one needs a decision on grading
//      methodology (which sequence, how subjects are weighted) before
//      it can be built honestly — flagging rather than guessing.
//   2. "Recommended for You" was 4 hardcoded fake content cards, always
//      the same regardless of the signed-in user or actual library
//      content — direct contradiction of this file's own header comment
//      claiming zero hardcoded rows. Now a live stream over
//      AcademicContentRepository.watch(), most-recent-first. There's no
//      real personalization/ranking signal yet, so this is honestly
//      "Recently Added" wearing the existing section title, not a true
//      recommendation engine — worth renaming the header if that
//      distinction matters to you.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../models/app_user.dart';
import '../../models/hero_slide.dart';
import '../../models/announcement.dart';
import '../../models/magazine_article.dart';
import '../../models/quick_access_feature.dart';
import '../../models/academic_content.dart';
import '../../models/xp_transaction.dart' show kDailyXpCap;
import '../../repositories/hero_slide_repository.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/academic_content_repository.dart';
import '../../repositories/streak_repository.dart';
import '../../repositories/xp_repository.dart';
import '../../services/auth_service.dart';
import '../../services/analytics_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/coming_soon_page.dart';
import '../../pages/marks_page.dart';
import '../timetable/timetable_page.dart';
import '../assignments/assignments_page.dart';
import '../courses/courses_page.dart';
import '../clubs/clubs_page.dart';
import '../academic_content/academic_content_page.dart';
import '../academic_content/content_viewer_page.dart';
import '../magazine/magazine_feed_page.dart';
import '../magazine/author_profile_page.dart';
import '../../pages/notifications_page.dart';
import '../../repositories/notification_repository.dart';
import '../magazine/top_writers_page.dart';
import '../announcements/announcements_page.dart';
import '../../pages/profile_page.dart';
import '../admin/hero_slide_manager_page.dart';

class UniversalHomePage extends StatefulWidget {
  final AppUser? user;
  const UniversalHomePage({super.key, this.user});

  @override
  State<UniversalHomePage> createState() => _UniversalHomePageState();
}

class _UniversalHomePageState extends State<UniversalHomePage> {
  Future<({int streak, List<bool> week})>? _streakFuture;
  Future<({AcademicContent content, int page, int totalPages})?>? _continueReadingFuture;

  bool get _isGuest => widget.user == null;
  AppUser? get _u => widget.user;

  @override
  void initState() {
    super.initState();
    if (!_isGuest) {
      // Fire-and-forget: marks today active for the streak, then the
      // summary read below reflects it. Best-effort by design (see
      // StreakRepository) so a failure here never blocks the page.
      StreakRepository.instance.recordActiveToday(_u!.id);
      _streakFuture = StreakRepository.instance.loadSummary(_u!.id);
      _continueReadingFuture = AcademicContentRepository.instance.continueReading(_u!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      color: ac.bg,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Top band: subtle blue-tinted gradient fading to the app
            // background, instead of flat white all the way down.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ac.primaryBg, ac.bg],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  stops: const [0.0, 0.7],
                ),
              ),
              child: Column(children: [
                _topBar(context),
                const SizedBox(height: 14),
                _idCard(context),
                const SizedBox(height: 20),
                _bannerCarousel(),
                const SizedBox(height: 8),
              ]),
            ),
            // Alternating surface band for Quick Access.
            Container(
              color: ac.surf,
              child: Stack(children: [
                const SectionWatermark(icon: Icons.science_outlined, alignment: Alignment.topRight),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(children: [
                    _sectionHeader('Quick Access',
                        onViewAll: () => showToast(context, 'Tap a tile above — more will appear here as you use them.')),
                    const SizedBox(height: 12),
                    _quickAccessGrid(context),
                  ]),
                ),
              ]),
            ),
            if (!_isGuest) _progressAndChallengeRow(),
            // Back to app-bg for Top Writers / Announcements.
            Container(
              color: ac.bg,
              child: Stack(children: [
                const SectionWatermark(icon: Icons.menu_book_outlined, alignment: Alignment.topLeft),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _upcomingAndAnnouncements(),
                ),
              ]),
            ),
            // Surface band again for Recommended.
            Container(
              color: ac.surf,
              child: Stack(children: [
                const SectionWatermark(icon: Icons.school_outlined, alignment: Alignment.topRight),
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  child: Column(children: [
                    _sectionHeader('Recommended for You', onViewAll: () => _open(context, const _LibraryDest())),
                    const SizedBox(height: 12),
                    _recommendedRow(),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar: menu (drawer), search, notifications ──────────────────────
  Widget _topBar(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = context.watch<ThemeProvider>().isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Row(children: [
        Builder(builder: (ctx) => IconButton(
          icon: Icon(Icons.menu_rounded, color: ac.txt),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        const SizedBox(width: 4),
        Container(
          decoration: isDark
              ? BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: ac.primary.withValues(alpha: .45), blurRadius: 18, spreadRadius: 1),
                ])
              : null,
          child: const AcademiaLogo(size: 34),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Academia', style: AppText.title.copyWith(fontSize: 17, color: ac.txt)),
            Text('Your Complete Smart School Platform',
                style: AppText.caption.copyWith(fontSize: 10, color: ac.txt2),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        IconButton(
          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined, color: ac.txt2),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () {
            HapticFeedback.selectionClick();
            context.read<ThemeProvider>().toggle();
          },
        ),
        IconButton(
          icon: Icon(Icons.search_rounded, color: ac.txt2),
          onPressed: () => showToast(context, 'Search is coming soon.'),
        ),
        _isGuest
            ? IconButton(
                icon: Icon(Icons.notifications_outlined, color: ac.txt2),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ComingSoonPage(
                          title: 'Sign in required',
                          subtitle: 'Create a free account to see notifications.',
                          icon: Icons.lock_outline_rounded)));
                },
              )
            : StreamBuilder<int>(
                stream: NotificationRepository.instance.watchUnreadCount(_u!.id),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return Stack(clipBehavior: Clip.none, children: [
                    WiggleIcon(
                      active: count > 0,
                      child: IconButton(
                        icon: Icon(Icons.notifications_outlined, color: ac.txt2),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => NotificationsPage(userId: _u!.id)));
                        },
                      ),
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
      ]),
    );
  }

  // ── Identity card — approved 2-column mockup layout:
  // LEFT column: avatar + name/role, spans the card's full height.
  // RIGHT column: stat tiles (streak/XP/courses) stacked above the
  // weekday-streak dots, confined to that column's width only — this
  // was iterated on explicitly in chat before being approved, see the
  // shared HTML mockup for the reference this mirrors.
  Widget _idCard(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = context.watch<ThemeProvider>().isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ac.surf, isDark ? ac.surf2 : ac.primaryBg],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(Rad.md),
          border: Border.all(color: ac.bdr),
          boxShadow: [BoxShadow(color: ac.shadow, blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // LEFT — avatar + name/role
          _isGuest
              ? _avatar(ac, isDark)
              : InkWell(
                  borderRadius: BorderRadius.circular(32),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfilePage(user: _u!))),
                  child: _avatar(ac, isDark),
                ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isGuest ? 'Browsing as' : 'Welcome back,',
                  style: AppText.subtitle.copyWith(fontSize: 10.5, color: ac.txt2)),
              Text(_isGuest ? 'Guest' : (_u!.name.isEmpty ? 'Member' : _u!.name),
                  style: AppText.h1.copyWith(fontSize: 14.5, color: ac.txt),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x2422D3EE) : ac.primaryBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_isGuest ? 'Guest' : _u!.roleLabel,
                    style: AppText.label.copyWith(
                        fontSize: 8.5, color: isDark ? const Color(0xFF22D3EE) : ac.primary, letterSpacing: 0)),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          // RIGHT — stats row above weekday dots, right column only
          if (!_isGuest)
            Expanded(
              child: FutureBuilder<({int streak, List<bool> week})>(
                future: _streakFuture,
                builder: (context, snap) {
                  final streak = snap.data?.streak ?? 0;
                  final week = snap.data?.week ?? List<bool>.filled(7, false);
                  return Column(children: [
                    Row(children: [
                      Expanded(child: _statChip(ac, isDark,
                          icon: Icons.local_fire_department_rounded, tint: ac.org,
                          value: '$streak', label: 'Day Streak')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StreamBuilder<(int, int)>(
                          stream: XpRepository.instance.watchBalance(_u!.id),
                          builder: (context, xpSnap) {
                            final balance = xpSnap.data?.$1 ?? 0;
                            return _statChip(ac, isDark,
                                icon: Icons.star_rounded, tint: ac.gold,
                                value: NumberFormat.compact().format(balance), label: 'XP Points');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _statChip(ac, isDark,
                          icon: Icons.menu_book_rounded, tint: ac.pur,
                          value: '${_u!.courseIds.length}', label: 'Courses')),
                    ]),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: ac.bdr2))),
                      child: _weekDotRow(week, ac, isDark),
                    ),
                  ]);
                },
              ),
            ),
        ]),
      ),
    );
  }

  Widget _avatar(AppColors ac, bool isDark) {
    final glow = isDark
        ? [BoxShadow(color: ac.primary.withValues(alpha: .35), blurRadius: 14, spreadRadius: 1)]
        : <BoxShadow>[];
    if (!_isGuest && (_u!.photoUrl ?? '').isNotEmpty) {
      return Container(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: glow),
        child: CircleAvatar(radius: 23, backgroundImage: NetworkImage(_u!.photoUrl!)),
      );
    }
    // NPC placeholder — guest, or signed-in with no profile photo.
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: ac.surf3,
        shape: BoxShape.circle,
        border: Border.all(color: ac.bdr, width: 1.5),
        boxShadow: glow,
      ),
      child: Icon(Icons.person_rounded, size: 24, color: ac.muted),
    );
  }

  Widget _statChip(AppColors ac, bool isDark, {
    required IconData icon, required Color tint, required String value, required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? .12 : .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: isDark ? .45 : .25)),
        boxShadow: isDark ? [BoxShadow(color: tint.withValues(alpha: .16), blurRadius: 10)] : null,
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -1, right: -2, child: Icon(Icons.chevron_right_rounded, size: 14, color: ac.muted)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(icon, color: tint, size: 14),
            const SizedBox(width: 4),
            Flexible(child: Text(value, style: AppText.title.copyWith(fontSize: 13, color: ac.txt),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption.copyWith(fontSize: 8.5, color: ac.txt2),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ]),
    );
  }

  Widget _weekDotRow(List<bool> week, AppColors ac, bool isDark) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final active = week[i];
        return Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? ac.org : (isDark ? ac.surf2 : ac.surf3),
              border: Border.all(color: active ? ac.org : ac.bdr),
              boxShadow: active && isDark
                  ? [BoxShadow(color: ac.org.withValues(alpha: .55), blurRadius: 8)]
                  : null,
            ),
            // Checkmark shown in light mode; dark mode is a clean glowing
            // dot with no glyph, per the approved dark mockup.
            child: (active && !isDark) ? const Icon(Icons.check_rounded, size: 10, color: Colors.white) : null,
          ),
          const SizedBox(height: 2),
          Text(labels[i], style: AppText.caption.copyWith(fontSize: 7.5, color: ac.txt2)),
        ]);
      }),
    );
  }

  // ── Today's Progress (real XP %, with Continue Reading folded in) +
  // Daily Challenge. Daily Challenge is deliberately front-end only: the
  // quiz backend doesn't exist yet (no question bank, no attempt
  // tracking), so "Today's Physics Quiz" / "3 Questions" / "+50 XP" are
  // placeholder copy, not live data — Start Challenge is a toast, not a
  // dead end pretending to work. Swap in a real stream the moment the
  // quiz backend lands; the card shell is ready for it.
  Widget _progressAndChallengeRow() {
    if (_isGuest) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _todaysProgressCard()),
        const SizedBox(width: 12),
        Expanded(child: _dailyChallengeCard()),
      ]),
    );
  }

  Widget _todaysProgressCard() {
    final ac = AppColors.of(context);
    return StreamBuilder<int>(
      stream: XpRepository.instance.watchXpEarnedToday(_u!.id),
      builder: (context, xpSnap) {
        final earned = (xpSnap.data ?? 0).clamp(0, kDailyXpCap);
        final pct = kDailyXpCap == 0 ? 0 : ((earned / kDailyXpCap) * 100).round();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.trending_up_rounded, size: 15, color: ac.primary),
              const SizedBox(width: 6),
              Expanded(child: Text("Today's Progress", style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2))),
              Text('$pct%', style: AppText.title.copyWith(fontSize: 13, color: ac.primary)),
            ]),
            const SizedBox(height: 8),
            AnimatedMiniBar(value: pct / 100, color: ac.primary),
            const SizedBox(height: 14),
            FutureBuilder<({AcademicContent content, int page, int totalPages})?>(
              future: _continueReadingFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const ShimmerBlock(height: 40);
                }
                final data = snap.data;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.sm),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (data == null) { _open(context, const _LibraryDest()); return; }
                      final kind = viewableKindFor(data.content.fileUrl ?? '');
                      if (kind == null || (data.content.fileUrl ?? '').isEmpty) {
                        _open(context, const _LibraryDest());
                        return;
                      }
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContentViewerPage(
                        fileUrl: data.content.fileUrl!, title: data.content.title, kind: kind,
                        contentId: data.content.id, userId: _u!.id,
                      )));
                    },
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.menu_book_rounded, color: ac.primary, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Continue Reading', style: AppText.caption.copyWith(color: ac.primary, fontSize: 9.5)),
                          Text(data == null ? 'Nothing read yet' : data.content.title,
                              style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 11.5),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: ac.muted, size: 18),
                    ]),
                  ),
                );
              },
            ),
          ]),
        );
      },
    );
  }

  Widget _dailyChallengeCard() {
    final isDark = context.watch<ThemeProvider>().isDark;
    return TapScale(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Rad.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            showToast(context, 'Daily quizzes are launching soon — check back here.');
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF6D28D9), Color(0xFF2E1065)]
                    : const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              boxShadow: isDark
                  ? [BoxShadow(color: const Color(0xFF6D28D9).withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))]
                  : null,
            ),
            child: Stack(children: [
              Positioned(
                right: -10, bottom: -10,
                child: Icon(Icons.psychology_alt_rounded, size: 64,
                    color: Colors.white.withValues(alpha: isDark ? .18 : .12)),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text('Daily Challenge', style: AppText.caption.copyWith(
                      color: Colors.white.withValues(alpha: .9), fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Text("Today's Physics Quiz", style: AppText.title.copyWith(color: Colors.white, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('3 Questions · +50 XP',
                    style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: .75), fontSize: 10.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Start Challenge', style: AppText.subtitle.copyWith(
                        color: const Color(0xFF6D28D9), fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF6D28D9)),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Banner carousel — live Firestore slides, no hardcoded copy ──────────
  Widget _bannerCarousel() => _HomeBannerCarousel(onOpenSlide: _openHeroSlide, isSuperAdmin: !_isGuest && _u!.isSuperAdmin, userId: _u?.id);

  void _openHeroSlide(HeroSlide slide) {
    switch (slide.destination) {
      case HeroDestination.clubs:
        _open(context, const _ClubsDest());
        break;
      case HeroDestination.pastQuestions:
        _open(context, const _PastQuestionsDest());
        break;
      case HeroDestination.magazine:
        _open(context, const _MagazineDest());
        break;
      case HeroDestination.library:
        _open(context, const _LibraryDest());
        break;
      case HeroDestination.courses:
        _open(context, const _CoursesDest());
        break;
      case HeroDestination.custom:
        break; // no-op until custom in-app routing is defined
    }
  }

  Widget _sectionHeader(String title, {required VoidCallback onViewAll}) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 16, color: ac.txt))),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.xs),
            onTap: () {
              HapticFeedback.selectionClick();
              onViewAll();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('View All', style: AppText.subtitle.copyWith(
                  color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Quick Access grid — exactly 4 tiles, ranked by real tap frequency ───
  // New users (empty usage map) see the QuickAccessRegistry default order:
  // Library, Past Questions, Magazine, Clubs.
  Widget _quickAccessGrid(BuildContext context) {
    final ac = AppColors.of(context);
    final usage = _isGuest ? const <String, int>{} : _u!.quickAccessUsage;
    final tiles = QuickAccessRegistry.topFourPlusNew(usage);

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final feat = tiles[i];
          return FadeSlideIn(
            index: i,
            child: TapScale(
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(Rad.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.md),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _openQuickAccess(context, feat);
                  },
                  child: Container(
                    width: 84,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: ac.surf, borderRadius: BorderRadius.circular(Rad.md),
                      border: Border.all(color: ac.bdr),
                    ),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: feat.bg,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: feat.fg.withValues(alpha: .28),
                                  blurRadius: 12, spreadRadius: -2, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Icon(feat.icon, color: feat.fg, size: 19),
                        ),
                        const SizedBox(height: 8),
                        Text(feat.label, textAlign: TextAlign.center,
                            style: AppText.bodySm.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.txt),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                      if (feat.isNew)
                        Positioned(
                          top: -6, right: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: ac.org, borderRadius: BorderRadius.circular(8)),
                            child: Text('New', style: AppText.caption.copyWith(
                                fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
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
        _open(context, const _PastQuestionsDest());
        break;
      case 'magazine':
        _open(context, const _MagazineDest());
        break;
      case 'clubs':
        _open(context, const _ClubsDest());
        break;
      case 'courses':
        _open(context, const _CoursesDest());
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
      case 'quizzes':
        // Front-end only for now — see the Daily Challenge card's doc
        // comment. Same ComingSoonPage pattern as 'lecture_notes' above.
        _open(context, const ComingSoonPage(
          title: 'Daily Quizzes',
          subtitle: 'Quick daily quizzes with XP rewards are on the way — this screen is reserved for them.',
          icon: Icons.quiz_rounded,
        ));
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
      page = AcademicContentPage(user: _u!);
    } else if (destResolver is _PastQuestionsDest) {
      page = AcademicContentPage(user: _u!, initialTypeFilter: ContentType.pastPaper);
    } else if (destResolver is _CoursesDest) {
      page = CoursesPage(user: _u!);
    } else if (destResolver is _ClubsDest) {
      page = ClubsPage(user: _u!);
    } else if (destResolver is _MagazineDest) {
      page = MagazineFeedPage(user: _u);
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
        _panelCard(title: 'Top Writers', child: _topWritersPanel(),
            onViewAll: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TopWritersPage()))),
        const SizedBox(height: 16),
        _panelCard(title: 'Recent Announcements', child: _announcementsPanel(),
            onViewAll: _isGuest ? null : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AnnouncementsPage(user: _u!, canPost: _u!.canPostAnnouncement)))),
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
          return Column(children: [
            for (int i = 0; i < 2; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == 0 ? 14 : 0),
                child: const Row(children: [
                  ShimmerCircle(size: 32),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerLine(height: 13)),
                ]),
              ),
          ]);
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
            if (i > 0) Divider(height: 20, color: AppColors.of(context).bdr2),
            _topWriterRow(rank: i + 1, entry: writers[i]),
          ],
        ]);
      },
    );
  }

  Widget _topWriterRow({required int rank, required TopWriterEntry entry}) {
    final ac = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(Rad.sm),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AuthorProfilePage(authorId: entry.authorId, currentUser: _u))),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: ac.goldBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('#$rank', style: AppText.subtitle.copyWith(
              fontSize: 12, fontWeight: FontWeight.w800, color: ac.gold)),
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
            Text(entry.authorName, style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 12.5)),
            Text('${entry.totalReads} reads · ${entry.totalComments} comments',
                style: AppText.caption.copyWith(color: ac.muted)),
          ]),
        ),
      ]),
    );
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
    final ac = AppColors.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: ac.muted, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: AppText.bodySm.copyWith(height: 1.4, color: ac.txt2))),
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

  Widget _panelCard({required String title, required Widget child, VoidCallback? onViewAll}) {
    final ac = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf, borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: AppText.title.copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: ac.txt))),
          if (onViewAll != null)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text('View All', style: AppText.subtitle.copyWith(
                    color: ac.primary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _announceRow(IconData icon, Color fg, Color bg, String text, String time) {
    final ac = AppColors.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: fg, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: AppText.bodySm.copyWith(color: ac.txt, height: 1.35)),
          const SizedBox(height: 3),
          Text(time, style: AppText.caption.copyWith(fontSize: 10.5, color: ac.muted)),
        ]),
      ),
    ]);
  }

  // ── Recommended row — live recent content, not hardcoded cards ──────────
  IconData _contentIcon(ContentType t) {
    switch (t) {
      case ContentType.note:          return Icons.article_rounded;
      case ContentType.pastPaper:     return Icons.description_rounded;
      case ContentType.book:          return Icons.menu_book_rounded;
      case ContentType.video:         return Icons.play_circle_fill_rounded;
      case ContentType.assignment:    return Icons.edit_note_rounded;
      case ContentType.presentation:  return Icons.slideshow_rounded;
      case ContentType.researchPaper: return Icons.science_rounded;
    }
  }

  (Color, Color) _contentColors(ContentType t) {
    switch (t) {
      case ContentType.note:          return (C.primaryBg, C.primary);
      case ContentType.pastPaper:     return (C.goldp, C.gold);
      case ContentType.book:          return (C.purb, C.pur);
      case ContentType.video:         return (C.grnb, C.grn);
      case ContentType.assignment:    return (C.blub, C.blu);
      case ContentType.presentation:  return (C.orgb, C.org);
      case ContentType.researchPaper: return (C.redb, C.red);
    }
  }

  Widget _recommendedRow() {
    return StreamBuilder<List<AcademicContent>>(
      stream: AcademicContentRepository.instance.watch(institutionId: _u?.schoolId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const ShimmerBlock(width: 160, height: 140),
            ),
          );
        }
        final items = (snap.data ?? const <AcademicContent>[]).take(6).toList();
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _emptyPanelRow(
              icon: Icons.auto_awesome_outlined,
              text: 'Nothing to recommend yet — content added to the Library '
                  'will show up here.',
            ),
          );
        }
        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = items[i];
              final (bg, fg) = _contentColors(item.contentType);
              final ac = AppColors.of(context);
              final isDark = context.watch<ThemeProvider>().isDark;
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(Rad.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.md),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (!_isGuest) {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AcademicContentPage(user: _u!)));
                    } else {
                      _open(context, const _LibraryDest());
                    }
                  },
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? ac.surf : bg,
                      borderRadius: BorderRadius.circular(Rad.md),
                      border: isDark ? Border(left: BorderSide(color: fg, width: 3)) : null,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Row(children: [
                        Icon(_contentIcon(item.contentType), size: 18, color: fg),
                        const SizedBox(width: 6),
                        Expanded(child: Text(item.contentType.label,
                            style: AppText.caption.copyWith(fontSize: 10, color: ac.muted))),
                      ]),
                    ]),
                  ),
                ),
              );
            },
          ),
        );
      },
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
class _CoursesDest extends StatelessWidget {
  const _CoursesDest();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class _ClubsDest extends StatelessWidget {
  const _ClubsDest();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class _MagazineDest extends StatelessWidget {
  const _MagazineDest();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class _PastQuestionsDest extends StatelessWidget {
  const _PastQuestionsDest();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Home banner carousel — isolated from the rest of Home ──────────
// Previously the whole Home page's setState() fired on every manual
// swipe (onPageChanged called setState on _UniversalHomePageState),
// so every section below — Quick Access, Today's Progress, Daily
// Challenge, Top Writers, everything — rebuilt on every swipe. That's
// exactly what looked/felt like "the page reloads" when swiping.
// This widget owns its own state entirely, so swiping only rebuilds
// itself. Also adds: auto-advancing slideshow (paused/reset on manual
// interaction so it doesn't fight the user), and a proper left-to-right
// fading gradient overlay (matching the technique already used
// elsewhere in this file) instead of a flat uniform darkening — so
// text stays readable on the left no matter what the banner image
// looks like on the right.
class _HomeBannerCarousel extends StatefulWidget {
  final void Function(HeroSlide) onOpenSlide;
  final bool isSuperAdmin;
  final String? userId;
  const _HomeBannerCarousel({required this.onOpenSlide, required this.isSuperAdmin, required this.userId});

  @override
  State<_HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<_HomeBannerCarousel> {
  final _ctrl = PageController();
  int _index = 0;
  Timer? _autoTimer;
  int _slideCount = 0;

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _restartAutoAdvance() {
    _autoTimer?.cancel();
    if (_slideCount <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_index + 1) % _slideCount;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HeroSlide>>(
      stream: HeroSlideRepository.instance.watchActive(),
      builder: (context, snap) {
        if (snap.hasError) {
          CrashService.instance.recordError(snap.error, snap.stackTrace,
              context: 'UniversalHomePage.watchActive');
          return ErrorView(message: "Couldn't load the banner — ${snap.error}");
        }
        final slides = snap.data ?? const <HeroSlide>[];

        if (slides.isEmpty) {
          _autoTimer?.cancel();
          // Nothing configured yet. superAdmin gets a nudge to add the
          // first slide via the in-app image manager; everyone else just
          // doesn't see the carousel — no fake placeholder banners.
          if (widget.isSuperAdmin && widget.userId != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HeroSlideManagerPage(createdByUid: widget.userId!))),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add your first Home banner'),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        if (_slideCount != slides.length) {
          _slideCount = slides.length;
          WidgetsBinding.instance.addPostFrameCallback((_) => _restartAutoAdvance());
        }

        return SizedBox(
          height: 190,
          child: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _restartAutoAdvance(); // manual swipe resets the auto timer, doesn't fight it
                },
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
                    color: i == _index ? C.gold : C.bdr,
                  ),
                ))),
          ]),
        );
      },
    );
  }

  Widget _bannerCard(HeroSlide slide) {
    final hasImage = slide.imageUrl != null && slide.imageUrl!.isEmpty == false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: TapScale(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Rad.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onOpenSlide(slide);
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [C.navy, C.navy2],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: Shad.md,
              ),
              child: Stack(fit: StackFit.expand, children: [
                if (hasImage)
                  KenBurnsImage(image: NetworkImage(slide.imageUrl!)),
                if (hasImage)
                  // Dark on the left, fading to transparent on the right —
                  // keeps the title/CTA readable regardless of what's in
                  // the image, instead of the old flat uniform darkening.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black87, Colors.black45, Colors.transparent],
                        stops: [0.0, 0.55, 1.0],
                        begin: Alignment.centerLeft, end: Alignment.centerRight,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(slide.headline, style: AppText.h2.copyWith(color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(slide.subtext, style: AppText.bodySm.copyWith(
                            color: Colors.white.withValues(alpha: .75))),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(10)),
                          child: Text(slide.ctaLabel, style: AppText.subtitle.copyWith(
                              color: C.navy, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                    if (!hasImage)
                      const Icon(Icons.school_rounded, size: 56, color: Colors.white24),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

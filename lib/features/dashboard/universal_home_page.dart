// lib/features/dashboard/universal_home_page.dart
// The one dashboard layout shared across Guest, Normal, Premium, and
// Student accounts — matches the reference design (greeting block, stat
// card, banner carousel, Quick Access grid, Upcoming/Announcements split,
// Recommended row) but themed to Academia's navy/gold system instead of
// generic purple.
//
// user == null            -> Guest (NPC placeholder, no stats, read-only)
// user.photoUrl == null   -> signed in, no photo -> NPC placeholder, real name
// user.photoUrl != null   -> real avatar
//
// NOTE: Upcoming / Recent Announcements / Recommended sections use mock
// data for now — real Firestore wiring is a follow-up pass. Quick Access
// tiles route to real pages where they exist, and to a "Coming Soon"
// placeholder where they don't yet.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/app_user.dart';
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

  // ── Banner carousel ──────────────────────────────────────────────────────
  Widget _bannerCarousel() {
    final banners = [
      ('Learn. Connect. Excel.',
          'Access resources, join clubs, track performance and achieve more.'),
      ('Every Past Question. One App.',
          'GCE, BEPC, BAC — search, revise, and download.'),
      ('Your Voice in the Magazine.',
          'Publish, get read, and build your name across schools.'),
    ];
    return SizedBox(
      height: 190,
      child: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _bannerCtrl,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemCount: banners.length,
            itemBuilder: (_, i) {
              final (title, body) = banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [C.navy, C.navy2],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(Rad.lg),
                    boxShadow: Shad.md,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: GoogleFonts.sora(
                            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(body, style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.white.withValues(alpha: .75), height: 1.4)),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(10)),
                          child: Text('Explore Now', style: GoogleFonts.sora(
                              fontSize: 12, fontWeight: FontWeight.w700, color: C.navy)),
                        ),
                      ]),
                    ),
                    const Icon(Icons.school_rounded, size: 56, color: Colors.white24),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (i) => Container(
              width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _bannerIndex ? C.gold : C.bdr,
              ),
            ))),
      ]),
    );
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

  // ── Quick Access grid ────────────────────────────────────────────────────
  Widget _quickAccessGrid(BuildContext context) {
    final items = <_QuickItem>[
      _QuickItem('Library', Icons.menu_book_rounded, C.primary, C.primaryBg,
          () => _open(context, const _LibraryDest())),
      _QuickItem('Past Questions', Icons.description_rounded, C.grn, C.grnb,
          () => _open(context, const ComingSoonPage(
              title: 'Past Questions', icon: Icons.description_rounded))),
      _QuickItem('Lecture Notes', Icons.sticky_note_2_rounded, C.gold, C.goldp,
          () => _open(context, const ComingSoonPage(
              title: 'Lecture Notes', icon: Icons.sticky_note_2_rounded))),
      _QuickItem('Assignments', Icons.assignment_rounded, C.blu, C.blub,
          () => _open(context, const _AssignmentsDest())),
      _QuickItem('Results', Icons.bar_chart_rounded, C.red, C.redb,
          () => _open(context, const _MarksDest())),
      _QuickItem('Timetable', Icons.calendar_month_rounded, C.pur, C.purb,
          () => _open(context, const _TimetableDest())),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final it = items[i];
          return GestureDetector(
            onTap: it.onTap,
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
                  decoration: BoxDecoration(color: it.bg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(it.icon, color: it.fg, size: 19),
                ),
                const SizedBox(height: 8),
                Text(it.label, textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: C.txt),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    );
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

  // ── Upcoming + Announcements split ──────────────────────────────────────
  Widget _upcomingAndAnnouncements() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(children: [
        _panelCard(
          title: 'Upcoming',
          child: Column(children: [
            _upcomingRow('MAY', '21', 'Debate Club Meeting', '3:00 PM – 5:00 PM · Students\' Lounge'),
            const Divider(height: 20, color: C.bdr2),
            _upcomingRow('MAY', '23', 'Economics Lecture', '10:00 AM – 12:00 PM · Room 302'),
            const Divider(height: 20, color: C.bdr2),
            _upcomingRow('MAY', '25', 'Assignment Due', 'Business Management · 11:59 PM'),
          ]),
        ),
        const SizedBox(height: 16),
        _panelCard(
          title: 'Recent Announcements',
          child: Column(children: [
            _announceRow(Icons.campaign_rounded, C.primary, C.primaryBg,
                'School resumes on Monday, 27th May.', '2 hours ago'),
            const SizedBox(height: 14),
            _announceRow(Icons.description_rounded, C.grn, C.grnb,
                'New past questions uploaded for Law 300 Level.', '5 hours ago'),
            const SizedBox(height: 14),
            _announceRow(Icons.groups_rounded, C.blu, C.blub,
                'Entrepreneurship workshop this Saturday!', '1 day ago'),
          ]),
        ),
      ]),
    );
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

  Widget _upcomingRow(String month, String day, String title, String sub) {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(month, style: GoogleFonts.sora(fontSize: 8, fontWeight: FontWeight.w700, color: C.red)),
          Text(day, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: C.red)),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.txt)),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: C.txt2)),
        ]),
      ),
      const Icon(Icons.chevron_right_rounded, color: C.muted, size: 18),
    ]);
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

class _QuickItem {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
  _QuickItem(this.label, this.icon, this.fg, this.bg, this.onTap);
}

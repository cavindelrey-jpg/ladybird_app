// lib/screens/app_router.dart
// Root navigator. 2026-09 correction: a fresh install (no session) shows
// VoucherEntryScreen FIRST — activate with a code or log in to an
// existing (already-activated) account — with guest browsing one tap
// away, not the default. Once signed in (including after a code is
// redeemed once), reopening the app skips straight to HomeShell — this
// screen only ever appears when authStateChanges reports signed-out, so
// a returning user with a live session, or one who reinstalls and logs
// back into their existing account, never sees it again. School
// membership (schoolId/schoolRole on AppUser) is orthogonal to the
// 6-role UserRole permission system, which still governs content
// moderation/authoring privilege independent of any school.

import 'dart:async';
import '../features/daily_learning/daily_challenge_gate.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../repositories/magazine_repository.dart';
import 'first_login_screen.dart';
// pages
import '../features/academic_content/library_home_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../pages/profile_page.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/school/parent_dashboard_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_content_sheet.dart';
import '../features/clubs/clubs_page.dart';
import '../features/onboarding/account_choice_screen.dart';
import '../features/onboarding/voucher_entry_screen.dart';
import 'dictionary_screen.dart';

// ────────────────────────────────────────────────────────────────────────────
// AppRouter — watches Firebase auth state only.
//
//  1. Nobody signed in → VoucherEntryScreen (the front door: activate
//     with a code, log in, or "continue browsing without a code" ->
//     _GuestShell).
//  2. Somebody IS signed in → HomeShell (via _AppUserGate).
// ────────────────────────────────────────────────────────────────────────────

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService.instance.authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      initialData: AuthService.instance.firebaseUser,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) {
          return const _SignedOutGate();
        }
        return const _AppUserGate();
      },
    );
  }
}

/// Toggles between the voucher/login front door and full guest browsing,
/// purely a local UI choice (never touches auth) — tapping "Continue
/// browsing without a code" on VoucherEntryScreen just swaps which of
/// these two this widget shows.
class _SignedOutGate extends StatefulWidget {
  const _SignedOutGate();
  @override
  State<_SignedOutGate> createState() => _SignedOutGateState();
}

class _SignedOutGateState extends State<_SignedOutGate> {
  bool _browsingAsGuest = false;

  @override
  Widget build(BuildContext context) {
    if (_browsingAsGuest) return const _GuestShell();
    return VoucherEntryScreen(onBrowseAsGuest: () => setState(() => _browsingAsGuest = true));
  }
}

/// Scaffold shown to signed-out Guests — same universal dashboard as
/// signed-in accounts, wrapped with the drawer and a lightweight bottom
/// nav. Tapping anything that needs an account routes to sign-up/sign-in.
class _GuestShell extends StatefulWidget {
  const _GuestShell();
  @override State<_GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<_GuestShell> {
  int _tab = 0;

  void _guestGate(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const AccountChoiceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final pages = [
      const UniversalHomePage(),
      ClubsPage(user: AppUser.guest()),
      const UniversalHomePage(),
      _GuestGateTab(onTap: () => _guestGate(context), label: 'Messages'),
      _GuestGateTab(onTap: () => _guestGate(context), label: 'Profile'),
    ];
    return Scaffold(
      drawer: AppDrawer(user: null, onHomeTap: () => setState(() => _tab = 0)),
      body: SafeArea(
        child: Column(
          children: [
            const _OfflineBanner(),
            Expanded(child: IndexedStack(index: _tab, children: pages)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ac.gold,
        onPressed: () => _guestGate(context),
        child: Icon(Icons.add_rounded, color: ac.navy),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        color: ac.surf,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _navIcon(ac, Icons.home_rounded, 'Home', 0),
          _navIcon(ac, Icons.groups_rounded, 'Groups', 1),
          const SizedBox(width: 40),
          _navIcon(ac, Icons.chat_bubble_outline_rounded, 'Messages', 3),
          _navIcon(ac, Icons.person_outline_rounded, 'Profile', 4),
        ]),
      ),
    );
  }

  Widget _navIcon(AppColors ac, IconData icon, String label, int index) {
    final selected = _tab == index;
    return InkWell(
      onTap: () => setState(() => _tab = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: selected ? ac.primary : ac.muted),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(
              fontSize: 9.5, color: selected ? ac.primary : ac.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _GuestGateTab extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _GuestGateTab({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: ac.muted),
            const SizedBox(height: 16),
            Text('Sign in to access $label',
                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 8),
            Text('Create a free account to join groups, message, and post.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: ac.txt2)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.navy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text('Create Free Account'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Gate for signed-in users — resolves the account (suspended / first-login
/// / normal) and lands on HomeShell.
class _AppUserGate extends StatefulWidget {
  const _AppUserGate();

  @override
  State<_AppUserGate> createState() => _AppUserGateState();
}

class _AppUserGateState extends State<_AppUserGate> {
  late Stream<AppUser?> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = AuthService.instance.currentAppUserStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userStream,
      initialData: AuthService.instance.lastKnownUser,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          // currentAppUserStream() only ever emits null after a
          // SUCCESSFUL fetch that found no row at all (account deleted
          // server-side) — a network failure/offline reconnect keeps
          // showing the last cached/known user instead of reaching
          // here, so this signOut() no longer fires on a connectivity
          // hiccup (see auth_service.dart's currentAppUserStream doc).
          AuthService.instance.signOut();
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user.status == AccountStatus.suspended) return _SuspendedScreen(user: user);
        if (user.isFirstLogin) return FirstLoginScreen(user: user);
        return DailyChallengeGate(user: user, child: HomeShell(user: user));
      },
    );
  }
}

class _SuspendedScreen extends StatelessWidget {
  final AppUser user;
  const _SuspendedScreen({required this.user});
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block_outlined, size: 64, color: ac.red),
          const SizedBox(height: 16),
          Text('Account Suspended',
              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 8),
          Text('Please contact support.',
              style: GoogleFonts.inter(color: ac.txt2), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton(
              onPressed: () => AuthService.instance.performSignOut(context),
              child: const Text('Sign Out')),
        ]),
      )),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HomeShell — role-gated bottom navigation
// ────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Recovery sweep for any magazine-read XP that was durably recorded
    // as "owed" (see MagazineRepository.recordRead()) but never settled
    // — e.g. this device was offline right after a reader's first visit.
    // Fire-and-forget, cheap no-op when nothing's pending; deliberately
    // not blocking the shell's first frame on it.
    unawaited(MagazineRepository.instance.settlePendingXp(widget.user.id));
  }

  // The bottom nav stays fixed — Home, Library, Magazine, Courses, Profile
  // — the same shape for every account, guest or signed-in.
  List<_NavDef> _buildNav() {
    final u = widget.user;
    final nav = <_NavDef>[
      const _NavDef('Home', Icons.home_rounded, Icons.home_outlined, UserRole.guest),
      const _NavDef('Groups', Icons.groups_rounded, Icons.groups_outlined, UserRole.guest),
      const _NavDef('Library', Icons.menu_book_rounded, Icons.menu_book_outlined, UserRole.guest),
      const _NavDef('Magazine', Icons.auto_stories_rounded, Icons.auto_stories_outlined, UserRole.guest),
      const _NavDef('Courses', Icons.school_rounded, Icons.school_outlined, UserRole.guest),
      const _NavDef('Profile', Icons.person_rounded, Icons.person_outlined, UserRole.guest),
    ];

    // Filter by minimum role (privilege gate)
    return nav.where((n) => u.hasMinRole(n.minRole)).toList();
  }

  Widget _buildPage(AppColors ac, _NavDef def) {
    final u = widget.user;
    // Guard check
    if (!u.hasMinRole(def.minRole)) {
      return Scaffold(body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: ac.muted),
            const SizedBox(height: 12),
            Text('Access Restricted',
                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          ])));
    }
    switch (def.label) {
      // Item 5: a parent's Home tab shows their linked student's
      // information (timetable/marks/homework), never their own —
      // there is no "own" student data for a parent account to show.
      case 'Home':     return u.isParent ? ParentDashboardPage(user: u) : UniversalHomePage(user: u);
      case 'Groups':   return ClubsPage(user: u);
      case 'Library':  return LibraryHomePage(user: u);
      case 'Magazine': return MagazineFeedPage(user: u);
      case 'Courses':  return CoursesHomePage(user: u);
      case 'Profile':  return ProfilePage(user: u);
      default:         return const SizedBox.shrink();
    }
  }

  // Lazy tab loading: IndexedStack previously built every single nav
  // page eagerly on shell mount (nav.map(_buildPage).toList()) — only
  // building it lazily (on first visit) keeps an untouched tab's own
  // Firestore streams from starting until it's actually opened.
  final Set<int> _visitedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final nav     = _buildNav();
    final safeTab = _tab.clamp(0, nav.length - 1);
    _visitedTabs.add(safeTab);

    return Scaffold(
      drawer: AppDrawer(user: widget.user, onHomeTap: () => setState(() => _tab = 0)),
      body: SafeArea(
        child: Column(children: [
          const _OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: safeTab,
              children: List.generate(nav.length,
                  (i) => _visitedTabs.contains(i) ? _buildPage(ac, nav[i]) : const SizedBox.shrink()),
            ),
          ),
        ]),
      ),
      // Architecture brief item 14: content creation lives behind this
      // one "+" button instead of permanent per-page CTA cards -- see
      // create_content_sheet.dart for the destinations it opens.
      floatingActionButton: FloatingActionButton(
        backgroundColor: ac.gold,
        onPressed: () => showCreateContentSheet(context, widget.user),
        child: Icon(Icons.add_rounded, color: ac.navy),
      ),
      bottomNavigationBar: DecoratedBox(
        // A restyle of the selected-tab indicator only (still a plain
        // Material 3 pill behind the active icon) — floated above the
        // page content with its own shadow/rounded top edge so it reads
        // as a distinct capsule bar rather than a flat strip. Tabs and
        // destinations below are untouched.
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
          boxShadow: Shad.lg,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
          child: NavigationBar(
            selectedIndex: safeTab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: nav.map((n) => NavigationDestination(
              icon: Icon(n.outlinedIcon), selectedIcon: Icon(n.filledIcon), label: n.label,
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final String label;
  final IconData filledIcon, outlinedIcon;
  final UserRole minRole;
  const _NavDef(this.label, this.filledIcon, this.outlinedIcon, this.minRole);
}


/// Tells the student they're offline and what still works, instead of
/// sections silently showing "nothing here yet".
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<bool>(
      stream: ConnectivityService().watchOffline(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: ac.orgBg,
          child: Row(children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: ac.org),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Offline — saved downloads & dictionary open.',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: ac.org),
            )),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DictionaryScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ac.org.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Dictionary', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.org)),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryHomePage(user: AppUser.guest()))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ac.org.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Downloads', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.org)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

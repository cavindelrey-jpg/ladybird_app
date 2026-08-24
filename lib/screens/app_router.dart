// lib/screens/app_router.dart
// Root navigator — single account model (Guest / Individual / Premium
// Silver / Premium Gold), no institution/school-linking. 6-role permission
// system retained for content moderation (student/lecturer/admin roles),
// independent of any school.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../repositories/magazine_repository.dart';
import 'first_login_screen.dart';
// pages
import '../features/academic_content/academic_content_page.dart';
import '../features/courses_marketplace/courses_marketplace_page.dart';
import '../pages/profile_page.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_content_sheet.dart';
import '../features/onboarding/account_choice_screen.dart';

// ────────────────────────────────────────────────────────────────────────────
// AppRouter — watches Firebase auth state only.
//
// Entry logic:
//  1. Nobody signed in → Guest is the true front door — full read access to
//     the feed, notes, past questions, magazine, etc. with no login wall.
//  2. Somebody IS signed in → HomeShell under the single Academia brand.
// ────────────────────────────────────────────────────────────────────────────

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) {
          // Guest: no login wall, browse everything read-only.
          return const _GuestShell();
        }
        return const _AppUserGate();
      },
    );
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
      _GuestGateTab(onTap: () => _guestGate(context), label: 'Clubs'),
      const UniversalHomePage(),
      _GuestGateTab(onTap: () => _guestGate(context), label: 'Messages'),
      _GuestGateTab(onTap: () => _guestGate(context), label: 'Profile'),
    ];
    return Scaffold(
      drawer: const AppDrawer(user: null),
      body: IndexedStack(index: _tab, children: pages),
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
          _navIcon(ac, Icons.groups_rounded, 'Clubs', 1),
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
            Text('Create a free account to join clubs, message, and post.',
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
class _AppUserGate extends StatelessWidget {
  const _AppUserGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.currentAppUserStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          FirebaseAuth.instance.signOut();
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user.status == AccountStatus.suspended) return _SuspendedScreen(user: user);
        if (user.isFirstLogin) return FirstLoginScreen(user: user);
        return HomeShell(user: user);
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
              onPressed: () => AuthService.instance.signOut(),
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
      case 'Home':     return UniversalHomePage(user: u);
      case 'Library':  return AcademicContentPage(user: u);
      case 'Magazine': return MagazineFeedPage(user: u);
      case 'Courses':  return CoursesMarketplacePage(user: u);
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
      drawer: AppDrawer(user: widget.user),
      body: SafeArea(
        child: IndexedStack(
          index: safeTab,
          children: List.generate(nav.length,
              (i) => _visitedTabs.contains(i) ? _buildPage(ac, nav[i]) : const SizedBox.shrink()),
        ),
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

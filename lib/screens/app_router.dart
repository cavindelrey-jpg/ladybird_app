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
import 'first_login_screen.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/school/parent_dashboard_page.dart';
import '../features/onboarding/voucher_entry_screen.dart';

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
    if (_browsingAsGuest) return HomeShell(user: AppUser.guest());
    return VoucherEntryScreen(onBrowseAsGuest: () => setState(() => _browsingAsGuest = true));
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
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt)),
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
// HomeShell — primary authenticated/guest landing
// ────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatelessWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.isParent) {
      return ParentDashboardPage(user: user);
    }
    return UniversalHomePage(user: user);
  }
}



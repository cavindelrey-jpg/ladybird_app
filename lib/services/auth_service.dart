// lib/services/auth_service.dart
//
// Supabase Auth + Postgres version — same public API (method names/
// signatures) as the pre-migration Firebase version so screens/pages
// didn't need to change. Ported from academia-cameroon's rewrite (same
// shared Supabase project/database — see AUTH_MIGRATION.md there).
//
// One forced behavioral difference from the Firebase version: no
// client-side self-account-deletion API exists in Supabase (that's an
// admin-only operation). This app never called that path anyway (no
// serial/seat-claim flow exists here), so it doesn't come up.
//
// Two real logic differences from academia-cameroon's own auth_service.dart,
// both preserved from this app's original Firebase version:
//   1. Audit logging on every login attempt (success / no-profile /
//      suspended / failed) — ported to AuditService.log() writing to
//      Supabase's audit_log_entries table (see analytics_service.dart).
//   2. recordDailyActivity() closes a real race condition (two
//      near-simultaneous calls both awarding streak XP) — ported to the
//      record_daily_activity() Postgres RPC (`select ... for update`),
//      same pattern as XpRepository's award_xp/spend_xp.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/branding.dart';
import '../models/models.dart';
import '../models/xp_transaction.dart';
import '../core/xp_rules.dart';
import '../core/result.dart';
import '../repositories/school_repository.dart';
import '../repositories/xp_repository.dart';
import '../screens/app_router.dart';
import '../widgets/widgets.dart';
import 'analytics_service.dart' show AuditService, AuditSeverity;
import 'app_user_cache_service.dart';
import 'message_cache_service.dart';
import '../core/realtime_tolerant.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _google = GoogleSignIn(scopes: ['email', 'profile']);

  User? get firebaseUser => _supabase.auth.currentUser;
  Stream<User?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map((state) => state.session?.user);

  AppUser? _lastKnownUser;
  AppUser? get lastKnownUser =>
      _lastKnownUser ??
      (firebaseUser != null
          ? AppUserCacheService.instance.getCachedInMemory(firebaseUser!.id)
          : null);

  Future<AppUser?> currentAppUser() async {
    final u = _supabase.auth.currentUser;
    if (u == null) return null;
    final row = await _supabase.from('users').select().eq('id', u.id).maybeSingle();
    if (row == null) return null;
    final user = AppUser.fromSupabase(row);
    _lastKnownUser = user;
    return user;
  }

  /// Live-updates whenever the user's row changes (XP awarded, streak
  /// recorded, profile edited, etc.) — the underlying Realtime `.stream()`
  /// requires an active websocket, which offline or a flaky reconnect
  /// breaks. This must NEVER be read as "this account doesn't exist" —
  /// _AppUserGate (screens/app_router.dart) treats a null emission from
  /// this stream as a reason to sign out, so a network hiccup must not
  /// produce one. Strategy: paint the cached row instantly (if any),
  /// replace it with a fresh one-time fetch as soon as that succeeds,
  /// then layer live Realtime updates on top — but a Realtime error is
  /// swallowed (logged only), never forwarded, so it can't blank out an
  /// already-known-good user. The only way this stream legitimately
  /// emits null is a *successful* fetch that finds no row at all (e.g.
  /// the account was really deleted server-side).
  Stream<AppUser?> currentAppUserStream() {
    final u = _supabase.auth.currentUser;
    if (u == null) return Stream.value(null);
    final uid = u.id;
    final controller = StreamController<AppUser?>();

    Future<void> emitCacheThenFetch() async {
      final cached = await AppUserCacheService.instance.getUser(uid);
      if (cached != null && !controller.isClosed) {
        _lastKnownUser = cached;
        controller.add(cached);
      }
      try {
        final fresh = await currentAppUser();
        if (controller.isClosed) return;
        if (fresh != null) {
          _lastKnownUser = fresh;
          unawaited(AppUserCacheService.instance.putUser(fresh));
          controller.add(fresh);
        } else if (cached == null) {
          // A real, successful "no row" result with nothing cached to
          // fall back on -- the only legitimate null emission.
          controller.add(null);
        }
        // fresh == null but cached != null: leave the cached value
        // showing rather than overwrite it with an absence we can't
        // yet distinguish from a transient blip.
      } catch (_) {
        // Network/REST failure -- keep showing whatever we already
        // emitted (cache or nothing yet); never emit null for this.
      }
    }

    unawaited(emitCacheThenFetch());

    final sub = _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .realtimeTolerant()
        .listen(
          (rows) {
            if (controller.isClosed) return;
            if (rows.isNotEmpty) {
              final user = AppUser.fromSupabase(rows.first);
              _lastKnownUser = user;
              unawaited(AppUserCacheService.instance.putUser(user));
              controller.add(user);
            }
            // An empty row list from a live update is far more likely a
            // transient resync than a genuine deletion (that already
            // went through the one-time-fetch "no row" path above) --
            // ignored rather than emitted as null.
          },
          onError: (_) {
            // Realtime disconnected/errored (offline, etc.) -- keep
            // showing whatever was last emitted, don't propagate.
          },
        );

    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  /// All three white-label apps (Green Hills, Ladybird, Academia) share
  /// one Supabase project/auth.users table, so credentials that are
  /// valid for one are valid for all of them unless the CLIENT enforces
  /// a brand check — Supabase Auth itself has no concept of "which app"
  /// a session came from. Voucher *redemption* already tenant-checks
  /// this way (SchoolAccessRepository.redeemSchoolVoucher passing
  /// Branding.current.voucherPrefix) — this is the same check applied
  /// at LOGIN, so an account already linked to Green Hills can't sign
  /// into the Ladybird app (or vice versa) just because both sit on the
  /// same backend. Academia is the shared, brand-agnostic hub (open to
  /// any paying account, including school-linked ones), so it's exempt.
  /// superAdmin always bypasses, matching the platform-owner role's
  /// existing "sees everything" contract everywhere else in the app.
  Future<void> _assertBelongsToThisBrand(AppUser user) async {
    if (Branding.current.brandId == 'academia' || user.isSuperAdmin) return;
    final mismatch = user.schoolId == null
        ? true
        : (await SchoolRepository.instance.getByIdOnce(user.schoolId!))?.code !=
            Branding.current.voucherPrefix;
    if (mismatch) {
      await _supabase.auth.signOut();
      unawaited(AuditService.instance.log(
        institutionId: user.schoolId, actorId: user.id, actorRole: user.roleLabel,
        action: 'login_blocked_wrong_brand', severity: AuditSeverity.warning,
      ));
      throw Exception(
          'This account isn\'t linked to ${Branding.current.appName}. '
          'Sign in from the app your school gave you a code for.');
    }
  }

  // Pre-launch audit: real login attempts (success, suspended-account
  // block, and failure) were not logged anywhere -- fire-and-forget
  // (unawaited, best-effort per AuditService.log's own contract) so a
  // slow/failed audit write never blocks or breaks the actual sign-in
  // flow. institutionId is left null for accounts with no schoolId (this
  // app's single-account model means that's most of them) rather than
  // the old Firestore 'platform' string sentinel, since audit_log_entries
  // .institution_id is a nullable uuid FK, not a free-text bucket.
  Future<AppUser?> signIn({required String email, required String password}) async {
    try {
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      final uid = res.user!.id;
      final row = await _supabase.from('users').select().eq('id', uid).maybeSingle();
      if (row == null) {
        unawaited(AuditService.instance.log(
          actorId: uid, actorRole: 'unknown',
          action: 'login_failed_no_profile', severity: AuditSeverity.warning,
        ));
        return null;
      }
      final user = AppUser.fromSupabase(row);
      if (user.status == AccountStatus.suspended) {
        await _supabase.auth.signOut();
        unawaited(AuditService.instance.log(
          institutionId: user.schoolId, actorId: uid, actorRole: user.roleLabel,
          action: 'login_blocked_suspended', severity: AuditSeverity.warning,
        ));
        throw Exception('This account has been suspended. Contact administration.');
      }
      await _assertBelongsToThisBrand(user);
      unawaited(AuditService.instance.log(
        institutionId: user.schoolId, actorId: uid, actorRole: user.roleLabel,
        action: 'login_success',
      ));
      return user;
    } on AuthException catch (e) {
      // Deliberately logs the email + error message, never the password --
      // useful for spotting a brute-force pattern against one account
      // without recording anything sensitive. actorId is left null here
      // (no uid exists yet for a failed sign-in) — the email goes in
      // metadata instead.
      unawaited(AuditService.instance.log(
        actorRole: 'unknown',
        action: 'login_failed', metadata: {'email': email, 'message': e.message},
        severity: AuditSeverity.warning,
      ));
      rethrow;
    }
  }

  Future<AppUser> signUpIndependent({
    required String email, required String password, required String name,
    UserRole role = UserRole.student,
  }) async {
    final res = await _supabase.auth.signUp(email: email, password: password);
    final uid = res.user!.id;
    final user = AppUser(
      id: uid, name: name, email: email,
      role: role, accountType: AccountType.independent, status: AccountStatus.active,
    );
    // handle_new_user (Postgres trigger) already inserted a bare row on
    // signUp — update it with the real profile fields rather than insert.
    await _supabase.from('users').update(user.toSupabase()).eq('id', uid);
    return user;
  }

  /// Runs the Google account picker and signs in. Returns null if the user
  /// cancels the picker — a normal outcome, not an error.
  Future<AppUser?> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw Exception('Google sign-in did not return an ID token.');
    }
    return signInWithGoogleTokens(idToken: googleAuth.idToken!, accessToken: googleAuth.accessToken);
  }

  Future<AppUser> signInWithGoogleTokens({required String idToken, String? accessToken}) async {
    final res = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google, idToken: idToken, accessToken: accessToken,
    );
    final u = res.user!;
    final uid = u.id;
    final row = await _supabase.from('users').select().eq('id', uid).maybeSingle();
    if (row != null) {
      final user = AppUser.fromSupabase(row);
      await _assertBelongsToThisBrand(user);
      return user;
    }
    // handle_new_user inserted a bare row already — fill in the Google
    // profile fields the trigger doesn't know about.
    final user = AppUser(
      id: uid, name: (u.userMetadata?['full_name'] as String?) ?? 'Student',
      email: u.email ?? '', photoUrl: u.userMetadata?['avatar_url'] as String?,
      role: UserRole.student, accountType: AccountType.independent, status: AccountStatus.active,
    );
    await _supabase.from('users').update(user.toSupabase()).eq('id', uid);
    await _assertBelongsToThisBrand(user);
    return user;
  }

  // ── Admin operations ───────────────────────────────────────────────────────
  Future<void> changeUserRole(String userId, UserRole newRole) =>
      _supabase.from('users').update({'role': newRole.pgValue}).eq('id', userId);

  Future<void> suspendUser(String userId) =>
      _supabase.from('users').update({'status': AccountStatus.suspended.name}).eq('id', userId);

  Future<void> reactivateUser(String userId) =>
      _supabase.from('users').update({'status': AccountStatus.active.name}).eq('id', userId);

  bool _isSigningOut = false;
  bool get isSigningOut => _isSigningOut;

  /// Explicit, immediate asynchronous logout with UI feedback.
  /// Shows a non-dismissible loading indicator, prevents duplicate taps,
  /// executes sign-out, and automatically cleans the navigation stack so the
  /// user transitions immediately to the signed-out state without needing
  /// to press the Android Back button.
  Future<void> performSignOut(BuildContext context) async {
    if (_isSigningOut) return;
    _isSigningOut = true;

    final nav = Navigator.of(context, rootNavigator: true);

    // Show immediate progress dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 20),
                Text(
                  'Signing out…',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await signOut();
      unawaited(MessageCacheService.instance.clearAll());

      // Pop all routes and land clean at AppRouter root
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppRouter()),
        (route) => false,
      );
    } catch (e) {
      if (nav.canPop()) {
        nav.pop();
      }
      if (context.mounted) {
        showToast(
          context,
          'Failed to sign out: ${e.toString().replaceAll("Exception:", "").trim()}. Please try again.',
          isError: true,
        );
      }
    } finally {
      _isSigningOut = false;
    }
  }

  Future<void> signOut() async {
    _lastKnownUser = null;
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null) unawaited(AppUserCacheService.instance.clear(uid));
    await _google.signOut();
    await _supabase.auth.signOut();
  }

  /// Re-authenticates with the current password, then sets the new one.
  /// Throws with a user-facing message on wrong-password / weak-password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('You must be signed in with an email account to change your password.');
    }
    try {
      // Supabase has no separate reauthenticate step — signInWithPassword
      // with the current password IS the reauth check (fails with
      // AuthApiException if wrong), then updateUser sets the new one.
      await _supabase.auth.signInWithPassword(email: user.email!, password: currentPassword);
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid')) throw Exception('Current password is incorrect.');
      if (e.message.toLowerCase().contains('weak') || e.message.toLowerCase().contains('short')) {
        throw Exception('New password is too weak.');
      }
      throw Exception(e.message);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> updateUser(AppUser user, Map<String, dynamic> fields) async {
    if (user.id.isEmpty) return;
    await _supabase.from('users').update(fields).eq('id', user.id);
  }

  static Future<void> markFirstLoginComplete(String userId) async =>
      Supabase.instance.client.from('users').update({'is_first_login': false}).eq('id', userId);

  // ── Gamification (real, minimal) ───────────────────────────────────────
  // Called once per Home page load. Decides — from the user's OWN last
  // activity date — whether the streak continues, resets, or is a no-op
  // for today. Never fabricates a number; every value here traces back to
  // an actual recorded day of app use.

  Future<void> recordDailyActivity(AppUser user) async {
    if (user.id.isEmpty) return; // guest — nothing to record

    // The old Firestore version wrapped this in a transaction specifically
    // to close a race (two near-simultaneous calls both reading "not
    // recorded yet" and both awarding streak XP). record_daily_activity()
    // is the same guarantee via `select ... for update` server-side —
    // only the caller that actually wins the row lock gets
    // should_award = true.
    final rows = await _supabase.rpc('record_daily_activity', params: {
      'p_user_id': user.id,
    }) as List;
    if (rows.isEmpty) return;
    final result = rows.first as Map<String, dynamic>;
    if (result['should_award'] != true) return;
    final newStreak = (result['new_streak'] as num?)?.toInt() ?? 0;

    // Real streak XP — the RPC's row lock means this whole block runs at
    // most once per calendar day per user, so there's no separate de-dup
    // check needed here. Best-effort: a failed XP award should never
    // block Home from loading.
    try {
      await XpRepository.instance.awardXp(
        user.id, XpSource.streakDaily, kStreakDailyXp,
      );
      final milestone = streakMilestoneBonusXp(newStreak);
      if (milestone > 0) {
        await XpRepository.instance.awardXp(
          user.id, XpSource.streakMilestone, milestone,
        );
      }
    } catch (_) {
      // best-effort, same policy as the streak-day write itself
    }
  }

  /// Awards XP for a decided source (quiz answer, magazine read, daily
  /// challenge, test — never an arbitrary bonus). Delegates to
  /// XpRepository.awardXp() so every XP source shares the same capped,
  /// logged ledger (xpBalance/lifetimeXP + xp_transactions) instead of
  /// writing a separate, cap-less `xpTotal` field the way this method
  /// used to. Returns the amount actually awarded (may be less than
  /// [amount] if the daily cap was hit) so callers can show an honest
  /// "+N XP" rather than assuming the full amount landed.
  Future<int> addXp(String userId, int amount, XpSource source) async {
    if (userId.isEmpty || amount <= 0) return 0;
    final result = await XpRepository.instance.awardXp(userId, source, amount);
    return switch (result) { Success(:final value) => value, Failure() => 0 };
  }

  /// Real, user-driven "Continue Reading" position — set by
  /// the content viewer page whenever the person turns a page.
  Future<void> setContinueReading(
    String userId, {
    required String itemId,
    required String title,
    required int page,
    int? totalPages,
  }) async {
    if (userId.isEmpty) return;
    await _supabase.from('users').update({
      'continue_reading_item_id': itemId,
      'continue_reading_title': title,
      'continue_reading_page': page,
      'continue_reading_total_pages': totalPages,
    }).eq('id', userId);
  }
}

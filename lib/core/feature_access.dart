// lib/core/feature_access.dart
// THE single authoritative feature-classification/entitlement registry.
//
// Every gate in the app — UI (show/hide/lock a tile), routes, deep links,
// services, and actions — MUST decide access by calling
// FeatureAccess.canAccess(user, feature) instead of re-deriving
// tier/role/auth logic inline. A second, slightly-different copy of "is
// this Silver or Gold" anywhere else in the codebase is exactly how an
// entitlement bypass creeps in (one call site upgraded, another
// forgotten). If a new feature needs a gate, add it to [AppFeature] and
// [_registry] here first, then call [FeatureAccess.canAccess] at the
// call site — never invent a local `user.isGold || user.isSilver` check.
//
// Role-gated features (lecturer/admin/staff tooling) are NOT decided
// here — those already have their own authoritative source of truth,
// AppUser.hasMinRole()/canX getters (models/app_user.dart), which this
// file deliberately does not duplicate. Such features are classified
// FeatureAccessLevel.unavailable in this registry (meaning: "not gated
// by account tier at all") and call sites gate them with the AppUser role
// check directly, same as before this registry existed.

import '../models/app_user.dart';

/// Every distinct access tier a feature can require.
enum FeatureAccessLevel {
  free,          // anyone, including a signed-out Guest
  authenticated, // any signed-in account, any entitlement tier
  silver,        // signed-in AND an active Silver-or-above entitlement
  gold,          // signed-in AND an active Gold entitlement
  unavailable,   // not gated by account tier — role-gated or staff-only,
                 // see file header
}

/// One entry per distinct feature/surface in the app. Names are the
/// feature/surface, not the screen class, so one feature reachable from
/// multiple entry points (e.g. a locked video reachable from both the
/// course card and a deep link) still has exactly one classification.
enum AppFeature {
  home,
  contentLibrary,       // Content Library / notes (academic_content)
  pastQuestions,        // Past papers (academic_content, pastPaper type)
  magazine,
  clubs,
  messages,
  coursesBrowse,        // Reading/browsing text course lessons
  coursesVideoLessons,  // Video Courses — Gold only
  testsQuizzes,
  dailyChallenge,
  xpDashboard,
  announcements,
  profile,
  settings,
  bookmarks,
  notifications,
  redeemVoucher,
  courseCreation,       // Writing/publishing a course
  magazineComposer,     // Writing/publishing a magazine article
  salesDesk,            // Staff-only — role-gated, see file header
  gradingQueue,         // Lecturer+ — role-gated, see file header
  testComposer,         // Lecturer+ — role-gated, see file header
}

class FeatureAccess {
  FeatureAccess._();

  static const Map<AppFeature, FeatureAccessLevel> _registry = {
    AppFeature.home:               FeatureAccessLevel.free,
    AppFeature.contentLibrary:     FeatureAccessLevel.free,
    AppFeature.pastQuestions:      FeatureAccessLevel.free,
    AppFeature.magazine:           FeatureAccessLevel.free,
    AppFeature.clubs:              FeatureAccessLevel.authenticated,
    AppFeature.messages:           FeatureAccessLevel.authenticated,
    AppFeature.coursesBrowse:      FeatureAccessLevel.free,
    AppFeature.coursesVideoLessons:FeatureAccessLevel.gold,
    AppFeature.testsQuizzes:       FeatureAccessLevel.free,
    AppFeature.dailyChallenge:     FeatureAccessLevel.authenticated,
    AppFeature.xpDashboard:        FeatureAccessLevel.authenticated,
    AppFeature.announcements:      FeatureAccessLevel.free,
    AppFeature.profile:            FeatureAccessLevel.authenticated,
    AppFeature.settings:           FeatureAccessLevel.authenticated,
    AppFeature.bookmarks:          FeatureAccessLevel.authenticated,
    AppFeature.notifications:      FeatureAccessLevel.authenticated,
    AppFeature.redeemVoucher:      FeatureAccessLevel.authenticated,
    AppFeature.courseCreation:     FeatureAccessLevel.authenticated,
    AppFeature.magazineComposer:   FeatureAccessLevel.authenticated,
    AppFeature.salesDesk:          FeatureAccessLevel.unavailable,
    AppFeature.gradingQueue:       FeatureAccessLevel.unavailable,
    AppFeature.testComposer:       FeatureAccessLevel.unavailable,
  };

  static FeatureAccessLevel levelOf(AppFeature feature) =>
      _registry[feature] ?? FeatureAccessLevel.unavailable;

  /// THE access check. Pass the real signed-in user, or null/AppUser.guest()
  /// for a signed-out visitor — both are treated identically (a guest
  /// placeholder has `id.isEmpty`, same as [AppUser.isGuest]).
  static bool canAccess(AppUser? user, AppFeature feature) {
    final level = levelOf(feature);
    final u = user ?? AppUser.guest();
    switch (level) {
      case FeatureAccessLevel.free:
        return true;
      case FeatureAccessLevel.authenticated:
        return !u.isGuest;
      case FeatureAccessLevel.silver:
        // Gold also satisfies a Silver gate — Gold is a superset of Silver.
        return !u.isGuest && u.entitlement.isActive;
      case FeatureAccessLevel.gold:
        return !u.isGuest && u.isGold;
      case FeatureAccessLevel.unavailable:
        // Not decided here by design — the call site must use the
        // relevant AppUser role check (hasMinRole/canX) instead. Default
        // closed so a feature added here without a role check elsewhere
        // fails safe rather than silently opening to everyone.
        return false;
    }
  }

  /// Short, user-facing reason a locked feature is locked — for an
  /// upgrade sheet / "sign in" prompt copy. Empty string if not blocked.
  static String reasonBlocked(AppUser? user, AppFeature feature) {
    if (canAccess(user, feature)) return '';
    final level = levelOf(feature);
    final u = user ?? AppUser.guest();
    switch (level) {
      case FeatureAccessLevel.authenticated:
        return 'Sign in to continue.';
      case FeatureAccessLevel.silver:
        return 'Upgrade to Premium to continue.';
      case FeatureAccessLevel.gold:
        return u.isSilver
            ? 'Video Courses need Premium Gold — upgrade to unlock.'
            : 'Upgrade to Premium Gold to continue.';
      case FeatureAccessLevel.free:
      case FeatureAccessLevel.unavailable:
        return 'This isn\'t available.';
    }
  }
}

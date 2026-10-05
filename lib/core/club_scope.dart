// lib/core/club_scope.dart
import '../config/branding.dart';
import '../models/app_user.dart';
import '../models/club.dart';

/// Enforces strict multi-tenant school-scoped visibility for academic groups/clubs.
///
/// Core Rules:
/// 1. School-branded apps (Ladybird, Green Hills, St. Stephen, etc.):
///    - Club visibility is strictly determined by the school/app context.
///    - Even a Super Admin inside a school-branded app only sees that school's clubs.
///    - Teachers, Admins, Class Masters, and Students NEVER get cross-school club access.
/// 2. Academia General app:
///    - Only Super Admins in the central Academia General environment have cross-school visibility.
///    - Ordinary users in Academia General see only their linked school's clubs, or general
///      Academia clubs if unlinked.
/// 3. Cross-school clubs must never leak through discovery, search, recommendations,
///    direct link navigation, chat, posts, discussions, or management.
class ClubScope {
  ClubScope._();

  /// Canonicalizes school/institution slugs so slight variations (e.g. green_hill vs green_hills)
  /// map cleanly to their uniform tenant identifier.
  static String? normalizeSchoolId(String? id) {
    if (id == null) return null;
    final s = id.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'green_hill' || s == 'green_hills' || s == 'greenhill' || s == 'greenhills') {
      return 'green_hill';
    }
    if (s == 'ladybird' || s == 'ladybird_app' || s == 'lady_bird') {
      return 'ladybird';
    }
    if (s == 'st_stephen' || s == 'ststephen' || s == 'st_stephens') {
      return 'st_stephen';
    }
    if (s == 'academia' || s == 'general' || s == 'academia_general') {
      return 'academia';
    }
    return s;
  }

  /// Resolves the permitted school identifier for the current context.
  ///
  /// Returns `null` ONLY when operating inside the Academia General app AND the user
  /// is a Super Admin (granting cross-school platform-wide access).
  ///
  /// In all other cases (including any user or super admin inside a school-branded app),
  /// returns the non-null school identifier for the school context.
  static String? resolveSchoolId({
    AppUser? user,
    String? explicitSchoolId,
    Branding? branding,
  }) {
    final brand = branding ?? Branding.current;

    // School-branded applications: isolation is absolute.
    // Even a super admin inside a school app MUST NOT see cross-school clubs.
    if (!brand.isGeneralApp) {
      final appSchoolId = brand.effectiveSchoolId ?? brand.schoolId ?? brand.brandId;
      return normalizeSchoolId(appSchoolId);
    }

    // Inside Academia General application:
    // Only super-admin team has cross-school visibility.
    if (user != null && user.isSuperAdmin) {
      return null;
    }

    // Non-super-admin in Academia General:
    if (explicitSchoolId != null && explicitSchoolId.isNotEmpty) {
      return normalizeSchoolId(explicitSchoolId);
    }
    if (user?.schoolId != null && user!.schoolId!.isNotEmpty) {
      return normalizeSchoolId(user.schoolId);
    }
    return 'academia';
  }

  /// Evaluates whether a club is visible and accessible in the current app and user context.
  static bool canAccessClub(
    Club club, {
    AppUser? user,
    Branding? branding,
  }) {
    final allowedSchoolId = normalizeSchoolId(resolveSchoolId(user: user, branding: branding));
    if (allowedSchoolId == null) {
      // Academia General Super Admin has authorized cross-school access
      return true;
    }

    final clubSchool = normalizeSchoolId(club.schoolId);
    if (clubSchool == null || clubSchool.isEmpty) {
      // Unscoped clubs only appear in 'academia' context, never in school-branded apps
      return allowedSchoolId == 'academia';
    }

    return clubSchool == allowedSchoolId;
  }
}

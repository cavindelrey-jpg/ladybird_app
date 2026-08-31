// lib/models/school_voucher.dart
// 2026-08-31 voucher redesign: a school voucher is no longer just a
// membership grant, it's a compact AUTHORIZATION TOKEN. Every code
// carries four delimited segments (delimited, not concatenated-and-
// inferred -- explicit '-' boundaries make generation/validation/
// revocation/lookup unambiguous):
//
//   {SCHOOL}-{ROLE}-{RANDOM6}-{PREMIUM}    e.g. GH-T-6X8294-G
//
// which tells the backend, in one lookup: which school/tenant this
// account may belong to, what role they hold there, and what premium
// entitlement tier comes with it -- see redeem_school_voucher() in
// supabase/migrations/20260831000000_unified_voucher_authorization.sql
// for the server-side authority (the actual security boundary; this
// model's parsing is a client-side convenience/UX layer only).
//
// Deliberately still a SEPARATE model from lib/models/academia_voucher.dart
// (the AC-prefixed equivalent for the school-less Academia brand) and from
// lib/models/voucher.dart (the older opaque-code content-only voucher,
// kept only for any already-issued codes still outstanding).

import 'dart:math';
import 'app_user.dart';

/// A user's role WITHIN their school, orthogonal to [UserRole] (Academia's
/// platform-wide content-authoring privilege axis). Stored on
/// AppUser.schoolRole; null means "not part of any school's app experience
/// yet". `itSupport`'s code/label were repointed to 'I'/"Super Admin" in
/// the 2026-08-31 redesign (product spec's school role list is
/// Student/Teacher/Class Master/Administrator/Super Admin) -- its
/// [contentRole] ceiling stays `schoolAdmin`, same as `admin`, NOT the
/// platform-wide `UserRole.superAdmin`: that ceiling is a deliberate
/// security boundary documented in
/// supabase/migrations/20260829530000_super_admin_vouchers.sql (granting
/// real platform superAdmin only ever happens through that separate,
/// super_admin-only-mintable flow, never through an institution-scoped
/// school voucher). The enum member keeps its original Dart name
/// (`itSupport`) to avoid an exhaustive-switch rename sweep across the
/// codebase; only its user-facing code/label/privilege changed.
enum SchoolRole { student, parent, teacher, classMaster, admin, itSupport }

extension SchoolRoleX on SchoolRole {
  /// The prefix segment used inside voucher codes — kept short since it's
  /// typed by hand off a printed slip.
  String get code {
    switch (this) {
      case SchoolRole.student:     return 'S';
      case SchoolRole.parent:      return 'P';
      case SchoolRole.teacher:     return 'T';
      case SchoolRole.classMaster: return 'CM';
      case SchoolRole.admin:       return 'A';
      case SchoolRole.itSupport:   return 'I';
    }
  }

  String get label {
    switch (this) {
      case SchoolRole.student:     return 'Student';
      case SchoolRole.parent:      return 'Parent';
      case SchoolRole.teacher:     return 'Teacher';
      case SchoolRole.classMaster: return 'Class Master';
      case SchoolRole.admin:       return 'Administrator';
      case SchoolRole.itSupport:   return 'Super Admin';
    }
  }

  /// Every SchoolRole maps to a real [UserRole] so the existing
  /// content-privilege axis stays meaningful for school staff. Parent
  /// deliberately maps to `guest` (no content-authoring rights). `admin`
  /// and `itSupport` share the same `schoolAdmin` ceiling — see the enum
  /// doc comment for why `itSupport`/"Super Admin" does NOT reach
  /// `UserRole.superAdmin`. Mirrored server-side in
  /// redeem_school_voucher() — keep both in sync.
  UserRole get contentRole {
    switch (this) {
      case SchoolRole.student:     return UserRole.student;
      case SchoolRole.parent:      return UserRole.guest;
      case SchoolRole.teacher:     return UserRole.lecturer;
      case SchoolRole.classMaster: return UserRole.lecturer;
      case SchoolRole.admin:       return UserRole.schoolAdmin;
      case SchoolRole.itSupport:   return UserRole.schoolAdmin;
    }
  }

  /// Fixed premium rule (redesign item 6): true for every role EXCEPT
  /// student, whose issuer picks Silver or Gold, and parent, who never
  /// gets a content-premium tier (functional parent access instead).
  bool get isAlwaysGold =>
      this == SchoolRole.teacher || this == SchoolRole.classMaster ||
      this == SchoolRole.admin || this == SchoolRole.itSupport;

  static SchoolRole? fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'S':  return SchoolRole.student;
      case 'P':  return SchoolRole.parent;
      case 'T':  return SchoolRole.teacher;
      case 'CM': return SchoolRole.classMaster;
      case 'A':  return SchoolRole.admin;
      case 'I':  return SchoolRole.itSupport;
      default:   return null;
    }
  }

  static SchoolRole? fromName(String name) {
    for (final r in SchoolRole.values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// The premium content-entitlement tier a voucher's final segment
/// encodes. `null` on [SchoolVoucher.premiumTier] means the 'N' (none)
/// segment — only ever used for an auto-issued parent-role code, which
/// grants functional parent access without a content-premium perk.
enum VoucherPremiumTier { silver, gold }

extension VoucherPremiumTierX on VoucherPremiumTier {
  String get code => this == VoucherPremiumTier.gold ? 'G' : 'S';
  String get label => this == VoucherPremiumTier.gold ? 'Gold' : 'Silver';

  static VoucherPremiumTier? fromCode(String c) {
    switch (c.toUpperCase()) {
      case 'G': return VoucherPremiumTier.gold;
      case 'S': return VoucherPremiumTier.silver;
      default:  return null;
    }
  }
}

enum SchoolVoucherStatus { unused, redeemed, revoked }

/// Parsed shape of a school voucher code — returned by [SchoolVoucher.parse]
/// for validation/generation without needing a full [SchoolVoucher] row.
typedef ParsedSchoolVoucherCode = ({
  String schoolCode,
  SchoolRole role,
  String random,
  VoucherPremiumTier? premium,
});

class SchoolVoucher {
  /// The row id AND the full code the user types in — the dashed display
  /// form itself (e.g. `GH-T-6X8294-G`) IS the id now: the '-' delimiters
  /// are load-bearing for parsing, not merely decorative, so there's no
  /// separate "strip dashes for storage" step anymore. Same "id IS the
  /// code" reasoning as before: atomic redemption needs a direct row read
  /// under a lock, and RLS deliberately doesn't expose a client-side
  /// query path for this table.
  final String id;
  String get code => id;

  final String schoolId;
  final String schoolCode;
  final SchoolRole role;

  /// Null only for an auto-issued parent-role voucher (the 'N' segment).
  final VoucherPremiumTier? premiumTier;

  final SchoolVoucherStatus status;

  /// Set only on a parent-role row: the id of the student voucher it was
  /// issued alongside (redesign item 4 — School -> Student -> Parent).
  final String? linkedStudentVoucherId;

  final DateTime createdAt;
  final DateTime? redeemedAt;
  final String? redeemedByUserId;
  final String createdByUid;

  const SchoolVoucher({
    required this.id,
    required this.schoolId,
    required this.schoolCode,
    required this.role,
    this.premiumTier,
    this.status = SchoolVoucherStatus.unused,
    this.linkedStudentVoucherId,
    required this.createdAt,
    this.redeemedAt,
    this.redeemedByUserId,
    this.createdByUid = '',
  });

  bool get isRedeemable => status == SchoolVoucherStatus.unused;

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no O/0, I/1/L — same as Voucher
  static const int _randomLen = 6;

  /// [schoolCode] e.g. "GH", already validated against School.code by the
  /// caller (SchoolAccessRepository). [premiumTier] is null only when
  /// issuing an auto-generated parent code (item 4); every other role
  /// must pass one (student: issuer's choice; every staff role: forced
  /// Gold — see [SchoolRoleX.isAlwaysGold] and issueVouchers()). Uses
  /// [Random.secure] so a predictable PRNG can't let someone who's seen
  /// one code derive others issued around it.
  static String generateCode({
    required String schoolCode,
    required SchoolRole role,
    VoucherPremiumTier? premiumTier,
  }) {
    final rnd = Random.secure();
    final random = List.generate(_randomLen, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
    final premiumSeg = premiumTier?.code ?? 'N';
    return '${schoolCode.toUpperCase()}-${role.code}-$random-$premiumSeg';
  }

  /// Uppercases and strips everything outside A-Z/0-9/dash so
  /// `gh-t 6x8294-g` still resolves to the same code. Deliberately NOT
  /// filtered against [_alphabet] here — that confusable-free 31-char
  /// set only constrains what [generateCode] puts in the RANDOM segment;
  /// the school prefix and role segments are real letters chosen for
  /// meaning, not randomness, and legitimately include characters
  /// [_alphabet] excludes (e.g. Ladybird's "LB" prefix has an L, the
  /// itSupport/"Super Admin" role code is "I" — both would silently get
  /// stripped by an [_alphabet]-only filter, corrupting the code before
  /// [parse] ever sees it).
  static String normalizeCode(String raw) {
    // Whitespace -> dash BEFORE filtering, not just dropped: with real
    // delimiters now load-bearing, a typo'd space in place of a dash
    // (mobile autocorrect does this) must still land on a segment
    // boundary, not silently glue two segments together.
    final upper = raw.toUpperCase().trim().replaceAll(RegExp(r'\s+'), '-');
    final buf = StringBuffer();
    for (final ch in upper.split('')) {
      if (RegExp(r'[A-Z0-9-]').hasMatch(ch)) buf.write(ch);
    }
    // Collapses any run of dashes into one -- e.g. a space typed right
    // next to an already-present dash would otherwise produce "--" and
    // throw off parse()'s exact 4-segment split.
    return buf.toString().replaceAll(RegExp(r'-+'), '-');
  }

  /// Splits a normalized code into its four explicit segments. Returns
  /// null for anything that isn't exactly {SCHOOL}-{ROLE}-{RANDOM6}-
  /// {PREMIUM} shaped — explicit delimiters mean this is a real parse,
  /// not a length-inference guess.
  static ParsedSchoolVoucherCode? parse(String normalized) {
    final parts = normalized.split('-');
    if (parts.length != 4) return null;
    final schoolCode = parts[0];
    if (schoolCode.isEmpty) return null;
    final role = SchoolRoleX.fromCode(parts[1]);
    if (role == null) return null;
    final random = parts[2];
    if (random.length != _randomLen) return null;
    final premiumSeg = parts[3];
    VoucherPremiumTier? premium;
    if (premiumSeg == 'N') {
      premium = null;
    } else {
      premium = VoucherPremiumTierX.fromCode(premiumSeg);
      if (premium == null) return null;
    }
    return (schoolCode: schoolCode, role: role, random: random, premium: premium);
  }

  static bool isPlausibleCode(String raw) => parse(normalizeCode(raw)) != null;

  /// The code is already the display form (dashed) — kept as a named
  /// static so call sites that used to reformat an id don't need to
  /// change shape, but it's now the identity function.
  static String formatCode(String normalized) => normalized;

  factory SchoolVoucher.fromSupabase(Map<String, dynamic> d) => SchoolVoucher(
        id: d['id']?.toString() ?? '',
        schoolId: d['school_id']?.toString() ?? '',
        schoolCode: d['school_code']?.toString() ?? '',
        role: SchoolRoleX.fromName(d['role']?.toString() ?? '') ?? SchoolRole.student,
        premiumTier: _premiumFromColumn(d['premium_tier']?.toString()),
        status: SchoolVoucherStatus.values.firstWhere(
            (s) => s.name == d['status']?.toString(),
            orElse: () => SchoolVoucherStatus.unused),
        linkedStudentVoucherId: d['linked_student_voucher_id']?.toString(),
        createdAt: _dt(d['created_at']) ?? DateTime.now(),
        redeemedAt: _dt(d['redeemed_at']),
        redeemedByUserId: d['redeemed_by_user_id']?.toString(),
        createdByUid: d['created_by_uid']?.toString() ?? '',
      );

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'code': code,
        'school_id': schoolId,
        'school_code': schoolCode,
        'role': role.name,
        'premium_tier': premiumTier == null ? 'none' : premiumTier!.name,
        'status': status.name,
        'linked_student_voucher_id': linkedStudentVoucherId,
        'created_by_uid': createdByUid,
      };

  static VoucherPremiumTier? _premiumFromColumn(String? v) {
    if (v == null || v == 'none') return null;
    return VoucherPremiumTier.values.firstWhere((t) => t.name == v, orElse: () => VoucherPremiumTier.silver);
  }

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
}

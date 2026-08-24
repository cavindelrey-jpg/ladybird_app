// lib/models/school_voucher.dart
// Architecture brief items 2-6: school access is granted through a
// voucher, never by simply holding any signed-in account. Deliberately a
// SEPARATE model from lib/models/voucher.dart -- that one grants a
// content ENTITLEMENT (Silver/Gold premium) to any account and is keyed
// by an opaque random code by design (nothing about it should be
// guessable). This one grants SCHOOL MEMBERSHIP + ROLE, and item 4
// explicitly asks the code to be self-describing on its face:
//
//   [SCHOOL CODE][ROLE CODE][UNIQUE IDENTIFIER]   e.g. GHS-4K9QX7M2
//
// The prefix is for humans (printed on an enrollment slip, readable at a
// glance), not the security boundary -- the security boundary is the
// same one lib/models/voucher.dart already uses: the full code is the
// Firestore document id, redemption is a single transaction keyed off
// that id, and the random suffix is long enough (8 chars from a 31-char
// alphabet, ~1.4e11 possibilities per school+role prefix) that guessing
// one is not practical even knowing the prefix. See
// SchoolAccessRepository.redeemSchoolVoucher for the transaction itself
// and firestore.rules' `school_vouchers/{code}` match for the
// server-side half.

import 'dart:math';
import 'app_user.dart';

/// A user's role WITHIN their school, orthogonal to [UserRole] (which is
/// Academia's platform-wide content-authoring privilege axis and stays
/// unchanged by this feature). Stored on AppUser.schoolRole; null means
/// "not part of any school's app experience yet".
enum SchoolRole { student, parent, teacher, classMaster, admin }

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
    }
  }

  String get label {
    switch (this) {
      case SchoolRole.student:     return 'Student';
      case SchoolRole.parent:      return 'Parent';
      case SchoolRole.teacher:     return 'Teacher';
      case SchoolRole.classMaster: return 'Class Master';
      case SchoolRole.admin:       return 'Administrator';
    }
  }

  /// Every SchoolRole maps to a real [UserRole] so the existing
  /// content-privilege axis (canUploadContent/canPostAnnouncement/
  /// canManageUsers/canManageSchool) stays meaningful for school staff
  /// without inventing a second privilege system. A class master is also
  /// a teacher for content purposes, so both map to `lecturer`. Parent
  /// deliberately maps to `guest` (no content-authoring rights) —
  /// matching the mapping AppUser._parseRole already used for the legacy
  /// 'parent' string, so this isn't a new convention.
  UserRole get contentRole {
    switch (this) {
      case SchoolRole.student:     return UserRole.student;
      case SchoolRole.parent:      return UserRole.guest;
      case SchoolRole.teacher:     return UserRole.lecturer;
      case SchoolRole.classMaster: return UserRole.lecturer;
      case SchoolRole.admin:       return UserRole.schoolAdmin;
    }
  }

  static SchoolRole? fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'S':  return SchoolRole.student;
      case 'P':  return SchoolRole.parent;
      case 'T':  return SchoolRole.teacher;
      case 'CM': return SchoolRole.classMaster;
      case 'A':  return SchoolRole.admin;
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

enum SchoolVoucherStatus { unused, redeemed, revoked }

class SchoolVoucher {
  /// Firestore document id AND the full code the user types in —
  /// normalized (uppercase, dash stripped for the id; display form below
  /// keeps a dash for readability). Same "id IS the code" reasoning as
  /// lib/models/voucher.dart: atomic redemption needs a direct document
  /// read, and the client SDK cannot query inside a transaction.
  final String id;
  final String code;

  final String schoolId;
  final String schoolCode;
  final SchoolRole role;
  final SchoolVoucherStatus status;

  final DateTime createdAt;
  final DateTime? redeemedAt;
  final String? redeemedByUserId;
  final String createdByUid;

  const SchoolVoucher({
    required this.id,
    required this.code,
    required this.schoolId,
    required this.schoolCode,
    required this.role,
    this.status = SchoolVoucherStatus.unused,
    required this.createdAt,
    this.redeemedAt,
    this.redeemedByUserId,
    this.createdByUid = '',
  });

  bool get isRedeemable => status == SchoolVoucherStatus.unused;

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no O/0, I/1/L — same as Voucher
  static const int _suffixLen = 8;

  /// [schoolCode] e.g. "GH", already validated against School.code by the
  /// caller (SchoolAccessRepository). Uses [Random.secure] for the same
  /// reason lib/models/voucher.dart does — a predictable PRNG would let
  /// someone who's seen one code derive others issued around it.
  static String generateCode({required String schoolCode, required SchoolRole role}) {
    final rnd = Random.secure();
    final suffix = List.generate(_suffixLen, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
    return '${schoolCode.toUpperCase()}${role.code}$suffix';
  }

  /// Uppercases and strips everything outside the alphabet (plus digits
  /// already in it) so `gh s-4k9q x7m2` still resolves to the same code —
  /// same forgiving-input reasoning as Voucher.normalizeCode.
  static String normalizeCode(String raw) {
    final upper = raw.toUpperCase();
    final buf = StringBuffer();
    for (final ch in upper.split('')) {
      if (_alphabet.contains(ch)) buf.write(ch);
    }
    return buf.toString();
  }

  /// Display form with a dash before the random suffix: GHS4K9QX7M2 ->
  /// GHS-4K9QX7M2. The prefix length is variable (school code + role
  /// code), so this just inserts a dash [_suffixLen] characters from the
  /// end rather than assuming a fixed split point.
  static String formatCode(String normalized) {
    if (normalized.length <= _suffixLen) return normalized;
    final split = normalized.length - _suffixLen;
    return '${normalized.substring(0, split)}-${normalized.substring(split)}';
  }

  static bool isPlausibleCode(String raw) => normalizeCode(raw).length > _suffixLen;

  factory SchoolVoucher.fromFirestore(String id, Map<String, dynamic> d) => SchoolVoucher(
        id: id,
        code: d['code']?.toString() ?? formatCode(id),
        schoolId: d['schoolId']?.toString() ?? '',
        schoolCode: d['schoolCode']?.toString() ?? '',
        role: SchoolRoleX.fromName(d['role']?.toString() ?? '') ?? SchoolRole.student,
        status: SchoolVoucherStatus.values.firstWhere(
            (s) => s.name == d['status']?.toString(),
            orElse: () => SchoolVoucherStatus.unused),
        createdAt: _dt(d['createdAt']) ?? DateTime.now(),
        redeemedAt: _dt(d['redeemedAt']),
        redeemedByUserId: d['redeemedByUserId']?.toString(),
        createdByUid: d['createdByUid']?.toString() ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'code': code,
        'schoolId': schoolId,
        'schoolCode': schoolCode,
        'role': role.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'redeemedAt': redeemedAt?.toIso8601String(),
        'redeemedByUserId': redeemedByUserId,
        'createdByUid': createdByUid,
      };

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    try {
      return (v as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}

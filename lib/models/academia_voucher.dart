// lib/models/academia_voucher.dart
// The Academia-brand equivalent of lib/models/school_voucher.dart —
// same authorization-token design (2026-08-31 redesign), minus a school
// tenant: this only exists for BRAND_ID=academia builds (Branding.
// current.voucherPrefix == 'AC'), where there's no institution to scope
// membership to. Format:
//
//   AC-{ROLE}-{RANDOM6}-{PREMIUM}    e.g. AC-U-7K492X-S
//
// Deliberately a separate model/table (academia_vouchers) from
// school_vouchers rather than a null-school_id row in that table — the
// RLS story is different (issuance is super_admin-only/platform-wide,
// not "staff of your own school"), and keeping them apart means the
// school_vouchers redemption RPC never has to branch on "is this actually
// a schoolless Academia code".

import 'dart:math';
import 'app_user.dart';
import 'school_voucher.dart' show VoucherPremiumTier, VoucherPremiumTierX;

/// `user` = a normal Academia account; `superAdmin` = platform owner /
/// IT team, always Gold (redesign item 6).
enum AcademiaRole { user, superAdmin }

extension AcademiaRoleX on AcademiaRole {
  String get code => this == AcademiaRole.superAdmin ? 'I' : 'U';
  String get label => this == AcademiaRole.superAdmin ? 'Super Admin / IT' : 'User';

  /// `user` doesn't change the platform-wide [UserRole] at all — only
  /// `superAdmin` does (redeem_academia_voucher() raises role_level the
  /// same "only ever rises" way redeem_school_voucher() does).
  UserRole? get contentRole => this == AcademiaRole.superAdmin ? UserRole.superAdmin : null;

  bool get isAlwaysGold => this == AcademiaRole.superAdmin;

  static AcademiaRole? fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'U': return AcademiaRole.user;
      case 'I': return AcademiaRole.superAdmin;
      default:  return null;
    }
  }

  static AcademiaRole? fromName(String name) {
    for (final r in AcademiaRole.values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

enum AcademiaVoucherStatus { unused, redeemed, revoked }

typedef ParsedAcademiaVoucherCode = ({AcademiaRole role, String random, VoucherPremiumTier premium});

class AcademiaVoucher {
  /// Same "id IS the code" design as SchoolVoucher — the dashed display
  /// form itself is the primary key.
  final String id;
  String get code => id;

  final AcademiaRole role;
  final VoucherPremiumTier premiumTier;
  final AcademiaVoucherStatus status;

  final DateTime createdAt;
  final DateTime? redeemedAt;
  final String? redeemedByUserId;
  final String createdByUid;

  const AcademiaVoucher({
    required this.id,
    required this.role,
    required this.premiumTier,
    this.status = AcademiaVoucherStatus.unused,
    required this.createdAt,
    this.redeemedAt,
    this.redeemedByUserId,
    this.createdByUid = '',
  });

  bool get isRedeemable => status == AcademiaVoucherStatus.unused;

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int _randomLen = 6;
  static const String _prefix = 'AC';

  static String generateCode({required AcademiaRole role, required VoucherPremiumTier premiumTier}) {
    final rnd = Random.secure();
    final random = List.generate(_randomLen, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
    return '$_prefix-${role.code}-$random-${premiumTier.code}';
  }

  /// Deliberately NOT filtered against [_alphabet] — see
  /// school_voucher.dart's normalizeCode for why: that confusable-free
  /// set only constrains the RANDOM segment [generateCode] produces, not
  /// the role segment ('I' for superAdmin would otherwise be stripped).
  static String normalizeCode(String raw) {
    final upper = raw.toUpperCase().trim().replaceAll(RegExp(r'\s+'), '-');
    final buf = StringBuffer();
    for (final ch in upper.split('')) {
      if (RegExp(r'[A-Z0-9-]').hasMatch(ch)) buf.write(ch);
    }
    return buf.toString().replaceAll(RegExp(r'-+'), '-');
  }

  static ParsedAcademiaVoucherCode? parse(String normalized) {
    final parts = normalized.split('-');
    if (parts.length != 4) return null;
    if (parts[0] != _prefix) return null;
    final role = AcademiaRoleX.fromCode(parts[1]);
    if (role == null) return null;
    if (parts[2].length != _randomLen) return null;
    final premium = VoucherPremiumTierX.fromCode(parts[3]);
    if (premium == null) return null;
    return (role: role, random: parts[2], premium: premium);
  }

  static bool isPlausibleCode(String raw) => parse(normalizeCode(raw)) != null;

  factory AcademiaVoucher.fromSupabase(Map<String, dynamic> d) => AcademiaVoucher(
        id: d['id']?.toString() ?? '',
        role: AcademiaRoleX.fromName(d['role']?.toString() ?? '') ?? AcademiaRole.user,
        premiumTier: VoucherPremiumTier.values.firstWhere(
            (t) => t.name == d['premium_tier']?.toString(),
            orElse: () => VoucherPremiumTier.silver),
        status: AcademiaVoucherStatus.values.firstWhere(
            (s) => s.name == d['status']?.toString(),
            orElse: () => AcademiaVoucherStatus.unused),
        createdAt: _dt(d['created_at']) ?? DateTime.now(),
        redeemedAt: _dt(d['redeemed_at']),
        redeemedByUserId: d['redeemed_by_user_id']?.toString(),
        createdByUid: d['created_by_uid']?.toString() ?? '',
      );

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'code': code,
        'role': role.name,
        'premium_tier': premiumTier.name,
        'status': status.name,
        'created_by_uid': createdByUid,
      };

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
}

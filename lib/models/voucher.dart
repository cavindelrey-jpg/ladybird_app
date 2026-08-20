// lib/models/voucher.dart
// production_plan.md §9 — Gifted Premium / Physical Sales, "Gift / Voucher".
//
// A voucher is the bridge between §9's two halves: it is created BY a
// Purchase (someone paid physically) and it is redeemed INTO an
// Entitlement (a premium grant on the redeemer's account). It is the
// only part of the flow the end user ever sees — the child types a code
// and gets Premium, knowing nothing about the transaction behind it,
// exactly as §9 requires.

import 'dart:math';
import 'entitlement.dart';

/// §9's voucher lifecycle: Unused -> Redeemed -> Active -> Expired/Revoked.
///
/// Only [unused], [redeemed] and [revoked] are ever STORED. `active` and
/// `expired` are not independent stored states — they are the same
/// redeemed voucher before and after its expiry instant, which is a pure
/// function of `expiresAt` and the clock. Storing them would mean every
/// voucher needed a scheduled job to flip it at midnight (a Cloud
/// Function this project doesn't have) and would let the stored value
/// silently disagree with the dates next to it. [effectiveStatus] derives
/// them instead, so all five of §9's states are observable while only the
/// three that represent real decisions are persisted.
enum VoucherStatus {
  unused,   // created, never redeemed — stored
  redeemed, // claimed by an account — stored
  active,   // derived: redeemed and still within its window
  expired,  // derived: redeemed but past expiresAt
  revoked,  // killed by staff (refund, fraud, error) — stored
}

extension VoucherStatusX on VoucherStatus {
  String get label {
    switch (this) {
      case VoucherStatus.unused:   return 'Unused';
      case VoucherStatus.redeemed: return 'Redeemed';
      case VoucherStatus.active:   return 'Active';
      case VoucherStatus.expired:  return 'Expired';
      case VoucherStatus.revoked:  return 'Revoked';
    }
  }
}

class Voucher {
  /// Firestore document id. This is the NORMALIZED code (uppercase, no
  /// separators) — see [normalizeCode].
  ///
  /// Using the code as the document id is a deliberate design choice, not
  /// a shortcut: redemption must be atomic, and the Firestore client SDK
  /// cannot run a QUERY inside a transaction — only direct document
  /// reads. Looking a voucher up by `where('code', ...)` would force a
  /// read outside the transaction, reintroducing exactly the
  /// check-then-write race the transaction exists to prevent (two
  /// simultaneous redemptions both reading "unused"). Addressing the doc
  /// directly by its code keeps the whole redeem path inside one
  /// transaction. It also makes the firestore.rules redemption rule
  /// expressible, since the rule can name the document being written.
  final String id;

  /// Display form of the code, with dashes — what gets printed on the
  /// slip handed to the buyer (e.g. `A7K4-9MPX-3TQR`).
  final String code;

  /// §9's "Source purchase" — back-reference to the Purchase that
  /// generated this voucher.
  final String purchaseId;

  /// §9's "Duration" — days of premium access granted on redemption.
  /// Copied from the package at creation time rather than looked up, so
  /// changing a package definition later can never retroactively alter
  /// vouchers already sold.
  final int durationDays;

  /// WHAT tier this voucher grants — Silver or Gold. Copied from the
  /// package at issuance for the same reason [durationDays] is: a later
  /// change to a package's tier definition must never alter a voucher
  /// already printed and sold.
  final EntitlementTier tier;

  /// The package label at time of sale, for display/audit.
  final String packageLabel;

  /// STORED status — only unused/redeemed/revoked. Read [effectiveStatus].
  final VoucherStatus status;

  /// §9's "Recipient account after redemption". Null until redeemed.
  final String? recipientUserId;
  final String? recipientName;

  final DateTime createdAt;
  final DateTime? redeemedAt;

  /// When the granted access lapses — set at REDEMPTION (createdAt +
  /// duration would burn the buyer's money while the voucher sits in an
  /// envelope waiting to be gifted).
  final DateTime? expiresAt;

  final DateTime? revokedAt;
  final String? revokedReason;

  /// Staff account that generated it (the sales agent).
  final String createdByUid;

  const Voucher({
    required this.id,
    required this.code,
    required this.purchaseId,
    required this.durationDays,
    this.tier = EntitlementTier.silver,
    this.packageLabel = '',
    this.status = VoucherStatus.unused,
    this.recipientUserId,
    this.recipientName,
    required this.createdAt,
    this.redeemedAt,
    this.expiresAt,
    this.revokedAt,
    this.revokedReason,
    this.createdByUid = '',
  });

  /// The full five-state view §9 describes, derived from stored status
  /// plus the clock. See [VoucherStatus] for why this isn't stored.
  VoucherStatus get effectiveStatus {
    if (status == VoucherStatus.revoked) return VoucherStatus.revoked;
    if (status == VoucherStatus.unused)  return VoucherStatus.unused;
    final exp = expiresAt;
    if (exp != null && !exp.isAfter(DateTime.now())) return VoucherStatus.expired;
    return VoucherStatus.active;
  }

  bool get isRedeemable => status == VoucherStatus.unused;

  // ── Code generation ────────────────────────────────────────────────────
  /// Alphabet for generated codes.
  ///
  /// A human reads this off a printed slip and types it on a phone, so
  /// every visually confusable pair is removed: no O/0, no I/1/L. What's
  /// left is 31 unambiguous characters. Digits 2-9 and letters that
  /// can't be mistaken for each other in common phone fonts.
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// 12 characters in 3 groups of 4 — `A7K4-9MPX-3TQR`.
  ///
  /// 31^12 is ~7.9e17 possible codes, so guessing one is not a practical
  /// attack even though redemption is unauthenticated-by-code. Short
  /// enough to type without frustration, long enough that the repository
  /// only needs a cheap existence check for collisions.
  static const int _groups = 3;
  static const int _groupLen = 4;

  /// Uses [Random.secure] — a predictable PRNG would let someone who
  /// bought one voucher derive the codes issued around it.
  static String generateCode() {
    final rnd = Random.secure();
    final parts = List.generate(
      _groups,
      (_) => List.generate(
        _groupLen,
        (_) => _alphabet[rnd.nextInt(_alphabet.length)],
      ).join(),
    );
    return parts.join('-');
  }

  /// Canonical form used as the document id and for all lookups.
  ///
  /// Uppercases and strips every character outside the alphabet, so a
  /// user typing `a7k4 9mpx-3tqr` (lowercase, space instead of dash)
  /// still resolves to the same voucher.
  ///
  /// Note that the excluded confusables (O/0, I/1/L) are dropped rather
  /// than folded onto a neighbour. Since NEITHER member of each pair is
  /// in the alphabet, there is no correct character to fold toward, and
  /// guessing one would silently resolve to a different voucher than the
  /// one printed. Dropping them makes the code fail the length check in
  /// [isPlausibleCode] instead, which surfaces an honest "check the code"
  /// error to the user.
  static String normalizeCode(String raw) {
    final upper = raw.toUpperCase();
    final buf = StringBuffer();
    for (final ch in upper.split('')) {
      if (_alphabet.contains(ch)) buf.write(ch);
    }
    return buf.toString();
  }

  /// Re-inserts dashes for display: `A7K49MPX3TQR` -> `A7K4-9MPX-3TQR`.
  static String formatCode(String normalized) {
    final chunks = <String>[];
    for (var i = 0; i < normalized.length; i += _groupLen) {
      chunks.add(normalized.substring(
          i, i + _groupLen > normalized.length ? normalized.length : i + _groupLen));
    }
    return chunks.join('-');
  }

  /// Cheap client-side sanity check so an obviously malformed entry
  /// doesn't cost a Firestore read.
  static bool isPlausibleCode(String raw) =>
      normalizeCode(raw).length == _groups * _groupLen;

  // ── Firestore ──────────────────────────────────────────────────────────
  factory Voucher.fromFirestore(String id, Map<String, dynamic> d) => Voucher(
        id: id,
        code: d['code']?.toString() ?? formatCode(id),
        purchaseId: d['purchaseId']?.toString() ?? '',
        durationDays: (d['durationDays'] as num?)?.toInt() ?? 0,
        tier: EntitlementTier.values.firstWhere(
            (t) => t.name == d['tier']?.toString(),
            orElse: () => EntitlementTier.silver),
        packageLabel: d['packageLabel']?.toString() ?? '',
        status: VoucherStatus.values.firstWhere(
            (s) => s.name == d['status']?.toString(),
            orElse: () => VoucherStatus.unused),
        recipientUserId: d['recipientUserId']?.toString(),
        recipientName: d['recipientName']?.toString(),
        createdAt: _dt(d['createdAt']) ?? DateTime.now(),
        redeemedAt: _dt(d['redeemedAt']),
        expiresAt: _dt(d['expiresAt']),
        revokedAt: _dt(d['revokedAt']),
        revokedReason: d['revokedReason']?.toString(),
        createdByUid: d['createdByUid']?.toString() ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'code': code,
        'purchaseId': purchaseId,
        'durationDays': durationDays,
        'tier': tier.name,
        'packageLabel': packageLabel,
        'status': status.name,
        'recipientUserId': recipientUserId,
        'recipientName': recipientName,
        'createdAt': createdAt.toIso8601String(),
        'redeemedAt': redeemedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'revokedAt': revokedAt?.toIso8601String(),
        'revokedReason': revokedReason,
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

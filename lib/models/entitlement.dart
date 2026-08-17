// lib/models/entitlement.dart
// production_plan.md §8 — "User → Account → Entitlements".
//
// The plan's core architectural point is that Premium and Gifted Premium
// must NOT be separate permanent account types. They are an *entitlement*
// attached to an ordinary individual account:
//
//   Free account + Premium entitlement          (bought it themselves)
//   Free account + Gifted Premium entitlement   (someone else bought it)
//
// So this model deliberately splits two things the old flat
// `AppUser.isPremium` bool conflated:
//
//   tier   — WHAT access the account currently has (free / premium)
//   source — WHY it has it (self purchase, gift, sponsor, school, promo…)
//
// "Gifted Premium" is therefore not a third tier; it is
// `tier == premium && source == gift`. That is exactly the plan's
// closing principle: "Gifted Premium is not necessarily a different
// account. It is a Premium entitlement whose source is another person's
// purchase." Keeping source as its own axis is what lets Sponsored /
// School / Promotional access (§9's forward-looking list: parents,
// teachers, schools, sponsors, organizations, promotions, scholarships)
// land later as new EntitlementSource values with no redesign — no new
// account type, no new tier, no migration.

/// WHAT access an account currently has.
///
/// Intentionally only two values today. New *reasons* for premium access
/// belong in [EntitlementSource], not here — adding tiers is what would
/// force the redesign §8 is trying to avoid. A genuinely different
/// capability level (e.g. a future "pro") is the only thing that should
/// ever be added here.
enum EntitlementTier { free, premium }

/// WHY an account has its current tier.
///
/// `none` pairs with [EntitlementTier.free]. The rest pair with premium.
/// Values after `gift` are not wired to any flow yet — they exist so the
/// architecture already has a home for §9's future access types rather
/// than needing a schema change to accept them.
enum EntitlementSource {
  none,          // free account, no entitlement granted
  selfPurchase,  // the account holder paid for it themselves
  gift,          // Gifted Premium — someone else's purchase (§9 vouchers)
  sponsor,       // future: an organization/sponsor funds this account
  school,        // future: access granted by the linked institution
  promotional,   // future: campaign / scholarship / free-trial grant
  adminGrant,    // manually granted by platform staff (support, comps)
}

/// An access grant attached to one individual account.
///
/// Immutable value object. Stored FLAT on the user document (not nested)
/// so `firestore.rules` can guard each field individually — a nested map
/// can only be compared wholesale, which would make the narrow
/// "redemption may write these fields and nothing else" rule in
/// firestore.rules impossible to express.
class Entitlement {
  final EntitlementTier tier;
  final EntitlementSource source;

  /// When this entitlement began. Null for a plain free account.
  final DateTime? startAt;

  /// When it lapses. Null means perpetual — used by adminGrant/school
  /// style grants that shouldn't silently expire. A dated entitlement
  /// past this instant is no longer [isActive].
  final DateTime? expiresAt;

  /// Back-reference to whatever produced this entitlement — a voucher id
  /// for [EntitlementSource.gift], a purchase id for a self purchase.
  /// Audit trail only; never affects access evaluation.
  final String? sourceRef;

  const Entitlement({
    this.tier = EntitlementTier.free,
    this.source = EntitlementSource.none,
    this.startAt,
    this.expiresAt,
    this.sourceRef,
  });

  /// The default for every account that has never been granted anything.
  const Entitlement.free()
      : tier = EntitlementTier.free,
        source = EntitlementSource.none,
        startAt = null,
        expiresAt = null,
        sourceRef = null;

  /// True while this grant actually confers premium access.
  ///
  /// Time-checked on every call against the device clock. Same honest
  /// limitation already documented on XpRepository's daily cap: a user
  /// who moves their device clock backwards can stretch an expired
  /// entitlement locally. firestore.rules stops them from *writing* a
  /// longer one, and any server-authoritative check would be a Cloud
  /// Function (production_plan.md §4.9's deferred work) — flagging
  /// rather than pretending this is airtight.
  bool get isActive {
    if (tier != EntitlementTier.premium) return false;
    final exp = expiresAt;
    if (exp != null && !exp.isAfter(DateTime.now())) return false;
    return true;
  }

  /// True once a dated premium grant has lapsed. Distinct from
  /// `!isActive` (which is also true for a plain free account) so the UI
  /// can say "expired" instead of "free" when that's what happened.
  bool get isExpired {
    final exp = expiresAt;
    return tier == EntitlementTier.premium &&
        exp != null &&
        !exp.isAfter(DateTime.now());
  }

  /// Whole days of access left, or null when perpetual/inactive.
  int? get daysRemaining {
    final exp = expiresAt;
    if (!isActive || exp == null) return null;
    return exp.difference(DateTime.now()).inDays;
  }

  /// The three user-facing states §8 names: Free, Premium, Gifted Premium.
  /// Gifted Premium is derived, not stored — see the file header.
  String get label {
    if (!isActive) return isExpired ? 'Premium (expired)' : 'Free';
    switch (source) {
      case EntitlementSource.gift:        return 'Gifted Premium';
      case EntitlementSource.sponsor:     return 'Sponsored Premium';
      case EntitlementSource.school:      return 'School Premium';
      case EntitlementSource.promotional: return 'Promotional Premium';
      case EntitlementSource.selfPurchase:
      case EntitlementSource.adminGrant:
      case EntitlementSource.none:        return 'Premium';
    }
  }

  /// Human-readable explanation of where the access came from, for the
  /// Profile membership row. Deliberately vague about the money for
  /// gifts: §9 states "the child does not need to know anything about
  /// the underlying transaction."
  String get sourceLabel {
    switch (source) {
      case EntitlementSource.none:        return 'No active entitlement';
      case EntitlementSource.selfPurchase:return 'Purchased';
      case EntitlementSource.gift:        return 'Gifted to you';
      case EntitlementSource.sponsor:     return 'Sponsored';
      case EntitlementSource.school:      return 'Provided by your school';
      case EntitlementSource.promotional: return 'Promotional access';
      case EntitlementSource.adminGrant:  return 'Granted by Academia';
    }
  }

  // ── Firestore (flat keys on the user doc) ──────────────────────────────
  static const String kTier      = 'entitlementTier';
  static const String kSource    = 'entitlementSource';
  static const String kStartAt   = 'entitlementStartAt';
  static const String kExpiresAt = 'entitlementExpiresAt';
  static const String kSourceRef = 'entitlementSourceRef';

  /// Reads the flat entitlement keys out of a full user document map.
  ///
  /// [legacyIsPremium] is the pre-§8 flat bool. Accounts created before
  /// this model existed have `isPremium: true` and no entitlement keys at
  /// all; without this fallback every currently-premium user would
  /// silently drop to Free on their next app open. Such an account is
  /// read as perpetual premium of unknown origin (adminGrant) — the
  /// honest reading, since the old schema recorded no source and no
  /// expiry to recover.
  factory Entitlement.fromUserMap(Map<String, dynamic> d,
      {bool legacyIsPremium = false}) {
    final rawTier = d[kTier]?.toString();
    if (rawTier == null || rawTier.isEmpty) {
      return legacyIsPremium
          ? const Entitlement(
              tier: EntitlementTier.premium,
              source: EntitlementSource.adminGrant,
            )
          : const Entitlement.free();
    }
    return Entitlement(
      tier: EntitlementTier.values.firstWhere((t) => t.name == rawTier,
          orElse: () => EntitlementTier.free),
      source: EntitlementSource.values.firstWhere(
          (s) => s.name == d[kSource]?.toString(),
          orElse: () => EntitlementSource.none),
      startAt: _dt(d[kStartAt]),
      expiresAt: _dt(d[kExpiresAt]),
      sourceRef: d[kSourceRef]?.toString(),
    );
  }

  /// Flat map merged into the user document by `AppUser.toFirestore()`.
  Map<String, dynamic> toUserMap() => {
        kTier: tier.name,
        kSource: source.name,
        kStartAt: startAt?.toIso8601String(),
        kExpiresAt: expiresAt?.toIso8601String(),
        kSourceRef: sourceRef,
      };

  /// Accepts both ISO strings and Firestore Timestamps without importing
  /// cloud_firestore here — models/ stays a plain-Dart layer (every other
  /// model in this folder follows the same rule). Timestamp exposes
  /// `toDate()`, so a duck-typed dynamic call handles it.
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

  Entitlement copyWith({
    EntitlementTier? tier,
    EntitlementSource? source,
    DateTime? startAt,
    DateTime? expiresAt,
    String? sourceRef,
  }) =>
      Entitlement(
        tier: tier ?? this.tier,
        source: source ?? this.source,
        startAt: startAt ?? this.startAt,
        expiresAt: expiresAt ?? this.expiresAt,
        sourceRef: sourceRef ?? this.sourceRef,
      );

  @override
  String toString() =>
      'Entitlement($label, source: ${source.name}, expires: $expiresAt)';
}

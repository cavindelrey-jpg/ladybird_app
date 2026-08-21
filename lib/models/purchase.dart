// lib/models/purchase.dart
import 'entitlement.dart';

// production_plan.md §9 — Gifted Premium / Physical Sales, "Purchase".
//
// IMPORTANT — what this is NOT: this is not a payment integration, and
// there is deliberately no in-app payment code path anywhere in this
// feature. §9 describes a PHYSICAL sale:
//
//   Parent -> pays Academia physically -> receives voucher/code
//          -> child redeems voucher -> child's account receives Premium
//
// The money changes hands in person (cash to a sales agent at an office).
// By the time anything reaches this app the transaction has ALREADY
// happened offline. A Purchase document is therefore a RECORD of that
// completed external transaction, entered manually by a sales agent, and
// its only in-app job is to justify and audit the voucher it generated.
// Nothing here moves money or talks to a payment provider.

/// How the (already-completed, offline) transaction was paid.
///
/// `cash` is the primary real-world case §9 describes. The mobile-money
/// and bank-transfer values exist because a sales agent needs to be able
/// to record what actually happened — recording that a transfer occurred
/// is bookkeeping, not a payment integration.
enum PaymentMethod { cash, mobileMoney, bankTransfer, other }

/// State of the external transaction this document records.
enum PurchaseStatus {
  completed, // money received, voucher issued — the normal path
  pending,   // recorded but funds not yet confirmed by the agent
  refunded,  // money returned; any issued voucher should be revoked
  cancelled, // recorded in error / sale fell through
}

/// What was bought — the tier and access period a redeemed voucher grants.
///
/// Duration is a product definition, not fabricated data: it's the same
/// kind of constant as the XP costs in core/xp_rules.dart. The PRICE is
/// deliberately NOT encoded here for the sales-agent flow — the agent
/// types the actual amount collected, because real physical sales involve
/// negotiated, promotional and regional pricing, and a hardcoded price
/// shown as if it were the real one is exactly the fabricated-data
/// pattern this project bans. [suggestedPriceFcfa] is the one exception —
/// it backs the app's OWN direct-payment sheet (premium_unlock_sheet.dart),
/// which genuinely does need to display a sticker price up front.
enum EntitlementPackage {
  silver1Month, silver3Months, silver6Months, silver1Year,
  gold1Month, gold3Months, gold6Months, gold1Year,
}

extension EntitlementPackageX on EntitlementPackage {
  /// WHAT tier this package grants — Silver (no Video Courses) or Gold
  /// (full access). The single source of truth Voucher/Purchase read to
  /// stamp their own `tier` field at issuance time.
  EntitlementTier get tier {
    switch (this) {
      case EntitlementPackage.silver1Month:
      case EntitlementPackage.silver3Months:
      case EntitlementPackage.silver6Months:
      case EntitlementPackage.silver1Year:
        return EntitlementTier.silver;
      case EntitlementPackage.gold1Month:
      case EntitlementPackage.gold3Months:
      case EntitlementPackage.gold6Months:
      case EntitlementPackage.gold1Year:
        return EntitlementTier.gold;
    }
  }

  /// Access period granted, in days, measured from redemption.
  /// 30/90/180/365 — calendar-month drift is acceptable here and keeps
  /// the arithmetic auditable (a "1 year" voucher is exactly 365 days).
  int get durationDays {
    switch (this) {
      case EntitlementPackage.silver1Month:
      case EntitlementPackage.gold1Month:   return 30;
      case EntitlementPackage.silver3Months:
      case EntitlementPackage.gold3Months:  return 90;
      case EntitlementPackage.silver6Months:
      case EntitlementPackage.gold6Months:  return 180;
      case EntitlementPackage.silver1Year:
      case EntitlementPackage.gold1Year:    return 365;
    }
  }

  String get label {
    switch (this) {
      case EntitlementPackage.silver1Month:  return 'Premium Silver — 1 month';
      case EntitlementPackage.silver3Months: return 'Premium Silver — 3 months';
      case EntitlementPackage.silver6Months: return 'Premium Silver — 6 months';
      case EntitlementPackage.silver1Year:   return 'Premium Silver — 1 year';
      case EntitlementPackage.gold1Month:    return 'Premium Gold — 1 month';
      case EntitlementPackage.gold3Months:   return 'Premium Gold — 3 months';
      case EntitlementPackage.gold6Months:   return 'Premium Gold — 6 months';
      case EntitlementPackage.gold1Year:     return 'Premium Gold — 1 year';
    }
  }

  /// Sticker price for the app's own direct-payment flow (MoMo/Orange
  /// Money) — NOT used by the sales-agent/voucher flow, which always
  /// types the real amount collected instead (see file header). A
  /// reasonable default price ladder; not a live pricing feed.
  int get suggestedPriceFcfa {
    switch (this) {
      case EntitlementPackage.silver1Month:  return 1500;
      case EntitlementPackage.silver3Months: return 4000;
      case EntitlementPackage.silver6Months: return 7500;
      case EntitlementPackage.silver1Year:   return 13000;
      case EntitlementPackage.gold1Month:    return 2500;
      case EntitlementPackage.gold3Months:   return 6500;
      case EntitlementPackage.gold6Months:   return 12000;
      case EntitlementPackage.gold1Year:     return 21000;
    }
  }

  static EntitlementPackage parse(dynamic raw) =>
      EntitlementPackage.values.firstWhere((p) => p.name == raw?.toString(),
          orElse: () => EntitlementPackage.silver1Month);
}

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:         return 'Cash';
      case PaymentMethod.mobileMoney:  return 'Mobile Money';
      case PaymentMethod.bankTransfer: return 'Bank Transfer';
      case PaymentMethod.other:        return 'Other';
    }
  }
}

extension PurchaseStatusX on PurchaseStatus {
  String get label {
    switch (this) {
      case PurchaseStatus.completed: return 'Completed';
      case PurchaseStatus.pending:   return 'Pending';
      case PurchaseStatus.refunded:  return 'Refunded';
      case PurchaseStatus.cancelled: return 'Cancelled';
    }
  }
}

class Purchase {
  /// Firestore document id — §9's "Purchase ID".
  final String id;

  /// Amount actually collected, in [currency]. Entered by the agent.
  final num amount;

  /// ISO-ish currency label. Defaults to Cameroon's FCFA, the currency
  /// the physical sales in §9 actually happen in.
  final String currency;

  final PaymentMethod paymentMethod;
  final EntitlementPackage package;

  /// The voucher this purchase generated — §9's "Voucher/code generated".
  /// Both stored: the id addresses the document, the code is what's
  /// printed/handed to the buyer and is useful in a receipt/audit view
  /// without a second read.
  final String voucherId;
  final String voucherCode;

  final DateTime createdAt;

  /// §9's "Sales agent" — the staff account that recorded this sale.
  final String salesAgentId;
  final String salesAgentName;

  /// §9's "Purchase source" — where the sale physically happened, e.g.
  /// "Yaoundé Office", "Buea Branch", a partner bookshop, a school fair.
  final String purchaseSource;

  final PurchaseStatus status;

  /// Who handed over the money (e.g. "Mrs. Foka"). Free text, used for
  /// support lookups ("a parent says she bought a voucher last week").
  /// Not an account reference — the buyer usually has no app account at
  /// all, which is the entire point of the gifting flow.
  final String buyerName;

  /// Optional free-text note by the agent.
  final String note;

  const Purchase({
    required this.id,
    required this.amount,
    this.currency = 'FCFA',
    required this.paymentMethod,
    required this.package,
    required this.voucherId,
    required this.voucherCode,
    required this.createdAt,
    required this.salesAgentId,
    this.salesAgentName = '',
    this.purchaseSource = '',
    this.status = PurchaseStatus.completed,
    this.buyerName = '',
    this.note = '',
  });

  String get amountLabel => '$amount $currency';

  factory Purchase.fromFirestore(String id, Map<String, dynamic> d) => Purchase(
        id: id,
        amount: (d['amount'] as num?) ?? 0,
        currency: d['currency']?.toString() ?? 'FCFA',
        paymentMethod: PaymentMethod.values.firstWhere(
            (m) => m.name == d['paymentMethod']?.toString(),
            orElse: () => PaymentMethod.cash),
        package: EntitlementPackageX.parse(d['package']),
        voucherId: d['voucherId']?.toString() ?? '',
        voucherCode: d['voucherCode']?.toString() ?? '',
        createdAt: _dt(d['createdAt']) ?? DateTime.now(),
        salesAgentId: d['salesAgentId']?.toString() ?? '',
        salesAgentName: d['salesAgentName']?.toString() ?? '',
        purchaseSource: d['purchaseSource']?.toString() ?? '',
        status: PurchaseStatus.values.firstWhere(
            (s) => s.name == d['status']?.toString(),
            orElse: () => PurchaseStatus.completed),
        buyerName: d['buyerName']?.toString() ?? '',
        note: d['note']?.toString() ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'amount': amount,
        'currency': currency,
        'paymentMethod': paymentMethod.name,
        'package': package.name,
        'voucherId': voucherId,
        'voucherCode': voucherCode,
        'createdAt': createdAt.toIso8601String(),
        'salesAgentId': salesAgentId,
        'salesAgentName': salesAgentName,
        'purchaseSource': purchaseSource,
        'status': status.name,
        'buyerName': buyerName,
        'note': note,
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

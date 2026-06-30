// lib/services/subscription_service.dart
// Institution feature licensing and subscription management.
// Reads from Firestore 'subscriptions/{institutionId}' document.
// No payment processing here — that lives in a Cloud Function or backend.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/institution.dart';
import '../core/result.dart';

/// Subscription tiers available to institutions.
enum SubscriptionTier {
  /// Free trial — limited features, limited seats.
  free,
  /// Single campus — full features, up to 500 seats.
  basic,
  /// Multi-campus — full features, unlimited seats, white-label.
  professional,
  /// Enterprise — custom domain, SLA, priority support.
  enterprise,
}

extension SubscriptionTierExt on SubscriptionTier {
  String get label {
    switch (this) {
      case SubscriptionTier.free:         return 'Free Trial';
      case SubscriptionTier.basic:        return 'Basic';
      case SubscriptionTier.professional: return 'Professional';
      case SubscriptionTier.enterprise:   return 'Enterprise';
    }
  }

  /// Features unlocked at this tier and above.
  Set<InstitutionFeature> get unlockedFeatures {
    switch (this) {
      case SubscriptionTier.free:
        return {InstitutionFeature.announcements, InstitutionFeature.library};
      case SubscriptionTier.basic:
        return {
          InstitutionFeature.announcements, InstitutionFeature.library,
          InstitutionFeature.marks, InstitutionFeature.timetable,
          InstitutionFeature.courses,
        };
      case SubscriptionTier.professional:
        return {
          InstitutionFeature.announcements, InstitutionFeature.library,
          InstitutionFeature.marks, InstitutionFeature.timetable,
          InstitutionFeature.courses, InstitutionFeature.attendance,
          InstitutionFeature.assignments, InstitutionFeature.events,
          InstitutionFeature.clubs, InstitutionFeature.analytics,
        };
      case SubscriptionTier.enterprise:
        return Set.from(InstitutionFeature.values);
    }
  }

  int get maxSeats {
    switch (this) {
      case SubscriptionTier.free:         return 30;
      case SubscriptionTier.basic:        return 500;
      case SubscriptionTier.professional: return 2000;
      case SubscriptionTier.enterprise:   return 999999;
    }
  }

  bool get allowsWhiteLabel => this == SubscriptionTier.professional ||
      this == SubscriptionTier.enterprise;
}

/// Live subscription record for one institution.
class InstitutionSubscription {
  final String institutionId;
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final bool isActive;
  final int seatsPurchased;
  final String? billingEmail;
  final String? paymentRef; // MTN/Orange Money transaction reference

  const InstitutionSubscription({
    required this.institutionId,
    required this.tier,
    this.expiresAt,
    required this.isActive,
    required this.seatsPurchased,
    this.billingEmail,
    this.paymentRef,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isValid => isActive && !isExpired;

  Set<InstitutionFeature> get allowedFeatures => tier.unlockedFeatures;

  bool canUseFeature(InstitutionFeature f) =>
      isValid && tier.unlockedFeatures.contains(f);

  factory InstitutionSubscription.fromFirestore(
      String id, Map<String, dynamic> d) {
    return InstitutionSubscription(
      institutionId: id,
      tier: SubscriptionTier.values.firstWhere(
          (t) => t.name == d['tier'], orElse: () => SubscriptionTier.free),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      isActive: d['isActive'] ?? false,
      seatsPurchased: (d['seatsPurchased'] as num?)?.toInt() ?? 0,
      billingEmail: d['billingEmail'],
      paymentRef: d['paymentRef'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'tier': tier.name,
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    'isActive': isActive,
    'seatsPurchased': seatsPurchased,
    'billingEmail': billingEmail,
    'paymentRef': paymentRef,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Free tier fallback for institutions with no subscription document.
  static InstitutionSubscription freeTier(String institutionId) =>
      InstitutionSubscription(
        institutionId: institutionId,
        tier: SubscriptionTier.free,
        isActive: true,
        seatsPurchased: 30,
      );
}

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final _db = FirebaseFirestore.instance;

  /// Live stream of subscription for an institution.
  Stream<InstitutionSubscription> watchSubscription(String institutionId) {
    return _db
        .collection('subscriptions')
        .doc(institutionId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return InstitutionSubscription.freeTier(institutionId);
      }
      return InstitutionSubscription.fromFirestore(
          institutionId, doc.data()!);
    });
  }

  /// One-shot fetch — use for checks that don't need live updates.
  Future<InstitutionSubscription> getSubscription(
      String institutionId) async {
    try {
      final doc =
          await _db.collection('subscriptions').doc(institutionId).get();
      if (!doc.exists || doc.data() == null) {
        return InstitutionSubscription.freeTier(institutionId);
      }
      return InstitutionSubscription.fromFirestore(
          institutionId, doc.data()!);
    } catch (e) {
      debugPrint('[Subscription] Error fetching: $e');
      return InstitutionSubscription.freeTier(institutionId);
    }
  }

  /// Check if a specific feature is licensed for an institution.
  Future<bool> isFeatureLicensed(
      String institutionId, InstitutionFeature feature) async {
    final sub = await getSubscription(institutionId);
    return sub.canUseFeature(feature);
  }

  /// Upgrade an institution's tier (called after payment confirmation).
  Future<Result<void>> upgradeTier({
    required String institutionId,
    required SubscriptionTier tier,
    required DateTime expiresAt,
    required int seatsPurchased,
    String? billingEmail,
    String? paymentRef,
  }) async {
    try {
      await _db.collection('subscriptions').doc(institutionId).set({
        'tier': tier.name,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
        'seatsPurchased': seatsPurchased,
        'billingEmail': billingEmail,
        'paymentRef': paymentRef,
        'upgradedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to upgrade subscription', e);
    }
  }
}

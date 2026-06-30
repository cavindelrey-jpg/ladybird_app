// lib/repositories/institution_repository.dart
// Validates school codes, fetches institution config from Firestore.
// Enhanced: robust validation, feature flag helpers, admin-level tenant management.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/institution.dart';
import '../core/result.dart';

class InstitutionRepository {
  InstitutionRepository._();
  static final InstitutionRepository instance = InstitutionRepository._();

  static const String _col = 'institutions';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Validation helpers ───────────────────────────────────────────────────

  /// Validates a school code string before hitting Firestore.
  /// Returns a human-readable error string, or null if valid.
  static String? validateCode(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return 'Please enter a school code.';
    if (trimmed.length < 4) return 'School code must be at least 4 characters.';
    if (trimmed.length > 12) return 'School code must be at most 12 characters.';
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(trimmed.toUpperCase())) {
      return 'School code may only contain letters and numbers.';
    }
    return null; // valid
  }

  // ─── Validation + fetch by code ──────────────────────────────────────────

  /// Validates a school code and returns the matching Institution, or failure.
  Future<Result<Institution>> findByCode(String code) async {
    final validationError = validateCode(code);
    if (validationError != null) return Failure(validationError, null);

    try {
      final snap = await _db
          .collection(_col)
          .where('schoolCode', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return const Failure(
            'Invalid school code. Please check with your institution.', null);
      }

      final inst = Institution.fromFirestore(snap.docs.first);

      // Check institution-level suspension flag
      final data = snap.docs.first.data();
      if (data['suspended'] == true) {
        return const Failure(
            'This institution is temporarily suspended. Contact Academia support.', null);
      }

      return Success(inst);
    } catch (e) {
      return Failure('Connection error. Please try again.', e);
    }
  }

  /// Fetch by Firestore document ID (used when restoring from local storage).
  Future<Result<Institution>> findById(String institutionId) async {
    try {
      final doc = await _db.collection(_col).doc(institutionId).get();
      if (!doc.exists) {
        return const Failure('Institution not found.', null);
      }
      final data = doc.data()!;
      if (data['suspended'] == true) {
        return const Failure(
            'This institution is temporarily suspended.', null);
      }
      return Success(Institution.fromFirestore(doc));
    } catch (e) {
      return Failure('Failed to load institution.', e);
    }
  }

  /// Live stream of institution config — theme/feature changes propagate instantly.
  Stream<Institution?> watch(String institutionId) {
    return _db.collection(_col).doc(institutionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Institution.fromFirestore(doc);
    });
  }

  // ─── Feature flag helpers ─────────────────────────────────────────────────

  /// Enable a feature for an institution.
  Future<Result<void>> enableFeature(
      String institutionId, InstitutionFeature feature) async {
    try {
      await _db.collection(_col).doc(institutionId).update({
        'enabledFeatures': FieldValue.arrayUnion([feature.key]),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to enable feature: ${feature.key}', e);
    }
  }

  /// Disable a feature for an institution.
  Future<Result<void>> disableFeature(
      String institutionId, InstitutionFeature feature) async {
    try {
      await _db.collection(_col).doc(institutionId).update({
        'enabledFeatures': FieldValue.arrayRemove([feature.key]),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to disable feature: ${feature.key}', e);
    }
  }

  /// Update branding fields (logo, colors, font, tagline) without touching
  /// other institution data — safe for white-label runtime rebranding.
  Future<Result<void>> updateBranding(
    String institutionId, {
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? fontFamily,
    String? tagline,
    String? bannerImage,
  }) async {
    final updates = <String, dynamic>{};
    if (logoUrl != null) updates['logoUrl'] = logoUrl;
    if (primaryColor != null) updates['primaryColor'] = primaryColor;
    if (secondaryColor != null) updates['secondaryColor'] = secondaryColor;
    if (accentColor != null) updates['accentColor'] = accentColor;
    if (fontFamily != null) updates['fontFamily'] = fontFamily;
    if (tagline != null) updates['tagline'] = tagline;
    if (bannerImage != null) updates['bannerImage'] = bannerImage;

    if (updates.isEmpty) return const Success(null);

    try {
      await _db.collection(_col).doc(institutionId).update(updates);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update branding.', e);
    }
  }

  // ─── Admin: create/update ─────────────────────────────────────────────────

  Future<Result<String>> create(Institution institution) async {
    try {
      final ref = await _db.collection(_col).add(institution.toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to create institution.', e);
    }
  }

  Future<Result<void>> update(Institution institution) async {
    try {
      await _db
          .collection(_col)
          .doc(institution.institutionId)
          .update(institution.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update institution.', e);
    }
  }

  /// Hard-suspend an institution (users cannot log in).
  Future<Result<void>> suspend(String institutionId) async {
    try {
      await _db.collection(_col).doc(institutionId).update({'suspended': true});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to suspend institution.', e);
    }
  }

  Future<Result<void>> unsuspend(String institutionId) async {
    try {
      await _db.collection(_col).doc(institutionId).update({'suspended': false});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to reactivate institution.', e);
    }
  }
}

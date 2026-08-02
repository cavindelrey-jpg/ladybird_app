// lib/repositories/serial_repository.dart
// Backs the serial-number enrollment system: validating a serial, showing
// its institution as a branded preview before any account exists, and
// atomically claiming it so the same serial can never be used twice — even
// under concurrent attempts (two people racing to redeem a leaked serial).

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';
import '../models/institution.dart';
import '../models/serial_number.dart';

class SerialRepository {
  SerialRepository._();
  static final SerialRepository instance = SerialRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Validation ───────────────────────────────────────────────────────

  /// Local shape check before any network call.
  static String? validateFormat(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return 'Please enter your serial number.';
    if (trimmed.length < 6) return 'That serial number looks too short.';
    if (trimmed.length > 20) return 'That serial number looks too long.';
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(trimmed.toUpperCase())) {
      return 'Serial numbers only contain letters, numbers, and dashes.';
    }
    return null;
  }

  /// Looks up a serial and, if it's valid and still unclaimed, returns the
  /// institution it belongs to — so the app can show that institution's
  /// branding ("morph") *before* the student commits to creating an
  /// account. Does not claim anything yet.
  Future<Result<({SerialNumber serial, Institution institution})>> preview(
      String code) async {
    final formatError = validateFormat(code);
    if (formatError != null) return Failure(formatError, null);
    final normalized = code.trim().toUpperCase();

    try {
      final serialDoc =
          await _db.collection(AppConstants.colSerials).doc(normalized).get();
      if (!serialDoc.exists) {
        return const Failure(
            "We couldn't find that serial number. Double-check it with your school.",
            null);
      }
      final serial = SerialNumber.fromFirestore(serialDoc.id, serialDoc.data()!);

      if (serial.status == SerialStatus.claimed) {
        return const Failure(
            'This serial number has already been used to create an account.',
            null);
      }
      if (serial.status == SerialStatus.revoked) {
        return const Failure(
            'This serial number is no longer valid. Contact your school.', null);
      }

      final instDoc = await _db
          .collection(AppConstants.colInstitutions)
          .doc(serial.institutionId)
          .get();
      if (!instDoc.exists) {
        return const Failure(
            'This serial number is not linked to an active school. Contact Academia support.',
            null);
      }
      final data = instDoc.data()!;
      if (data['suspended'] == true) {
        return const Failure(
            "This school's account is temporarily suspended. Contact Academia support.",
            null);
      }

      return Success((serial: serial, institution: Institution.fromFirestore(instDoc)));
    } catch (e) {
      return Failure('Could not verify that serial number: $e', e);
    }
  }

  // ─── Claim (atomic) ───────────────────────────────────────────────────

  /// Marks a serial claimed by [uid], inside a transaction so two people
  /// racing on the same leaked serial can't both succeed — whoever's
  /// transaction commits first wins, the other gets a clean failure.
  /// Called by AuthService immediately after the Firebase Auth user is
  /// created, as part of account creation.
  Future<Result<void>> claim({
    required String code,
    required String uid,
  }) async {
    final normalized = code.trim().toUpperCase();
    final ref = _db.collection(AppConstants.colSerials).doc(normalized);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw Exception("Serial number no longer exists.");
        }
        final serial = SerialNumber.fromFirestore(snap.id, snap.data()!);
        if (serial.status != SerialStatus.unclaimed) {
          throw Exception('This serial number has already been claimed.');
        }
        tx.update(ref, {
          'status': SerialStatus.claimed.name,
          'claimedByUid': uid,
          'claimedAt': FieldValue.serverTimestamp(),
        });
      });
      return const Success(null);
    } catch (e) {
      return Failure(e.toString().replaceFirst('Exception: ', ''), e);
    }
  }

  /// Releases a claim — used only as rollback if account creation fails
  /// *after* the serial was claimed but before the user doc was written
  /// (e.g. Firestore write failure right after Auth succeeded).
  Future<void> release(String code) async {
    final normalized = code.trim().toUpperCase();
    try {
      await _db.collection(AppConstants.colSerials).doc(normalized).update({
        'status': SerialStatus.unclaimed.name,
        'claimedByUid': null,
        'claimedAt': null,
      });
    } catch (_) {
      // best-effort rollback only
    }
  }

  // ─── Admin: batch generation ──────────────────────────────────────────

  /// Generates [count] fresh, unclaimed serials for [institutionId] — e.g.
  /// when a school signs a contract for 720 seats. Codes are prefixed with
  /// [institutionPrefix] (e.g. "SM" for St. Michael) for readability.
  Future<Result<List<String>>> generateBatch({
    required String institutionId,
    required String institutionPrefix,
    required int count,
    String? classLevel,
  }) async {
    try {
      final rng = Random.secure();
      final codes = <String>[];
      final batch = _db.batch();

      while (codes.length < count) {
        final suffix = List.generate(6, (_) => rng.nextInt(36))
            .map((n) => n < 10 ? n.toString() : String.fromCharCode(55 + n))
            .join();
        final code = '${institutionPrefix.toUpperCase()}-$suffix';
        if (codes.contains(code)) continue; // extremely unlikely collision
        codes.add(code);
        final ref = _db.collection(AppConstants.colSerials).doc(code);
        batch.set(ref, SerialNumber(
          code: code,
          institutionId: institutionId,
          classLevel: classLevel,
        ).toFirestore());
      }

      await batch.commit();
      return Success(codes);
    } catch (e) {
      return Failure('Failed to generate serial numbers: $e', e);
    }
  }

  /// Live counts for an institution's admin dashboard — e.g. "612 / 720 claimed".
  Future<({int total, int claimed})> countsFor(String institutionId) async {
    final all = await _db
        .collection(AppConstants.colSerials)
        .where('institutionId', isEqualTo: institutionId)
        .get();
    final claimed = all.docs
        .where((d) => d.data()['status'] == SerialStatus.claimed.name)
        .length;
    return (total: all.docs.length, claimed: claimed);
  }

  Future<Result<void>> revoke(String code) async {
    try {
      await _db.collection(AppConstants.colSerials).doc(code.trim().toUpperCase())
          .update({'status': SerialStatus.revoked.name});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to revoke serial number.', e);
    }
  }
}

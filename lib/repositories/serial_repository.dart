// lib/repositories/serial_repository.dart
// Backs the serial-number enrollment system: validating a serial, showing
// its institution as a branded preview before any account exists, and
// atomically claiming it so the same serial can never be used twice — even
// under concurrent attempts (two people racing to redeem a leaked serial).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import '../core/constants.dart';
import '../core/result.dart';
import '../models/institution.dart';
import '../models/serial_number.dart';

class SerialRepository {
  SerialRepository._();
  static final SerialRepository instance = SerialRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _fn = FirebaseFunctions.instance;

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

  // ─── Claim (server-enforced) ────────────────────────────────────────

  /// Marks a serial claimed by [uid]. This now calls the `claimSerial`
  /// Cloud Function instead of writing to Firestore directly — the
  /// atomic transaction lives server-side, so a modified/rooted client
  /// can no longer forge a claim by calling Firestore directly (rules
  /// deny client writes to `serials/*` — see firestore.rules).
  /// Called by AuthService immediately after the Firebase Auth user is
  /// created, as part of account creation.
  Future<Result<void>> claim({
    required String code,
    required String uid,
  }) async {
    final normalized = code.trim().toUpperCase();
    try {
      await _fn.httpsCallable('claimSerial').call({
        'code': normalized,
        // uid is also read server-side from context.auth — sent here only
        // for logging/back-compat, the function does not trust this value.
        'uid': uid,
      });
      return const Success(null);
    } on FirebaseFunctionsException catch (e) {
      return Failure(e.message ?? 'This serial number could not be claimed.', e);
    } catch (e) {
      return Failure(e.toString(), e);
    }
  }

  /// Releases a claim — used only as rollback if account creation fails
  /// *after* the serial was claimed but before the user doc was written
  /// (e.g. Firestore write failure right after Auth succeeded). Calls the
  /// `releaseSerial` Cloud Function, which only allows the uid that holds
  /// the claim to release it.
  Future<void> release(String code) async {
    final normalized = code.trim().toUpperCase();
    try {
      await _fn.httpsCallable('releaseSerial').call({'code': normalized});
    } catch (_) {
      // best-effort rollback only
    }
  }

  // ─── Admin: batch generation (server-enforced) ────────────────────────

  /// Generates [count] fresh, unclaimed serials for [institutionId] — e.g.
  /// when a school signs a contract for 720 seats. Codes are prefixed with
  /// [institutionPrefix] (e.g. "SM" for St. Michael) for readability.
  /// Calls the `generateSerials` Cloud Function — admin-only server-side,
  /// so a client can no longer mint free seats by writing to Firestore
  /// directly (rules deny client writes to `serials/*`).
  Future<Result<List<String>>> generateBatch({
    required String institutionId,
    required String institutionPrefix,
    required int count,
    String? classLevel,
  }) async {
    try {
      final result = await _fn.httpsCallable('generateSerials').call({
        'institutionId': institutionId,
        'institutionPrefix': institutionPrefix,
        'count': count,
        if (classLevel != null) 'classLevel': classLevel,
      });
      final codes = List<String>.from(result.data['codes'] as List);
      return Success(codes);
    } on FirebaseFunctionsException catch (e) {
      return Failure(e.message ?? 'Failed to generate serial numbers.', e);
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
      await _fn.httpsCallable('revokeSerial').call({'code': code.trim().toUpperCase()});
      return const Success(null);
    } on FirebaseFunctionsException catch (e) {
      return Failure(e.message ?? 'Failed to revoke serial number.', e);
    } catch (e) {
      return Failure('Failed to revoke serial number.', e);
    }
  }
}

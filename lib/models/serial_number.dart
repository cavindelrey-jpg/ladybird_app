// lib/models/serial_number.dart
// A SerialNumber is a single pre-provisioned enrollment seat at one
// institution. An institution admin (or Academia ops, on the institution's
// behalf) generates a batch up front — one per paid seat — and hands them
// out as fees are paid. Each serial can be claimed by exactly one student
// account, exactly once. This replaces the old shared "school code" model,
// where anyone who knew the code could join — with these, only someone
// holding a specific, pre-issued serial can create an account under that
// institution, and once claimed it can never be reused or transferred.

import 'package:cloud_firestore/cloud_firestore.dart';

enum SerialStatus { unclaimed, claimed, revoked }

SerialStatus _statusFromString(String? s) {
  switch (s) {
    case 'claimed':
      return SerialStatus.claimed;
    case 'revoked':
      return SerialStatus.revoked;
    default:
      return SerialStatus.unclaimed;
  }
}

class SerialNumber {
  /// The serial code itself (e.g. "SM-4231-A9"), also the Firestore doc ID.
  final String code;
  final String institutionId;
  final SerialStatus status;

  /// Optional pre-assignment metadata set when the batch was generated —
  /// e.g. the class/level this seat was sold for. Purely informational.
  final String? classLevel;
  final String? note;

  final String? claimedByUid;
  final DateTime? claimedAt;
  final DateTime? createdAt;

  const SerialNumber({
    required this.code,
    required this.institutionId,
    this.status = SerialStatus.unclaimed,
    this.classLevel,
    this.note,
    this.claimedByUid,
    this.claimedAt,
    this.createdAt,
  });

  bool get isClaimable => status == SerialStatus.unclaimed;

  factory SerialNumber.fromFirestore(String code, Map<String, dynamic> d) {
    return SerialNumber(
      code: code,
      institutionId: d['institutionId'] ?? '',
      status: _statusFromString(d['status']),
      classLevel: d['classLevel'],
      note: d['note'],
      claimedByUid: d['claimedByUid'],
      claimedAt: (d['claimedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'institutionId': institutionId,
        'status': status.name,
        if (classLevel != null) 'classLevel': classLevel,
        if (note != null) 'note': note,
        'claimedByUid': claimedByUid,
        'claimedAt': claimedAt == null ? null : Timestamp.fromDate(claimedAt!),
        'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      };
}

// lib/models/school.dart
// The school registry this app never actually had. `schoolId` has existed
// on AppUser since long before this session, and content models
// (Announcement/Club/MagazineArticle/SchoolMark/SchoolRequest) all carry a
// schoolId for scoping — but nothing ever wrote a `schools/{schoolId}`
// document itself, and no user account has ever had schoolId set anywhere
// in this codebase (verified by grep before writing this). This is the
// generic, multi-school registry item 4 of the architecture brief asks
// for: "Do not hard-code Green Hills as the only possible school."
//
// Firestore: schools/{schoolId}

import 'package:cloud_firestore/cloud_firestore.dart';

class School {
  final String id;

  /// Short, human-typed prefix used inside every voucher code for this
  /// school (e.g. "GH" for Green Hills) — see school_voucher.dart. Stored
  /// uppercase; unique across the schools collection (enforced at
  /// creation time by SchoolRepository, not by a Firestore constraint —
  /// Firestore has none).
  final String code;

  final String name;
  final DateTime createdAt;

  const School({
    required this.id,
    required this.code,
    required this.name,
    required this.createdAt,
  });

  factory School.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    return School(
      id: doc.id,
      code: (d['code'] ?? '').toString().toUpperCase(),
      name: d['name'] ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'code': code.toUpperCase(),
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

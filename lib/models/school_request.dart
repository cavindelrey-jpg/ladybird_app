// lib/models/school_request.dart
// School Connect's five request types (Report an Issue, Leave Request,
// Fee Inquiry, School Request, Give Feedback) modeled as ONE collection
// with a `type` field, not five separate collections/pages -- they share
// the exact same shape (a student writes a message, staff sees and
// responds to it), so five collections would just be the same rule and
// the same UI five times over.
//
// Firestore: school_requests/{id}

import 'package:cloud_firestore/cloud_firestore.dart';

enum SchoolRequestType { issue, leave, feeInquiry, general, feedback }

extension SchoolRequestTypeExt on SchoolRequestType {
  String get label {
    switch (this) {
      case SchoolRequestType.issue:       return 'Report an Issue';
      case SchoolRequestType.leave:       return 'Leave Request';
      case SchoolRequestType.feeInquiry:  return 'Fee Inquiry';
      case SchoolRequestType.general:     return 'School Request';
      case SchoolRequestType.feedback:    return 'Give Feedback';
    }
  }
}

enum SchoolRequestStatus { pending, inProgress, resolved }

extension SchoolRequestStatusExt on SchoolRequestStatus {
  String get label {
    switch (this) {
      case SchoolRequestStatus.pending:    return 'Pending';
      case SchoolRequestStatus.inProgress: return 'In Progress';
      case SchoolRequestStatus.resolved:   return 'Resolved';
    }
  }
}

class SchoolRequest {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String classLevel;
  final SchoolRequestType type;
  final String message;
  final SchoolRequestStatus status;
  final String? staffResponse;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  const SchoolRequest({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.classLevel,
    required this.type,
    required this.message,
    this.status = SchoolRequestStatus.pending,
    this.staffResponse,
    this.createdAt,
    this.respondedAt,
  });

  factory SchoolRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SchoolRequest(
      id: doc.id,
      schoolId: d['schoolId'] ?? '',
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      classLevel: d['classLevel'] ?? '',
      type: SchoolRequestType.values.firstWhere(
          (t) => t.name == d['type'], orElse: () => SchoolRequestType.general),
      message: d['message'] ?? '',
      status: SchoolRequestStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => SchoolRequestStatus.pending),
      staffResponse: d['staffResponse'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      respondedAt: (d['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        'classLevel': classLevel,
        'type': type.name,
        'message': message,
        'status': status.name,
        'staffResponse': staffResponse,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

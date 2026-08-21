// lib/models/school_request.dart
// The real backing model for School Connect's "How can we help you
// today?" grid. Deliberately ONE model/collection differentiated by
// [SchoolRequestType] rather than five bespoke forms and five
// collections — Report an Issue, Leave Request, Fee Enquiries, School
// Requests and Give Feedback all route through the same submit/track
// pipeline, which is what actually makes every tile in that grid a real
// destination instead of a dead button: submit once, see it land in
// "Your Requests" with a status, no fabricated backend behind it.

import 'package:cloud_firestore/cloud_firestore.dart';

enum SchoolRequestType { issue, leaveRequest, feeEnquiry, generalRequest, feedback }

extension SchoolRequestTypeX on SchoolRequestType {
  String get label {
    switch (this) {
      case SchoolRequestType.issue:          return 'Report an Issue';
      case SchoolRequestType.leaveRequest:   return 'Leave Request';
      case SchoolRequestType.feeEnquiry:     return 'Fee Enquiries';
      case SchoolRequestType.generalRequest: return 'School Requests';
      case SchoolRequestType.feedback:       return 'Give Feedback';
    }
  }

  /// Which real-world office this is routed to — shown to the student so
  /// "Contact" reads as a genuine routing rule rather than three
  /// fabricated phone numbers this app has no data for.
  String get routedTo {
    switch (this) {
      case SchoolRequestType.issue:          return 'School Office';
      case SchoolRequestType.leaveRequest:   return 'Class Master';
      case SchoolRequestType.feeEnquiry:     return "Bursar's Office";
      case SchoolRequestType.generalRequest: return 'School Office';
      case SchoolRequestType.feedback:       return 'School Administration';
    }
  }

  String get hint {
    switch (this) {
      case SchoolRequestType.issue:
        return 'Describe what happened, where, and when.';
      case SchoolRequestType.leaveRequest:
        return 'State the dates you\'ll be away and the reason.';
      case SchoolRequestType.feeEnquiry:
        return 'Ask about balances, payment plans or receipts.';
      case SchoolRequestType.generalRequest:
        return 'Any other request for the school office.';
      case SchoolRequestType.feedback:
        return 'Tell us what\'s working and what could be better.';
    }
  }
}

enum SchoolRequestStatus { open, inReview, resolved }

extension SchoolRequestStatusX on SchoolRequestStatus {
  String get label {
    switch (this) {
      case SchoolRequestStatus.open:     return 'Submitted';
      case SchoolRequestStatus.inReview: return 'In Review';
      case SchoolRequestStatus.resolved: return 'Resolved';
    }
  }
}

class SchoolRequest {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final SchoolRequestType type;
  final String subject;
  final String message;
  final SchoolRequestStatus status;
  final DateTime createdAt;

  const SchoolRequest({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.type,
    required this.subject,
    required this.message,
    this.status = SchoolRequestStatus.open,
    required this.createdAt,
  });

  factory SchoolRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SchoolRequest(
      id: doc.id,
      schoolId: d['schoolId'] ?? '',
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      type: SchoolRequestType.values.firstWhere(
          (t) => t.name == d['type'],
          orElse: () => SchoolRequestType.generalRequest),
      subject: d['subject'] ?? '',
      message: d['message'] ?? '',
      status: SchoolRequestStatus.values.firstWhere(
          (s) => s.name == d['status'],
          orElse: () => SchoolRequestStatus.open),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolId': schoolId,
    'studentId': studentId,
    'studentName': studentName,
    'type': type.name,
    'subject': subject,
    'message': message,
    'status': status.name,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

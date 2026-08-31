// lib/models/school_request.dart
// School Connect's five request types (Report an Issue, Leave Request,
// Fee Inquiry, School Request, Give Feedback) modeled as ONE type with a
// `type` field, not five separate models/pages. No Postgres table yet —
// zero real data at migration time; SchoolRequestRepository below is an
// honest stub.

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
}

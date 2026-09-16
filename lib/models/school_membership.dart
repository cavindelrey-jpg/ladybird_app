// lib/models/school_membership.dart

import 'school_voucher.dart' show SchoolRole, SchoolRoleX;
import 'teaching_assignment.dart';

class SchoolMembership {
  final String id;
  final String userId;
  final String schoolId;
  final SchoolRole role;
  final String classLevel;
  final String? departmentId;
  final List<TeachingAssignment> teachingAssignments;
  final String? classMasterOfClass;
  final String? schoolVoucherRef;
  final DateTime joinedAt;

  const SchoolMembership({
    required this.id,
    required this.userId,
    required this.schoolId,
    this.role = SchoolRole.student,
    this.classLevel = '',
    this.departmentId,
    this.teachingAssignments = const [],
    this.classMasterOfClass,
    this.schoolVoucherRef,
    required this.joinedAt,
  });

  factory SchoolMembership.fromSupabase(Map<String, dynamic> d) => SchoolMembership(
    id: d['id'] as String,
    userId: d['user_id'] as String,
    schoolId: d['school_id'] as String,
    role: SchoolRoleX.fromName(d['role']?.toString() ?? '') ?? SchoolRole.student,
    classLevel: d['class_level'] ?? '',
    departmentId: d['department_id'],
    teachingAssignments: (d['teaching_assignments'] as List<dynamic>? ?? [])
        .map((m) => TeachingAssignment.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList(),
    classMasterOfClass: d['class_master_of_class'],
    schoolVoucherRef: d['school_voucher_ref'],
    joinedAt: DateTime.tryParse(d['joined_at']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toSupabase() => {
    'user_id': userId,
    'school_id': schoolId,
    'role': role.name,
    'class_level': classLevel,
    'department_id': departmentId,
    'teaching_assignments': teachingAssignments.map((t) => t.toMap()).toList(),
    'class_master_of_class': classMasterOfClass,
    'school_voucher_ref': schoolVoucherRef,
    'joined_at': joinedAt.toIso8601String(),
  };

  SchoolMembership copyWith({
    String? id,
    String? userId,
    String? schoolId,
    SchoolRole? role,
    String? classLevel,
    String? departmentId,
    List<TeachingAssignment>? teachingAssignments,
    String? classMasterOfClass,
    String? schoolVoucherRef,
    DateTime? joinedAt,
  }) => SchoolMembership(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    schoolId: schoolId ?? this.schoolId,
    role: role ?? this.role,
    classLevel: classLevel ?? this.classLevel,
    departmentId: departmentId ?? this.departmentId,
    teachingAssignments: teachingAssignments ?? this.teachingAssignments,
    classMasterOfClass: classMasterOfClass ?? this.classMasterOfClass,
    schoolVoucherRef: schoolVoucherRef ?? this.schoolVoucherRef,
    joinedAt: joinedAt ?? this.joinedAt,
  );
}

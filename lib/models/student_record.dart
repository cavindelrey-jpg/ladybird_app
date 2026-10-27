// lib/models/student_record.dart
// Roster entry for an enrolled student in a school.
// Preserves official student name for class lists, attendance and marks,
// alongside a separate account username and linked account ID.

class StudentRecord {
  final String id;
  final String schoolId;
  /// Official student name on the school register (e.g. "Brice Ngono")
  final String name;
  /// Separate student account username / handle (e.g. "brice2026")
  final String? username;
  /// Linked auth / user account ID
  final String? accountId;
  final String classLevel;
  final String? matricule;
  final String? parentContact;
  final String? gender;
  final DateTime? createdAt;

  const StudentRecord({
    required this.id,
    required this.schoolId,
    required this.name,
    this.username,
    this.accountId,
    required this.classLevel,
    this.matricule,
    this.parentContact,
    this.gender,
    this.createdAt,
  });

  String get officialName => name;

  factory StudentRecord.fromMap(Map<String, dynamic> m) {
    return StudentRecord(
      id: m['id']?.toString() ?? '',
      schoolId: m['school_id']?.toString() ?? m['schoolId']?.toString() ?? '',
      name: m['student_name']?.toString() ?? m['official_name']?.toString() ?? m['name']?.toString() ?? '',
      username: m['username']?.toString() ?? m['account_username']?.toString(),
      accountId: m['account_id']?.toString() ?? m['user_id']?.toString(),
      classLevel: m['class_level']?.toString() ?? m['classLevel']?.toString() ?? '',
      matricule: m['matricule']?.toString(),
      parentContact: m['parent_contact']?.toString() ?? m['parentContact']?.toString(),
      gender: m['gender']?.toString(),
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_id': schoolId,
      'student_name': name,
      'official_name': name,
      'username': username,
      'account_id': accountId,
      'user_id': accountId,
      'class_level': classLevel,
      'matricule': matricule,
      'parent_contact': parentContact,
      'gender': gender,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  StudentRecord copyWith({
    String? id,
    String? schoolId,
    String? name,
    String? username,
    String? accountId,
    String? classLevel,
    String? matricule,
    String? parentContact,
    String? gender,
    DateTime? createdAt,
  }) {
    return StudentRecord(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      username: username ?? this.username,
      accountId: accountId ?? this.accountId,
      classLevel: classLevel ?? this.classLevel,
      matricule: matricule ?? this.matricule,
      parentContact: parentContact ?? this.parentContact,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

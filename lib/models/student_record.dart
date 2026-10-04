// lib/models/student_record.dart
// Roster entry for an enrolled student in a school.

class StudentRecord {
  final String id;
  final String schoolId;
  final String name;
  final String classLevel;
  final String? matricule;
  final String? parentContact;
  final String? gender;
  final DateTime? createdAt;

  const StudentRecord({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.classLevel,
    this.matricule,
    this.parentContact,
    this.gender,
    this.createdAt,
  });

  factory StudentRecord.fromMap(Map<String, dynamic> m) {
    return StudentRecord(
      id: m['id']?.toString() ?? '',
      schoolId: m['school_id']?.toString() ?? m['schoolId']?.toString() ?? '',
      name: m['student_name']?.toString() ?? m['name']?.toString() ?? '',
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
      classLevel: classLevel ?? this.classLevel,
      matricule: matricule ?? this.matricule,
      parentContact: parentContact ?? this.parentContact,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// lib/models/examination.dart
// Production-ready data models for Examinations and School-configured Letterheads/Templates.

import 'exam_question.dart';

enum ExamTemplateType {
  examination,
  classTest,
  assignment,
  mockExamination,
  practical,
  quiz;

  String get label {
    switch (this) {
      case ExamTemplateType.examination:
        return 'Examination';
      case ExamTemplateType.classTest:
        return 'Class Test';
      case ExamTemplateType.assignment:
        return 'Assignment';
      case ExamTemplateType.mockExamination:
        return 'Mock Examination';
      case ExamTemplateType.practical:
        return 'Practical';
      case ExamTemplateType.quiz:
        return 'Quiz';
    }
  }

  static ExamTemplateType fromString(String? val) {
    return ExamTemplateType.values.firstWhere(
      (e) => e.name.toLowerCase() == (val ?? '').toLowerCase(),
      orElse: () => ExamTemplateType.examination,
    );
  }
}

/// School-level examination template and digital letterhead configured by
/// administrators (e.g. logo, country header, ministry, motto, formatting).
class SchoolExamTemplate {
  final String id;
  final String schoolId;
  final String name;
  final ExamTemplateType type;
  final String schoolName;
  final String? schoolLogoUrl;
  final String countryHeader;
  final String subHeader;
  final String? motto;
  final bool includeStudentFields;
  final bool includeInstructionsBox;
  final bool includeMarksBox;
  final String fontFamily;
  final bool isDefault;
  final String? defaultInstructions;

  const SchoolExamTemplate({
    required this.id,
    required this.schoolId,
    required this.name,
    this.type = ExamTemplateType.examination,
    required this.schoolName,
    this.schoolLogoUrl,
    this.countryHeader = 'REPUBLIC OF CAMEROON\nPeace - Work - Fatherland\nMINISTRY OF SECONDARY EDUCATION',
    this.subHeader = 'REGIONAL DELEGATION OF SECONDARY EDUCATION\nP.O. Box 1234, Douala | Tel: +237 670 000 000',
    this.motto = 'Excellence - Discipline - Success',
    this.includeStudentFields = true,
    this.includeInstructionsBox = true,
    this.includeMarksBox = true,
    this.fontFamily = 'Serif',
    this.isDefault = false,
    this.defaultInstructions,
  });

  SchoolExamTemplate copyWith({
    String? id,
    String? schoolId,
    String? name,
    ExamTemplateType? type,
    String? schoolName,
    String? schoolLogoUrl,
    String? countryHeader,
    String? subHeader,
    String? motto,
    bool? includeStudentFields,
    bool? includeInstructionsBox,
    bool? includeMarksBox,
    String? fontFamily,
    bool? isDefault,
    String? defaultInstructions,
  }) {
    return SchoolExamTemplate(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      type: type ?? this.type,
      schoolName: schoolName ?? this.schoolName,
      schoolLogoUrl: schoolLogoUrl ?? this.schoolLogoUrl,
      countryHeader: countryHeader ?? this.countryHeader,
      subHeader: subHeader ?? this.subHeader,
      motto: motto ?? this.motto,
      includeStudentFields: includeStudentFields ?? this.includeStudentFields,
      includeInstructionsBox: includeInstructionsBox ?? this.includeInstructionsBox,
      includeMarksBox: includeMarksBox ?? this.includeMarksBox,
      fontFamily: fontFamily ?? this.fontFamily,
      isDefault: isDefault ?? this.isDefault,
      defaultInstructions: defaultInstructions ?? this.defaultInstructions,
    );
  }

  factory SchoolExamTemplate.fromJson(Map<String, dynamic> json) {
    return SchoolExamTemplate(
      id: json['id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Standard Examination Template',
      type: ExamTemplateType.fromString(json['type'] as String?),
      schoolName: json['school_name'] as String? ?? 'CFPMI',
      schoolLogoUrl: json['school_logo_url'] as String?,
      countryHeader: json['country_header'] as String? ??
          'REPUBLIC OF CAMEROON\nPeace - Work - Fatherland\nMINISTRY OF SECONDARY EDUCATION',
      subHeader: json['sub_header'] as String? ??
          'REGIONAL DELEGATION OF SECONDARY EDUCATION\nP.O. Box 1234, Douala | Tel: +237 670 000 000',
      motto: json['motto'] as String? ?? 'Excellence - Discipline - Success',
      includeStudentFields: json['include_student_fields'] as bool? ?? true,
      includeInstructionsBox: json['include_instructions_box'] as bool? ?? true,
      includeMarksBox: json['include_marks_box'] as bool? ?? true,
      fontFamily: json['font_family'] as String? ?? 'Serif',
      isDefault: json['is_default'] as bool? ?? false,
      defaultInstructions: json['default_instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'type': type.name,
        'school_name': schoolName,
        'school_logo_url': schoolLogoUrl,
        'country_header': countryHeader,
        'sub_header': subHeader,
        'motto': motto,
        'include_student_fields': includeStudentFields,
        'include_instructions_box': includeInstructionsBox,
        'include_marks_box': includeMarksBox,
        'font_family': fontFamily,
        'is_default': isDefault,
        'default_instructions': defaultInstructions,
      };
}

/// A complete examination composed by a teacher.
class Examination {
  final String id;
  final String schoolId;
  final String title; // e.g. "First Sequence Examination"
  final ExamTemplateType examinationType;
  final String subject;
  final String classLevel;
  final String academicYear; // e.g. "2025/2026"
  final int durationMinutes; // e.g. 90
  final DateTime date;
  final String examinerName;
  final String examinerId;
  final String instructions;
  final int totalMarks;
  final String? templateId;
  final SchoolExamTemplate? selectedTemplate;
  final List<ExamQuestion> questions;
  final String status; // "draft", "finalized"
  final DateTime createdAt;
  final DateTime updatedAt;

  const Examination({
    required this.id,
    required this.schoolId,
    required this.title,
    this.examinationType = ExamTemplateType.examination,
    required this.subject,
    required this.classLevel,
    required this.academicYear,
    this.durationMinutes = 90,
    required this.date,
    required this.examinerName,
    required this.examinerId,
    this.instructions = 'Answer all questions. Show all working clearly.',
    this.totalMarks = 0,
    this.templateId,
    this.selectedTemplate,
    this.questions = const [],
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
  });

  int get computedTotalMarks => questions.fold(0, (acc, q) => acc + q.marks);

  int get effectiveTotalMarks => totalMarks > 0 ? totalMarks : computedTotalMarks;

  Examination copyWith({
    String? id,
    String? schoolId,
    String? title,
    ExamTemplateType? examinationType,
    String? subject,
    String? classLevel,
    String? academicYear,
    int? durationMinutes,
    DateTime? date,
    String? examinerName,
    String? examinerId,
    String? instructions,
    int? totalMarks,
    String? templateId,
    SchoolExamTemplate? selectedTemplate,
    List<ExamQuestion>? questions,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Examination(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      title: title ?? this.title,
      examinationType: examinationType ?? this.examinationType,
      subject: subject ?? this.subject,
      classLevel: classLevel ?? this.classLevel,
      academicYear: academicYear ?? this.academicYear,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      date: date ?? this.date,
      examinerName: examinerName ?? this.examinerName,
      examinerId: examinerId ?? this.examinerId,
      instructions: instructions ?? this.instructions,
      totalMarks: totalMarks ?? this.totalMarks,
      templateId: templateId ?? this.templateId,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      questions: questions ?? this.questions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Examination.fromJson(Map<String, dynamic> json) {
    return Examination(
      id: json['id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Examination',
      examinationType: ExamTemplateType.fromString(json['examination_type'] as String?),
      subject: json['subject'] as String? ?? '',
      classLevel: json['class_level'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '2025/2026',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 90,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      examinerName: json['examiner_name'] as String? ?? '',
      examinerId: json['examiner_id'] as String? ?? '',
      instructions: json['instructions'] as String? ?? 'Answer all questions. Show all working clearly.',
      totalMarks: (json['total_marks'] as num?)?.toInt() ?? 0,
      templateId: json['template_id'] as String?,
      selectedTemplate: json['selected_template'] != null
          ? SchoolExamTemplate.fromJson(json['selected_template'] as Map<String, dynamic>)
          : null,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((q) => ExamQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'draft',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'title': title,
        'examination_type': examinationType.name,
        'subject': subject,
        'class_level': classLevel,
        'academic_year': academicYear,
        'duration_minutes': durationMinutes,
        'date': date.toIso8601String(),
        'examiner_name': examinerName,
        'examiner_id': examinerId,
        'instructions': instructions,
        'total_marks': effectiveTotalMarks,
        'template_id': templateId,
        'selected_template': selectedTemplate?.toJson(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

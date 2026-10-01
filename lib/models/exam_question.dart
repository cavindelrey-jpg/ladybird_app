// lib/models/exam_question.dart
// Three-layer model: Question -> Collection/Question Bank -> Exam.
// Preserves unique question ID, original source, topic, subtopic, marks,
// question content, and source reference while allowing teachers to edit
// wording or marks and reorder freely like songs in a playlist.

import 'essay_key_point.dart';
import 'test.dart';

export 'test.dart' show QuestionType, QuestionTypeExt;

class ExamQuestion {
  final String id;
  final String content; // Question prompt / text
  final int marks;
  final QuestionType type; // mcq, structured, longForm (essay)
  final String subject;
  final String classLevel;
  final String topic;
  final String subtopic;
  final String difficulty; // easy, medium, hard
  final String source; // e.g. "GCE O-Level 2023 Paper 2", "School Question Bank"
  final String? sourceRef; // e.g. academic_content.id or textbook citation
  final int? year;
  final List<String> options; // For MCQ
  final int? correctOptionIndex; // For MCQ
  final String? rubric; // Guidance for grading structured / essay
  final List<EssayKeyPoint> expectedPoints; // Key grading points
  final List<String> tags;
  final String? schoolId;
  final String? createdBy; // Teacher user ID
  final DateTime createdAt;

  const ExamQuestion({
    required this.id,
    required this.content,
    required this.marks,
    this.type = QuestionType.structured,
    required this.subject,
    this.classLevel = '',
    this.topic = '',
    this.subtopic = '',
    this.difficulty = 'medium',
    this.source = 'School Question Bank',
    this.sourceRef,
    this.year,
    this.options = const [],
    this.correctOptionIndex,
    this.rubric,
    this.expectedPoints = const [],
    this.tags = const [],
    this.schoolId,
    this.createdBy,
    required this.createdAt,
  });

  ExamQuestion copyWith({
    String? id,
    String? content,
    int? marks,
    QuestionType? type,
    String? subject,
    String? classLevel,
    String? topic,
    String? subtopic,
    String? difficulty,
    String? source,
    String? sourceRef,
    int? year,
    List<String>? options,
    int? correctOptionIndex,
    String? rubric,
    List<EssayKeyPoint>? expectedPoints,
    List<String>? tags,
    String? schoolId,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ExamQuestion(
      id: id ?? this.id,
      content: content ?? this.content,
      marks: marks ?? this.marks,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      classLevel: classLevel ?? this.classLevel,
      topic: topic ?? this.topic,
      subtopic: subtopic ?? this.subtopic,
      difficulty: difficulty ?? this.difficulty,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      year: year ?? this.year,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      rubric: rubric ?? this.rubric,
      expectedPoints: expectedPoints ?? this.expectedPoints,
      tags: tags ?? this.tags,
      schoolId: schoolId ?? this.schoolId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? json['prompt'] as String? ?? '',
      marks: (json['marks'] as num?)?.toInt() ?? (json['points'] as num?)?.toInt() ?? 5,
      type: QuestionTypeExt.fromKey(json['type'] as String?),
      subject: json['subject'] as String? ?? '',
      classLevel: json['class_level'] as String? ?? json['classLevel'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      subtopic: json['subtopic'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      source: json['source'] as String? ?? 'School Question Bank',
      sourceRef: json['source_ref'] as String? ?? json['sourceRef'] as String?,
      year: (json['year'] as num?)?.toInt(),
      options: (json['options'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      correctOptionIndex: (json['correct_option_index'] as num?)?.toInt() ?? (json['correctIndex'] as num?)?.toInt(),
      rubric: json['rubric'] as String? ?? json['rubric_guidance'] as String?,
      expectedPoints: (json['expected_points'] as List<dynamic>? ?? [])
          .map((e) => EssayKeyPoint.fromMap(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      schoolId: json['school_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'marks': marks,
        'type': type.name,
        'subject': subject,
        'class_level': classLevel,
        'topic': topic,
        'subtopic': subtopic,
        'difficulty': difficulty,
        'source': source,
        'source_ref': sourceRef,
        'year': year,
        'options': options,
        'correct_option_index': correctOptionIndex,
        'rubric': rubric,
        'expected_points': expectedPoints.map((e) => e.toMap()).toList(),
        'tags': tags,
        'school_id': schoolId,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };
}

/// A teacher's saved collection of questions (e.g. "My Revision Questions", "Algebra Term 1")
class QuestionCollection {
  final String id;
  final String teacherId;
  final String schoolId;
  final String name;
  final String description;
  final String subject;
  final List<ExamQuestion> questions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuestionCollection({
    required this.id,
    required this.teacherId,
    required this.schoolId,
    required this.name,
    this.description = '',
    required this.subject,
    this.questions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalMarks => questions.fold(0, (acc, q) => acc + q.marks);

  QuestionCollection copyWith({
    String? id,
    String? teacherId,
    String? schoolId,
    String? name,
    String? description,
    String? subject,
    List<ExamQuestion>? questions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuestionCollection(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory QuestionCollection.fromJson(Map<String, dynamic> json) {
    return QuestionCollection(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Collection',
      description: json['description'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((q) => ExamQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'teacher_id': teacherId,
        'school_id': schoolId,
        'name': name,
        'description': description,
        'subject': subject,
        'questions': questions.map((q) => q.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

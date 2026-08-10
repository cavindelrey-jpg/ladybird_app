// lib/models/academic_content.dart
// Replaces LibraryItem. Unified model for all academic content types.

import 'package:cloud_firestore/cloud_firestore.dart';

enum ContentType {
  note,
  pastPaper,
  book,
  video,
  assignment,
  presentation,
  researchPaper,
}

extension ContentTypeExt on ContentType {
  String get label {
    switch (this) {
      case ContentType.note:          return 'Notes';
      case ContentType.pastPaper:     return 'Past Papers';
      case ContentType.book:          return 'Books';
      case ContentType.video:         return 'Videos';
      case ContentType.assignment:    return 'Assignments';
      case ContentType.presentation:  return 'Presentations';
      case ContentType.researchPaper: return 'Research Papers';
    }
  }

  String get emoji {
    switch (this) {
      case ContentType.note:          return '📝';
      case ContentType.pastPaper:     return '📄';
      case ContentType.book:          return '📚';
      case ContentType.video:         return '🎬';
      case ContentType.assignment:    return '✏️';
      case ContentType.presentation:  return '🖥️';
      case ContentType.researchPaper: return '🔬';
    }
  }
}

/// Predefined, admin/system-controlled categories. This is the ONLY
/// source of subject values allowed at upload time — never free text.
/// Both the upload picker and the Library filter bar read from this list.
const kAcademicSubjects = [
  'Mathematics',
  'Science',
  'Languages',
  'Social Studies',
  'Computer Science',
  'Arts & Literature',
  'Business',
  'Other',
];

/// Level/Class classification — same "predefined, never free text" model
/// as [kAcademicSubjects]. Cameroon secondary system (Form 1-5, Lower/
/// Upper Sixth) plus catch-alls for content that isn't level-specific.
const kAcademicLevels = [
  'Form 1',
  'Form 2',
  'Form 3',
  'Form 4',
  'Form 5',
  'Lower Sixth',
  'Upper Sixth',
  'Undergraduate',
  'All Levels',
];

/// Examination/series classification — distinct from [ContentType] (which
/// captures the *document* kind: Notes/Past Paper/Book/etc). This captures
/// which exam series a resource belongs to, so "GCE Physics 2022" and
/// "GCE Physics 2023" share one exam value instead of minting a new
/// unstructured tag per upload.
const kExamBoards = [
  'GCE',
  'Probatoire',
  'BEPC',
  'BAC',
  'Mock Exam',
  'School Exam',
  'N/A',
];

class AcademicContent {
  final String id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String? fileUrl;
  final ContentType contentType;
  final String subject;
  /// Level/Class — one of [kAcademicLevels], or '' for older docs uploaded
  /// before this field existed (treated as "unspecified", not a bug).
  final String level;
  /// Exam series — one of [kExamBoards], or '' for content this doesn't
  /// apply to / older docs uploaded before this field existed.
  final String examBoard;
  /// Exam/publication year, e.g. 2024. Null when not applicable/unknown.
  final int? year;
  final String institutionId;
  final String uploadedBy;
  final String uploaderName;
  final int? fileSizeBytes;
  final DateTime uploadDate;
  final List<String> tags;
  final int views;
  final int downloads;

  const AcademicContent({
    required this.id,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    this.fileUrl,
    required this.contentType,
    required this.subject,
    this.level = '',
    this.examBoard = '',
    this.year,
    required this.institutionId,
    required this.uploadedBy,
    this.uploaderName = 'Unknown',
    this.fileSizeBytes,
    required this.uploadDate,
    required this.tags,
    this.views = 0,
    this.downloads = 0,
  });

  factory AcademicContent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final typeStr = d['contentType'] as String? ?? 'note';
    final ts = d['uploadDate'];
    return AcademicContent(
      id: doc.id,
      title: d['title'] ?? 'Untitled',
      description: d['description'] ?? '',
      thumbnailUrl: d['thumbnailUrl'],
      fileUrl: d['fileUrl'],
      contentType: ContentType.values.firstWhere(
        (t) => t.name == typeStr, orElse: () => ContentType.note),
      subject: d['subject'] ?? '',
      level: d['level'] ?? '',
      examBoard: d['examBoard'] ?? '',
      year: (d['year'] as num?)?.toInt(),
      institutionId: d['institutionId'] ?? '',
      uploadedBy: d['uploadedBy'] ?? '',
      uploaderName: d['uploaderName'] ?? 'Unknown',
      fileSizeBytes: (d['fileSizeBytes'] as num?)?.toInt(),
      uploadDate: ts is Timestamp
          ? ts.toDate()
          : DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now(),
      tags: List<String>.from(d['tags'] ?? []),
      views: (d['views'] as num?)?.toInt() ?? 0,
      downloads: (d['downloads'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'fileUrl': fileUrl,
    'contentType': contentType.name,
    'subject': subject,
    'level': level,
    'examBoard': examBoard,
    'year': year,
    'institutionId': institutionId,
    'uploadedBy': uploadedBy,
    'uploaderName': uploaderName,
    'fileSizeBytes': fileSizeBytes,
    'uploadDate': Timestamp.fromDate(uploadDate),
    'tags': tags,
    'views': views,
    'downloads': downloads,
  };

  AcademicContent copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? fileUrl,
    ContentType? contentType,
    String? subject,
    String? level,
    String? examBoard,
    int? year,
    bool clearYear = false,
    String? institutionId,
    String? uploadedBy,
    String? uploaderName,
    int? fileSizeBytes,
    DateTime? uploadDate,
    List<String>? tags,
    int? views,
    int? downloads,
  }) => AcademicContent(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    fileUrl: fileUrl ?? this.fileUrl,
    contentType: contentType ?? this.contentType,
    subject: subject ?? this.subject,
    level: level ?? this.level,
    examBoard: examBoard ?? this.examBoard,
    year: clearYear ? null : (year ?? this.year),
    institutionId: institutionId ?? this.institutionId,
    uploadedBy: uploadedBy ?? this.uploadedBy,
    uploaderName: uploaderName ?? this.uploaderName,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    uploadDate: uploadDate ?? this.uploadDate,
    tags: tags ?? this.tags,
    views: views ?? this.views,
    downloads: downloads ?? this.downloads,
  );
}


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

class AcademicContent {
  final String id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String? fileUrl;
  final ContentType contentType;
  final String subject;
  final String institutionId;
  final String uploadedBy;
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
    required this.institutionId,
    required this.uploadedBy,
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
      institutionId: d['institutionId'] ?? '',
      uploadedBy: d['uploadedBy'] ?? '',
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
    'institutionId': institutionId,
    'uploadedBy': uploadedBy,
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
    String? institutionId,
    String? uploadedBy,
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
    institutionId: institutionId ?? this.institutionId,
    uploadedBy: uploadedBy ?? this.uploadedBy,
    uploadDate: uploadDate ?? this.uploadDate,
    tags: tags ?? this.tags,
    views: views ?? this.views,
    downloads: downloads ?? this.downloads,
  );
}

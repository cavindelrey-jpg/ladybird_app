// lib/models/library_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'academic_content.dart';

class LibraryItem {
  final String id;
  final String title;
  final String author;
  final String subject;
  final String size;
  final int views;
  final String? thumbnailUrl;
  final ContentType type;
  final bool isPremium;
  final String? downloadUrl;
  final String? schoolId;

  const LibraryItem({
    required this.id,
    required this.title,
    required this.author,
    required this.subject,
    required this.size,
    required this.views,
    this.thumbnailUrl,
    required this.type,
    this.isPremium = false,
    this.downloadUrl,
    this.schoolId,
  });

  factory LibraryItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final typeStr = d['type'] as String? ?? 'note';
    return LibraryItem(
      id: doc.id,
      title: d['title'] ?? 'Untitled',
      author: d['author'] ?? '',
      subject: d['subject'] ?? '',
      size: d['size'] ?? '0 MB',
      views: (d['views'] as num?)?.toInt() ?? 0,
      thumbnailUrl: d['thumbnailUrl'],
      type: ContentType.values.firstWhere(
        (t) => t.name == typeStr, orElse: () => ContentType.note),
      isPremium: d['isPremium'] ?? false,
      downloadUrl: d['downloadUrl'],
      schoolId: d['schoolId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'author': author,
    'subject': subject,
    'size': size,
    'views': views,
    'thumbnailUrl': thumbnailUrl,
    'type': type.name,
    'isPremium': isPremium,
    'downloadUrl': downloadUrl,
    'schoolId': schoolId,
  };
}

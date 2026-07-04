// lib/models/announcement.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String body;
  final String tag;
  final String authorName;
  final String authorId;
  final DateTime date;
  final bool urgent;
  final String? schoolId;

  /// What generated this row: 'magazinePost' | 'paperUpload' |
  /// 'clubAnnouncement' | 'general'. Lets the Home feed route the tap to
  /// the right place via [referenceId] instead of everything being static.
  final String sourceType;
  final String? referenceId; // articleId / paperId / clubId

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.tag,
    required this.authorName,
    required this.authorId,
    required this.date,
    this.urgent = false,
    this.schoolId,
    this.sourceType = 'general',
    this.referenceId,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      tag: d['tag'] ?? '',
      authorName: d['authorName'] ?? '',
      authorId: d['authorId'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      urgent: d['urgent'] ?? false,
      schoolId: d['schoolId'],
      sourceType: d['sourceType'] ?? 'general',
      referenceId: d['referenceId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'body': body,
    'tag': tag,
    'authorName': authorName,
    'authorId': authorId,
    'date': Timestamp.fromDate(date),
    'urgent': urgent,
    'schoolId': schoolId,
    'sourceType': sourceType,
    'referenceId': referenceId,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

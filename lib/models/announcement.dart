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
    'createdAt': FieldValue.serverTimestamp(),
  };
}

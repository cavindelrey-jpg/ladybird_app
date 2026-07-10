// lib/models/public_course.dart
// The general-app "marketplace" Course — genuinely separate from the
// school-scoped `Course` model (models/course.dart), which stays exactly
// as-is and keeps powering Attendance/Assignments for school-linked
// accounts. This one is Academia's own written content: any signed-in
// user can create and publish a course, organized by category (and, per
// the earlier design conversation, eventually educational level > subject
// > topic) rather than by school. Read in-app, not downloaded — same
// "notes made to be read on the app, not a file" distinction Library
// doesn't share.
//
// Firestore: public_courses/{courseId}
//            public_courses/{courseId}/comments/{commentId}
//            public_courses/{courseId}/ratings/{userId}
//            public_courses/{courseId}/bookmarks/{userId}
//            public_courses/{courseId}/learners/{userId}

import 'package:cloud_firestore/cloud_firestore.dart';

class PublicCourse {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorPhotoUrl;
  String title;
  String description;

  /// Plain-text body — kept as a fallback/derived value for card
  /// excerpts, search, and read-time estimates. Always regenerated from
  /// bodyDelta's plain text whenever the rich content is saved; never
  /// edited directly once bodyDelta exists.
  String body;

  /// Rich content as a Quill Delta, JSON-encoded. Null/empty means this
  /// course predates rich text and only has plain `body` — the reader
  /// falls back to rendering that as plain text in that case.
  String? bodyDelta;

  String category;
  String? coverImageUrl;
  bool published;

  int enrolledCount;  // "learners" — people who've started this course
  double avgRating;
  int ratingCount;
  int likeCount;
  int commentCount;

  final DateTime createdAt;
  DateTime updatedAt;

  PublicCourse({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorPhotoUrl,
    required this.title,
    this.description = '',
    this.body = '',
    this.bodyDelta,
    this.category = 'Mathematics',
    this.coverImageUrl,
    this.published = true,
    this.enrolledCount = 0,
    this.avgRating = 0,
    this.ratingCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory PublicCourse.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PublicCourse(
      id: doc.id,
      creatorId: d['creatorId'] ?? '',
      creatorName: d['creatorName'] ?? 'Unknown',
      creatorPhotoUrl: d['creatorPhotoUrl'],
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      body: d['body'] ?? '',
      bodyDelta: d['bodyDelta'],
      category: d['category'] ?? 'Mathematics',
      coverImageUrl: d['coverImageUrl'],
      published: d['published'] ?? true,
      enrolledCount: d['enrolledCount'] ?? 0,
      avgRating: (d['avgRating'] ?? 0).toDouble(),
      ratingCount: d['ratingCount'] ?? 0,
      likeCount: d['likeCount'] ?? 0,
      commentCount: d['commentCount'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'creatorId': creatorId,
        'creatorName': creatorName,
        'creatorPhotoUrl': creatorPhotoUrl,
        'title': title,
        'description': description,
        'body': body,
        'bodyDelta': bodyDelta,
        'category': category,
        'coverImageUrl': coverImageUrl,
        'published': published,
        'enrolledCount': enrolledCount,
        'avgRating': avgRating,
        'ratingCount': ratingCount,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

const kCourseCategories = [
  'Mathematics', 'Science', 'Languages', 'Computer Science',
  'Arts', 'Business', 'Social Studies', 'Other',
];

class CourseComment {
  final String id;
  final String courseId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  String body;
  final DateTime createdAt;

  CourseComment({
    required this.id,
    required this.courseId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.body,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CourseComment.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, String courseId) {
    final d = doc.data() ?? {};
    return CourseComment(
      id: doc.id,
      courseId: courseId,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorPhotoUrl: d['authorPhotoUrl'],
      body: d['body'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'body': body,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

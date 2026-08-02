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

  /// Free-text multi-select tags, in addition to the single `category` —
  /// see kCourseTags for the suggested picker list; custom tags allowed.
  List<String> tags;

  // ── Curriculum hierarchy ──────────────────────────────────────────
  // A course is really a single "lesson" that lives at a fixed address
  // inside an academic tree: Category (existing `category` above) →
  // Subject → Curriculum/Level → Topic → this lesson. All four of
  // subject/level/topic/difficulty are free-text (autocompleted from
  // what already exists, see PublicCourseRepository.hierarchyOptions),
  // so a course written before this feature existed just has them
  // blank and shows up under "Uncategorized" in the browser.

  /// e.g. "History" — sits directly under `category` ("Social Studies").
  String subject;

  /// e.g. "GCE Advanced Level".
  String level;

  /// e.g. "World War I in Cameroon" — the unit/topic this lesson
  /// belongs to. Siblings sharing the same (category, subject, level,
  /// topic) tuple form one ordered sequence.
  String topic;

  /// e.g. "Advanced" — see kDifficultyLevels.
  String difficulty;

  /// Hidden sequence position within this course's topic. Never shown
  /// to users — the composer only ever offers "before/between/after"
  /// choices and computes this value (see PublicCourseRepository
  /// .positionBefore/positionBetween/positionAfter). Large gaps
  /// (100, 200, 300…) are left between siblings on purpose so a new
  /// lesson can be inserted anywhere without renumbering the rest.
  double order;

  /// Course IDs that should be read before this one. Purely advisory —
  /// shown as links on the reader page, not enforced.
  List<String> prerequisiteIds;

  /// True once this course has been placed somewhere in the curriculum
  /// tree (subject/level/topic all set). Courses created before this
  /// feature, or ones an author skips placement for, fall back to
  /// showing only in the flat marketplace feed, not the hierarchy
  /// browser.
  bool get hasCurriculumPlacement =>
      subject.trim().isNotEmpty && level.trim().isNotEmpty && topic.trim().isNotEmpty;

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
    List<String>? tags,
    this.subject = '',
    this.level = '',
    this.topic = '',
    this.difficulty = '',
    this.order = 0,
    List<String>? prerequisiteIds,
    this.coverImageUrl,
    this.published = true,
    this.enrolledCount = 0,
    this.avgRating = 0,
    this.ratingCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        prerequisiteIds = prerequisiteIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
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
      tags: List<String>.from(d['tags'] ?? const []),
      subject: d['subject'] ?? '',
      level: d['level'] ?? '',
      topic: d['topic'] ?? '',
      difficulty: d['difficulty'] ?? '',
      order: (d['order'] ?? 0).toDouble(),
      prerequisiteIds: List<String>.from(d['prerequisiteIds'] ?? const []),
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
        'tags': tags,
        'subject': subject,
        'level': level,
        'topic': topic,
        'difficulty': difficulty,
        'order': order,
        'prerequisiteIds': prerequisiteIds,
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

/// Suggested tag picker options — free-text under the hood (see `tags` on
/// PublicCourse), same pattern as kCourseCategories.
const kCourseTags = [
  'GCE O-Level', 'GCE A-Level', 'Beginner', 'Intermediate', 'Advanced',
  'Exam Prep', 'Past Papers', 'Practical',
];

/// Difficulty picker options for a lesson's curriculum placement.
const kDifficultyLevels = ['Beginner', 'Intermediate', 'Advanced'];

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

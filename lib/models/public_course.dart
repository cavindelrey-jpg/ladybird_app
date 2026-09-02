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

import 'dart:convert';

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

  /// True once this course has been placed in the Level -> Subject ->
  /// Topic hierarchy (level/category/topic all set — category is the
  /// "Subject" tier; see PublicCourseRepository's IA methods). A course an
  /// author skips placement for still exists but won't appear under any
  /// Level/Subject/Topic browse screen.
  bool get hasCurriculumPlacement =>
      level.trim().isNotEmpty && category.trim().isNotEmpty && topic.trim().isNotEmpty;

  String? coverImageUrl;

  /// Optional video lesson attached to this course — a "Video Course" in
  /// account/entitlement terms. Gold-only: see AppFeature.coursesVideoLessons
  /// in core/feature_access.dart, the single place this gate is decided.
  /// Null/empty means this is a text-only lesson, same as before this field
  /// existed.
  String? videoUrl;

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
    this.videoUrl,
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

  factory PublicCourse.fromSupabase(Map<String, dynamic> d) {
    return PublicCourse(
      id: d['id'] as String,
      creatorId: d['creator_id'] ?? '',
      creatorName: d['creator_name'] ?? 'Unknown',
      creatorPhotoUrl: d['creator_photo_url'],
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      body: d['body'] ?? '',
      // Some legacy/bulk-imported rows have this jsonb column holding the
      // decoded Quill Delta (a JSON array) rather than the app's own
      // convention of a jsonEncode'd string -- postgrest then hands back
      // a native List, which crashes a plain `as String?` read. Re-encode
      // it back into the string form the reader (jsonDecode(bodyDelta!))
      // expects either way.
      bodyDelta: d['body_delta'] == null || d['body_delta'] is String
          ? d['body_delta'] as String?
          : jsonEncode(d['body_delta']),
      category: d['category'] ?? 'Mathematics',
      tags: List<String>.from(d['tags'] ?? const []),
      subject: d['subject'] ?? '',
      level: d['level'] ?? '',
      topic: d['topic'] ?? '',
      difficulty: d['difficulty'] ?? '',
      order: (d['sort_order'] ?? 0).toDouble(),
      prerequisiteIds: List<String>.from(d['prerequisite_ids'] ?? const []),
      coverImageUrl: d['cover_image_url'],
      videoUrl: d['video_url'],
      published: d['published'] ?? true,
      enrolledCount: d['enrolled_count'] ?? 0,
      avgRating: (d['avg_rating'] ?? 0).toDouble(),
      ratingCount: d['rating_count'] ?? 0,
      likeCount: d['like_count'] ?? 0,
      commentCount: d['comment_count'] ?? 0,
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(d['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() => {
        'creator_id': creatorId.isEmpty ? null : creatorId,
        'creator_name': creatorName,
        'creator_photo_url': creatorPhotoUrl,
        'title': title,
        'description': description,
        'body': body,
        'body_delta': bodyDelta,
        'category': category,
        'tags': tags,
        'subject': subject,
        'level': level,
        'topic': topic,
        'difficulty': difficulty,
        'sort_order': order,
        'prerequisite_ids': prerequisiteIds,
        'cover_image_url': coverImageUrl,
        'video_url': videoUrl,
        'published': published,
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
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

/// A Subject/Level/Topic node's chosen look — an uploaded photo takes
/// priority over an emoji if somehow both are set; neither is required
/// (see HierarchyAvatar's letter-avatar fallback in widgets.dart).
class CurriculumIcon {
  final String emoji;
  final String imageUrl;
  const CurriculumIcon({this.emoji = '', this.imageUrl = ''});
  bool get isEmpty => emoji.isEmpty && imageUrl.isEmpty;
  static const none = CurriculumIcon();
}

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

  factory CourseComment.fromSupabase(Map<String, dynamic> d) {
    return CourseComment(
      id: d['id'] as String,
      courseId: d['course_id'] as String,
      authorId: d['author_id'] ?? '',
      authorName: d['author_name'] ?? 'Unknown',
      authorPhotoUrl: d['author_photo_url'],
      body: d['body'] ?? '',
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

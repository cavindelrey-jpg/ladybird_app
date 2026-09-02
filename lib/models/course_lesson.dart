// lib/models/course_lesson.dart
// One lesson inside a marketplace Course (see models/public_course.dart).
// A course used to BE a single piece of content; now it's a container and
// this is the actual readable/watchable unit — video if videoUrl is set,
// otherwise the quill body, same fallback rule course readers already use.

class CourseLesson {
  final String id;
  final String courseId;
  String title;

  /// Optional video for this lesson. When set, the lesson reader shows a
  /// video player instead of the quill body.
  String? videoUrl;

  /// Plain-text fallback/derived value — same role as PublicCourse.body.
  String body;

  /// Rich content as a Quill Delta, JSON-encoded — same role as
  /// PublicCourse.bodyDelta. Null when this lesson is video-only.
  String? bodyDelta;

  /// Null when unknown — e.g. a text-only lesson, or a video whose length
  /// hasn't been recorded. Never fabricated; the reader shows nothing
  /// rather than a fake duration in that case.
  int? durationSeconds;

  int viewCount;

  /// Hidden sequence position within the course — same gap-of-100 pattern
  /// as PublicCourse.order (see PublicCourseRepository.positionAtStart/
  /// End/Between).
  double order;

  String? coverImageUrl;

  final DateTime createdAt;
  DateTime updatedAt;

  CourseLesson({
    required this.id,
    required this.courseId,
    required this.title,
    this.videoUrl,
    this.body = '',
    this.bodyDelta,
    this.durationSeconds,
    this.viewCount = 0,
    this.order = 0,
    this.coverImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory CourseLesson.fromSupabase(Map<String, dynamic> d) {
    return CourseLesson(
      id: d['id'] as String,
      courseId: d['course_id'] as String,
      title: d['title'] ?? '',
      videoUrl: d['video_url'],
      body: d['body'] ?? '',
      bodyDelta: d['body_delta'],
      durationSeconds: d['duration_seconds'],
      viewCount: d['view_count'] ?? 0,
      order: (d['sort_order'] ?? 0).toDouble(),
      coverImageUrl: d['cover_image_url'],
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(d['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() => {
        'course_id': courseId,
        'title': title,
        'video_url': videoUrl,
        'body': body,
        'body_delta': bodyDelta,
        'duration_seconds': durationSeconds,
        'sort_order': order,
        'cover_image_url': coverImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

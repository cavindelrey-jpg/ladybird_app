// lib/models/magazine_video_post.dart
// "Latest Videos" — production_plan.md's academia_fix Magazine mockup
// shows a real video-post section on the For You tab (thumbnail, play
// icon, duration badge, view count). No Postgres table exists yet — zero
// real data at migration time, same "stub with an honest empty state"
// call as magazine_media.dart's other non-article content types.
// Playback would reuse the same video_player/chewie pair already used by
// academic_content's ContentViewerPage — no new dependency needed.

class MagazineVideoPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int viewCount;
  final DateTime createdAt;

  const MagazineVideoPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    this.viewCount = 0,
    required this.createdAt,
  });

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

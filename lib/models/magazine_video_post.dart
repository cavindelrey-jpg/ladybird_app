// lib/models/magazine_video_post.dart
// "Latest Videos" — production_plan.md's academia_fix Magazine mockup
// shows a real video-post section on the For You tab (thumbnail, play
// icon, duration badge, view count). Firestore: magazine_videos/{id}.
// Playback reuses the same video_player/chewie pair already used by
// academic_content's ContentViewerPage — no new dependency needed.

import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory MagazineVideoPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MagazineVideoPost(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorPhotoUrl: d['authorPhotoUrl'],
      title: d['title'] ?? '',
      videoUrl: d['videoUrl'] ?? '',
      thumbnailUrl: d['thumbnailUrl'],
      durationSeconds: (d['durationSeconds'] as num?)?.toInt() ?? 0,
      viewCount: (d['viewCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'title': title,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'viewCount': viewCount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

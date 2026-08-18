// lib/models/magazine_gallery_post.dart
// "Student Gallery" — production_plan.md's academia_fix Magazine mockup
// shows a real photo-gallery section on the For You tab (thumbnail grid,
// "16 Photos" style counts). Firestore: magazine_gallery/{id}.

import 'package:cloud_firestore/cloud_firestore.dart';

class MagazineGalleryPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String caption;
  final List<String> imageUrls;
  final int likeCount;
  final DateTime createdAt;

  const MagazineGalleryPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.caption = '',
    required this.imageUrls,
    this.likeCount = 0,
    required this.createdAt,
  });

  factory MagazineGalleryPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MagazineGalleryPost(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorPhotoUrl: d['authorPhotoUrl'],
      caption: d['caption'] ?? '',
      imageUrls: List<String>.from(d['imageUrls'] ?? const []),
      likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'caption': caption,
        'imageUrls': imageUrls,
        'likeCount': likeCount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

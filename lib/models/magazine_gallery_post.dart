// lib/models/magazine_gallery_post.dart
// "Student Gallery" — production_plan.md's academia_fix Magazine mockup
// shows a real photo-gallery section on the For You tab (thumbnail grid,
// "16 Photos" style counts). No Postgres table exists yet — zero real
// data at migration time, same "stub with an honest empty state" call as
// magazine_media.dart's other non-article content types. Add a table +
// fromSupabase()/toSupabase() here if real content shows up.

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
}

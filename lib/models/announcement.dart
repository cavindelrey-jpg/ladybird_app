// lib/models/announcement.dart
// General-purpose notice board — NOT school-management. `schoolId` is an
// optional scope (kept for a future institution/org context), the default
// unscoped collection is what independent/guest accounts read from.

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

  /// Composer-uploaded photo — populated by uploading a device photo,
  /// pick-then-upload pattern shared with hero slides/article thumbnails.
  final String? imageUrl;

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
    this.imageUrl,
  });

  factory Announcement.fromSupabase(Map<String, dynamic> d) {
    return Announcement(
      id: d['id'] as String,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      tag: d['tag'] ?? '',
      authorName: d['author_name'] ?? '',
      authorId: d['author_id'] ?? '',
      date: DateTime.tryParse(d['occurred_at']?.toString() ?? '') ?? DateTime.now(),
      urgent: d['urgent'] ?? false,
      schoolId: d['institution_id'],
      sourceType: d['source_type'] ?? 'general',
      referenceId: d['reference_id'],
      imageUrl: d['image_url'],
    );
  }

  Map<String, dynamic> toSupabase() => {
    'title': title,
    'body': body,
    'tag': tag,
    'author_name': authorName,
    'author_id': authorId.isEmpty ? null : authorId,
    'occurred_at': date.toIso8601String(),
    'urgent': urgent,
    'institution_id': schoolId,
    'source_type': sourceType,
    'reference_id': referenceId,
    'image_url': imageUrl,
  };
}

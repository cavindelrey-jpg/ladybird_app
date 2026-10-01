// lib/models/library_folder.dart
// A node in the Academia Library's File Explorer tree. parentId == null
// means a root category (Past Papers / Notes / Documents / Books, seeded
// on the shared Supabase project by academia-cameroon's migration
// 20260903120000_library_file_explorer.sql, plus whatever an admin adds
// later — this list is never hardcoded in Dart).

class LibraryFolder {
  final String id;
  final String? parentId;
  final String name;
  final String emoji;
  final String? imageUrl;
  final double sortOrder;

  const LibraryFolder({
    required this.id,
    required this.parentId,
    required this.name,
    required this.emoji,
    this.imageUrl,
    required this.sortOrder,
  });

  bool get isRoot => parentId == null;

  factory LibraryFolder.fromSupabase(Map<String, dynamic> d) => LibraryFolder(
    id: d['id'] as String,
    parentId: d['parent_id'] as String?,
    name: d['name'] as String? ?? 'Untitled folder',
    emoji: d['emoji'] as String? ?? '',
    imageUrl: (d['image_url'] as String?)?.isEmpty ?? true ? null : d['image_url'] as String,
    sortOrder: (d['sort_order'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toSupabase() => {
    'id': id,
    'parent_id': parentId,
    'name': name,
    'emoji': emoji,
    'image_url': imageUrl,
    'sort_order': sortOrder,
  };
}

// lib/repositories/library_folder_repository.dart
// Backs the Academia Library's File Explorer: a genuine, admin-editable
// folder tree (library_folders), not a fixed taxonomy. The table lives on
// the Supabase project shared with academia-cameroon and ladybird_app —
// see academia-cameroon's migration 20260903120000_library_file_explorer
// .sql for the schema and why this shape was chosen over reusing the
// Courses Level/Subject/Topic hierarchy.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/library_folder.dart';
import '../models/academic_content.dart';
import '../core/result.dart';

/// Which root folder a given [ContentType] backfills into by default —
/// mirrors the mapping in academia-cameroon's
/// 20260903120000_library_file_explorer.sql migration, so a Home shortcut
/// filtered by content type can deep-link to the matching root folder.
String rootFolderNameForContentType(ContentType type) {
  switch (type) {
    case ContentType.pastPaper: return 'Past Papers';
    case ContentType.note: return 'Notes';
    case ContentType.book: return 'Books';
    default: return 'Documents';
  }
}

class LibraryFolderRepository {
  LibraryFolderRepository._();
  static final LibraryFolderRepository instance = LibraryFolderRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _folders => _db.from('library_folders');

  /// The top-level categories (Past Papers, Notes, Documents, Books, plus
  /// anything an admin has added) — never a Dart-side constant list.
  Stream<List<LibraryFolder>> watchRootFolders() {
    return _folders.stream(primaryKey: ['id']).order('sort_order').map(
        (rows) => rows.where((r) => r['parent_id'] == null).map(LibraryFolder.fromSupabase).toList());
  }

  Stream<List<LibraryFolder>> watchChildFolders(String parentId) {
    return _folders.stream(primaryKey: ['id']).eq('parent_id', parentId).order('sort_order').map(
        (rows) => rows.map(LibraryFolder.fromSupabase).toList());
  }

  /// Looks up a root folder by its exact name — used by Home shortcuts
  /// that deep-link straight into e.g. "Past Papers" instead of the
  /// Academia Library home page. Returns null if no root folder with that
  /// name exists yet (an admin renamed or removed it).
  Future<LibraryFolder?> rootFolderByName(String name) async {
    final row = await _folders.select().filter('parent_id', 'is', null).eq('name', name).maybeSingle();
    return row == null ? null : LibraryFolder.fromSupabase(row);
  }

  Future<LibraryFolder?> folderOnce(String id) async {
    final row = await _folders.select().eq('id', id).maybeSingle();
    return row == null ? null : LibraryFolder.fromSupabase(row);
  }

  /// Items placed directly in this folder (not recursive — matches
  /// file-explorer semantics where a folder shows its immediate children).
  Stream<List<AcademicContent>> watchItemsInFolder(String folderId) {
    return _db.from('academic_content').stream(primaryKey: ['id']).eq('folder_id', folderId).map(
        (rows) => rows.map(AcademicContent.fromSupabase).toList());
  }

  Future<Result<String>> createFolder({required String? parentId, required String name}) async {
    try {
      final row = await _folders
          .insert({'parent_id': parentId, 'name': name.trim(), 'updated_at': DateTime.now().toIso8601String()})
          .select('id')
          .single();
      return Success(row['id'] as String);
    } catch (e) {
      return Failure('Failed to create folder', e);
    }
  }

  Future<Result<void>> renameFolder(String id, String newName) async {
    try {
      await _folders.update({'name': newName.trim(), 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to rename folder', e);
    }
  }

  /// [id] plus every folder nested under it, at any depth — used to stop
  /// an admin from moving a folder into its own subtree, which would
  /// otherwise silently create an unreachable cycle.
  Future<Set<String>> descendantIdsIncludingSelf(String id) async {
    final all = await _folders.select('id, parent_id');
    final childrenOf = <String?, List<String>>{};
    for (final row in all) {
      final pid = row['parent_id'] as String?;
      (childrenOf[pid] ??= []).add(row['id'] as String);
    }
    final result = <String>{};
    final stack = [id];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!result.add(current)) continue;
      stack.addAll(childrenOf[current] ?? const []);
    }
    return result;
  }

  Future<Result<void>> moveFolder(String id, String? newParentId) async {
    try {
      await _folders
          .update({'parent_id': newParentId, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to move folder', e);
    }
  }

  /// Deletes a folder and its subfolders (cascade, DB-enforced). Items that
  /// were filed directly in it are unfiled (folder_id -> null), never
  /// deleted — a folder is organization, not a trash can.
  Future<Result<void>> deleteFolder(String id) async {
    try {
      await _folders.delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete folder', e);
    }
  }

  Future<Result<void>> moveItem(String contentId, String? folderId) async {
    try {
      await _db.from('academic_content').update({'folder_id': folderId}).eq('id', contentId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to move item', e);
    }
  }
}

// lib/repositories/academic_content_repository.dart
// Supabase Postgres + Storage operations for the Library feature.

import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import "../core/offline_cache.dart";
import '../models/academic_content.dart';
import '../core/result.dart';
import '../core/realtime_tolerant.dart';
import '../services/content_cache_service.dart';
import '../data/local_database.dart';

class AcademicContentRepository {
  AcademicContentRepository._();
  static final AcademicContentRepository instance = AcademicContentRepository._();

  static const String _table = 'academic_content';
  static const String _bucket = 'app-content';

  final SupabaseClient _db = Supabase.instance.client;

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// Live stream of content. Filters by institution and optional
  /// type/subject/level/examBoard/year. supabase_flutter's realtime
  /// .stream() only supports one .eq() filter plus client-side ordering —
  /// apply the cheapest indexed dimension server-side (institution_id) and
  /// refine the rest client-side over a wider page when any of
  /// level/examBoard/year are active, same pattern used elsewhere in this
  /// rewrite for multi-filter streams.
  Stream<List<AcademicContent>> watch({
    String? institutionId,
    ContentType? contentType,
    String? subject,
    String? level,
    String? examBoard,
    int? year,
  }) {
    final cacheKey = 'academic_content_watch_${institutionId ?? "all"}_${contentType?.name ?? "all"}_${subject ?? "all"}';
    final controller = StreamController<List<AcademicContent>>();
    final hasClientFilter =
        (level != null && level.isNotEmpty) || (examBoard != null && examBoard.isNotEmpty) || year != null;

    List<AcademicContent> applyFilters(List<AcademicContent> items) {
      var filtered = items;
      if (level != null && level.isNotEmpty) {
        filtered = filtered.where((i) => i.level == level).toList();
      }
      if (examBoard != null && examBoard.isNotEmpty) {
        filtered = filtered.where((i) => i.examBoard == examBoard).toList();
      }
      if (year != null) {
        filtered = filtered.where((i) => i.year == year).toList();
      }
      return filtered;
    }

    () async {
      // 1. Emit from ContentCacheService immediately (0ms)
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && !controller.isClosed) {
        final items = cached.map(AcademicContent.fromSupabase).toList();
        controller.add(applyFilters(items));
      } else {
        // Fallback: emit matching offline downloaded content
        final offlineItems = await getOfflineContent();
        if (offlineItems.isNotEmpty && !controller.isClosed) {
          var matched = offlineItems;
          if (contentType != null) matched = matched.where((i) => i.contentType == contentType).toList();
          if (subject != null && subject.isNotEmpty) matched = matched.where((i) => i.subject == subject).toList();
          if (matched.isNotEmpty && !controller.isClosed) controller.add(applyFilters(matched));
        }
      }

      // 2. Live stream
      final stream = _db.from(_table).stream(primaryKey: ['id']).realtimeTolerant();
      final sub = stream.listen(
        (rows) {
          if (controller.isClosed) return;
          var filtered = rows;
          if (institutionId != null) {
            filtered = filtered.where((r) => r['institution_id'] == institutionId).toList();
          }
          if (contentType != null) {
            filtered = filtered.where((r) => r['content_type'] == contentType.name).toList();
          }
          if (subject != null && subject.isNotEmpty) {
            filtered = filtered.where((r) => r['subject'] == subject).toList();
          }
          filtered.sort((a, b) => (b['upload_date'] as String).compareTo(a['upload_date'] as String));
          final items = filtered.take(hasClientFilter ? 300 : 80).map(AcademicContent.fromSupabase).toList();
          unawaited(ContentCacheService.instance.putList(cacheKey, filtered.take(80).toList()));
          controller.add(applyFilters(items));
        },
        onError: (_) {
          // Keep showing cached data on network error / offline
        },
      );
      controller.onCancel = () => sub.cancel();
    }();

    return controller.stream;
  }

  /// One-shot real count of library resources in scope — powers the Home
  /// "Library" banner's resource count.
  Future<int> countAll({String? institutionId}) async {
    var q = _db.from(_table).select();
    if (institutionId != null) q = q.eq('institution_id', institutionId);
    final rows = await q;
    return rows.length;
  }

  /// The most recently uploaded thumbnail already used for [tag] (e.g. a
  /// discipline name like "Physics"), if any — lets bulk past-paper
  /// upload reuse one thumbnail per subject automatically instead of
  /// asking the uploader to pick the same image over and over, and
  /// without re-uploading a duplicate copy of it each time.
  Future<String?> findThumbnailForTag(String tag, {String? institutionId}) async {
    var q = _db.from(_table).select('thumbnail_url').contains('tags', [tag]);
    if (institutionId != null) q = q.eq('institution_id', institutionId);
    final rows = await q.order('upload_date', ascending: false).limit(1);
    if (rows.isEmpty) return null;
    return rows.first['thumbnail_url'] as String?;
  }

  /// Stream for a single row with local offline cache fallback.
  Stream<AcademicContent?> watchOne(String id) {
    final controller = StreamController<AcademicContent?>();

    () async {
      // 1. Check local offline metadata first
      try {
        final prefs = await SharedPreferences.getInstance();
        final metaStr = prefs.getString('$_offlineMetaPrefix$id');
        if (metaStr != null && metaStr.isNotEmpty && !controller.isClosed) {
          final json = jsonDecode(metaStr) as Map<String, dynamic>;
          controller.add(AcademicContent.fromSupabase(json));
        } else {
          final cached = await LocalDatabase.instance.getCachedData('academic_content', id);
          if (cached != null && !controller.isClosed) {
            controller.add(AcademicContent.fromSupabase(cached));
          }
        }
      } catch (_) {}

      // 2. Connect to live stream
      final sub = _db
          .from(_table)
          .stream(primaryKey: ['id'])
          .eq('id', id)
          .realtimeTolerant()
          .listen(
            (rows) {
              if (controller.isClosed) return;
              if (rows.isNotEmpty) {
                final item = AcademicContent.fromSupabase(rows.first);
                LocalDatabase.instance.cacheData('academic_content', id, rows.first);
                controller.add(item);
              } else {
                controller.add(null);
              }
            },
            onError: (_) {
              // Realtime failed / offline -- keep showing cached item!
            },
          );
      controller.onCancel = () => sub.cancel();
    }();

    return controller.stream;
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<List<AcademicContent>> search(
    String query, {
    String? institutionId,
    ContentType? contentType,
    String? subject,
    String? level,
    String? examBoard,
    int? year,
  }) async {
    final lower = query.toLowerCase();
    List<AcademicContent> candidates = [];
    try {
      var q = _db.from(_table).select();
      if (institutionId != null) q = q.eq('institution_id', institutionId);
      if (contentType != null) q = q.eq('content_type', contentType.name);
      final rows = await q.order('title', ascending: true);
      candidates = rows.map(AcademicContent.fromSupabase).toList();
    } catch (_) {
      // Offline fallback: search offline downloaded content!
      candidates = await getOfflineContent();
    }

    return candidates
        .where((item) =>
            (item.title.toLowerCase().contains(lower) ||
                item.description.toLowerCase().contains(lower) ||
                item.subject.toLowerCase().contains(lower) ||
                item.level.toLowerCase().contains(lower) ||
                item.examBoard.toLowerCase().contains(lower) ||
                item.tags.any((t) => t.toLowerCase().contains(lower))) &&
            (subject == null || subject.isEmpty || item.subject == subject) &&
            (level == null || level.isEmpty || item.level == level) &&
            (examBoard == null || examBoard.isEmpty || item.examBoard == examBoard) &&
            (year == null || item.year == year))
        .toList();
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<Result<String>> add(AcademicContent content) async {
    try {
      final row = await _db.from(_table).insert(content.toSupabase()).select('id').single();
      return Success(row['id'] as String);
    } catch (e) {
      return Failure('Failed to add content', e);
    }
  }

  Future<Result<void>> update(AcademicContent content) async {
    try {
      await _db.from(_table).update(content.toSupabase()).eq('id', content.id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update content', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      final row = await _db.from(_table).select('file_url,thumbnail_url').eq('id', id).maybeSingle();
      if (row != null) {
        await _tryDeleteStorageFile(row['file_url']);
        await _tryDeleteStorageFile(row['thumbnail_url']);
      }
      await _db.from(_table).delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete content', e);
    }
  }

  // ─── Tracking ─────────────────────────────────────────────────────────────

  Future<Result<void>> incrementViews(String id) async {
    try {
      await _db.rpc('increment_academic_content_views', params: {'p_id': id});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to track view', e);
    }
  }

  Future<Result<void>> incrementDownloads(String id) async {
    try {
      await _db.rpc('increment_academic_content_downloads', params: {'p_id': id});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to track download', e);
    }
  }

  // ─── Saved for Offline ──────────────────────────────────────────────────
  // Two distinct, separately-tracked concepts:
  //  - "Saved" (toggleSave/watchIsSaved below): a bookmark marker,
  //    powers "my saved list" across devices. Does NOT imply the file is
  //    actually on this device.
  //  - "Downloaded" (downloadForOffline/offlineFilePath below): the
  //    file's bytes actually written to local device storage, tracked in
  //    SharedPreferences (per-device, deliberately not synced).

  Stream<bool> watchIsSaved(String contentId, String userId) => _db
      .from('content_saves')
      .stream(primaryKey: ['content_id', 'user_id'])
      .eq('content_id', contentId)
      .realtimeTolerant()
      .map((rows) => rows.any((r) => r['user_id'] == userId));

  Future<Result<void>> toggleSave(String contentId, String userId) async {
    try {
      final existing = await _db
          .from('content_saves')
          .select()
          .eq('content_id', contentId)
          .eq('user_id', userId)
          .maybeSingle();
      if (existing != null) {
        await _db.from('content_saves').delete().eq('content_id', contentId).eq('user_id', userId);
      } else {
        await _db.from('content_saves').insert({'content_id': contentId, 'user_id': userId});
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update saved status', e);
    }
  }

  /// A user's saved content, newest-saved first.
  Stream<List<AcademicContent>> watchSavedContent(String userId) {
    return _db
        .from('content_saves')
        .stream(primaryKey: ['content_id', 'user_id'])
        .eq('user_id', userId)
        .realtimeTolerant()
        .asyncMap((rows) async {
      final ids = rows.map((r) => r['content_id'] as String).toList();
      if (ids.isEmpty) return <AcademicContent>[];
      final content = await _db.from(_table).select().inFilter('id', ids.take(30).toList());
      return content.map(AcademicContent.fromSupabase).toList();
    });
  }

  // ─── Offline download (real on-device file caching) ─────────────────────

  static const _offlinePrefsPrefix = 'offline_content_path_';
  static const _offlineMetaPrefix = 'offline_content_meta_';
  static const _offlineIdsKey = 'offline_downloaded_ids';

  final StreamController<void> _offlineNotifier = StreamController<void>.broadcast();

  /// Local file path for [contentId] if it's actually been downloaded to
  /// this device, else null. Cheap SharedPreferences lookup plus an
  /// existence check (the file may have been cleared by the OS/user
  /// without the app knowing).
  Future<String?> offlineFilePath(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_offlinePrefsPrefix$contentId');
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  /// All content items currently cached/downloaded to this device and available offline.
  Future<List<AcademicContent>> getOfflineContent() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_offlineIdsKey) ?? <String>[];
    final validItems = <AcademicContent>[];
    final cleanIds = <String>[];

    for (final id in ids) {
      final path = prefs.getString('$_offlinePrefsPrefix$id');
      if (path != null && File(path).existsSync()) {
        final metaStr = prefs.getString('$_offlineMetaPrefix$id');
        if (metaStr != null && metaStr.isNotEmpty) {
          try {
            final json = jsonDecode(metaStr) as Map<String, dynamic>;
            validItems.add(AcademicContent.fromSupabase(json));
            cleanIds.add(id);
          } catch (_) {}
        }
      }
    }

    if (cleanIds.length != ids.length) {
      await prefs.setStringList(_offlineIdsKey, cleanIds);
    }

    return validItems;
  }

  /// Real-time stream of all offline-ready books, papers, and documents on this device.
  Stream<List<AcademicContent>> watchOfflineContent() async* {
    yield await getOfflineContent();
    await for (final _ in _offlineNotifier.stream) {
      yield await getOfflineContent();
    }
  }

  /// Downloads the content's file to app-local storage and records the
  /// path and metadata so it can be opened without network afterward. Reports 0.0-1.0
  /// progress where the response provides a content-length.
  Future<Result<String>> downloadForOffline(
    AcademicContent item, {
    void Function(double)? onProgress,
  }) async {
    final url = item.fileUrl;
    if (url == null || url.isEmpty) {
      return const Failure('This item has no file to download.', null);
    }
    try {
      final path = await _streamToCache(item.id, url, onProgress: onProgress);
      if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
        try {
          await _streamToCache('${item.id}_thumb', item.thumbnailUrl!);
        } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_offlineMetaPrefix${item.id}', jsonEncode(item.toSupabase()));
      final ids = prefs.getStringList(_offlineIdsKey) ?? <String>[];
      if (!ids.contains(item.id)) {
        ids.add(item.id);
        await prefs.setStringList(_offlineIdsKey, ids);
      }
      _offlineNotifier.add(null);
      return Success(path);
    } catch (e) {
      return Failure('Download failed — check your connection and try again.', e);
    }
  }

  /// Path to locally-cached thumbnail for offline viewing.
  Future<String?> offlineThumbnailPath(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_offlinePrefsPrefix${contentId}_thumb');
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  /// True only for items the user explicitly saved for offline (listed in
  /// "Available Offline"), with the file still on disk. NOT the same as
  /// [offlineFilePath]: the viewer silently caches every file it opens,
  /// and treating that cache as "saved" showed a green "saved offline"
  /// check for items that never appeared in the offline section.
  Future<bool> isSavedForOffline(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_offlineIdsKey) ?? const <String>[];
    return ids.contains(contentId) && await offlineFilePath(contentId) != null;
  }

  /// Explicit "Save for offline" from the viewer, which only knows the
  /// id/url/title: downloads (or reuses the cached file), then registers
  /// the item with its metadata so it's listed and openable offline.
  Future<Result<void>> saveForOffline({
    required String contentId,
    required String fileUrl,
    required String title,
    void Function(double)? onProgress,
  }) async {
    try {
      await ensureLocalCopy(contentId: contentId, fileUrl: fileUrl, onProgress: onProgress);
    } catch (e) {
      return Failure('Download failed — check your connection and try again.', e);
    }
    Map<String, dynamic> meta;
    try {
      meta = await _db.from('academic_content').select().eq('id', contentId).single()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // File is on the device; list it with what we know rather than fail.
      meta = {'id': contentId, 'title': title, 'file_url': fileUrl};
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_offlineMetaPrefix$contentId', jsonEncode(meta));
    final ids = prefs.getStringList(_offlineIdsKey) ?? <String>[];
    if (!ids.contains(contentId)) {
      ids.add(contentId);
      await prefs.setStringList(_offlineIdsKey, ids);
    }
    _offlineNotifier.add(null);
    return const Success(null);
  }

  /// The viewer-facing counterpart to [downloadForOffline] -- same cache
  /// slot, but silent/automatic: ContentViewerPage calls this on open so
  /// PDFs/Word docs open from a real local file instead of the whole
  /// document being buffered into memory on every single view. Returns
  /// the cached path if one already exists, otherwise streams to disk and
  /// returns once ready. Throws on failure; callers show their own error
  /// state.
  Future<String> ensureLocalCopy({
    required String contentId,
    required String fileUrl,
    AcademicContent? content,
    void Function(double)? onProgress,
  }) async {
    final existing = await offlineFilePath(contentId);
    if (existing != null) {
      if (content != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_offlineMetaPrefix$contentId', jsonEncode(content.toSupabase()));
        final ids = prefs.getStringList(_offlineIdsKey) ?? <String>[];
        if (!ids.contains(contentId)) {
          ids.add(contentId);
          await prefs.setStringList(_offlineIdsKey, ids);
          _offlineNotifier.add(null);
        }
      }
      return existing;
    }
    final localPath = await _streamToCache(contentId, fileUrl, onProgress: onProgress);
    if (content != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_offlineMetaPrefix$contentId', jsonEncode(content.toSupabase()));
      final ids = prefs.getStringList(_offlineIdsKey) ?? <String>[];
      if (!ids.contains(contentId)) {
        ids.add(contentId);
        await prefs.setStringList(_offlineIdsKey, ids);
        _offlineNotifier.add(null);
      }
    }
    return localPath;
  }

  /// Shared streaming-download core for [downloadForOffline] and
  /// [ensureLocalCopy] -- writes incrementally to disk via the response
  /// stream, reports 0.0-1.0 progress, and records the resulting path in
  /// the same offline-cache slot both callers share.
  Future<String> _streamToCache(
    String contentId,
    String url, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${dir.path}/offline_content');
    if (!await offlineDir.exists()) await offlineDir.create(recursive: true);
    final ext = url.contains('.') ? url.split('.').last.split('?').first : 'bin';
    final localPath = '${offlineDir.path}/$contentId.$ext';

    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send().timeout(const Duration(minutes: 5));
    if (response.statusCode >= 400) {
      throw Exception('Download failed (server returned ${response.statusCode}).');
    }
    final total = response.contentLength ?? 0;
    var received = 0;
    final file = File(localPath);
    final sink = file.openWrite();
    try {
      // A per-chunk silence timeout (30s with no new data = something's
      // actually stuck, not just a big file on a slow connection) —
      // the 5-minute timeout above only covers getting response headers,
      // not the body stream that follows.
      await response.stream.timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) => sink.addError(
            TimeoutException('Download stalled — no data received for 30 seconds.')),
      ).map((chunk) {
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
        return chunk;
      }).pipe(sink);
    } catch (e) {
      await sink.close();
      // A partial file left on disk from a failed download must not be
      // mistaken for a real cached copy on the next open — delete it
      // rather than leave a corrupt file that "successfully" reopens broken.
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await sink.close();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_offlinePrefsPrefix$contentId', localPath);
    return localPath;
  }

  /// Deletes the locally-downloaded file (if any) and forgets its path.
  /// Does not touch the separate "saved" bookmark.
  Future<void> removeOfflineFile(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_offlinePrefsPrefix$contentId');
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // best-effort
      }
      await prefs.remove('$_offlinePrefsPrefix$contentId');
      await prefs.remove('$_offlineMetaPrefix$contentId');
      final ids = prefs.getStringList(_offlineIdsKey) ?? <String>[];
      if (ids.contains(contentId)) {
        ids.remove(contentId);
        await prefs.setStringList(_offlineIdsKey, ids);
      }
      _offlineNotifier.add(null);
    }
  }

  // ─── Recently viewed (real data — powers "Continue Learning") ──────────

  Future<void> recordView(String contentId, String userId) async {
    try {
      await _db.from('content_recent_views').upsert(
        {'content_id': contentId, 'user_id': userId, 'viewed_at': DateTime.now().toIso8601String()},
        onConflict: 'content_id,user_id',
      );
    } catch (_) {
      // best-effort — a failed recency update shouldn't block viewing the content
    }
  }

  /// Most-recently-viewed content for this user.
  Stream<List<AcademicContent>> watchRecentlyViewed(String userId, {int limit = 10}) {
    final live = _db
        .from('content_recent_views')
        .stream(primaryKey: ['content_id', 'user_id'])
        .eq('user_id', userId)
        .realtimeTolerant()
        .asyncMap((rows) async {
      final sorted = rows.toList()
        ..sort((a, b) => (b['viewed_at'] as String).compareTo(a['viewed_at'] as String));
      final ids = sorted.take(limit).map((r) => r['content_id'] as String).toList();
      if (ids.isEmpty) return <AcademicContent>[];
      final content = await _db.from(_table).select().inFilter('id', ids);
      final byId = {for (final c in content) c['id'] as String: c};
      return ids.where(byId.containsKey).map((id) => AcademicContent.fromSupabase(byId[id]!)).toList();
    });

    return OfflineCache.instance.watch<List<AcademicContent>>(
      'recently_viewed_$userId',
      live,
      toJson: (list) => OfflineCache.listToJson(list, (c) => (c as AcademicContent).toSupabase()),
      fromJson: (json) => OfflineCache.listFromJson(json, (j) => AcademicContent.fromSupabase(j)),
      emptyValue: [],
    );
  }

  // ─── Read position (real data — powers Home "Continue Reading") ────────

  /// Persists how far [userId] has read into [contentId]. Best-effort — a
  /// failed position write should never interrupt reading.
  Future<void> recordReadPosition({
    required String contentId,
    required String userId,
    required int page,
    required int totalPages,
  }) async {
    // Local first, so the position survives (and is used) offline.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('read_page_${userId}_$contentId', page);
    } catch (_) {}
    try {
      await _db.from('content_read_positions').upsert({
        'content_id': contentId,
        'user_id': userId,
        'page': page,
        'total_pages': totalPages,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'content_id,user_id').timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort
    }
  }

  /// The page [userId] last left off on for [contentId], or 1 if there's
  /// no saved position yet. The server copy (another device may be ahead)
  /// wins when it answers within 3 s; otherwise this device's own last
  /// page is used -- offline it used to fall back to page 1, after the
  /// viewer had waited on the failing request before opening at all.
  Future<int> savedReadPage({required String contentId, required String userId}) async {
    int? local;
    try {
      final prefs = await SharedPreferences.getInstance();
      local = prefs.getInt('read_page_${userId}_$contentId');
    } catch (_) {}
    try {
      final row = await _db
          .from('content_read_positions')
          .select('page')
          .eq('content_id', contentId)
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));
      final page = (row?['page'] as num?)?.toInt();
      if (page != null && page > 0) return page;
    } catch (_) {}
    return (local != null && local > 0) ? local : 1;
  }

  /// Most-recent real reading position for [userId] across all content —
  /// powers the Home "Continue Reading: <title>, Page X of Y" card.
  Future<({AcademicContent content, int page, int totalPages})?> continueReading(String userId) async {
    try {
      final rows = await _db
          .from('content_read_positions')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final latest = rows.first;
      final contentRow = await _db.from(_table).select().eq('id', latest['content_id']).maybeSingle();
      if (contentRow == null) return null;
      return (
        content: AcademicContent.fromSupabase(contentRow),
        page: (latest['page'] as num?)?.toInt() ?? 1,
        totalPages: (latest['total_pages'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Recommendations (real data, date-seeded rotation) ─────────────────
  // Same approach as PublicCourseRepository.recommendedForUser: same order
  // all day for a given user, a different one the next day — a real
  // rotation, not per-refresh randomness, and never a fabricated list.

  Future<List<AcademicContent>> recommendedForUser(String? userId, {int limit = 5}) async {
    final cacheKey = 'academic_recommended_${userId ?? "all"}';
    try {
      final pool = await _db.from(_table).select().order('upload_date', ascending: false).limit(200);
      var items = pool.map(AcademicContent.fromSupabase).toList();
      if (items.isEmpty) return const [];

      Set<String> subjects = {};
      if (userId != null) {
        final recentRows = await _db
            .from('content_recent_views')
            .select('content_id')
            .eq('user_id', userId)
            .order('viewed_at', ascending: false)
            .limit(20);
        final recentIds = recentRows.map((r) => r['content_id'] as String).toSet();
        subjects = items.where((c) => recentIds.contains(c.id) && c.subject.isNotEmpty)
            .map((c) => c.subject).toSet();
      }

      final scored = items.where((c) => subjects.isEmpty || subjects.contains(c.subject)).toList();
      final candidates = scored.length >= limit ? scored : items;
      candidates.sort((a, b) {
        final scoreA = a.views * 1.0 + a.downloads * 2.0;
        final scoreB = b.views * 1.0 + b.downloads * 2.0;
        return scoreB.compareTo(scoreA);
      });
      final top = candidates.take(limit * 3).toList();
      final seed = DateTime.now().difference(DateTime(2020)).inDays + (userId?.hashCode ?? 0);
      top.shuffle(Random(seed));
      final result = top.take(limit).toList();
      unawaited(ContentCacheService.instance.putList(cacheKey, result.map((e) => e.toSupabase()).toList()));
      return result;
    } catch (_) {
      // Offline fallback: try cached recommendations, then offline downloaded items
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.map(AcademicContent.fromSupabase).take(limit).toList();
      }
      final offline = await getOfflineContent();
      return offline.take(limit).toList();
    }
  }

  // ─── Storage Upload ───────────────────────────────────────────────────────

  /// Uploads a file to Supabase Storage. Returns the public URL. Times out
  /// instead of hanging forever on a dead connection and retries once.
  Future<Result<String>> uploadFile({
    required File file,
    required String folder, // e.g. 'content_files' or 'thumbnails'
    required String institutionId,
    void Function(double)? onProgress,
    int attempt = 1,
  }) async {
    try {
      final ext = file.path.split('.').last;
      final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$folder/$institutionId/$name';
      onProgress?.call(0);
      await _db.storage.from(_bucket).upload(path, file).timeout(const Duration(minutes: 5));
      onProgress?.call(1);
      final url = _db.storage.from(_bucket).getPublicUrl(path);
      return Success(url);
    } catch (e) {
      if (attempt < 2) {
        onProgress?.call(0);
        return uploadFile(
          file: file, folder: folder, institutionId: institutionId,
          onProgress: onProgress, attempt: attempt + 1,
        );
      }
      return Failure('Upload failed — check your connection and try again', e);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _tryDeleteStorageFile(dynamic url) async {
    if (url is! String || url.isEmpty) return;
    try {
      // Public URL looks like .../storage/v1/object/public/<bucket>/<path>
      final marker = '/object/public/$_bucket/';
      final idx = url.indexOf(marker);
      if (idx == -1) return;
      final path = url.substring(idx + marker.length);
      await _db.storage.from(_bucket).remove([path]);
    } catch (_) {
      // File may already be gone — ignore
    }
  }

  /// Returns the list of distinct subjects from the table.
  Future<List<String>> getSubjects({String? institutionId}) async {
    var q = _db.from(_table).select('subject');
    if (institutionId != null) q = q.eq('institution_id', institutionId);
    final rows = await q;
    final subjects = rows
        .map((r) => (r['subject'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return subjects;
  }

  /// Distinct exam/publication years currently in use — drives the Year
  /// filter picker.
  Future<List<int>> yearsInUseOnce({String? institutionId}) async {
    var q = _db.from(_table).select('year');
    if (institutionId != null) q = q.eq('institution_id', institutionId);
    final rows = await q.limit(500);
    final years = rows
        .map((r) => (r['year'] as num?)?.toInt())
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  /// Real per-subject item counts — powers the Categories grid.
  Future<Map<String, int>> subjectCountsOnce({String? institutionId}) async {
    var q = _db.from(_table).select('subject');
    if (institutionId != null) q = q.eq('institution_id', institutionId);
    final rows = await q.limit(500);
    final counts = <String, int>{};
    for (final row in rows) {
      final subject = (row['subject'] as String?) ?? '';
      if (subject.isEmpty) continue;
      counts[subject] = (counts[subject] ?? 0) + 1;
    }
    return counts;
  }
}

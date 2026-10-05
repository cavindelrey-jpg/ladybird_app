import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local_database.dart';
import '../services/connectivity_service.dart';

/// Drains the offline write queue (LocalDatabase.sync_queue) back to Supabase.
///
/// Writes made while offline are queued by the repositories as 'upsert',
/// 'delete', 'insert' or 'update' actions; this service flushes them whenever
/// connectivity is available — both on a periodic timer and immediately when
/// the device reconnects, so the user never has to refresh manually.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;
  StreamSubscription<bool>? _connectivitySub;
  bool _isSyncing = false;

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (ConnectivityService().isOnline) {
        _processQueue();
      }
    });

    // Flush as soon as connectivity is restored, without waiting for the next
    // tick. connectionStatusStream emits the new offline flag on each change.
    _connectivitySub?.cancel();
    _connectivitySub = ConnectivityService().connectionStatusStream.listen((isOffline) {
      if (!isOffline) _processQueue();
    });
  }

  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> _processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final db = await LocalDatabase.instance.database;
      final queue = await db.query('sync_queue', orderBy: 'created_at ASC');
      final client = Supabase.instance.client;

      for (final item in queue) {
        final id = item['id'] as int;
        final action = item['action'] as String;
        final collection = item['collection'] as String;
        final docId = item['doc_id'] as String;
        final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;

        try {
          switch (action) {
            case 'insert':
              await client.from(collection).insert(data);
              break;
            case 'update':
              await client.from(collection).update(data).eq('id', docId);
              break;
            case 'upsert':
              await client.from(collection).upsert(data, onConflict: 'id');
              break;
            case 'delete':
              await client.from(collection).delete().eq('id', docId);
              break;
            default:
              // Unknown action: drop it rather than retry forever.
              break;
          }
          // Remove from queue on success (or on an unknown/undeliverable action).
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
        } catch (e) {
          // Transient failure (still offline / server error): leave it queued
          // and retry on the next flush.
          debugPrint('Sync deferred for queue item $id ($action $collection): $e');
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}

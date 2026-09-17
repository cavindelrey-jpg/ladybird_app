import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database.dart';
import '../services/connectivity_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;

  void startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (ConnectivityService().isOnline) {
        _processQueue();
      }
    });
  }

  Future<void> _processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final db = await LocalDatabase.instance.database;
      final queue = await db.query('sync_queue', orderBy: 'created_at ASC');

      for (var item in queue) {
        final id = item['id'] as int;
        final action = item['action'] as String;
        final collection = item['collection'] as String;
        final docId = item['doc_id'] as String;
        final dataStr = item['data'] as String;
        final data = jsonDecode(dataStr);

        try {
          if (action == 'insert') {
            await Supabase.instance.client.from(collection).insert(data);
          } else if (action == 'update') {
            await Supabase.instance.client.from(collection).update(data).eq('id', docId);
          }
          // Remove from queue on success
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
        } catch (e) {
          print('Sync failed for item \$id: \$e');
          // If it's a permanent error, maybe we delete it or mark it as failed. 
          // For now, we leave it in the queue.
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}

import 'dart:async';

class Memoizer {
  final Duration ttl;
  final Map<String, _CacheEntry> _cache = {};

  Memoizer({this.ttl = const Duration(minutes: 5)});

  Future<T> runOnce<T>(String key, Future<T> Function() computation) {
    final now = DateTime.now();
    final entry = _cache[key];

    if (entry != null && now.difference(entry.timestamp) < ttl) {
      return entry.future as Future<T>;
    }

    final future = computation();
    _cache[key] = _CacheEntry(future, now);
    
    // Remove on error so it can be retried immediately
    future.catchError((_) {
      _cache.remove(key);
      throw _;
    });

    return future;
  }
  
  void clear() => _cache.clear();
}

class _CacheEntry {
  final Future<dynamic> future;
  final DateTime timestamp;
  _CacheEntry(this.future, this.timestamp);
}

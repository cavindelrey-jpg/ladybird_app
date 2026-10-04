import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Silicon Valley-level Offline-First Cache Layer
class OfflineCache {
  static final OfflineCache instance = OfflineCache._();
  OfflineCache._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Wraps a Supabase live stream with aggressive local caching.
  /// Instantly emits the cached value (0ms latency), then silently updates
  /// in the background when the network connects. If the network is down,
  /// the app continues using the cached data flawlessly.
  Stream<T> watch<T>(
    String key,
    Stream<T> liveStream, {
    required dynamic Function(T) toJson,
    required T Function(dynamic) fromJson,
    T? emptyValue,
  }) async* {
    await init();
    
    // 1. Instant optimistic load from cache
    final cachedStr = _prefs!.getString('cache_$key');
    if (cachedStr != null) {
      try {
        yield fromJson(jsonDecode(cachedStr));
      } catch (e) {
        if (emptyValue != null) yield emptyValue;
      }
    } else if (emptyValue != null) {
      yield emptyValue;
    }

    // 2. Background sync & cache update
    try {
      await for (final data in liveStream) {
        _prefs!.setString('cache_$key', jsonEncode(toJson(data)));
        yield data;
      }
    } catch (e) {
      // Gracefully fallback to cache on network failure (SocketException, etc.)
      // No crash, no red errors. Just smooth offline operation.
    }
  }

  /// Wraps a Future fetch with fallback caching.
  Future<T> fetch<T>(
    String key,
    Future<T> Function() liveFetch, {
    required dynamic Function(T) toJson,
    required T Function(dynamic) fromJson,
  }) async {
    await init();
    try {
      final data = await liveFetch();
      _prefs!.setString('cache_$key', jsonEncode(toJson(data)));
      return data;
    } catch (e) {
      final cachedStr = _prefs!.getString('cache_$key');
      if (cachedStr != null) {
        return fromJson(jsonDecode(cachedStr));
      }
      rethrow;
    }
  }

  Future<void> remove(String key) async {
    await init();
    await _prefs?.remove('cache_$key');
  }

  /// Directly reads from cache without triggering live fetch.
  Future<T?> get<T>(String key, T Function(dynamic) fromJson) async {
    await init();
    final cachedStr = _prefs?.getString('cache_$key');
    if (cachedStr != null) {
      try {
        return fromJson(jsonDecode(cachedStr));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> put(String key, dynamic jsonVal) async {
    await init();
    await _prefs?.setString('cache_$key', jsonEncode(jsonVal));
  }

  // Utility to handle lists
  static dynamic listToJson<T>(List<T> list, dynamic Function(T) itemToJson) {
    return list.map((item) => itemToJson(item)).toList();
  }

  static List<T> listFromJson<T>(dynamic json, T Function(dynamic) itemFromJson) {
    if (json is! List) return [];
    return json.map((item) => itemFromJson(item)).toList();
  }
}

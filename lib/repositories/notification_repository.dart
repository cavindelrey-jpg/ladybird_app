// lib/repositories/notification_repository.dart
// All reads/writes for the per-user Notifications feed and the
// Notification Preferences toggle row.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../core/result.dart';
import 'dart:async';
import '../services/content_cache_service.dart';
import '../core/realtime_tolerant.dart';

class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _notifications => _db.from('notifications');
  SupabaseQueryBuilder get _prefs => _db.from('notification_preferences');

  // ── Feed ───────────────────────────────────────────────

  Stream<List<AppNotification>> watchFeed(String uid, {int limit = 50}) {
    if (uid.isEmpty) return Stream.value(const []);
    final controller = StreamController<List<AppNotification>>();
    StreamSubscription? liveSub;

    controller.onListen = () async {
      final cacheKey = 'notifications_$uid';
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && !controller.isClosed) {
        controller.add(cached.map(AppNotification.fromSupabase).toList());
      }
      liveSub = _notifications
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit)
          .realtimeTolerant()
          .listen((rows) {
        if (controller.isClosed) return;
        final list = List<Map<String, dynamic>>.from(rows);
        unawaited(ContentCacheService.instance.putList(cacheKey, list));
        controller.add(list.map(AppNotification.fromSupabase).toList());
      }, onError: (e) {
        if (cached == null && !controller.isClosed) controller.addError(e);
      });
    };

    controller.onCancel = () => liveSub?.cancel();
    return controller.stream;
  }

  Stream<int> watchUnreadCount(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _notifications
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .realtimeTolerant()
        .map((rows) => rows.where((r) => r['read'] == false).length);
  }

  Future<Result<void>> markRead(String uid, String notificationId) async {
    if (uid.isEmpty) return const Failure('Sign in to manage notifications.', null);
    try {
      await _notifications.update({'read': true}).eq('id', notificationId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update notification', e);
    }
  }

  Future<Result<void>> markAllRead(String uid) async {
    if (uid.isEmpty) return const Failure('Sign in to manage notifications.', null);
    try {
      await _notifications.update({'read': true}).eq('user_id', uid).eq('read', false);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to mark all as read', e);
    }
  }

  /// Fire-and-forget style creation — callers shouldn't block their own
  /// success path on this write.
  Future<Result<void>> create({
    required String uid,
    required NotificationType type,
    required String title,
    required String body,
    String? deepLinkId,
  }) async {
    if (uid.isEmpty) return const Failure('Cannot notify an empty user.', null);
    try {
      await _notifications.insert({
        'user_id': uid,
        ...AppNotification(
          id: '', type: type, title: title, body: body,
          deepLinkId: deepLinkId, createdAt: DateTime.now(),
        ).toSupabase(),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to create notification', e);
    }
  }

  Future<Result<void>> delete(String uid, String notificationId) async {
    if (uid.isEmpty) return const Failure('Sign in to manage notifications.', null);
    try {
      await _notifications.delete().eq('id', notificationId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete notification', e);
    }
  }

  // ── Preferences ────────────────────────────────────────

  Future<NotificationPreferences> getPreferences(String uid) async {
    if (uid.isEmpty) return NotificationPreferences.fromSupabase(null);
    final row = await _prefs.select().eq('user_id', uid).maybeSingle();
    return NotificationPreferences.fromSupabase(row);
  }

  Stream<NotificationPreferences> watchPreferences(String uid) {
    if (uid.isEmpty) return Stream.value(NotificationPreferences.fromSupabase(null));
    return _prefs
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .realtimeTolerant()
        .map((rows) => NotificationPreferences.fromSupabase(rows.isNotEmpty ? rows.first : null));
  }

  Future<Result<void>> updatePreferences(String uid, NotificationPreferences prefs) async {
    if (uid.isEmpty) return const Failure('Sign in to update preferences.', null);
    try {
      await _prefs.upsert({'user_id': uid, ...prefs.toSupabase()});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update preferences', e);
    }
  }
}

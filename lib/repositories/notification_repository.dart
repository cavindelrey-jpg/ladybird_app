// lib/repositories/notification_repository.dart
// All reads/writes for the per-user Notifications feed and the
// Notification Preferences toggle doc. Every path is scoped under the
// signed-in user's own document — no collectionGroup query needed.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';
import '../core/constants.dart';
import '../core/result.dart';

class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _feed(String uid) {
    if (uid.isEmpty) {
      throw ArgumentError('NotificationRepository called with an empty uid — guard the caller for guests.');
    }
    return _db
        .collection(AppConstants.colUsers)
        .doc(uid)
        .collection(AppConstants.colNotifications);
  }

  DocumentReference<Map<String, dynamic>> _prefsDoc(String uid) {
    if (uid.isEmpty) {
      throw ArgumentError('NotificationRepository called with an empty uid — guard the caller for guests.');
    }
    return _db
        .collection(AppConstants.colUsers)
        .doc(uid)
        .collection('settings')
        .doc('notifications');
  }

  // ── Feed ───────────────────────────────────────────────

  Stream<List<AppNotification>> watchFeed(String uid, {int limit = 50}) {
    if (uid.isEmpty) return Stream.value(const []);
    return _feed(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromFirestore).toList());
  }

  Stream<int> watchUnreadCount(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _feed(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<Result<void>> markRead(String uid, String notificationId) async {
    if (uid.isEmpty) return const Failure('Sign in to manage notifications.', null);
    try {
      await _feed(uid).doc(notificationId).update({'read': true});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update notification', e);
    }
  }

  Future<Result<void>> markAllRead(String uid) async {
    if (uid.isEmpty) return const Failure('Sign in to manage notifications.', null);
    try {
      final unread = await _feed(uid).where('read', isEqualTo: false).get();
      if (unread.docs.isEmpty) return const Success(null);
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to mark all as read', e);
    }
  }

  /// Fire-and-forget style creation — callers (e.g. comment/reply/publish
  /// flows) shouldn't block their own success path on this write.
  Future<Result<void>> create({
    required String uid,
    required NotificationType type,
    required String title,
    required String body,
    String? deepLinkId,
  }) async {
    if (uid.isEmpty) return const Failure('Cannot notify an empty user.', null);
    try {
      await _feed(uid).add(AppNotification(
        id: '', type: type, title: title, body: body,
        deepLinkId: deepLinkId, createdAt: DateTime.now(),
      ).toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to create notification', e);
    }
  }

  Future<Result<void>> delete(String uid, String notificationId) async {
    if (uid.isEmpty) return const Failure('Sign in to manage notifications.', null);
    try {
      await _feed(uid).doc(notificationId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete notification', e);
    }
  }

  // ── Preferences ────────────────────────────────────────

  Future<NotificationPreferences> getPreferences(String uid) async {
    if (uid.isEmpty) return NotificationPreferences.fromFirestore(null);
    final doc = await _prefsDoc(uid).get();
    return NotificationPreferences.fromFirestore(doc.data());
  }

  Stream<NotificationPreferences> watchPreferences(String uid) {
    if (uid.isEmpty) return Stream.value(NotificationPreferences.fromFirestore(null));
    return _prefsDoc(uid)
        .snapshots()
        .map((doc) => NotificationPreferences.fromFirestore(doc.data()));
  }

  Future<Result<void>> updatePreferences(String uid, NotificationPreferences prefs) async {
    if (uid.isEmpty) return const Failure('Sign in to update preferences.', null);
    try {
      await _prefsDoc(uid).set(prefs.toFirestore(), SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update preferences', e);
    }
  }
}


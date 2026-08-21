// lib/services/message_cache_service.dart
//
// Local cache-aside layer for the Messages feature. Two problems this
// solves that pure Firestore streams don't:
//
//  1. Cold start is slow-looking. `watchConversations`/`watchMessages`
//     previously had nothing to show until the first Firestore snapshot
//     arrived — on a slow connection that's a blank inbox / blank thread
//     for a second or more. This service lets the repository paint the
//     last-known state INSTANTLY from disk, then swap in live data the
//     moment it arrives. Same idea as the avatar-file cache already used
//     in auth_service.dart ("mirror to local cache so the avatar paints
//     instantly next launch"), applied to conversations/messages.
//
//  2. Flaky connections shouldn't mean an empty inbox. If Firestore's
//     listener is reconnecting, the last cached list is still better
//     than nothing.
//
// This is intentionally NOT a full offline queue / write cache — sends
// still go straight through MessagingRepository to Firestore (which
// already has its own retry-once behavior for media uploads). This is
// read-side only: cache what we've seen, serve it fast, then get out of
// the way once live data shows up.
//
// Storage: SharedPreferences, JSON-encoded — the same mechanism already
// used elsewhere in this codebase (institution_provider.dart,
// organization_provider.dart) rather than introducing a new local-db
// dependency (sqflite/Hive/Isar) for what's fundamentally a small,
// bounded amount of data (a conversation list + the last ~60 messages
// per open thread).

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/messaging.dart';

class MessageCacheService {
  MessageCacheService._();
  static final MessageCacheService instance = MessageCacheService._();

  static const _convPrefix = 'msg_cache_conversations_';
  static const _msgPrefix = 'msg_cache_messages_';

  /// How many messages to keep on disk per conversation. Small on
  /// purpose — this is a "paint something instantly" cache, not a full
  /// offline history; the live Firestore stream (already capped at 60,
  /// see MessagingRepository.watchMessages) takes over within moments.
  static const int maxCachedMessagesPerConversation = 60;

  /// In-session mirror so a second call within the same app run doesn't
  /// re-hit SharedPreferences' disk-backed storage. Cleared implicitly
  /// on app restart (a fresh instance is created either way); no TTL
  /// needed since every write here is immediately superseded by
  /// whatever the live stream produces next.
  final Map<String, List<Conversation>> _convMemory = {};
  final Map<String, List<ChatMessage>> _msgMemory = {};

  // ── Conversations ─────────────────────────────────────────────────

  Future<List<Conversation>> getConversations(String userId) async {
    final mem = _convMemory[userId];
    if (mem != null) return mem;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_convPrefix$userId');
      if (raw == null || raw.isEmpty) return const [];
      final list = (jsonDecode(raw) as List)
          .map((e) => Conversation.fromCacheJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _convMemory[userId] = list;
      return list;
    } catch (_) {
      // A corrupt or unreadable cache entry should never block the UI —
      // the live stream is the source of truth either way.
      return const [];
    }
  }

  Future<void> putConversations(String userId, List<Conversation> conversations) async {
    _convMemory[userId] = conversations;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(conversations.map((c) => c.toCacheJson()).toList());
      await prefs.setString('$_convPrefix$userId', raw);
    } catch (_) {
      // Best-effort — a failed cache write shouldn't surface to the user,
      // it just means next cold start won't have this snapshot to paint.
    }
  }

  // ── Messages ─────────────────────────────────────────────────────

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final mem = _msgMemory[conversationId];
    if (mem != null) return mem;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_msgPrefix$conversationId');
      if (raw == null || raw.isEmpty) return const [];
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatMessage.fromCacheJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _msgMemory[conversationId] = list;
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> putMessages(String conversationId, List<ChatMessage> messages) async {
    final trimmed = messages.length > maxCachedMessagesPerConversation
        ? messages.sublist(messages.length - maxCachedMessagesPerConversation)
        : messages;
    _msgMemory[conversationId] = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(trimmed.map((m) => m.toCacheJson()).toList());
      await prefs.setString('$_msgPrefix$conversationId', raw);
    } catch (_) {
      // Best-effort, see putConversations.
    }
  }

  /// Drops every cached conversation/message list this service knows
  /// about — memory immediately, disk best-effort. Call this from
  /// wherever the app signs a user out (e.g. AuthService.signOut()) so
  /// the next person to use the device doesn't get a flash of the
  /// previous account's inbox before the live stream replaces it.
  Future<void> clearAll() async {
    _convMemory.clear();
    _msgMemory.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
          (k) => k.startsWith(_convPrefix) || k.startsWith(_msgPrefix));
      for (final k in keys.toList()) {
        await prefs.remove(k);
      }
    } catch (_) {
      // Best-effort — worst case a stale cache entry lingers on disk
      // until it's overwritten by the next putConversations/putMessages.
    }
  }
}

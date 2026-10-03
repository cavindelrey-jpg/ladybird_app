// lib/repositories/messaging_repository.dart
// Friend requests, friendships, conversations, and messages. Friendship
// (mutual, request-gated) is what unlocks messaging — Following
// (FollowRepository) is a completely separate, one-way relationship and
// grants no messaging rights on its own.
//
// ── 2024 remake changes ────────────────────────────────────────────────
// - watchConversations / watchMessages now emit a cached snapshot
//   immediately (via MessageCacheService) before the live Supabase
//   stream attaches, and write every live update back to the cache.
// - pingActive(): a real per-conversation "I have this thread open right
//   now" signal, via the ping_conversation_active() RPC (same atomic-
//   jsonb-merge reasoning as setTyping).
// - unreadCount is now actually written — send_chat_message_v2()
//   increments the recipient's entry, mark_conversation_read() zeroes
//   the reader's — see supabase/migrations/20260829480000_messaging_
//   remake_rpcs.sql for why this needed its own RPC rather than reusing
//   academia-cameroon's send_chat_message/mark_conversation_read as-is.
// - sendMessage() gained `recipientId` (needed for the unreadCount fix)
//   and flat shared_* attachment fields, replacing the nested ContentRef
//   academia-cameroon's version still uses.

import 'dart:async';

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/messaging.dart';
import '../models/app_user.dart';
import '../core/result.dart';
import '../services/message_cache_service.dart';
import '../core/realtime_tolerant.dart';

class MessagingRepository {
  MessagingRepository._();
  static final MessagingRepository instance = MessagingRepository._();

  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;

  SupabaseQueryBuilder get _requests => _db.from('friend_requests');
  SupabaseQueryBuilder get _friendships => _db.from('friendships');
  SupabaseQueryBuilder get _conversations => _db.from('conversations');

  /// Sorted pair so a friendship has exactly one canonical row id
  /// regardless of who sent the original request.
  String _pairId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Friend requests ──────────────────────────────────────

  Future<Result<void>> sendFriendRequest({
    required String fromUserId,
    required String fromUserName,
    String? fromUserPhotoUrl,
    required String fromUserRoleLabel,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) return const Failure('You can\'t friend yourself', null);
    try {
      final alreadyFriends = await isFriend(fromUserId, toUserId);
      if (alreadyFriends) return const Failure('You\'re already friends', null);

      final existing = await _requests
          .select()
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', toUserId)
          .eq('status', 'pending')
          .limit(1);
      if (existing.isNotEmpty) return const Failure('Request already sent', null);

      await _requests.insert(FriendRequest(
        id: '', fromUserId: fromUserId, fromUserName: fromUserName,
        fromUserPhotoUrl: fromUserPhotoUrl, fromUserRoleLabel: fromUserRoleLabel,
        toUserId: toUserId, createdAt: DateTime.now(),
      ).toSupabase());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send friend request', e);
    }
  }

  Stream<List<FriendRequest>> watchIncomingRequests(String userId) => _requests
      .stream(primaryKey: ['id'])
      .eq('to_user_id', userId)
      .order('created_at', ascending: false)
      .realtimeTolerant()
      .map((rows) => rows
          .where((r) => r['status'] == 'pending')
          .map(FriendRequest.fromSupabase)
          .toList());

  Stream<int> watchIncomingRequestCount(String userId) =>
      watchIncomingRequests(userId).map((list) => list.length);

  Future<Result<void>> acceptRequest(FriendRequest request, String myName, String? myPhotoUrl) async {
    try {
      await _db.rpc('accept_friend_request', params: {'p_request_id': request.id});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to accept request', e);
    }
  }

  Future<Result<void>> declineRequest(String requestId) async {
    try {
      await _requests.update({'status': 'declined'}).eq('id', requestId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to decline request', e);
    }
  }

  // ── Friendships ──────────────────────────────────────────

  Future<bool> isFriend(String userId, String otherId) async {
    final row = await _friendships.select().eq('id', _pairId(userId, otherId)).maybeSingle();
    return row != null;
  }

  Stream<bool> watchIsFriend(String userId, String otherId) => _friendships
      .stream(primaryKey: ['id'])
      .eq('id', _pairId(userId, otherId))
      .realtimeTolerant()
      .map((rows) => rows.isNotEmpty);

  Stream<int> watchFriendCount(String userId) => _friendships
      .stream(primaryKey: ['id'])
      .realtimeTolerant()
      .map((rows) => rows.where((r) => r['user_a_id'] == userId || r['user_b_id'] == userId).length);

  /// IDs of everyone [userId] is mutually friends with.
  Stream<List<String>> watchFriendIds(String userId) => _friendships
      .stream(primaryKey: ['id'])
      .realtimeTolerant()
      .map((rows) => rows
          .where((r) => r['user_a_id'] == userId || r['user_b_id'] == userId)
          .map((r) => r['user_a_id'] == userId ? r['user_b_id'] as String : r['user_a_id'] as String)
          .toList());

  /// Full profiles behind [watchFriendIds] — powers the "My Friends" list.
  Stream<List<AppUser>> watchFriends(String userId) => watchFriendIds(userId).asyncMap((ids) async {
        if (ids.isEmpty) return <AppUser>[];
        final rows = await _db.from('users').select().inFilter('id', ids);
        return rows.map(AppUser.fromSupabase).toList();
      });

  /// Same-school users [user] isn't already friends with or hasn't
  /// already sent a pending request to. Purely institution-based since
  /// there's no recommendation engine here.
  Future<List<AppUser>> suggestedFriends(AppUser user, {int limit = 20}) async {
    if (user.schoolId == null || user.schoolId!.isEmpty) return [];
    final friendshipRows = await _friendships.select();
    final friendIds = friendshipRows
        .where((r) => r['user_a_id'] == user.id || r['user_b_id'] == user.id)
        .map((r) => r['user_a_id'] == user.id ? r['user_b_id'] as String : r['user_a_id'] as String)
        .toSet();
    final pendingOutgoing = await _requests
        .select('to_user_id')
        .eq('from_user_id', user.id)
        .eq('status', 'pending');
    final exclude = {user.id, ...friendIds, ...pendingOutgoing.map((r) => r['to_user_id'] as String)};
    final rows = await _db
        .from('users')
        .select()
        .eq('institution_id', user.schoolId!)
        .limit(limit + exclude.length);
    return rows
        .where((r) => !exclude.contains(r['id']))
        .take(limit)
        .map(AppUser.fromSupabase)
        .toList();
  }

  // ── Conversations ────────────────────────────────────────

  /// Finds the existing 1:1 conversation between two people, or creates
  /// one, via get_or_create_direct_conversation(): friends may always
  /// message; a teacher / class master and a student of the same school
  /// may too, without a friend request. (A direct insert used to fail on
  /// any environment without an undocumented INSERT policy.) The name/
  /// photo arguments are kept for call-site compatibility; the server
  /// reads them from public.users.
  Future<Result<String>> getOrCreateConversation({
    required String userAId, required String userAName, String? userAPhoto,
    required String userBId, required String userBName, String? userBPhoto,
  }) async {
    try {
      final id = await _db.rpc('get_or_create_direct_conversation', params: {'p_other': userBId});
      return Success(id as String);
    } on PostgrestException catch (e) {
      return Failure(e.code == '42501' ? 'Send a friend request first to start messaging.' : e.message, e);
    } catch (e) {
      return Failure('Couldn\'t open the conversation. Check your connection.', e);
    }
  }

  /// Recency-sorted conversations for [userId]. Emits a cached snapshot
  /// first (if one exists on disk from a previous session) so the inbox
  /// paints instantly instead of sitting blank until the first live
  /// snapshot arrives, then switches to — and stays on — the live
  /// stream. Every live update is written back to the cache.
  Stream<List<Conversation>> watchConversations(String userId) {
    late final StreamController<List<Conversation>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? liveSub;

    controller = StreamController<List<Conversation>>(
      onListen: () {
        MessageCacheService.instance.getConversations(userId).then((cached) {
          if (cached.isNotEmpty && !controller.isClosed) controller.add(cached);
        });
        liveSub = _conversations
            .stream(primaryKey: ['id'])
            .order('last_message_at', ascending: false)
            .realtimeTolerant()
            .listen(
              (rows) {
                if (controller.isClosed) return;
                final live = rows
                    .where((r) => (r['participant_ids'] as List?)?.contains(userId) ?? false)
                    .map(Conversation.fromSupabase)
                    .toList();
                controller.add(live);
                unawaited(MessageCacheService.instance.putConversations(userId, live));
              },
              onError: (Object e, StackTrace st) {
                if (!controller.isClosed) controller.addError(e, st);
              },
            );
      },
      onCancel: () async {
        await liveSub?.cancel();
        if (!controller.isClosed) await controller.close();
      },
    );
    return controller.stream;
  }

  /// Single conversation row — backs the typing indicator, the
  /// per-conversation presence dot, and anything else the chat screen
  /// needs from the conversation itself.
  Stream<Conversation?> watchConversation(String conversationId) => _conversations
      .stream(primaryKey: ['id'])
      .eq('id', conversationId)
      .realtimeTolerant()
      .map((rows) => rows.isNotEmpty ? Conversation.fromSupabase(rows.first) : null);

  /// Records that [userId] is actively typing in [conversationId]. Call
  /// sites should throttle this. No matching "stopped typing" call:
  /// readers treat any timestamp older than a few seconds as stale.
  Future<void> setTyping(String conversationId, String userId) async {
    try {
      final row = await _conversations.select('typing_at').eq('id', conversationId).maybeSingle()
          .timeout(const Duration(seconds: 10));
      final typing = Map<String, dynamic>.from(row?['typing_at'] ?? {});
      typing[userId] = DateTime.now().toIso8601String();
      await _conversations.update({'typing_at': typing}).eq('id', conversationId)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort — a missed typing ping is invisible, not worth surfacing
    }
  }

  /// Records that [userId] currently has [conversationId]'s screen open.
  /// Call sites should ping this on open and on a slow interval (e.g.
  /// every 45-60s) while the screen stays mounted — see
  /// Conversation.activeAt / isRecentlyActive for how readers interpret
  /// it. Uses an RPC (not a plain .update()) so concurrent participants'
  /// entries merge atomically instead of clobbering each other.
  Future<void> pingActive(String conversationId, String userId) async {
    try {
      await _db.rpc('ping_conversation_active', params: {
        'p_conversation_id': conversationId, 'p_user_id': userId,
      }).timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort — same reasoning as setTyping
    }
  }

  /// Open chats, so a send can refresh the sender's view immediately.
  final Map<String, Future<void> Function()> _openChats = {};

  /// Re-reads [conversationId] now if it's open on screen. Called after a
  /// successful send: the list used to update only through the realtime
  /// socket, so with realtime slow or down the sender's message seemed
  /// to vanish -- and people resent it.
  Future<void> refreshMessages(String conversationId) async => _openChats[conversationId]?.call();

  /// Live message stream, most-recent [limit] messages. Emits a cached
  /// snapshot first (see watchConversations doc comment — same pattern),
  /// then the live window takes over. A light REST poll (every 15 s)
  /// keeps incoming messages arriving when the realtime channel is down;
  /// identical snapshots aren't re-emitted.
  Stream<List<ChatMessage>> watchMessages(String conversationId, {int limit = 60}) {
    late final StreamController<List<ChatMessage>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? liveSub;
    Timer? poll;
    String? lastSignature;

    void emit(List<Map<String, dynamic>> ascendingRows) {
      if (controller.isClosed) return;
      final window = ascendingRows.length > limit
          ? ascendingRows.sublist(ascendingRows.length - limit)
          : ascendingRows;
      final signature = window.map((r) => '${r['id']}:${r['deleted']}:${(r['read_by'] as List?)?.length}').join(',');
      if (signature == lastSignature) return;
      lastSignature = signature;
      final live = window.map(ChatMessage.fromSupabase).toList();
      controller.add(live);
      unawaited(MessageCacheService.instance.putMessages(conversationId, live));
    }

    Future<void> fetch() async {
      try {
        final rows = await _db
            .from('direct_messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('sent_at', ascending: false)
            .limit(limit)
            .timeout(const Duration(seconds: 10));
        emit(rows.reversed.toList());
      } catch (_) {
        // offline: keep showing what we have; the live stream reports errors
      }
    }

    controller = StreamController<List<ChatMessage>>(
      onListen: () {
        MessageCacheService.instance.getMessages(conversationId).then((cached) {
          if (cached.isNotEmpty && !controller.isClosed && lastSignature == null) controller.add(cached);
        });
        _openChats[conversationId] = fetch;
        poll = Timer.periodic(const Duration(seconds: 15), (_) => fetch());
        liveSub = _db
            .from('direct_messages')
            .stream(primaryKey: ['id'])
            .eq('conversation_id', conversationId)
            // ascending: the window keeps the NEWEST [limit] messages.
            // With postgrest's default (descending) it kept the oldest
            // ones, so a conversation past [limit] messages stopped
            // showing anything new.
            .order('sent_at', ascending: true)
            .realtimeTolerant()
            .listen(
              emit,
              onError: (Object e, StackTrace st) {
                if (!controller.isClosed) controller.addError(e, st);
              },
            );
      },
      onCancel: () async {
        poll?.cancel();
        if (_openChats[conversationId] == fetch) _openChats.remove(conversationId);
        await liveSub?.cancel();
        if (!controller.isClosed) await controller.close();
      },
    );
    return controller.stream;
  }

  String _sharedContentEmoji(SharedContentType t) => switch (t) {
        SharedContentType.note => '📝',
        SharedContentType.course => '🎓',
        SharedContentType.quiz => '❓',
        SharedContentType.article => '📰',
        SharedContentType.pastPaper => '📄',
        SharedContentType.clubPost => '📢',
        SharedContentType.authorProfile => '👤',
      };

  Future<Result<void>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    /// The other participant — used only to increment their unread
    /// counter. Optional so this stays source-compatible with any other
    /// call site; unreadCount simply won't advance without it.
    String? recipientId,
    String text = '',
    String? imageUrl,
    String? videoUrl,
    String? fileUrl,
    String? fileName,
    SharedContentType? sharedType,
    String? sharedId,
    String? sharedTitle,
    String? sharedSubtitle,
    String? sharedThumbnailUrl,
  }) async {
    try {
      final preview = text.isNotEmpty ? text
          : (imageUrl != null ? '📷 Photo'
          : (videoUrl != null ? '🎥 Video'
          : (fileUrl != null ? '📎 ${fileName ?? "File"}'
          : (sharedType != null ? '${_sharedContentEmoji(sharedType)} ${sharedTitle ?? sharedType.label}' : ''))));
      await _db.rpc('send_chat_message_v2', params: {
        'p_conversation_id': conversationId,
        'p_sender_id': senderId,
        'p_sender_name': senderName,
        'p_body': text,
        'p_image_url': imageUrl,
        'p_video_url': videoUrl,
        'p_file_url': fileUrl,
        'p_file_name': fileName,
        'p_shared_type': sharedType?.name,
        'p_shared_id': sharedId,
        'p_shared_title': sharedTitle,
        'p_shared_subtitle': sharedSubtitle,
        'p_shared_thumbnail_url': sharedThumbnailUrl,
        'p_preview': preview,
        'p_recipient_id': recipientId,
      });
      unawaited(refreshMessages(conversationId));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send message', e);
    }
  }

  /// Toggles [userId]'s personal "pin to top" on a conversation — a view
  /// preference, not something the other participant sees or is affected
  /// by. Uses an RPC so concurrent pin/unpin calls merge atomically.
  Future<Result<void>> togglePinned(String conversationId, String userId, bool pinned) async {
    try {
      await _db.rpc('toggle_conversation_pin', params: {
        'p_conversation_id': conversationId, 'p_user_id': userId, 'p_pinned': pinned,
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update pin', e);
    }
  }

  Future<Result<String>> uploadChatMedia({
    required String conversationId,
    required File file,
    required bool isVideo,
    void Function(double)? onProgress,
  }) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final path = 'chat_media/$conversationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    return _uploadWithRetry(path, file, onProgress);
  }

  /// General file attachments — any type (PDF, docx, etc.), not just
  /// photo/video. Keeps the original filename so it downloads with a
  /// sensible name rather than a bare timestamp.
  Future<Result<String>> uploadChatFile({
    required String conversationId,
    required File file,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    final path = 'chat_files/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    return _uploadWithRetry(path, file, onProgress);
  }

  /// Shared upload path for chat attachments: times out instead of
  /// hanging forever on a dead connection, retries once on failure.
  Future<Result<String>> _uploadWithRetry(
    String path,
    File file,
    void Function(double)? onProgress, {
    int attempt = 1,
  }) async {
    try {
      onProgress?.call(0);
      await _db.storage.from(_bucket).upload(path, file).timeout(const Duration(minutes: 5));
      onProgress?.call(1);
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      if (attempt < 2) {
        onProgress?.call(0);
        return _uploadWithRetry(path, file, onProgress, attempt: attempt + 1);
      }
      return Failure('Upload failed — check your connection and try again', e);
    }
  }

  /// Soft-deletes one of the caller's own messages: clears the content,
  /// flips `deleted`, keeps the row (sender/timestamp) so the thread
  /// shows a "message deleted" placeholder instead of a confusing gap.
  /// Only the sender can do this — enforced both here and in RLS.
  Future<Result<void>> deleteMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final row = await _db.from('direct_messages').select().eq('id', messageId).maybeSingle();
      if (row == null || row['sender_id'] != userId) {
        return const Failure('You can only delete your own messages', null);
      }
      await _db.from('direct_messages').update({
        'deleted': true,
        'body': '',
        'image_url': null,
        'video_url': null,
        'file_url': null,
        'file_name': null,
      }).eq('id', messageId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete message', e);
    }
  }

  /// Marks every message not yet read by [userId] as read, and resets
  /// their unread counter — called on opening a conversation.
  Future<void> markConversationRead(String conversationId, String userId) async {
    try {
      await _db.rpc('mark_conversation_read', params: {
        'p_conversation_id': conversationId, 'p_user_id': userId,
      });
    } catch (_) {
      // best-effort — a failed read-receipt update shouldn't block the UI
    }
  }

  /// Simple name-prefix search across users — powers "Find People".
  Future<List<Map<String, dynamic>>> searchUsers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final rows = await _db
        .from('users')
        .select()
        .ilike('name_lower', '$q%')
        .order('name_lower', ascending: true)
        .limit(limit);
    return rows;
  }
}

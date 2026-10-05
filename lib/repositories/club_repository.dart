// lib/repositories/club_repository.dart
//
// ── Clubs remake changes ────────────────────────────────────────────────
// - pingClubActive()/watchOnlineCount(): a real (not faked) "X members
//   online" figure for the club hero, built the same way
//   MessagingRepository.pingActive()/Conversation.activeAt already do it
//   for 1:1 chat presence — a cheap merged field write on the existing
//   member row, no new table, no realtime-presence infrastructure.
// - Feed/Discussions/Resources/Events are real Supabase tables (see
//   supabase/migrations/20260829450000_clubs_remake.sql) — atomic
//   counters (likes/comments/replies/rsvps) go through SECURITY DEFINER
//   RPCs, same pattern as every other engagement counter in this rewrite.

import 'dart:async';

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../core/result.dart';
import '../services/content_cache_service.dart';
import 'dart:async';
import 'xp_repository.dart';
import '../core/realtime_tolerant.dart';
import '../core/club_scope.dart';

class ClubRepository {
  ClubRepository._();
  static final ClubRepository instance = ClubRepository._();

  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;

  // ── Discovery ──────────────────────────────────────────

  Stream<List<Club>> watchClubs({String? schoolId, AppUser? user}) {
    final controller = StreamController<List<Club>>();
    StreamSubscription? liveSub;

    controller.onListen = () async {
      final scope = ClubScope.resolveSchoolId(user: user, explicitSchoolId: schoolId);
      final cacheKey = scope == null ? 'clubs_all_super_admin' : 'clubs_$scope';
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && !controller.isClosed) {
        var cachedRows = cached;
        if (scope != null) {
          cachedRows = cached.where((r) {
            final sid = ClubScope.normalizeSchoolId((r['school_id'] ?? r['institution_id']) as String?);
            return sid == scope;
          }).toList();
        }
        controller.add(cachedRows.map(Club.fromSupabase).toList());
      }
      
      final query = _db.from('clubs');
      final stream = (scope != null)
          ? query.stream(primaryKey: ['id']).eq('institution_id', scope).realtimeTolerant()
          : query.stream(primaryKey: ['id']).realtimeTolerant();

      liveSub = stream.listen((rows) {
        if (controller.isClosed) return;
        var filtered = rows;
        if (scope != null) {
          filtered = rows.where((r) {
            final sid = ClubScope.normalizeSchoolId((r['school_id'] ?? r['institution_id']) as String?);
            return sid == scope;
          }).toList();
        }
        final list = List<Map<String, dynamic>>.from(filtered);
        unawaited(ContentCacheService.instance.putList(cacheKey, list));
        controller.add(list.map(Club.fromSupabase).toList());
      }, onError: (e) {
        if (cached == null && !controller.isClosed) controller.addError(e);
      });
    };

    controller.onCancel = () => liveSub?.cancel();
    return controller.stream;
  }

  Future<List<Club>> searchClubs(
    String query, {
    String? category,
    String? schoolId,
    AppUser? user,
  }) async {
    final scope = ClubScope.resolveSchoolId(user: user, explicitSchoolId: schoolId);
    var q = _db.from('clubs').select();
    if (category != null && category != 'All') q = q.eq('category', category);
    if (scope != null) {
      q = q.or('institution_id.eq.$scope,school_id.eq.$scope');
    }
    final rows = await q;
    final lower = query.toLowerCase();
    var list = rows.map(Club.fromSupabase);
    if (scope != null) {
      list = list.where((c) => ClubScope.normalizeSchoolId(c.schoolId) == scope);
    }
    return list
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(lower))
        .toList();
  }

  /// Fetches a single club by ID, verifying that the current context/user is authorized to access it.
  Future<Result<Club>> getClub(String clubId, {AppUser? user}) async {
    try {
      final scope = ClubScope.resolveSchoolId(user: user);
      var q = _db.from('clubs').select().eq('id', clubId);
      if (scope != null) {
        q = q.or('institution_id.eq.$scope,school_id.eq.$scope');
      }
      final row = await q.maybeSingle();
      if (row == null) {
        return const Failure('Group not found or access denied for this school context.', null);
      }
      final club = Club.fromSupabase(row);
      if (!ClubScope.canAccessClub(club, user: user)) {
        return const Failure('Access denied: This group belongs to another school context.', null);
      }
      return Success(club);
    } catch (e) {
      return Failure('Failed to load group', e);
    }
  }

  // ── Membership ─────────────────────────────────────────

  Stream<ClubRole> watchUserRole(String clubId, String userId) {
    return _db
        .from('club_members')
        .stream(primaryKey: ['club_id', 'user_id'])
        .eq('club_id', clubId)
        .realtimeTolerant()
        .map((rows) {
      final mine = rows.where((r) => r['user_id'] == userId).toList();
      if (mine.isEmpty) return ClubRole.visitor;
      return ClubRole.values.firstWhere(
          (r) => r.name == mine.first['role'], orElse: () => ClubRole.member);
    });
  }

  /// Records that [userId] currently has [clubId]'s detail screen open —
  /// call on open, then on a slow interval (e.g. every 45-60s) while the
  /// screen stays mounted. Best-effort: silently does nothing for a
  /// non-member (the update matches zero rows).
  Future<void> pingClubActive(String clubId, String userId) async {
    try {
      await _db
          .from('club_members')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort, see doc comment
    }
  }

  /// Live count of members with a [pingClubActive] heartbeat inside the
  /// last two minutes — the real number behind the hero's "X online" stat.
  /// Recomputes both on every live update AND a 30s ticker, so idle
  /// members actually drop out of the count between row changes.
  Stream<int> watchOnlineCount(String clubId) {
    late final StreamController<int> controller;
    StreamSubscription<List<Map<String, dynamic>>>? sub;
    Timer? ticker;
    List<DateTime?> lastActive = const [];

    void recompute() {
      if (controller.isClosed) return;
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      final count = lastActive.where((ts) => ts != null && ts.isAfter(cutoff)).length;
      controller.add(count);
    }

    controller = StreamController<int>(
      onListen: () {
        sub = _db
            .from('club_members')
            .stream(primaryKey: ['club_id', 'user_id'])
            .eq('club_id', clubId)
            .realtimeTolerant()
            .listen(
              (rows) {
                lastActive = rows
                    .map((r) => DateTime.tryParse(r['last_active_at']?.toString() ?? ''))
                    .toList();
                recompute();
              },
              onError: (Object e, StackTrace st) {
                if (!controller.isClosed) controller.addError(e, st);
              },
            );
        ticker = Timer.periodic(const Duration(seconds: 30), (_) => recompute());
      },
      onCancel: () async {
        await sub?.cancel();
        ticker?.cancel();
        if (!controller.isClosed) await controller.close();
      },
    );
    return controller.stream;
  }

  Future<Result<void>> joinClub(
    String clubId,
    String userId, {
    required String name,
    String? photoUrl,
    AppUser? user,
  }) async {
    try {
      final clubRes = await getClub(clubId, user: user);
      if (clubRes is Failure<Club>) {
        return Failure(clubRes.message, clubRes.cause);
      }
      await _db.rpc('join_club', params: {'p_club_id': clubId, 'p_name': name, 'p_photo_url': photoUrl});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to join group', e);
    }
  }

  // ── Join requests (approval-gated clubs only) ─────────────

  SupabaseQueryBuilder get _joinRequests => _db.from('club_join_requests');

  Future<Result<void>> requestToJoin({
    required String clubId, required String clubName,
    required String userId, required String userName, String? userPhotoUrl,
    AppUser? user,
  }) async {
    try {
      final clubRes = await getClub(clubId, user: user);
      if (clubRes is Failure<Club>) {
        return Failure(clubRes.message, clubRes.cause);
      }
      final existing = await _joinRequests
          .select()
          .eq('club_id', clubId)
          .eq('user_id', userId)
          .eq('status', 'pending')
          .limit(1);
      if (existing.isNotEmpty) return const Failure('Request already pending', null);

      await _joinRequests.insert(ClubJoinRequest(
        id: '', clubId: clubId, clubName: clubName,
        userId: userId, userName: userName, userPhotoUrl: userPhotoUrl,
        createdAt: DateTime.now(),
      ).toSupabase());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send join request', e);
    }
  }

  /// Pending/approved/declined status of this user's most recent request
  /// for this club — drives the "Pending" badge on My Clubs.
  Stream<ClubJoinRequestStatus?> watchMyRequestStatus(String clubId, String userId) => _joinRequests
      .stream(primaryKey: ['id'])
      .eq('club_id', clubId)
      .order('created_at', ascending: false)
      .realtimeTolerant()
      .map((rows) {
    final mine = rows.where((r) => r['user_id'] == userId).toList();
    return mine.isEmpty ? null : ClubJoinRequest.fromSupabase(mine.first).status;
  });

  /// IDs of every club [userId] currently has a PENDING join request for.
  Stream<List<String>> watchMyPendingRequestClubIds(String userId) {
    final controller = StreamController<List<String>>();
    StreamSubscription? liveSub;

    controller.onListen = () async {
      final cacheKey = 'my_pending_club_ids_$userId';
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && !controller.isClosed) {
        controller.add(cached.map((e) => e['id'] as String).toList());
      }

      final stream = _joinRequests
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
        .realtimeTolerant();

      liveSub = stream.listen((rows) {
        if (controller.isClosed) return;
        final ids = rows
            .where((r) => r['status'] == 'pending')
            .map((r) => r['club_id'] as String)
            .toList();
        final cacheList = ids.map((id) => {'id': id}).toList();
        unawaited(ContentCacheService.instance.putList(cacheKey, cacheList));
        controller.add(ids);
      }, onError: (e) {
        if (cached == null && !controller.isClosed) controller.addError(e);
      });
    };

    controller.onCancel = () => liveSub?.cancel();
    return controller.stream;
  }

  /// Pending requests for a club — for its admins/moderators to review.
  Stream<List<ClubJoinRequest>> watchPendingRequests(String clubId) => _joinRequests
      .stream(primaryKey: ['id'])
      .eq('club_id', clubId)
      .order('created_at', ascending: false)
      .realtimeTolerant()
      .map((rows) => rows
          .where((r) => r['status'] == 'pending')
          .map(ClubJoinRequest.fromSupabase)
          .toList());

  Future<Result<void>> approveJoinRequest(ClubJoinRequest req) async {
    try {
      await _db.rpc('approve_club_join_request', params: {'p_request_id': req.id});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to approve request', e);
    }
  }

  Future<Result<void>> declineJoinRequest(String requestId) async {
    try {
      await _joinRequests.update({'status': 'declined'}).eq('id', requestId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to decline request', e);
    }
  }

  Future<Result<void>> leaveClub(String clubId, String userId) async {
    try {
      await _db.rpc('leave_club', params: {'p_club_id': clubId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to leave group', e);
    }
  }

  // ── Chat ───────────────────────────────────────────────

  /// The class group for [classLevel] at [schoolId], or null if the class
  /// master hasn't created one yet.
  Future<Result<Club?>> classGroup(String schoolId, String classLevel) async {
    try {
      final canonical = ClubScope.normalizeSchoolId(schoolId);
      final row = await _db.from('clubs').select()
          .or('institution_id.eq.$canonical,school_id.eq.$canonical')
          .eq('class_level', classLevel)
          .maybeSingle();
      return Success(row == null ? null : Club.fromSupabase(row));
    } catch (e) {
      return Failure('Couldn\'t load the class group. Check your connection.', e);
    }
  }

  /// Creates (or returns the existing) class group and enrols every
  /// current student of the class. Class master / school admin only --
  /// enforced by the create_class_group RPC.
  Future<Result<Club>> createClassGroup(String classLevel) async {
    try {
      final id = await _db.rpc('create_class_group', params: {'p_class_level': classLevel}) as String;
      final row = await _db.from('clubs').select().eq('id', id).single();
      return Success(Club.fromSupabase(row));
    } on PostgrestException catch (e) {
      return Failure(e.message, e);
    } catch (e) {
      return Failure('Couldn\'t create the class group.', e);
    }
  }

  /// Adds students who joined the class after the group was created.
  Future<Result<int>> syncClassGroup(String clubId) async {
    try {
      final added = await _db.rpc('sync_class_group_members', params: {'p_club_id': clubId}) as int;
      return Success(added);
    } on PostgrestException catch (e) {
      return Failure(e.message, e);
    } catch (e) {
      return Failure('Couldn\'t update the class group.', e);
    }
  }

  final Map<String, Future<void> Function()> _refreshClubChat = {};

  /// Newest 100 messages, oldest first (newest at the bottom by the input
  /// bar). Like direct messages: refreshed right after a send and polled
  /// every 15 s, so the group works when the realtime channel is down.
  Stream<List<ClubMessage>> watchMessages(String clubId) {
    late final StreamController<List<ClubMessage>> controller;
    StreamSubscription<List<ClubMessage>>? liveSub;
    Timer? poll;
    String? last;

    void emit(List<ClubMessage> msgs) {
      if (controller.isClosed) return;
      final sig = msgs.map((m) => '${m.id}:${m.deleted}').join(',');
      if (sig == last) return;
      last = sig;
      controller.add(msgs);
    }

    Future<void> fetch() async {
      try {
        final rows = await _db.from('club_messages').select().eq('club_id', clubId)
            .order('sent_at', ascending: false).limit(100).timeout(const Duration(seconds: 10));
        emit(rows.reversed.map(ClubMessage.fromSupabase).toList());
      } catch (_) {}
    }

    controller = StreamController<List<ClubMessage>>(
      onListen: () {
        _refreshClubChat[clubId] = fetch;
        poll = Timer.periodic(const Duration(seconds: 15), (_) => fetch());
        liveSub = _db
            .from('club_messages')
            .stream(primaryKey: ['id'])
            .eq('club_id', clubId)
            .order('sent_at') // newest 100 (descending) ...
            .limit(100)
            .realtimeTolerant()
            // ... shown oldest-first, newest at the bottom by the input bar.
            .map((rows) => rows.reversed.map(ClubMessage.fromSupabase).toList())
            .listen(emit, onError: (Object e, StackTrace st) {
              if (!controller.isClosed) controller.addError(e, st);
            });
      },
      onCancel: () async {
        poll?.cancel();
        if (_refreshClubChat[clubId] == fetch) _refreshClubChat.remove(clubId);
        await liveSub?.cancel();
        if (!controller.isClosed) await controller.close();
      },
    );
    return controller.stream;
  }

  Future<Result<void>> sendMessage(String clubId, ClubMessage message, {AppUser? user}) async {
    try {
      final clubRes = await getClub(clubId, user: user);
      if (clubRes is Failure<Club>) {
        return Failure(clubRes.message, clubRes.cause);
      }
      // The inbox preview (clubs.last_message_*) is maintained by the
      // trg_club_message_preview trigger -- the client used to update it
      // itself, which members (not moderators) aren't allowed to do, so
      // their sends were reported as failed after being saved.
      await _db.from('club_messages').insert({'club_id': clubId, ...message.toSupabase()});
      unawaited(_refreshClubChat[clubId]?.call());
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(e.message.contains('row-level security')
          ? 'You\'re not a member of this group any more.'
          : 'Message not sent. Please try again.', e);
    } catch (e) {
      return Failure('Message not sent — check your connection.', e);
    }
  }

  Stream<List<String>> watchMyClubIds(String userId) {
    final controller = StreamController<List<String>>();
    StreamSubscription? liveSub;

    controller.onListen = () async {
      final cacheKey = 'my_club_ids_$userId';
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && !controller.isClosed) {
        controller.add(cached.map((e) => e['id'] as String).toList());
      }

      final stream = _db
          .from('club_members')
          .stream(primaryKey: ['club_id', 'user_id'])
          .eq('user_id', userId)
        .realtimeTolerant();

      liveSub = stream.listen((rows) {
        if (controller.isClosed) return;
        final ids = rows.map((r) => r['club_id'] as String).toList();
        final cacheList = ids.map((id) => {'id': id}).toList();
        unawaited(ContentCacheService.instance.putList(cacheKey, cacheList));
        controller.add(ids);
      }, onError: (e) {
        if (cached == null && !controller.isClosed) controller.addError(e);
      });
    };

    controller.onCancel = () => liveSub?.cancel();
    return controller.stream;
  }

  /// Full Club rows for [watchMyClubIds] — the actual data the merged
  /// inbox renders (name, emoji, lastMessage*), filtered by authorized school context.
  Stream<List<Club>> watchMyClubs(String userId, {String? schoolId, AppUser? user}) {
    final scope = ClubScope.resolveSchoolId(user: user, explicitSchoolId: schoolId);
    return watchMyClubIds(userId).asyncMap((ids) async {
      if (ids.isEmpty) return <Club>[];
      var q = _db.from('clubs').select().inFilter('id', ids);
      if (scope != null) {
        q = q.or('institution_id.eq.$scope,school_id.eq.$scope');
      }
      final rows = await q;
      var clubs = rows.map(Club.fromSupabase);
      if (scope != null) {
        clubs = clubs.where((c) => ClubScope.normalizeSchoolId(c.schoolId) == scope);
      }
      return clubs.toList();
    });
  }

  /// Soft-delete -- same reasoning as MessagingRepository.deleteMessage:
  /// keeps the row so the thread shows a placeholder instead of a gap,
  /// sender-only both here and in RLS.
  Future<Result<void>> deleteMessage(String clubId, String messageId, String userId) async {
    try {
      final row = await _db.from('club_messages').select().eq('id', messageId).maybeSingle();
      if (row == null || row['sender_id'] != userId) {
        return const Failure('You can only delete your own messages', null);
      }
      await _db.from('club_messages').update({'deleted': true, 'body': ''}).eq('id', messageId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete message', e);
    }
  }

  // ── Create ─────────────────────────────────────────────

  Future<Result<String>> createClub(
    Club club,
    String founderId, {
    required String founderName,
    String? founderPhotoUrl,
    AppUser? user,
  }) async {
    try {
      final scope = ClubScope.resolveSchoolId(user: user, explicitSchoolId: club.schoolId);
      final scopedClub = Club(
        id: club.id,
        name: club.name,
        emoji: club.emoji,
        description: club.description,
        moderatorName: founderName,
        moderatorId: founderId,
        category: club.category,
        bannerUrl: club.bannerUrl,
        thumbnailUrl: club.thumbnailUrl,
        memberCount: club.memberCount,
        schoolId: scope ?? club.schoolId,
        requiresApproval: club.requiresApproval,
        classLevel: club.classLevel,
        lastMessageText: club.lastMessageText,
        lastMessageSenderId: club.lastMessageSenderId,
        lastMessageAt: club.lastMessageAt,
      );

      final row = await _db.from('clubs').insert(scopedClub.toSupabase()).select('id').single();
      final clubId = row['id'] as String;
      await _db.from('club_members').insert({
        'club_id': clubId, 'user_id': founderId,
        'name': founderName, 'photo_url': founderPhotoUrl, 'role': ClubRole.admin.name,
      });
      return Success(clubId);
    } catch (e) {
      return Failure('Failed to create group', e);
    }
  }

  // ── Member management (mod structure) ───────────────────

  Stream<List<ClubMember>> watchMemberPreview(String clubId, {int limit = 3}) => _db
      .from('club_members')
      .stream(primaryKey: ['club_id', 'user_id'])
      .eq('club_id', clubId)
      .order('joined_at')
      .limit(limit)
      .realtimeTolerant()
      .map((rows) => rows.map(ClubMember.fromSupabase).toList());

  Stream<List<ClubMember>> watchMembers(String clubId) => _db
      .from('club_members')
      .stream(primaryKey: ['club_id', 'user_id'])
      .eq('club_id', clubId)
      .order('joined_at')
      .realtimeTolerant()
      .map((rows) => rows.map(ClubMember.fromSupabase).toList());

  Future<Result<void>> updateMemberRole(
      String clubId, String userId, ClubRole newRole) async {
    try {
      await _db.from('club_members').update({'role': newRole.name}).eq('club_id', clubId).eq('user_id', userId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update member role', e);
    }
  }

  Future<Result<void>> removeMember(String clubId, String userId) async {
    try {
      await _db.rpc('remove_club_member', params: {'p_club_id': clubId, 'p_user_id': userId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to remove member', e);
    }
  }

  // ── Banner + thumbnail images ─────────────────────────────

  Future<Result<String>> uploadBanner({
    required String clubId,
    required File imageFile,
  }) async {
    try {
      final path = 'club_banners/$clubId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload group banner', e);
    }
  }

  /// The club's own logo/badge photo — a real picture the admin picks,
  /// distinct from [uploadBanner]'s wide cover photo.
  Future<Result<String>> uploadThumbnail({
    required String clubId,
    required File imageFile,
  }) async {
    try {
      final path = 'club_thumbnails/$clubId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload group thumbnail', e);
    }
  }

  Future<Result<void>> updateClub(Club club, {AppUser? user}) async {
    try {
      if (!ClubScope.canAccessClub(club, user: user)) {
        return const Failure('Access denied: You cannot edit a group from another school.', null);
      }
      final scope = ClubScope.resolveSchoolId(user: user, explicitSchoolId: club.schoolId);
      var q = _db.from('clubs').update(club.toUpdateMap()).eq('id', club.id);
      if (scope != null) {
        q = q.or('institution_id.eq.$scope,school_id.eq.$scope');
      }
      await q;
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update group', e);
    }
  }

  /// Founder or school staff only (mirrors RLS' clubs delete policy).
  Future<Result<void>> deleteClub(String clubId, {AppUser? user}) async {
    try {
      final clubRes = await getClub(clubId, user: user);
      if (clubRes is Failure<Club>) {
        return Failure(clubRes.message, clubRes.cause);
      }
      final scope = ClubScope.resolveSchoolId(user: user);
      var q = _db.from('clubs').delete().eq('id', clubId);
      if (scope != null) {
        q = q.or('institution_id.eq.$scope,school_id.eq.$scope');
      }
      await q;
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete group', e);
    }
  }

  // ── Feed (posts) ───────────────────────────────────────────

  Stream<List<ClubPost>> watchPosts(String clubId) => _db
      .from('club_posts')
      .stream(primaryKey: ['id'])
      .eq('club_id', clubId)
      .order('created_at', ascending: false)
      .limit(100)
      .realtimeTolerant()
      .map((rows) => rows.map(ClubPost.fromSupabase).toList());

  Future<Result<void>> createPost(String clubId, ClubPost post, {AppUser? user}) async {
    try {
      final clubRes = await getClub(clubId, user: user);
      if (clubRes is Failure<Club>) {
        return Failure(clubRes.message, clubRes.cause);
      }
      await _db.from('club_posts').insert(post.toSupabase());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to publish post', e);
    }
  }

  Future<Result<void>> togglePostLike(String clubId, String postId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to like posts.', null);
    try {
      await _db.rpc('toggle_club_post_like', params: {'p_post_id': postId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  Stream<bool> watchIsPostLiked(String clubId, String postId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db
        .from('club_post_likes')
        .stream(primaryKey: ['post_id', 'user_id'])
        .eq('post_id', postId)
        .realtimeTolerant()
        .map((rows) => rows.any((r) => r['user_id'] == userId));
  }

  Stream<List<ClubPostComment>> watchPostComments(String clubId, String postId) => _db
      .from('club_post_comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', postId)
      .order('created_at')
      .realtimeTolerant()
      .map((rows) => rows.map(ClubPostComment.fromSupabase).toList());

  Future<Result<void>> addPostComment(String clubId, String postId, ClubPostComment comment) async {
    try {
      await _db.rpc('add_club_post_comment', params: {
        'p_post_id': postId,
        'p_author_name': comment.authorName,
        'p_author_photo_url': comment.authorPhotoUrl,
        'p_text': comment.text,
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add comment', e);
    }
  }

  // ── Discussions (Q&A with best-answer + XP) ─────────────────
  // See models/club.dart's ClubDiscussion/ClubDiscussionReply doc
  // comments for the shape. XP amounts (10 / 10 / 25) match the Physics
  // Society mockup exactly — see XpSource.clubQuestion/clubAnswer/
  // clubBestAnswer in models/xp_transaction.dart.

  Stream<List<ClubDiscussion>> watchDiscussions(String clubId) => _db
      .from('club_discussions')
      .stream(primaryKey: ['id'])
      .eq('club_id', clubId)
      .order('created_at', ascending: false)
      .limit(100)
      .realtimeTolerant()
      .map((rows) => rows.map(ClubDiscussion.fromSupabase).toList());

  Stream<ClubDiscussion?> watchDiscussion(String clubId, String discussionId) => _db
      .from('club_discussions')
      .stream(primaryKey: ['id'])
      .eq('id', discussionId)
      .realtimeTolerant()
      .map((rows) => rows.isNotEmpty ? ClubDiscussion.fromSupabase(rows.first) : null);

  Future<Result<String>> createDiscussion(String clubId, ClubDiscussion discussion, {AppUser? user}) async {
    try {
      final clubRes = await getClub(clubId, user: user);
      if (clubRes is Failure<Club>) {
        return Failure(clubRes.message, clubRes.cause);
      }
      final row = await _db.from('club_discussions').insert(discussion.toSupabase()).select('id').single();
      final id = row['id'] as String;
      await XpRepository.instance.awardXp(discussion.authorId, XpSource.clubQuestion, XpSource.clubQuestion.baseXp, refId: id);
      return Success(id);
    } catch (e) {
      return Failure('Failed to post question', e);
    }
  }

  Future<void> incrementDiscussionView(String clubId, String discussionId) async {
    try {
      await _db.rpc('increment_discussion_view', params: {'p_discussion_id': discussionId});
    } catch (_) {
      // best-effort — a missed view count isn't worth surfacing
    }
  }

  Stream<List<ClubDiscussionReply>> watchReplies(String clubId, String discussionId) => _db
      .from('club_discussion_replies')
      .stream(primaryKey: ['id'])
      .eq('discussion_id', discussionId)
      .order('created_at')
      .realtimeTolerant()
      .map((rows) => rows.map(ClubDiscussionReply.fromSupabase).toList());

  Future<Result<void>> addReply(String clubId, String discussionId, ClubDiscussionReply reply) async {
    try {
      await _db.rpc('add_club_discussion_reply', params: {
        'p_discussion_id': discussionId,
        'p_author_name': reply.authorName,
        'p_author_photo_url': reply.authorPhotoUrl,
        'p_author_is_staff': reply.authorIsStaff,
        'p_body': reply.body,
        'p_attached_resource_id': reply.attachedResourceId,
        'p_attached_resource_title': reply.attachedResourceTitle,
        'p_attached_resource_url': reply.attachedResourceUrl,
      });
      await XpRepository.instance.awardXp(reply.authorId, XpSource.clubAnswer, XpSource.clubAnswer.baseXp, refId: discussionId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to post reply', e);
    }
  }

  /// Only the discussion's own author or a club admin/moderator may mark
  /// a best answer (enforced in the RPC too). Awards the replying user a
  /// bonus on top of whatever they already got for posting the reply —
  /// moving the mark to a different reply first un-marks the old one so
  /// exactly one best answer (and one bonus payout) exists per discussion
  /// at a time.
  Future<Result<void>> markBestAnswer({
    required String clubId, required String discussionId,
    required String replyId, required String replyAuthorId,
    String? previousBestAnswerReplyId,
  }) async {
    try {
      await _db.rpc('mark_club_best_answer', params: {
        'p_discussion_id': discussionId,
        'p_reply_id': replyId,
      });
      if (previousBestAnswerReplyId != replyId) {
        await XpRepository.instance.awardXp(replyAuthorId, XpSource.clubBestAnswer, XpSource.clubBestAnswer.baseXp, refId: replyId);
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to mark best answer', e);
    }
  }

  Future<Result<void>> toggleDiscussionLike(String clubId, String discussionId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to like discussions.', null);
    try {
      await _db.rpc('toggle_club_discussion_like', params: {'p_discussion_id': discussionId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  Stream<bool> watchIsDiscussionLiked(String clubId, String discussionId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db
        .from('club_discussion_likes')
        .stream(primaryKey: ['discussion_id', 'user_id'])
        .eq('discussion_id', discussionId)
        .realtimeTolerant()
        .map((rows) => rows.any((r) => r['user_id'] == userId));
  }

  /// Mirrors [toggleDiscussionLike] one level down — likes on an
  /// individual REPLY rather than the question itself.
  Future<Result<void>> toggleReplyLike(
      String clubId, String discussionId, String replyId, String userId) async {
    if (userId.isEmpty) return const Failure('Sign in to like replies.', null);
    try {
      await _db.rpc('toggle_club_discussion_reply_like', params: {'p_reply_id': replyId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update like', e);
    }
  }

  Stream<bool> watchIsReplyLiked(String clubId, String discussionId, String replyId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db
        .from('club_discussion_reply_likes')
        .stream(primaryKey: ['reply_id', 'user_id'])
        .eq('reply_id', replyId)
        .realtimeTolerant()
        .map((rows) => rows.any((r) => r['user_id'] == userId));
  }

  // ── Resources ────────────────────────────────────────────

  Stream<List<ClubResource>> watchResources(String clubId) => _db
      .from('club_resources')
      .stream(primaryKey: ['id'])
      .eq('club_id', clubId)
      .order('created_at', ascending: false)
      .realtimeTolerant()
      .map((rows) => rows.map(ClubResource.fromSupabase).toList());

  Future<Result<void>> addResource(String clubId, ClubResource resource, {AppUser? user}) async {
    try {
      final clubRes = await getClub(clubId, user: user);
      if (clubRes is Failure<Club>) {
        return Failure(clubRes.message, clubRes.cause);
      }
      await _db.from('club_resources').insert(resource.toSupabase());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add resource', e);
    }
  }

  Future<Result<String>> uploadResourceFile({required String clubId, required File file, required String fileName}) async {
    try {
      final path = 'club_resources/$clubId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _db.storage.from(_bucket).upload(path, file).timeout(const Duration(minutes: 3), onTimeout: () => throw Exception(
          'Upload is taking too long. Check your connection and try again.'));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload file', e);
    }
  }

  Future<Result<void>> deleteResource(String clubId, String resourceId) async {
    try {
      await _db.from('club_resources').delete().eq('id', resourceId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete resource', e);
    }
  }

  // ── Events ───────────────────────────────────────────────

  Stream<List<ClubEvent>> watchEvents(String clubId) => _db
      .from('club_events')
      .stream(primaryKey: ['id'])
      .eq('club_id', clubId)
      .order('start_at', ascending: true)
        .realtimeTolerant() // soonest upcoming first
      .map((rows) => rows.map(ClubEvent.fromSupabase).toList());

  Future<Result<void>> addEvent(String clubId, ClubEvent event, {AppUser? user}) async {
    try {
      final clubRes = await getClub(clubId, user: user);
      if (clubRes is Failure<Club>) {
        return Failure(clubRes.message, clubRes.cause);
      }
      await _db.from('club_events').insert(event.toSupabase());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add event', e);
    }
  }

  Future<Result<void>> deleteEvent(String clubId, String eventId) async {
    try {
      await _db.from('club_events').delete().eq('id', eventId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete event', e);
    }
  }

  Future<Result<void>> toggleEventRsvp(String clubId, String eventId, String userId, bool going) async {
    if (userId.isEmpty) return const Failure('Sign in to RSVP.', null);
    try {
      await _db.rpc('toggle_club_event_rsvp', params: {'p_event_id': eventId, 'p_going': going});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update RSVP', e);
    }
  }

  Stream<bool> watchIsGoingToEvent(String clubId, String eventId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db
        .from('club_event_rsvps')
        .stream(primaryKey: ['event_id', 'user_id'])
        .eq('event_id', eventId)
        .realtimeTolerant()
        .map((rows) => rows.any((r) => r['user_id'] == userId));
  }
}

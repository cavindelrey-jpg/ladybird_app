// lib/features/messages/find_people_page.dart
// Friends view: shows My Friends, Recent Conversations and Suggested
// Friends up front — searching used to be the ONLY way to see anyone
// here, which meant existing friends were invisible unless you typed
// their name. Search now filters the already-visible lists, and still
// falls through to a global name search below for finding new people.
//
// Online Friends (from the original spec) is deliberately not built:
// there's no presence/heartbeat system anywhere in this codebase, and
// faking an "online" dot would be exactly the kind of dishonest
// placeholder this project avoids (see chat_conversation_page.dart for
// the same call made there).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/messaging.dart';
import '../../repositories/messaging_repository.dart';
import '../../core/debouncer.dart';
import '../../core/result.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'chat_conversation_page.dart';

class FindPeoplePage extends StatefulWidget {
  final AppUser user;
  const FindPeoplePage({super.key, required this.user});

  @override
  State<FindPeoplePage> createState() => _FindPeoplePageState();
}

class _FindPeoplePageState extends State<FindPeoplePage> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 350);
  String _query = '';
  List<Map<String, dynamic>>? _globalResults;
  bool _globalLoading = false;
  int _searchSeq = 0; // guards against an earlier keystroke's slower response

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    setState(() => _query = query);
    if (query.trim().isEmpty) {
      _debouncer.cancel();
      setState(() { _globalResults = null; _globalLoading = false; });
      return;
    }
    setState(() => _globalLoading = true);
    _debouncer.run(() => _search(query));
  }

  Future<void> _search(String query) async {
    final mySeq = ++_searchSeq;
    final results = await MessagingRepository.instance.searchUsers(query.trim());
    // If newer keystrokes fired more searches while this one was in
    // flight, drop this now-stale response instead of letting it
    // overwrite the correct, more recent results.
    if (!mounted || mySeq != _searchSeq) return;
    setState(() {
      _globalResults = results.where((r) => r['id'] != widget.user.id).toList();
      _globalLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final filter = _query.trim().toLowerCase();
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('New Message', style: AppText.title),
      ),
      body: AppBackground(child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onChanged,
            style: AppText.bodySm.copyWith(color: ac.txt),
            decoration: InputDecoration(
              hintText: 'Search by name…',
              hintStyle: AppText.bodySm.copyWith(color: ac.muted),
              prefixIcon: Icon(Icons.search_rounded, color: ac.muted, size: 20),
              filled: true, fillColor: ac.surf2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _FriendsSection(user: widget.user, filter: filter),
              const SizedBox(height: 20),
              _RecentConversationsSection(user: widget.user, filter: filter),
              const SizedBox(height: 20),
              _SuggestedFriendsSection(user: widget.user, filter: filter),
              if (filter.isNotEmpty) ...[
                const SizedBox(height: 20),
                _globalSearchSection(),
              ],
            ],
          ),
        ),
      ])),
    );
  }

  Widget _globalSearchSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Everyone', style: AppText.h2.copyWith(fontSize: 16)),
      const SizedBox(height: 12),
      if (_globalLoading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LoadingView())
      else if (_globalResults == null || _globalResults!.isEmpty)
        Text('We couldn\'t find anyone with that exact name. Want to try searching for another name?', style: AppText.bodySm)
      else
        ..._globalResults!.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PersonRow(user: widget.user, person: p),
        )),
    ]);
  }
}

class _FriendsSection extends StatelessWidget {
  final AppUser user;
  final String filter;
  const _FriendsSection({required this.user, required this.filter});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('My Friends', style: AppText.h2.copyWith(fontSize: 16)),
      const SizedBox(height: 12),
      StreamBuilder<List<AppUser>>(
        stream: MessagingRepository.instance.watchFriends(user.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Column(children: List.generate(2, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(children: [
                ShimmerCircle(size: 44),
                SizedBox(width: 12),
                Expanded(child: ShimmerLine(height: 14)),
              ]),
            )));
          }
          if (snap.hasError) {
            CrashService.instance.recordError(snap.error, snap.stackTrace,
                context: 'FindPeoplePage._FriendsSection.watchFriends(${user.id})');
            return ErrorView(message: "Couldn't load your friends — ${snap.error}");
          }
          var friends = snap.data ?? const <AppUser>[];
          if (filter.isNotEmpty) {
            friends = friends.where((f) => f.name.toLowerCase().contains(filter)).toList();
          }
          if (friends.isEmpty) {
            return Text(
              filter.isNotEmpty ? 'No friends match "$filter".' : "You haven't added any friends yet.",
              style: AppText.bodySm,
            );
          }
          return Column(children: friends.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ACard(
              onTap: () async {
                final result = await MessagingRepository.instance.getOrCreateConversation(
                  userAId: user.id, userAName: user.name, userAPhoto: user.photoUrl,
                  userBId: f.id, userBName: f.name, userBPhoto: f.photoUrl,
                );
                if (result is Success<String> && context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatConversationPage(
                      conversationId: result.value, currentUser: user,
                      otherUserId: f.id, otherUserName: f.name, otherUserPhoto: f.photoUrl)));
                } else if (context.mounted && result is Failure) {
                  showToast(context, (result as Failure).message, isError: true);
                }
              },
              child: Row(children: [
                UserAvatar(initials: f.name.isEmpty ? '?' : f.name[0].toUpperCase(), radius: 22, photoUrl: f.photoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, style: AppText.title.copyWith(fontSize: 14)),
                    if (f.roleLabel.isNotEmpty)
                      Text(f.roleLabel, style: AppText.bodySm.copyWith(fontSize: 11.5)),
                  ]),
                ),
                Icon(Icons.chat_bubble_outline_rounded, size: 18, color: ac.muted),
              ]),
            ),
          )).toList());
        },
      ),
    ]);
  }
}

class _RecentConversationsSection extends StatelessWidget {
  final AppUser user;
  final String filter;
  const _RecentConversationsSection({required this.user, required this.filter});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Recent Conversations', style: AppText.h2.copyWith(fontSize: 16)),
      const SizedBox(height: 12),
      StreamBuilder<List<Conversation>>(
        stream: MessagingRepository.instance.watchConversations(user.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Column(children: List.generate(2, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(children: [
                ShimmerCircle(size: 44),
                SizedBox(width: 12),
                Expanded(child: ShimmerLine(height: 14)),
              ]),
            )));
          }
          if (snap.hasError) {
            CrashService.instance.recordError(snap.error, snap.stackTrace,
                context: 'FindPeoplePage._RecentConversationsSection.watchConversations(${user.id})');
            return ErrorView(message: "Couldn't load conversations — ${snap.error}");
          }
          var conversations = snap.data ?? const <Conversation>[];
          if (filter.isNotEmpty) {
            conversations = conversations.where((c) {
              final otherName = c.participantNames[c.otherParticipantId(user.id)] ?? '';
              return otherName.toLowerCase().contains(filter);
            }).toList();
          }
          if (conversations.isEmpty) {
            return Text(
              filter.isNotEmpty ? 'No conversations match "$filter".' : 'No conversations yet.',
              style: AppText.bodySm,
            );
          }
          return Column(children: conversations.map((c) {
            final otherId = c.otherParticipantId(user.id);
            final otherName = c.participantNames[otherId] ?? 'Unknown';
            final otherPhoto = c.participantPhotos[otherId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ACard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatConversationPage(
                        conversationId: c.id, currentUser: user,
                        otherUserId: otherId, otherUserName: otherName, otherUserPhoto: otherPhoto))),
                child: Row(children: [
                  UserAvatar(initials: otherName.isEmpty ? '?' : otherName[0].toUpperCase(), radius: 22, photoUrl: otherPhoto),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(otherName, style: AppText.title.copyWith(fontSize: 14)),
                      Text(c.lastMessageSenderId == user.id ? 'You: ${c.lastMessageText}' : c.lastMessageText,
                          style: AppText.bodySm.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
              ),
            );
          }).toList());
        },
      ),
    ]);
  }
}

class _SuggestedFriendsSection extends StatefulWidget {
  final AppUser user;
  final String filter;
  const _SuggestedFriendsSection({required this.user, required this.filter});

  @override
  State<_SuggestedFriendsSection> createState() => _SuggestedFriendsSectionState();
}

class _SuggestedFriendsSectionState extends State<_SuggestedFriendsSection> {
  List<AppUser>? _suggestions;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await MessagingRepository.instance.suggestedFriends(widget.user);
      if (mounted) setState(() => _suggestions = list);
    } catch (e, st) {
      CrashService.instance.recordError(e, st,
          context: 'FindPeoplePage._SuggestedFriendsSection.suggestedFriends(${widget.user.id})');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    // No schoolId means no school-based suggestions to make — an
    // independent-layer user, not an error. Show nothing rather than an
    // empty-state that implies something's broken.
    if (widget.user.schoolId == null || widget.user.schoolId!.isEmpty) {
      return const SizedBox.shrink();
    }
    final filtered = _suggestions == null
        ? null
        : (widget.filter.isEmpty
            ? _suggestions!
            : _suggestions!.where((s) => s.name.toLowerCase().contains(widget.filter)).toList());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Suggested Friends', style: AppText.h2.copyWith(fontSize: 16))),
        IconButton(
          icon: Icon(Icons.refresh_rounded, size: 18, color: ac.muted),
          tooltip: 'Refresh suggestions',
          onPressed: () {
            setState(() { _suggestions = null; _error = null; });
            _load();
          },
        ),
      ]),
      const SizedBox(height: 4),
      if (_error != null)
        ErrorView(message: "Couldn't load suggestions — $_error")
      else if (_suggestions == null)
        Column(children: List.generate(2, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Row(children: [
            ShimmerCircle(size: 44),
            SizedBox(width: 12),
            Expanded(child: ShimmerLine(height: 14)),
          ]),
        )))
      else if (filtered!.isEmpty)
        Text(
          widget.filter.isNotEmpty ? 'No suggestions match "${widget.filter}".' : 'No suggestions right now.',
          style: AppText.bodySm,
        )
      else
        ...filtered.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PersonRow(user: widget.user, person: {
            'id': s.id, 'name': s.name, 'photoUrl': s.photoUrl, 'roleName': s.roleLabel,
          }),
        )),
    ]);
  }
}

class _PersonRow extends StatefulWidget {
  final AppUser user;
  final Map<String, dynamic> person;
  const _PersonRow({required this.user, required this.person});

  @override
  State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  bool _requestSent = false;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final name = widget.person['name'] ?? 'Unknown';
    final photoUrl = widget.person['photo_url'];
    // Students have no role_name; their class tells two same-named
    // students apart.
    final roleLabel = (widget.person['role_name'] as String?)?.isNotEmpty == true
        ? widget.person['role_name']
        : (widget.person['class_level'] ?? '');
    final personId = widget.person['id'] as String;

    return ACard(
      onTap: () async {
        // The server decides (friends, or staff <-> student of the same
        // school) -- a client-side friendship check used to block
        // teachers from messaging their own students.
        final convResult = await MessagingRepository.instance.getOrCreateConversation(
          userAId: widget.user.id, userAName: widget.user.name, userAPhoto: widget.user.photoUrl,
          userBId: personId, userBName: name, userBPhoto: photoUrl,
        );
        if (!context.mounted) return;
        switch (convResult) {
          case Success(:final value):
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatConversationPage(
                conversationId: value, currentUser: widget.user,
                otherUserId: personId, otherUserName: name, otherUserPhoto: photoUrl)));
          case Failure(:final message):
            showToast(context, message);
        }
      },
      child: Row(children: [
        UserAvatar(initials: name.isEmpty ? '?' : name[0].toUpperCase(), radius: 22, photoUrl: photoUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppText.title.copyWith(fontSize: 14)),
            if (roleLabel.toString().isNotEmpty)
              Text(roleLabel.toString(), style: AppText.bodySm.copyWith(fontSize: 11.5)),
          ]),
        ),
        _requestSent
            ? Text('Requested', style: AppText.caption.copyWith(fontSize: 11.5, color: ac.muted))
            : OutlinedButton(
                onPressed: _sending ? null : () async {
                  HapticFeedback.mediumImpact();
                  setState(() => _sending = true);
                  final result = await MessagingRepository.instance.sendFriendRequest(
                    fromUserId: widget.user.id, fromUserName: widget.user.name,
                    fromUserPhotoUrl: widget.user.photoUrl, fromUserRoleLabel: widget.user.roleLabel,
                    toUserId: personId,
                  );
                  if (!mounted) return;
                  setState(() => _sending = false);
                  if (result is Success) {
                    setState(() => _requestSent = true);
                  } else if (context.mounted) {
                    showToast(context, (result as Failure).message, isError: true);
                  }
                },
                child: _sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Add Friend', style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
      ]),
    );
  }
}

// lib/features/messages/find_people_page.dart
// Search anyone by name, send a friend request. Following (from the
// profile they're viewing) is a separate action, not this screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../repositories/messaging_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'chat_conversation_page.dart';

class FindPeoplePage extends StatefulWidget {
  final AppUser user;
  const FindPeoplePage({super.key, required this.user});

  @override
  State<FindPeoplePage> createState() => _FindPeoplePageState();
}

class _FindPeoplePageState extends State<FindPeoplePage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>>? _results;
  bool _loading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _loading = true);
    final results = await MessagingRepository.instance.searchUsers(query);
    if (mounted) setState(() { _results = results.where((r) => r['id'] != widget.user.id).toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Find People', style: AppText.title),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: _search,
            style: AppText.bodySm.copyWith(color: C.txt),
            decoration: InputDecoration(
              hintText: 'Search by name…',
              hintStyle: AppText.bodySm.copyWith(color: C.muted),
              prefixIcon: const Icon(Icons.search_rounded, color: C.muted, size: 20),
              filled: true, fillColor: C.surf2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingView()
              : (_results == null)
                  ? Center(child: Text('Search for someone to connect with.', style: AppText.bodySm))
                  : _results!.isEmpty
                      ? const EmptyState(icon: Icons.search_off_rounded, title: 'No one found', subtitle: 'Try a different name.')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results!.length,
                          itemBuilder: (_, i) => _PersonRow(user: widget.user, person: _results![i]),
                        ),
        ),
      ]),
    );
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
    final name = widget.person['name'] ?? 'Unknown';
    final photoUrl = widget.person['photoUrl'];
    final roleLabel = widget.person['roleName'] ?? '';
    final personId = widget.person['id'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ACard(
        onTap: () async {
          final isFriend = await MessagingRepository.instance.isFriend(widget.user.id, personId);
          if (!context.mounted) return;
          if (isFriend) {
            final convResult = await MessagingRepository.instance.getOrCreateConversation(
              userAId: widget.user.id, userAName: widget.user.name, userAPhoto: widget.user.photoUrl,
              userBId: personId, userBName: name, userBPhoto: photoUrl,
            );
            if (convResult is Success<String> && context.mounted) {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatConversationPage(
                  conversationId: convResult.value, currentUser: widget.user,
                  otherUserId: personId, otherUserName: name, otherUserPhoto: photoUrl)));
            }
          } else {
            showToast(context, 'Send a friend request first to start messaging.');
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
              ? Text('Requested', style: AppText.caption.copyWith(fontSize: 11.5, color: C.muted))
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
      ),
    );
  }
}

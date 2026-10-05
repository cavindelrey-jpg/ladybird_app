// lib/pages/public_profile_page.dart
// Read-only view of someone ELSE's profile -- reached by tapping their
// avatar in search. Distinct from ProfilePage, which is always a
// self-service account page (Settings, Sign Out, Edit Profile) and must
// never be shown for anyone but the signed-in user themselves --
// search_page.dart's People tab used to push ProfilePage(user:
// thatPerson) directly, which meant tapping a search result opened what
// looked like an account-management screen for a STRANGER, complete
// with an "Edit Profile" button that a school-admin viewer's
// has_min_role(department_admin) RLS grant would have actually let them
// save through, and no way to send a friend request at all.
//
// Friend request / Message here reuses the exact same
// MessagingRepository calls _PersonRow (find_people_page.dart) already
// uses -- not a second implementation of that logic.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/result.dart';
import '../models/app_user.dart';
import '../repositories/messaging_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';
import '../widgets/app_background.dart';
import '../features/messages/chat_conversation_page.dart';

class PublicProfilePage extends StatefulWidget {
  final AppUser viewer;
  final AppUser person;
  const PublicProfilePage({super.key, required this.viewer, required this.person});

  /// Convenience for call sites that only have loose (id, name, photoUrl)
  /// data on hand — a club member, a post/reply author, a join request —
  /// rather than a full AppUser. [roleName] overrides the displayed role
  /// label (e.g. a club-specific role like "Group Moderator") since the
  /// viewer's real site-wide role usually isn't available at these call
  /// sites. No-ops when tapping your own row.
  static void open(BuildContext context, {
    required AppUser viewer,
    required String id,
    required String name,
    String? photoUrl,
    String? roleName,
  }) {
    if (id == viewer.id) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PublicProfilePage(
            viewer: viewer,
            person: AppUser(id: id, name: name, photoUrl: photoUrl, roleName: roleName ?? ''))));
  }

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool? _isFriend;
  bool _requestSent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.person.id != widget.viewer.id) _loadFriendStatus();
  }

  Future<void> _loadFriendStatus() async {
    final isFriend = await MessagingRepository.instance.isFriend(widget.viewer.id, widget.person.id);
    if (mounted) setState(() => _isFriend = isFriend);
  }

  Future<void> _sendRequest() async {
    setState(() => _busy = true);
    final result = await MessagingRepository.instance.sendFriendRequest(
      fromUserId: widget.viewer.id, fromUserName: widget.viewer.name,
      fromUserPhotoUrl: widget.viewer.photoUrl, fromUserRoleLabel: widget.viewer.roleLabel,
      toUserId: widget.person.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is Success) {
      setState(() => _requestSent = true);
    } else if (mounted) {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  Future<void> _openChat() async {
    setState(() => _busy = true);
    final result = await MessagingRepository.instance.getOrCreateConversation(
      userAId: widget.viewer.id, userAName: widget.viewer.name, userAPhoto: widget.viewer.photoUrl,
      userBId: widget.person.id, userBName: widget.person.name, userBPhoto: widget.person.photoUrl,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is Success<String>) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatConversationPage(
          conversationId: result.value, currentUser: widget.viewer,
          otherUserId: widget.person.id, otherUserName: widget.person.name, otherUserPhoto: widget.person.photoUrl)));
    } else if (result is Failure && mounted) {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final p = widget.person;
    final isSelf = p.id == widget.viewer.id;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(p.name, style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 12),
          UserAvatar(initials: p.name.isEmpty ? '?' : p.name[0].toUpperCase(), radius: 40, photoUrl: p.photoUrl),
          const SizedBox(height: 12),
          Text(p.name, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 4),
          if (p.roleLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: ac.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
              child: Text(p.roleLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ac.primary)),
            ),
          const SizedBox(height: 14),
          if (p.bio.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(p.bio, textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.5)),
            ),
          const SizedBox(height: 28),
          if (isSelf)
            Text('This is you.', style: GoogleFonts.inter(fontSize: 12.5, color: ac.muted))
          else if (_isFriend == null)
            const CircularProgressIndicator(strokeWidth: 2)
          else if (_isFriend!)
            SizedBox(width: double.infinity, child: PrimaryBtn(label: 'Message', loading: _busy, onTap: _openChat))
          else if (_requestSent)
            Text('Friend request sent.', style: GoogleFonts.inter(fontSize: 13, color: ac.muted))
          else
            SizedBox(width: double.infinity, child: PrimaryBtn(label: 'Add Friend', loading: _busy, onTap: _sendRequest)),
        ]),
      )),
    );
  }
}

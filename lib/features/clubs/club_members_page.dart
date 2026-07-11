// lib/features/clubs/club_members_page.dart
// Member list with the "normal mod structure": admins can set anyone's
// role (member/moderator/admin) or remove them; moderators can manage
// regular members but can't touch other moderators/admins; everyone else
// gets a read-only list with role badges.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../repositories/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ClubMembersPage extends StatelessWidget {
  final Club club;
  final AppUser currentUser;
  const ClubMembersPage({super.key, required this.club, required this.currentUser});

  String _roleLabel(ClubRole r) {
    switch (r) {
      case ClubRole.admin:     return 'Admin';
      case ClubRole.moderator: return 'Moderator';
      case ClubRole.member:    return 'Member';
      case ClubRole.visitor:   return 'Visitor';
    }
  }

  Color _roleColor(ClubRole r) {
    switch (r) {
      case ClubRole.admin:     return C.gold;
      case ClubRole.moderator: return C.blu;
      case ClubRole.member:    return C.txt2;
      case ClubRole.visitor:   return C.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('${club.name} · Members', style: GoogleFonts.sora(
            fontSize: 15, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: StreamBuilder<ClubRole>(
        stream: ClubRepository.instance.watchUserRole(club.id, currentUser.id),
        builder: (context, myRoleSnap) {
          final myRole = myRoleSnap.data ?? ClubRole.visitor;
          final canApprove = myRole == ClubRole.admin || myRole == ClubRole.moderator;
          return StreamBuilder<List<ClubMember>>(
            stream: ClubRepository.instance.watchMembers(club.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              final members = List<ClubMember>.from(snap.data ?? const <ClubMember>[]);
              members.sort((a, b) {
                const order = {ClubRole.admin: 0, ClubRole.moderator: 1, ClubRole.member: 2, ClubRole.visitor: 3};
                final byRole = order[a.role]!.compareTo(order[b.role]!);
                return byRole != 0 ? byRole : a.joinedAt.compareTo(b.joinedAt);
              });
              final adminCount = members.where((m) => m.role == ClubRole.admin).length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (canApprove) _PendingRequestsSection(club: club),
                  for (int i = 0; i < members.length; i++)
                    _memberTile(context, members[i], myRole, adminCount, members),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _memberTile(BuildContext context, ClubMember m, ClubRole myRole, int adminCount, List<ClubMember> members) {
                  final isSelf = m.userId == currentUser.id;
                  final canManage = _canManage(myRole, m.role);
                  final isOnlyAdmin = m.role == ClubRole.admin && adminCount <= 1;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ACard(
                      child: Row(children: [
                        UserAvatar(
                          initials: m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                          radius: 18, photoUrl: m.photoUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(
                                child: Text(m.name + (isSelf ? ' (you)' : ''), style: GoogleFonts.inter(
                                    fontSize: 13.5, fontWeight: FontWeight.w700, color: C.txt),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            StatusBadge(label: _roleLabel(m.role).toUpperCase(), color: _roleColor(m.role)),
                          ]),
                        ),
                        if (canManage && !isSelf)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: C.muted),
                            onSelected: (choice) => _handleAction(context, m, choice),
                            itemBuilder: (context) => [
                              if (m.role != ClubRole.member)
                                const PopupMenuItem(value: 'set_member', child: Text('Set as Member')),
                              if (m.role != ClubRole.moderator)
                                const PopupMenuItem(value: 'set_moderator', child: Text('Set as Moderator')),
                              if (myRole == ClubRole.admin && m.role != ClubRole.admin)
                                const PopupMenuItem(value: 'set_admin', child: Text('Set as Admin')),
                              if (!isOnlyAdmin)
                                const PopupMenuItem(value: 'remove', child: Text('Remove from Club',
                                    style: TextStyle(color: C.red))),
                            ],
                          )
                        else if (isOnlyAdmin && !isSelf)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Tooltip(message: "Club needs at least one admin",
                                child: Icon(Icons.shield_outlined, size: 16, color: C.muted)),
                          ),
                      ]),
                    ),
                  );
  }

  /// Admins can manage anyone. Moderators can only manage regular members
  /// — they can't touch other moderators or admins.
  bool _canManage(ClubRole myRole, ClubRole targetRole) {
    if (myRole == ClubRole.admin) return true;
    if (myRole == ClubRole.moderator) return targetRole == ClubRole.member;
    return false;
  }

  Future<void> _handleAction(BuildContext context, ClubMember member, String action) async {
    final repo = ClubRepository.instance;
    switch (action) {
      case 'set_member':
        await repo.updateMemberRole(club.id, member.userId, ClubRole.member);
        break;
      case 'set_moderator':
        await repo.updateMemberRole(club.id, member.userId, ClubRole.moderator);
        break;
      case 'set_admin':
        await repo.updateMemberRole(club.id, member.userId, ClubRole.admin);
        break;
      case 'remove':
        await repo.removeMember(club.id, member.userId);
        break;
    }
    if (context.mounted) {
      showToast(context, action == 'remove' ? '${member.name} removed.' : 'Role updated.');
    }
  }
}

/// Pending join requests, shown only to admins/moderators, above the
/// member list. Only relevant for clubs with requiresApproval — an open
/// club will simply never have any requests to show here.
class _PendingRequestsSection extends StatelessWidget {
  final Club club;
  const _PendingRequestsSection({required this.club});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClubJoinRequest>>(
      stream: ClubRepository.instance.watchPendingRequests(club.id),
      builder: (context, snap) {
        final requests = snap.data ?? const <ClubJoinRequest>[];
        if (requests.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Join Requests', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: C.txt)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: C.orgb, borderRadius: BorderRadius.circular(20)),
                child: Text('${requests.length}', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: C.org)),
              ),
            ]),
            const SizedBox(height: 10),
            ...requests.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ACard(child: Row(children: [
                UserAvatar(initials: r.userName.isEmpty ? '?' : r.userName[0].toUpperCase(),
                    radius: 18, photoUrl: r.userPhotoUrl),
                const SizedBox(width: 10),
                Expanded(child: Text(r.userName, style: GoogleFonts.inter(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: C.txt))),
                TextButton(
                  onPressed: () => ClubRepository.instance.declineJoinRequest(r.id),
                  child: const Text('Decline', style: TextStyle(color: C.muted)),
                ),
                ElevatedButton(
                  onPressed: () => ClubRepository.instance.approveJoinRequest(r),
                  style: ElevatedButton.styleFrom(backgroundColor: C.navy, foregroundColor: Colors.white),
                  child: const Text('Approve'),
                ),
              ])),
            )),
            const Divider(color: C.bdr2, height: 24),
          ]),
        );
      },
    );
  }
}

// lib/features/clubs/club_members_page.dart
// Member list with the "normal mod structure": admins can set anyone's
// role (member/moderator/admin) or remove them; moderators can manage
// regular members but can't touch other moderators/admins; everyone else
// gets a read-only list with role badges.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../repositories/club_repository.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../core/club_scope.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class ClubMembersPage extends StatelessWidget {
  final Club club;
  final AppUser currentUser;
  const ClubMembersPage({super.key, required this.club, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (!ClubScope.canAccessClub(club, user: currentUser)) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: const Center(child: Text('Access restricted to members of this institution.')),
      );
    }
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('${club.name} · Members', style: GoogleFonts.sora(
            fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(child: ClubMembersBody(club: club, currentUser: currentUser)),
    );
  }
}

/// The member list + mod-management logic, without the Scaffold/AppBar —
/// shared by [ClubMembersPage] (full page, reached via the club header's
/// icon) and the club detail's own MEMBERS tab (same content, no second
/// app bar needed since the tab bar already provides navigation chrome).
class ClubMembersBody extends StatelessWidget {
  final Club club;
  final AppUser currentUser;
  const ClubMembersBody({super.key, required this.club, required this.currentUser});

  String _roleLabel(ClubRole r) {
    switch (r) {
      case ClubRole.admin:     return 'Admin';
      case ClubRole.moderator: return 'Moderator';
      case ClubRole.member:    return 'Member';
      case ClubRole.visitor:   return 'Visitor';
    }
  }

  Color _roleColor(ClubRole r, AppColors ac) {
    switch (r) {
      case ClubRole.admin:     return ac.gold;
      case ClubRole.moderator: return ac.blu;
      case ClubRole.member:    return ac.txt2;
      case ClubRole.visitor:   return ac.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ClubScope.canAccessClub(club, user: currentUser)) {
      return const Center(child: Text('Access restricted to members of this institution.'));
    }
    return StreamBuilder<ClubRole>(
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
    );
  }

  Widget _memberTile(BuildContext context, ClubMember m, ClubRole myRole, int adminCount, List<ClubMember> members) {
                  final ac = AppColors.of(context);
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
                                    fontSize: 13.5, fontWeight: FontWeight.w700, color: ac.txt),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            StatusBadge(label: _roleLabel(m.role).toUpperCase(), color: _roleColor(m.role, ac)),
                          ]),
                        ),
                        if (canManage && !isSelf)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: ac.muted),
                            onSelected: (choice) => _handleAction(context, m, choice),
                            itemBuilder: (context) => [
                              if (m.role != ClubRole.member)
                                const PopupMenuItem(value: 'set_member', child: Text('Set as Member')),
                              if (m.role != ClubRole.moderator)
                                const PopupMenuItem(value: 'set_moderator', child: Text('Set as Moderator')),
                              if (myRole == ClubRole.admin && m.role != ClubRole.admin)
                                const PopupMenuItem(value: 'set_admin', child: Text('Set as Admin')),
                              if (!isOnlyAdmin)
                                PopupMenuItem(value: 'remove', child: Text('Remove from Group',
                                    style: TextStyle(color: ac.red))),
                            ],
                          )
                        else if (isOnlyAdmin && !isSelf)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Tooltip(message: 'Group needs at least one admin',
                                child: Icon(Icons.shield_outlined, size: 16, color: ac.muted)),
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
        final ac = AppColors.of(context);
        if (snap.hasError) {
          CrashService.instance.recordError(snap.error, snap.stackTrace,
              context: 'ClubMembersPage.watchPendingRequests(${club.id})');
          return ErrorView(message: "Couldn't load join requests — ${snap.error}");
        }
        final requests = snap.data ?? const <ClubJoinRequest>[];
        if (requests.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Join Requests', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: ac.txt)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ac.orgBg, borderRadius: BorderRadius.circular(20)),
                child: Text('${requests.length}', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: ac.org)),
              ),
            ]),
            const SizedBox(height: 10),
            ...requests.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _JoinRequestRow(request: r),
            )),
            Divider(color: ac.bdr2, height: 24),
          ]),
        );
      },
    );
  }
}

/// One join-request row — its own StatefulWidget so Approve/Decline can
/// show a per-row busy state and, critically, actually surface a
/// failure. Both actions used to be fire-and-forget (no await, no error
/// handling): if approve_club_join_request() rejected the caller (e.g.
/// a promoted admin who wasn't the club's original moderator_id), NOTHING
/// visibly happened, which read as "there's no way to accept."
class _JoinRequestRow extends StatefulWidget {
  final ClubJoinRequest request;
  const _JoinRequestRow({required this.request});

  @override
  State<_JoinRequestRow> createState() => _JoinRequestRowState();
}

class _JoinRequestRowState extends State<_JoinRequestRow> {
  bool _busy = false;

  Future<void> _decide(Future<Result<void>> Function() action) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is Failure<void>) {
      showToast(context, result.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final r = widget.request;
    return ACard(child: Row(children: [
      UserAvatar(initials: r.userName.isEmpty ? '?' : r.userName[0].toUpperCase(),
          radius: 18, photoUrl: r.userPhotoUrl),
      const SizedBox(width: 10),
      Expanded(child: Text(r.userName, style: GoogleFonts.inter(
          fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt))),
      if (_busy)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else ...[
        TextButton(
          onPressed: () => _decide(() => ClubRepository.instance.declineJoinRequest(r.id)),
          child: Text('Decline', style: TextStyle(color: ac.muted)),
        ),
        ElevatedButton(
          onPressed: () => _decide(() => ClubRepository.instance.approveJoinRequest(r)),
          style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white),
          child: const Text('Approve'),
        ),
      ],
    ]));
  }
}

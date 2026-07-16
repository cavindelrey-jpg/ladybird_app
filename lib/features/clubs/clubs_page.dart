// Repository-driven. Zero static club list.
// Design pass matching the reference layout: header (bell + avatar),
// search + filter row, My Clubs (with Joined/Pending status), Discover
// Clubs (with Approval required/Open to all badges), and cross-promo
// info cards. Backed by a real approval workflow — Club.requiresApproval
// + ClubJoinRequest — that didn't exist before this pass; previously
// every club was instant-join regardless of what the UI implied.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/club_repository.dart';
import '../../core/result.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../pages/notifications_page.dart';
import '../messages/messages_home_page.dart';
import 'create_club_page.dart';
import 'club_members_page.dart';

class ClubsPage extends StatefulWidget {
  final AppUser user;
  const ClubsPage({super.key, required this.user});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  String _searchQuery = '';

  bool get _canCreate => !widget.user.isGuest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: StreamBuilder<List<Club>>(
          stream: ClubRepository.instance.watchClubs(schoolId: widget.user.schoolId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _ClubsSkeleton();
            }
            if (snap.hasError) {
              return ErrorView(message: snap.error.toString());
            }
            final allClubs = snap.data ?? const <Club>[];
            final filtered = _searchQuery.isEmpty
                ? allClubs
                : allClubs.where((c) =>
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    c.category.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _header(context),
                const SizedBox(height: 10),
                _searchAndFilter(),
                const SizedBox(height: 20),
                _myClubsSection(context, filtered),
                const SizedBox(height: 24),
                _discoverClubsSection(context, filtered),
                const SizedBox(height: 20),
                _infoCards(context),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              backgroundColor: C.navy,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => CreateClubPage(user: widget.user)));
              },
              icon: const Icon(Icons.add_rounded, color: C.gold),
              label: Text('Create Club', style: AppText.button.copyWith(fontSize: 13)),
            )
          : null,
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clubs', style: AppText.h1.copyWith(fontSize: 22)),
            Text('Find your people. Share ideas. Grow together.', style: AppText.caption.copyWith(fontSize: 12)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: C.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: widget.user.id))),
        ),
        UserAvatar(initials: widget.user.name.isEmpty ? '?' : widget.user.name[0].toUpperCase(),
            radius: 18, photoUrl: widget.user.photoUrl),
      ]),
    );
  }

  Widget _searchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: AppText.bodySm.copyWith(color: C.txt),
              decoration: InputDecoration(
                hintText: 'Search clubs by name, interest or subject…',
                hintStyle: AppText.bodySm.copyWith(color: C.muted, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: C.muted),
                border: InputBorder.none, isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
          child: Row(children: [
            const Icon(Icons.filter_list_rounded, size: 18, color: C.txt2),
            const SizedBox(width: 6),
            Text('Filter', style: AppText.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _myClubsSection(BuildContext context, List<Club> allClubs) {
    if (widget.user.isGuest) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('My Clubs', style: AppText.h2.copyWith(fontSize: 16))),
          Text('View all', style: AppText.subtitle.copyWith(color: C.primary, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        if (allClubs.isEmpty)
          Text('No clubs yet — discover one below or create your own.', style: AppText.bodySm)
        else
          Container(
            decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
            child: Column(children: [
              for (int i = 0; i < allClubs.length; i++)
                _MyClubTile(
                  club: allClubs[i], user: widget.user,
                  showDivider: i < allClubs.length - 1,
                  onOpen: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ClubDetailPage(club: allClubs[i], user: widget.user))),
                ),
            ]),
          ),
      ]),
    );
  }

  Widget _discoverClubsSection(BuildContext context, List<Club> allClubs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Discover Clubs', style: AppText.h2.copyWith(fontSize: 16))),
          Text('See all', style: AppText.subtitle.copyWith(color: C.primary, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        if (allClubs.isEmpty)
          Text('No clubs on Academia yet — be the first to create one.', style: AppText.bodySm)
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allClubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _DiscoverClubCard(
                club: allClubs[i], user: widget.user,
                onOpen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubDetailPage(club: allClubs[i], user: widget.user))),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _infoCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.groups_rounded, color: C.blu, size: 20),
              const SizedBox(height: 8),
              Text('Clubs', style: AppText.title.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Shared spaces around common interests. Join open clubs or request to join those that require approval.',
                  style: AppText.caption.copyWith(fontSize: 10.5, height: 1.35)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.chat_bubble_rounded, color: C.pur, size: 20),
              const SizedBox(height: 8),
              Text('Messages', style: AppText.title.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text('One-to-one connections. Follow anyone or send a friend request to start a conversation.',
                  style: AppText.caption.copyWith(fontSize: 10.5, height: 1.35)),
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (widget.user.isGuest) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesHomePage(user: widget.user)));
                  },
                  child: Text('Go to Messages →', style: AppText.caption.copyWith(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: C.pur)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ClubsSkeleton extends StatelessWidget {
  const _ClubsSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const ShimmerLine(width: 100, height: 24),
        const SizedBox(height: 20),
        for (int i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(children: [
              ShimmerCircle(size: 44),
              SizedBox(width: 12),
              Expanded(child: ShimmerLine(height: 14)),
            ]),
          ),
      ],
    );
  }
}

/// A row in "My Clubs" — only rendered if the current user is actually a
/// member or has a pending join request; resolves its own status live so
/// the list updates the moment a request is approved.
class _MyClubTile extends StatelessWidget {
  final Club club;
  final AppUser user;
  final bool showDivider;
  final VoidCallback onOpen;
  const _MyClubTile({required this.club, required this.user, required this.showDivider, required this.onOpen});

  static const _palette = [C.gold, C.blu, C.grn, C.pur, C.org];
  Color get _accent => _palette[club.name.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(club.id, user.id),
      builder: (context, roleSnap) {
        final role = roleSnap.data ?? ClubRole.visitor;
        if (role != ClubRole.visitor) {
          return _tile(context, statusLabel: 'Joined', statusColor: C.grn, statusBg: C.grnb);
        }
        return StreamBuilder<ClubJoinRequestStatus?>(
          stream: ClubRepository.instance.watchMyRequestStatus(club.id, user.id),
          builder: (context, reqSnap) {
            if (reqSnap.hasError) {
              // Embedded status badge inside a fixed-height tile row — an
              // ErrorView here would break the row's layout, so this just
              // records the failure and falls back to "no badge" (same as
              // the loading/absent state) rather than a silent empty look
              // masking a real query failure.
              CrashService.instance.recordError(reqSnap.error, reqSnap.stackTrace,
                  context: 'ClubsPage.watchMyRequestStatus(${club.id}, ${user.id})');
              return const SizedBox.shrink();
            }
            if (reqSnap.data != ClubJoinRequestStatus.pending) return const SizedBox.shrink();
            return _tile(context, statusLabel: 'Pending', statusColor: C.org, statusBg: C.orgb, disabled: true);
          },
        );
      },
    );
  }

  Widget _tile(BuildContext context, {required String statusLabel, required Color statusColor, required Color statusBg, bool disabled = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : () { HapticFeedback.selectionClick(); onOpen(); },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: showDivider ? const BoxDecoration(border: Border(bottom: BorderSide(color: C.bdr2))) : null,
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(club.emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(club.name, style: AppText.title.copyWith(fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(statusLabel, style: AppText.label.copyWith(fontSize: 9.5, color: statusColor, letterSpacing: 0)),
                  ),
                ]),
                Text(club.description, style: AppText.bodySm.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  const Icon(Icons.people_alt_outlined, size: 12, color: C.muted),
                  const SizedBox(width: 3),
                  Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10.5)),
                ]),
              ]),
            ),
            if (!disabled) const Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      ),
    );
  }
}

/// Discover card — join instantly if open, or request-to-join if the
/// club requires approval. Hides itself once the user is already a
/// member or has a pending request (those show up in My Clubs instead).
class _DiscoverClubCard extends StatelessWidget {
  final Club club;
  final AppUser user;
  final VoidCallback onOpen;
  const _DiscoverClubCard({required this.club, required this.user, required this.onOpen});

  static const _palette = [C.pur, C.org, C.grn, C.blu, C.gold];
  Color get _accent => _palette[club.name.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    if (user.isGuest) return _card(context, joined: false, pending: false);
    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(club.id, user.id),
      builder: (context, roleSnap) {
        final isMember = (roleSnap.data ?? ClubRole.visitor) != ClubRole.visitor;
        if (isMember) return const SizedBox.shrink();
        return StreamBuilder<ClubJoinRequestStatus?>(
          stream: ClubRepository.instance.watchMyRequestStatus(club.id, user.id),
          builder: (context, reqSnap) {
            if (reqSnap.hasError) {
              // Same reasoning as _MyClubTile above: this only gates
              // whether the join card still shows, so record the failure
              // and fall back to showing the card rather than an ErrorView
              // wedged into a horizontally-scrolling card list.
              CrashService.instance.recordError(reqSnap.error, reqSnap.stackTrace,
                  context: 'ClubsPage.watchMyRequestStatus(${club.id}, ${user.id})');
              return _card(context, joined: false, pending: false);
            }
            final pending = reqSnap.data == ClubJoinRequestStatus.pending;
            if (pending) return const SizedBox.shrink();
            return _card(context, joined: false, pending: false);
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, {required bool joined, required bool pending}) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: _accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
          child: Center(child: Text(club.emoji, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(height: 10),
        Text(club.name, style: AppText.title.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          Icon(club.requiresApproval ? Icons.lock_outline_rounded : Icons.public_rounded,
              size: 12, color: club.requiresApproval ? C.pur : C.grn),
          const SizedBox(width: 4),
          Text(club.requiresApproval ? 'Approval required' : 'Open to all',
              style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: club.requiresApproval ? C.pur : C.grn)),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: Text(club.description, style: AppText.caption.copyWith(fontSize: 10.5, height: 1.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        Row(children: [
          const Icon(Icons.people_alt_outlined, size: 12, color: C.muted),
          const SizedBox(width: 3),
          Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10.5)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _handleJoin(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.navy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(club.requiresApproval ? 'Request to Join' : 'Join Club',
                style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Future<void> _handleJoin(BuildContext context) async {
    if (user.isGuest) {
      showToast(context, 'Create an account to join clubs');
      return;
    }
    HapticFeedback.mediumImpact();
    if (club.requiresApproval) {
      final result = await ClubRepository.instance.requestToJoin(
        clubId: club.id, clubName: club.name,
        userId: user.id, userName: user.name, userPhotoUrl: user.photoUrl,
      );
      if (context.mounted) {
        showToast(context, result is Success ? 'Request sent — pending admin approval.' : (result as Failure).message);
      }
    } else {
      final result = await ClubRepository.instance.joinClub(
        club.id, user.id, name: user.name, photoUrl: user.photoUrl,
      );
      if (context.mounted) {
        showToast(context, result is Success ? '✅ Welcome to ${club.name}!' : 'Failed to join');
      }
    }
  }
}

// ── Club Detail Page ──────────────────────────────────────
class ClubDetailPage extends StatefulWidget {
  final Club club;
  final AppUser user;
  const ClubDetailPage({super.key, required this.club, required this.user});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final msg = ClubMessage(
      id: '',
      senderId: widget.user.id,
      senderName: widget.user.name,
      senderInitials: widget.user.initials,
      text: text,
      time: DateTime.now(),
    );
    _ctrl.clear();
    await ClubRepository.instance.sendMessage(widget.club.id, msg);
    await Future.delayed(const Duration(milliseconds: 80));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(widget.club.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.club.name,
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${widget.club.memberCount} members',
                style: const TextStyle(fontSize: 11, color: C.muted)),
          ]),
        ]),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'CHAT'), Tab(text: 'ANNOUNCEMENTS')]),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Members',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ClubMembersPage(club: widget.club, currentUser: widget.user))),
          ),
        ],
      ),
      body: TabBarView(controller: _tabs, children: [
        _ChatTab(club: widget.club, user: widget.user,
            scroll: _scroll, ctrl: _ctrl, onSend: _send),
        const _AnnTab(),
      ]),
    );
  }
}

class _ChatTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  final ScrollController scroll;
  final TextEditingController ctrl;
  final VoidCallback onSend;
  const _ChatTab({required this.club, required this.user,
    required this.scroll, required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: StreamBuilder<List<ClubMessage>>(
          stream: ClubRepository.instance.watchMessages(club.id),
          builder: (context, snap) {
            final messagesList = snap.data ?? [];
            return ListView.builder(
              controller: scroll, padding: const EdgeInsets.all(16),
              itemCount: messagesList.length,
              itemBuilder: (_, i) {
                final m = messagesList[i];
                final isMe = m.senderId == user.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe)
                        Container(
                            width: 28, height: 28,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                                color: C.goldp, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text(m.senderInitials,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700, color: C.gold)))),
                      Flexible(child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(padding: const EdgeInsets.only(left: 2, bottom: 2),
                                child: Text(m.senderName,
                                    style: const TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w600, color: C.muted))),
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * .65),
                              decoration: BoxDecoration(
                                color: isMe ? C.primary : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: isMe ? null : Border.all(color: C.bdr),
                              ),
                              child: Text(m.text,
                                  style: TextStyle(
                                      fontSize: 13, color: isMe ? Colors.white : C.txt))),
                          Padding(padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                  '${m.time.hour.toString().padLeft(2, '0')}:'
                                      '${m.time.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 9, color: C.muted))),
                        ],
                      )),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
        decoration: const BoxDecoration(
            color: C.surf, border: Border(top: BorderSide(color: C.bdr))),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: ctrl,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                      hintText: 'Message ${club.name}…',
                      filled: true, fillColor: C.bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: C.bdr)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: C.bdr)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10)))),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                onSend();
              },
              child: Container(
                  width: 42, height: 42,
                  decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 18)),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _AnnTab extends StatelessWidget {
  const _AnnTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.campaign_outlined, size: 48, color: C.muted),
        const SizedBox(height: 12),
        Text('No club announcements yet',
            style: GoogleFonts.inter(color: C.muted)),
      ]),
    );
  }
}
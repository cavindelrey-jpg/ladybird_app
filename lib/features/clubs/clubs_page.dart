// Repository-driven. Zero static club list.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/club_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'create_club_page.dart';
import 'club_members_page.dart';

class ClubsPage extends StatelessWidget {
  final AppUser user;
  const ClubsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.navy,
        onPressed: () {
          if (user.isGuest) {
            showToast(context, 'Create an account to start a club');
            return;
          }
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => CreateClubPage(user: user)));
        },
        icon: const Icon(Icons.add_rounded, color: C.gold),
        label: Text('Create Club', style: GoogleFonts.sora(
            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: StreamBuilder<List<Club>>(
        stream: ClubRepository.instance.watchClubs(schoolId: user.schoolId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final clubs = snap.data ?? [];
          if (clubs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.groups_outlined, size: 48, color: C.muted),
                const SizedBox(height: 12),
                Text('No clubs yet',
                    style: GoogleFonts.inter(color: C.muted, fontSize: 15)),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: clubs.length,
            itemBuilder: (_, i) => _ClubTile(club: clubs[i], user: user),
          );
        },
      ),
    );
  }
}

class _ClubTile extends StatelessWidget {
  final Club club;
  final AppUser user;
  const _ClubTile({required this.club, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(club.id, user.id),
      builder: (context, snap) {
        final role = snap.data ?? ClubRole.visitor;
        final isMember = role != ClubRole.visitor;

        return GestureDetector(
          onTap: isMember
              ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ClubDetailPage(club: club, user: user)))
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isMember ? C.navy.withValues(alpha: 0.03) : C.surf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isMember ? C.navy.withValues(alpha: 0.2) : C.bdr),
            ),
            child: Row(children: [
              Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                      color: isMember ? C.goldp : C.surf2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isMember ? C.gold.withValues(alpha: 0.3) : C.bdr)),
                  child: Center(
                      child: Text(club.emoji,
                          style: const TextStyle(fontSize: 24)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(club.name, style: GoogleFonts.sora(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: isMember ? C.navy : C.txt)),
                  if (isMember) ...[
                    const SizedBox(width: 6),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: C.grnb, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Member', style: TextStyle(
                            fontSize: 9, color: C.grn, fontWeight: FontWeight.w700))),
                  ],
                ]),
                Text(club.description,
                    style: const TextStyle(fontSize: 11, color: C.muted)),
                Text('${club.memberCount} members · ${club.moderatorName}',
                    style: const TextStyle(fontSize: 10, color: C.muted)),
              ])),
              isMember
                  ? const Icon(Icons.chevron_right, color: C.muted)
                  : ElevatedButton(
                onPressed: () => _join(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('Join'),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _join(BuildContext context) async {
    if (user.isGuest) {
      showToast(context, 'Create an account to join clubs');
      return;
    }
    final result = await ClubRepository.instance.joinClub(
      club.id, user.id, name: user.name, photoUrl: user.photoUrl,
    );
    if (context.mounted) {
      if (result is Success) {
        showToast(context, '✅ Welcome to ${club.name}!');
      } else {
        showToast(context, 'Failed to join');
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
          GestureDetector(
              onTap: onSend,
              child: Container(
                  width: 42, height: 42,
                  decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 18))),
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
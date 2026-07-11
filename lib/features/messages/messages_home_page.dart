// lib/features/messages/messages_home_page.dart
// Matches the reference layout: Following/Friends summary cards, Friend
// Requests with Accept/Decline, Recent Conversations, a short explainer,
// and a New Message entry point. Following (one-way) and Friends
// (mutual, unlocks messaging) are deliberately shown as two separate
// systems here, not merged.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/messaging.dart';
import '../../repositories/messaging_repository.dart';
import '../../repositories/follow_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../pages/notifications_page.dart';
import 'chat_conversation_page.dart';
import 'find_people_page.dart';

class MessagesHomePage extends StatelessWidget {
  final AppUser user;
  const MessagesHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _header(context),
            const SizedBox(height: 10),
            _searchBar(context),
            const SizedBox(height: 16),
            _followFriendCards(context),
            const SizedBox(height: 20),
            _friendRequestsSection(context),
            const SizedBox(height: 20),
            _recentConversationsSection(context),
            const SizedBox(height: 24),
            _howItWorksSection(),
            const SizedBox(height: 20),
            _newMessageButton(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Messages', style: AppText.h1.copyWith(fontSize: 22)),
            Text('Connect one-to-one. Start conversations.', style: AppText.caption.copyWith(fontSize: 12)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: C.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: user.id))),
        ),
        UserAvatar(initials: user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
            radius: 18, photoUrl: user.photoUrl),
      ]),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 18, color: C.muted),
              const SizedBox(width: 8),
              Text('Search people by name, course, or school…', style: AppText.bodySm.copyWith(color: C.muted)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: C.navy,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => FindPeoplePage(user: user)));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                const Icon(Icons.person_add_alt_1_rounded, size: 16, color: C.gold),
                const SizedBox(width: 6),
                Text('Find People', style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _followFriendCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: FollowRepository.instance.watchFollowingCount(user.id),
            builder: (context, snap) => _SummaryCard(
              icon: Icons.record_voice_over_rounded, color: C.blu, bg: C.blub,
              title: 'Following', count: snap.data ?? 0,
              subtitle: 'People whose posts you follow. No approval needed.',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<int>(
            stream: MessagingRepository.instance.watchFriendCount(user.id),
            builder: (context, snap) => _SummaryCard(
              icon: Icons.people_alt_rounded, color: C.grn, bg: C.grnb,
              title: 'Friends', count: snap.data ?? 0,
              subtitle: 'People you can message. Mutual connection.',
            ),
          ),
        ),
      ]),
    );
  }

  Widget _friendRequestsSection(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: MessagingRepository.instance.watchIncomingRequests(user.id),
      builder: (context, snap) {
        final requests = snap.data ?? const <FriendRequest>[];
        if (requests.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Friend Requests', style: AppText.h2.copyWith(fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(20)),
                child: Text('${requests.length}', style: AppText.label.copyWith(fontSize: 11, color: C.red, letterSpacing: 0)),
              ),
            ]),
            const SizedBox(height: 12),
            ...requests.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  UserAvatar(initials: r.fromUserName.isEmpty ? '?' : r.fromUserName[0].toUpperCase(),
                      radius: 22, photoUrl: r.fromUserPhotoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.fromUserName, style: AppText.title.copyWith(fontSize: 14)),
                      if (r.fromUserRoleLabel.isNotEmpty)
                        Text(r.fromUserRoleLabel, style: AppText.bodySm.copyWith(fontSize: 11.5)),
                      Text('Wants to connect with you', style: AppText.caption.copyWith(fontSize: 11)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        MessagingRepository.instance.declineRequest(r.id);
                      },
                      child: Text('Decline', style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        MessagingRepository.instance.acceptRequest(r, user.name, user.photoUrl);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: C.navy, foregroundColor: Colors.white),
                      child: Text('Accept', style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ]),
              ])),
            )),
          ]),
        );
      },
    );
  }

  Widget _recentConversationsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Conversations', style: AppText.h2.copyWith(fontSize: 16)),
        const SizedBox(height: 12),
        StreamBuilder<List<Conversation>>(
          stream: MessagingRepository.instance.watchConversations(user.id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Column(children: List.generate(3, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: const [
                  ShimmerCircle(size: 44),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerLine(height: 14)),
                ]),
              )));
            }
            if (snap.hasError) {
              return Text('Failed to load: ${snap.error}', style: AppText.caption.copyWith(color: C.red, fontSize: 11));
            }
            final conversations = snap.data ?? const <Conversation>[];
            if (conversations.isEmpty) {
              return Text('No conversations yet — find someone and send a friend request.', style: AppText.bodySm);
            }
            return Column(children: conversations.map((c) {
              final otherId = c.otherParticipantId(user.id);
              final otherName = c.participantNames[otherId] ?? 'Unknown';
              final otherPhoto = c.participantPhotos[otherId];
              final unread = c.unreadCount[user.id] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ACard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatConversationPage(
                          conversationId: c.id, currentUser: user,
                          otherUserId: otherId, otherUserName: otherName, otherUserPhoto: otherPhoto))),
                  child: Row(children: [
                    UserAvatar(initials: otherName.isEmpty ? '?' : otherName[0].toUpperCase(),
                        radius: 22, photoUrl: otherPhoto),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(otherName, style: AppText.title.copyWith(fontSize: 14)),
                        Text(c.lastMessageSenderId == user.id ? 'You: ${c.lastMessageText}' : c.lastMessageText,
                            style: AppText.bodySm.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    if (unread > 0)
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('$unread', style: AppText.label.copyWith(fontSize: 11, color: Colors.white, letterSpacing: 0)),
                      ),
                  ]),
                ),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  Widget _howItWorksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How Messaging Works', style: AppText.h2.copyWith(fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _HowStep(icon: Icons.person_add_alt_1_rounded, step: '1. Send Request',
              text: 'Search for anyone and send a friend request.', color: C.blu, bg: C.blub)),
          const SizedBox(width: 8),
          Expanded(child: _HowStep(icon: Icons.people_alt_rounded, step: '2. They Accept',
              text: 'Only when they accept can you start chatting.', color: C.pur, bg: C.purb)),
          const SizedBox(width: 8),
          Expanded(child: _HowStep(icon: Icons.chat_bubble_rounded, step: '3. Start Conversation',
              text: "Message freely once you're connected.", color: C.grn, bg: C.grnb)),
        ]),
      ]),
    );
  }

  Widget _newMessageButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => FindPeoplePage(user: user)));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: C.navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: Text('New Message', style: AppText.button.copyWith(fontSize: 14)),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String title, subtitle;
  final int count;
  const _SummaryCard({required this.icon, required this.color, required this.bg,
      required this.title, required this.subtitle, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(title, style: AppText.title.copyWith(fontSize: 14)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text('$count', style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(subtitle, style: AppText.caption.copyWith(fontSize: 10.5, height: 1.3)),
      ]),
    );
  }
}

class _HowStep extends StatelessWidget {
  final IconData icon;
  final String step, text;
  final Color color, bg;
  const _HowStep({required this.icon, required this.step, required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(step, style: AppText.title.copyWith(fontSize: 11.5)),
        const SizedBox(height: 4),
        Text(text, style: AppText.caption.copyWith(fontSize: 10, height: 1.3)),
      ]),
    );
  }
}

// lib/features/messages/messages_home_page.dart
// Matches the reference layout: Following/Friends summary cards, Friend
// Requests with Accept/Decline, Recent Conversations, a short explainer,
// and a New Message entry point. Following (one-way) and Friends
// (mutual, unlocks messaging) are deliberately shown as two separate
// systems here, not merged.
//
// production_plan.md §7B retired this page's admin-configured banner.
// Messages isn't a content-discovery surface the way Library/Courses/
// Magazine/Past Papers are (there's nothing to "recommend" in an inbox),
// so unlike those pages this one has no replacement recommendation rail --
// a real absence, not a placeholder waiting to be filled.
//
// ── 2024 remake changes ────────────────────────────────────────────────
// - The search bar was decorative — a styled Row with static placeholder
//   text and no TextField, so typing into it was never actually
//   possible. It's now a real TextField that filters Pinned/Recent by
//   participant/club name and last-message text.
// - Inbox rows show the real per-conversation presence dot (see
//   Conversation.isRecentlyActive) instead of no indicator at all.
// - watchConversations now emits a cached snapshot before the live
//   Firestore listener attaches (see MessagingRepository), so this page
//   paints instantly on a warm cache instead of showing the shimmer
//   placeholder every time — no code change needed here, the
//   StreamBuilder benefits automatically.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/messaging.dart';
import '../../models/club.dart';
import '../../repositories/messaging_repository.dart';
import '../../repositories/follow_repository.dart';
import '../../repositories/club_repository.dart';
import '../clubs/clubs_page.dart' show ClubDetailPage;
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/club_visuals.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import 'chat_conversation_page.dart';
import 'find_people_page.dart';

class MessagesHomePage extends StatefulWidget {
  final AppUser user;
  const MessagesHomePage({super.key, required this.user});

  @override
  State<MessagesHomePage> createState() => _MessagesHomePageState();
}

class _MessagesHomePageState extends State<MessagesHomePage> {
  AppUser get user => widget.user;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: ac.bg,
      body: AppBackground(child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _header(context),
            const SizedBox(height: 10),
            _searchBar(context),
            const SizedBox(height: 16),
            if (!searching) ...[
              _followFriendCards(context),
              const SizedBox(height: 20),
              _friendRequestsSection(context),
              const SizedBox(height: 20),
            ],
            _recentConversationsSection(context),
            if (!searching) ...[
              const SizedBox(height: 24),
              _howItWorksSection(ac),
            ],
            const SizedBox(height: 20),
            _newMessageButton(context),
          ],
        ),
      )),
    );
  }

  Widget _header(BuildContext context) {
    final ac = AppColors.of(context);
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
          icon: Icon(Icons.notifications_outlined, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: user.id))),
        ),
        UserAvatar(initials: user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
            radius: 18, photoUrl: user.photoUrl,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfilePage(user: user)))),
      ]),
    );
  }

  Widget _searchBar(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: ac.bdr)),
            child: Row(children: [
              Icon(Icons.search_rounded, size: 18, color: ac.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppText.bodySm.copyWith(color: ac.txt),
                  decoration: InputDecoration(
                    hintText: 'Search conversations…',
                    hintStyle: AppText.bodySm.copyWith(color: ac.muted),
                    border: InputBorder.none, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                InkWell(
                  onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                  child: Icon(Icons.close_rounded, size: 16, color: ac.muted),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: ac.navy,
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
                Icon(Icons.person_add_alt_1_rounded, size: 16, color: ac.gold),
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
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: FollowRepository.instance.watchFollowingCount(user.id),
            builder: (context, snap) => _SummaryCard(
              icon: Icons.record_voice_over_rounded, color: ac.blu, bg: ac.bluBg,
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
              icon: Icons.people_alt_rounded, color: ac.grn, bg: ac.grnBg,
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
        final ac = AppColors.of(context);
        if (snap.hasError) {
          CrashService.instance.recordError(snap.error, snap.stackTrace,
              context: 'MessagesHomePage.watchIncomingRequests(${user.id})');
          return ErrorView(message: "Couldn't load friend requests — ${snap.error}");
        }
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
                decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(20)),
                child: Text('${requests.length}', style: AppText.label.copyWith(fontSize: 11, color: ac.red, letterSpacing: 0)),
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
                      style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white),
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

  /// Merged Messages inbox — the mockup shows club/group threads (e.g.
  /// "STEM Innovators Club") alongside 1:1 conversations in ONE
  /// recency-sorted list, not a separate section. Rather than folding
  /// clubs into the Conversation/conversations collection (a much larger,
  /// riskier data-model change touching two already-working systems),
  /// this merges two independent streams client-side into one sorted
  /// list of [_InboxEntry] — Club keeps its own real chat backend
  /// (clubs/{id}/messages), Conversation keeps its own; only the
  /// Messages-home LIST rendering is unified.
  ///
  /// When [_query] is non-empty this renders a flat, filtered "Search
  /// Results" list instead of the Pinned/Recent split — see the file
  /// header for why the search bar didn't do anything before.
  Widget _recentConversationsSection(BuildContext context) {
    final query = _query.trim().toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<List<Conversation>>(
        stream: MessagingRepository.instance.watchConversations(user.id),
        builder: (context, convSnap) {
          final ac = AppColors.of(context);
          return StreamBuilder<List<Club>>(
            stream: ClubRepository.instance.watchMyClubs(user.id),
            builder: (context, clubSnap) {
              if (convSnap.connectionState == ConnectionState.waiting) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(query.isEmpty ? 'Recent Conversations' : 'Search Results', style: AppText.h2.copyWith(fontSize: 16)),
                  const SizedBox(height: 12),
                  ...List.generate(3, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      ShimmerCircle(size: 44),
                      SizedBox(width: 12),
                      Expanded(child: ShimmerLine(height: 14)),
                    ]),
                  )),
                ]);
              }
              if (convSnap.hasError) {
                CrashService.instance.recordError(convSnap.error, convSnap.stackTrace,
                    context: 'MessagesHomePage.watchConversations(${user.id})');
                return Text('Failed to load: ${convSnap.error}', style: AppText.caption.copyWith(color: ac.red, fontSize: 11));
              }
              final conversations = convSnap.data ?? const <Conversation>[];
              final clubs = (clubSnap.data ?? const <Club>[])
                  .where((c) => c.lastMessageAt != null) // a club with no chat activity isn't an "inbox" entry
                  .toList();

              bool convMatches(Conversation c) {
                if (query.isEmpty) return true;
                final other = c.participantNames[c.otherParticipantId(user.id)] ?? '';
                return other.toLowerCase().contains(query) ||
                    c.lastMessageText.toLowerCase().contains(query);
              }
              bool clubMatches(Club c) {
                if (query.isEmpty) return true;
                return c.name.toLowerCase().contains(query) ||
                    (c.lastMessageText).toLowerCase().contains(query);
              }

              if (query.isNotEmpty) {
                final results = <_InboxEntry>[
                  ...conversations.where(convMatches).map(_ConversationEntry.new),
                  ...clubs.where(clubMatches).map(_ClubEntry.new),
                ]..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Search Results', style: AppText.h2.copyWith(fontSize: 16)),
                  const SizedBox(height: 12),
                  if (results.isEmpty)
                    Text('No conversations match "${_query.trim()}".', style: AppText.bodySm)
                  else
                    ...results.map((e) => _InboxRow(user: user, entry: e)),
                ]);
              }

              if (conversations.isEmpty && clubs.isEmpty) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Recent Conversations', style: AppText.h2.copyWith(fontSize: 16)),
                  const SizedBox(height: 12),
                  Text('No conversations yet — find someone and send a friend request.', style: AppText.bodySm),
                ]);
              }
              final pinned = conversations.where((c) => c.pinnedBy.contains(user.id))
                  .map<_InboxEntry>(_ConversationEntry.new).toList();
              final recent = <_InboxEntry>[
                ...conversations.where((c) => !c.pinnedBy.contains(user.id)).map(_ConversationEntry.new),
                ...clubs.map(_ClubEntry.new),
              ]..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (pinned.isNotEmpty) ...[
                  Row(children: [
                    Icon(Icons.push_pin_rounded, size: 14, color: ac.gold),
                    const SizedBox(width: 6),
                    Text('Pinned', style: AppText.h2.copyWith(fontSize: 16)),
                  ]),
                  const SizedBox(height: 12),
                  ...pinned.map((e) => _InboxRow(user: user, entry: e)),
                  const SizedBox(height: 20),
                ],
                Text('Recent', style: AppText.h2.copyWith(fontSize: 16)),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  Text('Nothing else — every conversation is pinned.', style: AppText.bodySm)
                else
                  ...recent.map((e) => _InboxRow(user: user, entry: e)),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _howItWorksSection(AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How Messaging Works', style: AppText.h2.copyWith(fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _HowStep(icon: Icons.person_add_alt_1_rounded, step: '1. Send Request',
              text: 'Search for anyone and send a friend request.', color: ac.blu, bg: ac.bluBg)),
          const SizedBox(width: 8),
          Expanded(child: _HowStep(icon: Icons.people_alt_rounded, step: '2. They Accept',
              text: 'Only when they accept can you start chatting.', color: ac.pur, bg: ac.purBg)),
          const SizedBox(width: 8),
          Expanded(child: _HowStep(icon: Icons.chat_bubble_rounded, step: '3. Start Conversation',
              text: "Message freely once you're connected.", color: ac.grn, bg: ac.grnBg)),
        ]),
      ]),
    );
  }

  Widget _newMessageButton(BuildContext context) {
    final ac = AppColors.of(context);
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
            backgroundColor: ac.navy, foregroundColor: Colors.white,
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

/// One entry in the merged inbox list — either a 1:1 [Conversation] or a
/// [Club] (club chat), rendered by the same [_InboxRow]. Only
/// Conversation supports pin/unread/presence (Club has none of those
/// concepts yet).
abstract class _InboxEntry {
  DateTime get lastMessageAt;
}

class _ConversationEntry extends _InboxEntry {
  final Conversation conversation;
  _ConversationEntry(this.conversation);
  @override
  DateTime get lastMessageAt => conversation.lastMessageAt;
}

class _ClubEntry extends _InboxEntry {
  final Club club;
  _ClubEntry(this.club);
  @override
  DateTime get lastMessageAt => club.lastMessageAt!; // filtered non-null by the caller
}

/// One row in Pinned/Recent — long-press to pin/unpin (Conversations
/// only), matching the mockup's Pinned-section split. Swipe gestures
/// were considered but long-press reuses the same discoverable pattern
/// chat bubbles already use for delete (chat_conversation_page.dart's
/// _MessageBubble).
class _InboxRow extends StatelessWidget {
  final AppUser user;
  final _InboxEntry entry;
  const _InboxRow({required this.user, required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e is _ClubEntry) return _clubRow(context, e.club);
    return _conversationRow(context, (e as _ConversationEntry).conversation);
  }

  Widget _clubRow(BuildContext context, Club club) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ACard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ClubDetailPage(club: club, user: user))),
        child: Row(children: [
          ClubLogo(club: club, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(club.name, style: AppText.title.copyWith(fontSize: 14)),
              Text(club.lastMessageSenderId == user.id ? 'You: ${club.lastMessageText}' : club.lastMessageText,
                  style: AppText.bodySm.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(_relativeTime(club.lastMessageAt!), style: AppText.caption.copyWith(fontSize: 10.5)),
        ]),
      ),
    );
  }

  Widget _conversationRow(BuildContext context, Conversation conversation) {
    final ac = AppColors.of(context);
    final otherId = conversation.otherParticipantId(user.id);
    final otherName = conversation.participantNames[otherId] ?? 'Unknown';
    final otherPhoto = conversation.participantPhotos[otherId];
    final unread = conversation.unreadCount[user.id] ?? 0;
    final isPinned = conversation.pinnedBy.contains(user.id);
    final online = conversation.isRecentlyActive(otherId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          MessagingRepository.instance.togglePinned(conversation.id, user.id, !isPinned);
          showToast(context, isPinned ? 'Unpinned' : 'Pinned to top');
        },
        child: ACard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatConversationPage(
                  conversationId: conversation.id, currentUser: user,
                  otherUserId: otherId, otherUserName: otherName, otherUserPhoto: otherPhoto))),
          child: Row(children: [
            UserAvatar(initials: otherName.isEmpty ? '?' : otherName[0].toUpperCase(),
                radius: 22, photoUrl: otherPhoto, showPresenceDot: true, online: online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(otherName, style: AppText.title.copyWith(fontSize: 14)),
                Text(conversation.lastMessageSenderId == user.id ? 'You: ${conversation.lastMessageText}' : conversation.lastMessageText,
                    style: AppText.bodySm.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_relativeTime(conversation.lastMessageAt), style: AppText.caption.copyWith(fontSize: 10.5)),
              const SizedBox(height: 6),
              if (unread > 0)
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(color: ac.primary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('$unread', style: AppText.label.copyWith(fontSize: 10.5, color: Colors.white, letterSpacing: 0)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    }
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
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

// lib/features/messages/messages_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/messaging.dart';
import '../../repositories/messaging_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'chat_conversation_page.dart';
import 'find_people_page.dart';
import '../../widgets/application_shell.dart';

class MessagesHomePage extends StatefulWidget {
  final AppUser user;
  const MessagesHomePage({super.key, required this.user});

  @override
  State<MessagesHomePage> createState() => _MessagesHomePageState();
}

class _MessagesHomePageState extends State<MessagesHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';
  Conversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _filter = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    final listPane = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search conversations or people...',
              hintStyle: TextStyle(color: ac.muted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: ac.muted, size: 20),
              filled: true,
              fillColor: ac.surf,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          indicatorColor: ac.gold,
          indicatorWeight: 3,
          labelColor: ac.navy,
          unselectedLabelColor: ac.muted,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Conversations'),
            Tab(text: 'Message Requests'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ConversationsTab(
                user: widget.user,
                filter: _filter,
                selectedConversationId: isDesktop ? _selectedConversation?.id : null,
                onSelectConversation: (c) {
                  if (isDesktop) {
                    setState(() => _selectedConversation = c);
                  } else {
                    final otherId = c.otherParticipantId(widget.user.id);
                    final otherName = c.participantNames[otherId] ?? 'Unknown';
                    final otherPhoto = c.participantPhotos[otherId];
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatConversationPage(
                        conversationId: c.id,
                        currentUser: widget.user,
                        otherUserId: otherId,
                        otherUserName: otherName,
                        otherUserPhoto: otherPhoto,
                      ),
                    ));
                  }
                },
              ),
              _MessageRequestsTab(user: widget.user, filter: _filter),
            ],
          ),
        ),
      ],
    );

    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Messaging',
      currentDestination: AppNavDestination.schoolConnect,
      showRightPanel: false, // In desktop messaging, the 2-pane chat workspace takes the full viewport
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => FindPeoplePage(user: widget.user)));
        },
        backgroundColor: ac.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_square, size: 18),
        label: Text('New Message', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 360,
                  child: listPane,
                ),
                VerticalDivider(width: 1, thickness: 1, color: ac.bdr),
                Expanded(
                  child: _selectedConversation != null
                      ? ChatConversationPage(
                          key: ValueKey(_selectedConversation!.id),
                          conversationId: _selectedConversation!.id,
                          currentUser: widget.user,
                          otherUserId: _selectedConversation!.otherParticipantId(widget.user.id),
                          otherUserName: _selectedConversation!.participantNames[_selectedConversation!.otherParticipantId(widget.user.id)] ?? 'Unknown',
                          otherUserPhoto: _selectedConversation!.participantPhotos[_selectedConversation!.otherParticipantId(widget.user.id)],
                          embedded: true,
                        )
                      : _buildEmptyDetailState(context, ac),
                ),
              ],
            )
          : listPane,
    );
  }

  Widget _buildEmptyDetailState(BuildContext context, AppColors ac) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ac.surf,
              shape: BoxShape.circle,
              border: Border.all(color: ac.bdr),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 54, color: ac.gold),
          ),
          const SizedBox(height: 20),
          Text(
            'Select a conversation',
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold, color: ac.txt),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Choose a conversation from the left to start messaging, share academic notes, or collaborate on coursework.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: ac.muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationsTab extends StatelessWidget {
  final AppUser user;
  final String filter;
  final String? selectedConversationId;
  final ValueChanged<Conversation> onSelectConversation;

  const _ConversationsTab({
    required this.user,
    required this.filter,
    this.selectedConversationId,
    required this.onSelectConversation,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Conversation>>(
      stream: MessagingRepository.instance.watchConversations(user.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: ErrorView(message: snap.error.toString()));
        }

        final all = snap.data ?? [];
        var filtered = all;
        if (filter.isNotEmpty) {
          filtered = filtered.where((c) {
            final otherId = c.otherParticipantId(user.id);
            final otherName = c.participantNames[otherId] ?? '';
            return otherName.toLowerCase().contains(filter) || c.lastMessageText.toLowerCase().contains(filter);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, size: 56, color: AppColors.of(context).muted.withValues(alpha: .5)),
                const SizedBox(height: 16),
                Text('No conversations found.', style: GoogleFonts.inter(color: AppColors.of(context).muted)),
              ],
            ),
          );
        }

        final pinned = filtered.where((c) => c.pinnedBy.contains(user.id)).toList();
        final unpinned = filtered.where((c) => !c.pinnedBy.contains(user.id)).toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (pinned.isNotEmpty) ...[
              Text('PINNED', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.of(context).muted, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ...pinned.map((c) => _ConversationRow(
                    user: user,
                    conversation: c,
                    isSelected: c.id == selectedConversationId,
                    onTap: () => onSelectConversation(c),
                  )),
              const SizedBox(height: 16),
              Text('RECENT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.of(context).muted, letterSpacing: 0.5)),
              const SizedBox(height: 8),
            ],
            ...unpinned.map((c) => _ConversationRow(
                  user: user,
                  conversation: c,
                  isSelected: c.id == selectedConversationId,
                  onTap: () => onSelectConversation(c),
                )),
            const SizedBox(height: 80), // Fab clearance
          ],
        );
      },
    );
  }
}

class _MessageRequestsTab extends StatelessWidget {
  final AppUser user;
  final String filter;
  const _MessageRequestsTab({required this.user, required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 56, color: AppColors.of(context).muted.withValues(alpha: .5)),
          const SizedBox(height: 16),
          Text('No pending message requests.', style: GoogleFonts.inter(color: AppColors.of(context).txt2, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'When new students or teachers try to network with you, their requests will appear here safely.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.of(context).muted, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final AppUser user;
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConversationRow({
    required this.user,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? ac.gold.withValues(alpha: 0.1) : ac.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? ac.gold : ac.bdr,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    UserAvatar(
                      initials: otherName.isEmpty ? '?' : otherName[0].toUpperCase(),
                      radius: 22,
                      photoUrl: otherPhoto,
                      showPresenceDot: true,
                      online: online,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  otherName,
                                  style: GoogleFonts.sora(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: ac.txt,
                                  ),
                                ),
                              ),
                              Text(
                                _relativeTime(conversation.lastMessageAt),
                                style: GoogleFonts.inter(fontSize: 11, color: ac.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation.lastMessageSenderId == user.id
                                      ? 'You: ${conversation.lastMessageText}'
                                      : conversation.lastMessageText,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                                    color: unread > 0 ? ac.txt : ac.txt2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: ac.gold, borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                    '$unread',
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: ac.navy),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

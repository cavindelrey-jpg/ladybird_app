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
import '../../routes/app_routes.dart';

class MessagesHomePage extends StatefulWidget {
  final AppUser user;
  final String? initialConversationId;
  final int initialTab;

  const MessagesHomePage({
    super.key,
    required this.user,
    this.initialConversationId,
    this.initialTab = 0,
  });

  @override
  State<MessagesHomePage> createState() => _MessagesHomePageState();
}

class _MessagesHomePageState extends State<MessagesHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';
  String? _selectedConversationId;
  Conversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _selectedConversationId = widget.initialConversationId;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _searchCtrl.addListener(() {
      setState(() => _filter = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(covariant MessagesHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialConversationId != null &&
        widget.initialConversationId != _selectedConversationId) {
      setState(() {
        _selectedConversationId = widget.initialConversationId;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectConversation(Conversation c) {
    setState(() {
      _selectedConversation = c;
      _selectedConversationId = c.id;
    });
    AppRoutes.updateBrowserUrl('/messages/${c.id}');
  }

  void _clearSelectedConversation() {
    setState(() {
      _selectedConversation = null;
      _selectedConversationId = null;
    });
    AppRoutes.updateBrowserUrl('/messages');
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    // ── Central Panel Content ──────────────────────────────────────────────
    Widget centerWorkspace;
    Widget? contextualPanel;

    if (isDesktop) {
      if (_selectedConversationId != null) {
        // State 2: Open conversation displays messages centrally & conversation list on the right
        centerWorkspace = _buildConversationDetail(context, ac, isEmbedded: true);
        contextualPanel = _buildConversationsRightSidebar(context, ac);
      } else {
        // State 1: Displays conversations centrally & message requests on the right
        centerWorkspace = _buildCentralConversationsWorkspace(context, ac);
        contextualPanel = _buildMessageRequestsRightSidebar(context, ac);
      }
    } else {
      // Mobile / Narrow: Single fluid view
      if (_selectedConversationId != null) {
        centerWorkspace = _buildConversationDetail(
          context,
          ac,
          isEmbedded: false,
          onBack: _clearSelectedConversation,
        );
      } else {
        centerWorkspace = _buildMobileConversationsList(context, ac);
      }
    }

    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Messaging',
      currentDestination: AppNavDestination.messages,
      contextualPanel: contextualPanel,
      showBackButton: !isDesktop && _selectedConversationId != null,
      onBack: !isDesktop && _selectedConversationId != null ? _clearSelectedConversation : null,
      floatingActionButton: (_selectedConversationId == null || isDesktop)
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FindPeoplePage(user: widget.user)),
                );
              },
              backgroundColor: const Color(0xFF081630),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_square, size: 18),
              label: Text(
                'New Message',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            )
          : null,
      child: centerWorkspace,
    );
  }

  // ── Central Workspace when viewing Conversations (Desktop) ─────────────────
  Widget _buildCentralConversationsWorkspace(BuildContext context, AppColors ac) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header bar with search
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(
            color: ac.surf,
            border: Border(bottom: BorderSide(color: ac.bdr)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search conversations or classmates...',
                    hintStyle: TextStyle(color: ac.muted, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: ac.muted, size: 20),
                    filled: true,
                    fillColor: ac.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ac.bdr),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ac.bdr),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => FindPeoplePage(user: widget.user)),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Start Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A93C),
                  foregroundColor: const Color(0xFF081630),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Conversation List
        Expanded(
          child: _ConversationsTab(
            user: widget.user,
            filter: _filter,
            selectedConversationId: _selectedConversationId,
            onSelectConversation: _selectConversation,
          ),
        ),
      ],
    );
  }

  // ── Central Conversation Detail View (Messages & Composer) ────────────────
  Widget _buildConversationDetail(
    BuildContext context,
    AppColors ac, {
    required bool isEmbedded,
    VoidCallback? onBack,
  }) {
    if (_selectedConversation != null) {
      final otherId = _selectedConversation!.otherParticipantId(widget.user.id);
      final otherName = _selectedConversation!.participantNames[otherId] ?? 'Unknown';
      final otherPhoto = _selectedConversation!.participantPhotos[otherId];

      return ChatConversationPage(
        key: ValueKey(_selectedConversation!.id),
        conversationId: _selectedConversation!.id,
        currentUser: widget.user,
        otherUserId: otherId,
        otherUserName: otherName,
        otherUserPhoto: otherPhoto,
        embedded: isEmbedded,
      );
    }

    // Direct URL loading fallback: stream conversation by ID
    return StreamBuilder<Conversation?>(
      stream: MessagingRepository.instance.watchConversation(_selectedConversationId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE5A93C)));
        }

        final conv = snapshot.data;
        if (conv == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: ac.muted),
                const SizedBox(height: 12),
                Text('Conversation not found.', style: GoogleFonts.inter(color: ac.txt)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _clearSelectedConversation,
                  child: const Text('Back to Conversations'),
                ),
              ],
            ),
          );
        }

        final otherId = conv.otherParticipantId(widget.user.id);
        final otherName = conv.participantNames[otherId] ?? 'Unknown';
        final otherPhoto = conv.participantPhotos[otherId];

        return ChatConversationPage(
          key: ValueKey(conv.id),
          conversationId: conv.id,
          currentUser: widget.user,
          otherUserId: otherId,
          otherUserName: otherName,
          otherUserPhoto: otherPhoto,
          embedded: isEmbedded,
        );
      },
    );
  }

  // ── Right Sidebar: WhatsApp-style Conversation List (Desktop) ──────────────
  Widget _buildConversationsRightSidebar(BuildContext context, AppColors ac) {
    return Column(
      children: [
        // Sidebar header with title & Close/Overview button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ac.bdr)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.chat_rounded, size: 18, color: ac.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Conversations',
                    style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: ac.txt),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.view_agenda_outlined, size: 18),
                tooltip: 'Back to Conversation Workspace',
                color: ac.muted,
                onPressed: _clearSelectedConversation,
              ),
            ],
          ),
        ),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search chats...',
              hintStyle: TextStyle(color: ac.muted, fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, color: ac.muted, size: 18),
              filled: true,
              fillColor: ac.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),

        // Live Conversation list
        Expanded(
          child: _ConversationsTab(
            user: widget.user,
            filter: _filter,
            selectedConversationId: _selectedConversationId,
            onSelectConversation: _selectConversation,
          ),
        ),
      ],
    );
  }

  // ── Right Sidebar: Message Requests (Desktop default) ──────────────────────
  Widget _buildMessageRequestsRightSidebar(BuildContext context, AppColors ac) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ac.bdr)),
          ),
          child: Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 18, color: ac.primary),
              const SizedBox(width: 8),
              Text(
                'Message Requests',
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: ac.txt),
              ),
            ],
          ),
        ),
        Expanded(
          child: _MessageRequestsTab(user: widget.user, filter: _filter),
        ),
      ],
    );
  }

  // ── Mobile Conversations List (with Tabs) ──────────────────────────────────
  Widget _buildMobileConversationsList(BuildContext context, AppColors ac) {
    return Column(
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
                selectedConversationId: _selectedConversationId,
                onSelectConversation: _selectConversation,
              ),
              _MessageRequestsTab(user: widget.user, filter: _filter),
            ],
          ),
        ),
      ],
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
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE5A93C)));
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
            return otherName.toLowerCase().contains(filter) ||
                c.lastMessageText.toLowerCase().contains(filter);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 48,
                    color: AppColors.of(context).muted.withValues(alpha: .5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No conversations found.',
                    style: GoogleFonts.inter(color: AppColors.of(context).muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final pinned = filtered.where((c) => c.pinnedBy.contains(user.id)).toList();
        final unpinned = filtered.where((c) => !c.pinnedBy.contains(user.id)).toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (pinned.isNotEmpty) ...[
              Text(
                'PINNED',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.of(context).muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              ...pinned.map((c) => _ConversationRow(
                    user: user,
                    conversation: c,
                    isSelected: c.id == selectedConversationId,
                    onTap: () => onSelectConversation(c),
                  )),
              const SizedBox(height: 16),
              Text(
                'RECENT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.of(context).muted,
                  letterSpacing: 0.5,
                ),
              ),
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 52,
              color: AppColors.of(context).muted.withValues(alpha: .5),
            ),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: GoogleFonts.inter(
                color: AppColors.of(context).txt,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When new students or teachers connect with you, their requests will appear here safely.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.of(context).muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
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
            color: isSelected ? const Color(0xFFE5A93C).withValues(alpha: 0.15) : ac.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFFE5A93C) : ac.bdr,
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
                      radius: 20,
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
                                    fontSize: 13.5,
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
                                    fontSize: 12,
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
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5A93C),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF081630),
                                    ),
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

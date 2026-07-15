// lib/features/messages/chat_conversation_page.dart
// 1:1 chat — message bubbles, read receipts, image/video sharing.
//
// Honest omission: the reference shows an "Online" status dot. Building
// real presence needs a heartbeat/lastActiveAt system (or Firebase
// Realtime Database's dedicated presence support) that doesn't exist in
// this codebase yet — faking a static "Online" label would be exactly
// the kind of dishonest placeholder this project has deliberately
// avoided elsewhere (the fake stat card, the fake recommendations).
// Left out rather than faked; a real follow-up, not done here.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../models/messaging.dart';
import '../../repositories/messaging_repository.dart';
import '../../services/link_preview_service.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ChatConversationPage extends StatefulWidget {
  final String conversationId;
  final AppUser currentUser;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  const ChatConversationPage({
    super.key, required this.conversationId, required this.currentUser,
    required this.otherUserId, required this.otherUserName, this.otherUserPhoto,
  });

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  bool _otherTyping = false;
  DateTime? _lastTypingPing;
  Timer? _typingHideTimer;
  StreamSubscription<Conversation?>? _convSub;

  @override
  void initState() {
    super.initState();
    MessagingRepository.instance.markConversationRead(widget.conversationId, widget.currentUser.id);
    _convSub = MessagingRepository.instance.watchConversation(widget.conversationId).listen(_onConversation);
  }

  void _onConversation(Conversation? conv) {
    if (conv == null || !mounted) return;
    final typedAt = conv.typingAt[widget.otherUserId];
    final isFresh = typedAt != null && DateTime.now().difference(typedAt) < const Duration(seconds: 5);
    if (!isFresh) return;
    setState(() => _otherTyping = true);
    _typingHideTimer?.cancel();
    _typingHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _otherTyping = false);
    });
  }

  void _onTextChanged(String _) {
    final now = DateTime.now();
    if (_lastTypingPing != null && now.difference(_lastTypingPing!) < const Duration(seconds: 2)) return;
    _lastTypingPing = now;
    MessagingRepository.instance.setTyping(widget.conversationId, widget.currentUser.id);
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _typingHideTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    HapticFeedback.lightImpact();
    await MessagingRepository.instance.sendMessage(
      conversationId: widget.conversationId,
      senderId: widget.currentUser.id, senderName: widget.currentUser.name,
      text: text,
    );
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    final picker = ImagePicker();
    final picked = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _sending = true);
    final upload = await MessagingRepository.instance.uploadChatMedia(
        conversationId: widget.conversationId, file: File(picked.path), isVideo: isVideo);
    if (upload is Success<String>) {
      await MessagingRepository.instance.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.currentUser.id, senderName: widget.currentUser.name,
        imageUrl: isVideo ? null : upload.value,
        videoUrl: isVideo ? upload.value : null,
      );
    } else if (mounted) {
      showToast(context, 'Failed to send — try again.', isError: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  /// General file attachment — any type, not just photo/video.
  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path;
    if (path == null) {
      if (mounted) showToast(context, 'Could not read that file.', isError: true);
      return;
    }
    setState(() => _sending = true);
    final upload = await MessagingRepository.instance.uploadChatFile(
        conversationId: widget.conversationId, file: File(path), fileName: picked.name);
    if (upload is Success<String>) {
      await MessagingRepository.instance.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.currentUser.id, senderName: widget.currentUser.name,
        fileUrl: upload.value, fileName: picked.name,
      );
    } else if (mounted) {
      showToast(context, 'Failed to send — try again.', isError: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        titleSpacing: 0,
        title: Row(children: [
          UserAvatar(initials: widget.otherUserName.isEmpty ? '?' : widget.otherUserName[0].toUpperCase(),
              radius: 18, photoUrl: widget.otherUserPhoto),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.otherUserName, style: AppText.title.copyWith(fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (_otherTyping)
                Text('typing…', style: AppText.caption.copyWith(fontSize: 11, color: C.primary)),
            ]),
          ),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined, color: C.txt2),
              onPressed: () => showToast(context, 'Voice calling isn\'t built yet.')),
          IconButton(icon: const Icon(Icons.videocam_outlined, color: C.txt2),
              onPressed: () => showToast(context, 'Video calling isn\'t built yet.')),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: MessagingRepository.instance.watchMessages(widget.conversationId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snap.hasError) {
                return ErrorView(message: snap.error.toString());
              }
              final messages = snap.data ?? const <ChatMessage>[];
              if (messages.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No messages yet',
                  subtitle: 'Say hello to start the conversation.',
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                }
              });
              // Interleave a date separator whenever the calendar day
              // changes, so a long thread doesn't read as one undated wall.
              final items = <Object>[];
              DateTime? lastDay;
              for (final m in messages) {
                final day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
                if (lastDay == null || day != lastDay) {
                  items.add(day);
                  lastDay = day;
                }
                items.add(m);
              }
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item is DateTime) return _DateSeparator(date: item);
                  final m = item as ChatMessage;
                  return _MessageBubble(
                    message: m, isMe: m.senderId == widget.currentUser.id,
                    otherUserId: widget.otherUserId,
                  );
                },
              );
            },
          ),
        ),
        _inputBar(),
      ]),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(children: [
          IconButton(
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_circle_outline_rounded, color: C.primary),
            onPressed: _sending ? null : () => _showAttachSheet(),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                  color: C.surf, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.bdr)),
              child: TextField(
                controller: _textCtrl,
                onChanged: _onTextChanged,
                style: AppText.bodySm.copyWith(color: C.txt),
                minLines: 1, maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type a message…', hintStyle: AppText.bodySm.copyWith(color: C.muted),
                  border: InputBorder.none, isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.send_rounded, color: C.primary), onPressed: _sendText),
        ]),
      ),
    );
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.image_outlined, color: C.primary),
            title: const Text('Photo'),
            onTap: () { Navigator.pop(context); _pickAndSendMedia(isVideo: false); },
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined, color: C.primary),
            title: const Text('Video'),
            onTap: () { Navigator.pop(context); _pickAndSendMedia(isVideo: true); },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file_rounded, color: C.primary),
            title: const Text('File'),
            onTap: () { Navigator.pop(context); _pickAndSendFile(); },
          ),
        ]),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(20)),
          child: Text(_label(), style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String otherUserId;
  const _MessageBubble({required this.message, required this.isMe, required this.otherUserId});

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min $ampm';
  }

  String? get _linkUrl => LinkPreviewService.instance.firstUrl(message.text);

  @override
  Widget build(BuildContext context) {
    final read = message.readBy.contains(otherUserId);
    final linkUrl = _linkUrl;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? C.primaryBg : C.surf,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: C.bdr),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((message.imageUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(message.imageUrl!, fit: BoxFit.cover),
            ),
          if ((message.videoUrl ?? '').isNotEmpty)
            Container(
              height: 160, width: 220,
              decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 40)),
            ),
          if ((message.fileUrl ?? '').isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => launchUrl(Uri.parse(message.fileUrl!), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: C.surf3, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.insert_drive_file_rounded, color: C.primary, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(message.fileName ?? 'File', style: AppText.bodySm.copyWith(fontSize: 12.5, color: C.txt),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.download_rounded, size: 16, color: C.muted),
                  ]),
                ),
              ),
            ),
          if (message.text.isNotEmpty) ...[
            if ((message.imageUrl ?? message.videoUrl ?? message.fileUrl ?? '').isNotEmpty) const SizedBox(height: 8),
            Text(message.text, style: AppText.bodySm.copyWith(color: C.txt, fontSize: 14)),
          ],
          if (linkUrl != null) _LinkPreviewCard(url: linkUrl),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_formatTime(message.sentAt), style: AppText.caption.copyWith(fontSize: 10)),
            if (isMe) ...[
              const SizedBox(width: 4),
              Icon(Icons.done_all_rounded, size: 13, color: read ? C.primary : C.muted),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// Fetched once per widget instance (LinkPreviewService.instance caches by
/// URL besides), so scrolling the message list back and forth doesn't
/// refetch a link already resolved earlier in the session.
class _LinkPreviewCard extends StatefulWidget {
  final String url;
  const _LinkPreviewCard({required this.url});

  @override
  State<_LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<_LinkPreviewCard> {
  LinkPreviewData? _data;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await LinkPreviewService.instance.fetch(widget.url);
    if (mounted) setState(() { _data = data; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        height: 40,
        decoration: BoxDecoration(color: C.surf3, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: C.muted)),
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
              color: C.surf3, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((data.imageUrl ?? '').isNotEmpty)
              Image.network(data.imageUrl!, height: 110, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if ((data.title ?? '').isNotEmpty)
                  Text(data.title!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.txt)),
                if ((data.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(data.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 11)),
                ],
                const SizedBox(height: 3),
                Text(Uri.tryParse(widget.url)?.host ?? widget.url,
                    style: AppText.caption.copyWith(fontSize: 10, color: C.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

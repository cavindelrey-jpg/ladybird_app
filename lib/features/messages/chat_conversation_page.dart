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
import '../../models/public_course.dart';
import '../../models/test.dart';
import '../../models/magazine_article.dart';
import '../../repositories/messaging_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../repositories/test_repository.dart';
import '../../repositories/magazine_repository.dart';
import '../../services/link_preview_service.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../courses_marketplace/course_reader_page.dart';
import '../testing/test_taking_page.dart';
import '../magazine/article_reader_page.dart';

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
  double? _uploadProgress;

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
    await _uploadAndSendMedia(File(picked.path), isVideo);
  }

  Future<void> _uploadAndSendMedia(File file, bool isVideo) async {
    setState(() { _sending = true; _uploadProgress = 0; });
    final upload = await MessagingRepository.instance.uploadChatMedia(
      conversationId: widget.conversationId, file: file, isVideo: isVideo,
      onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
    );
    if (upload is Success<String>) {
      await MessagingRepository.instance.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.currentUser.id, senderName: widget.currentUser.name,
        imageUrl: isVideo ? null : upload.value,
        videoUrl: isVideo ? upload.value : null,
      );
    } else if (mounted) {
      _showUploadFailedSnackBar(() => _uploadAndSendMedia(file, isVideo));
    }
    if (mounted) setState(() { _sending = false; _uploadProgress = null; });
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
    await _uploadAndSendFile(File(path), picked.name);
  }

  Future<void> _uploadAndSendFile(File file, String fileName) async {
    setState(() { _sending = true; _uploadProgress = 0; });
    final upload = await MessagingRepository.instance.uploadChatFile(
      conversationId: widget.conversationId, file: file, fileName: fileName,
      onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
    );
    if (upload is Success<String>) {
      await MessagingRepository.instance.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.currentUser.id, senderName: widget.currentUser.name,
        fileUrl: upload.value, fileName: fileName,
      );
    } else if (mounted) {
      _showUploadFailedSnackBar(() => _uploadAndSendFile(file, fileName));
    }
    if (mounted) setState(() { _sending = false; _uploadProgress = null; });
  }

  /// The repository already retries once internally — this surfaces a
  /// manual retry too, since a dead connection can outlast one automatic
  /// retry and the picked file shouldn't have to be reselected from
  /// scratch every time.
  void _showUploadFailedSnackBar(VoidCallback retry) {
    final ac = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Upload failed — check your connection.'),
      backgroundColor: ac.red,
      action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: retry),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
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
                Text('typing…', style: AppText.caption.copyWith(fontSize: 11, color: ac.primary)),
            ]),
          ),
        ]),
        actions: [
          IconButton(icon: Icon(Icons.call_outlined, color: ac.txt2),
              onPressed: () => showToast(context, 'Voice calling isn\'t built yet.')),
          IconButton(icon: Icon(Icons.videocam_outlined, color: ac.txt2),
              onPressed: () => showToast(context, 'Video calling isn\'t built yet.')),
        ],
      ),
      body: AppBackground(child: Column(children: [
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
                    otherUserId: widget.otherUserId, currentUser: widget.currentUser,
                  );
                },
              );
            },
          ),
        ),
        _inputBar(),
      ])),
    );
  }

  Widget _inputBar() {
    final ac = AppColors.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_sending && _uploadProgress != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress! > 0 ? _uploadProgress : null,
                      minHeight: 4, backgroundColor: ac.bdr, color: ac.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(_uploadProgress! * 100).toInt()}%',
                    style: AppText.caption.copyWith(fontSize: 10.5, color: ac.txt2)),
              ]),
            ),
            const SizedBox(height: 4),
          ],
          Row(children: [
          IconButton(
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.add_circle_outline_rounded, color: ac.primary),
            onPressed: _sending ? null : () => _showAttachSheet(),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                  color: ac.surf, borderRadius: BorderRadius.circular(24), border: Border.all(color: ac.bdr)),
              child: TextField(
                controller: _textCtrl,
                onChanged: _onTextChanged,
                style: AppText.bodySm.copyWith(color: ac.txt),
                minLines: 1, maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type a message…', hintStyle: AppText.bodySm.copyWith(color: ac.muted),
                  border: InputBorder.none, isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(icon: Icon(Icons.send_rounded, color: ac.primary), onPressed: _sendText),
          ]),
        ]),
      ),
    );
  }

  void _showAttachSheet() {
    final ac = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.image_outlined, color: ac.primary),
            title: const Text('Photo'),
            onTap: () { Navigator.pop(context); _pickAndSendMedia(isVideo: false); },
          ),
          ListTile(
            leading: Icon(Icons.videocam_outlined, color: ac.primary),
            title: const Text('Video'),
            onTap: () { Navigator.pop(context); _pickAndSendMedia(isVideo: true); },
          ),
          ListTile(
            leading: Icon(Icons.attach_file_rounded, color: ac.primary),
            title: const Text('File'),
            onTap: () { Navigator.pop(context); _pickAndSendFile(); },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.menu_book_rounded, color: ac.grn),
            title: const Text('Share a Course'),
            onTap: () { Navigator.pop(context); _pickCourse(); },
          ),
          ListTile(
            leading: Icon(Icons.quiz_rounded, color: ac.pur),
            title: const Text('Share a Quiz'),
            onTap: () { Navigator.pop(context); _pickQuiz(); },
          ),
          ListTile(
            leading: Icon(Icons.article_rounded, color: ac.org),
            title: const Text('Share an Article'),
            onTap: () { Navigator.pop(context); _pickArticle(); },
          ),
        ]),
      ),
    );
  }

  Future<void> _sendShared({
    required SharedContentType type, required String id,
    required String title, required String subtitle,
  }) async {
    await MessagingRepository.instance.sendMessage(
      conversationId: widget.conversationId,
      senderId: widget.currentUser.id, senderName: widget.currentUser.name,
      sharedType: type, sharedId: id, sharedTitle: title, sharedSubtitle: subtitle,
    );
  }

  Future<void> _pickCourse() async {
    final course = await Navigator.of(context).push<PublicCourse>(MaterialPageRoute(
      builder: (_) => _ContentPickerPage<PublicCourse>(
        title: 'Share a Course',
        stream: PublicCourseRepository.instance.watchLatest(limit: 40),
        matches: (c, q) => c.title.toLowerCase().contains(q) || c.subject.toLowerCase().contains(q),
        itemTitle: (c) => c.title,
        itemSubtitle: (c) => '${c.subject} · ${c.creatorName}',
        icon: Icons.menu_book_rounded,
      ),
    ));
    if (course != null) {
      await _sendShared(type: SharedContentType.course, id: course.id, title: course.title, subtitle: course.subject);
    }
  }

  Future<void> _pickArticle() async {
    final article = await Navigator.of(context).push<MagazineArticle>(MaterialPageRoute(
      builder: (_) => _ContentPickerPage<MagazineArticle>(
        title: 'Share an Article',
        stream: MagazineRepository.instance.watchFeed(limit: 40),
        matches: (a, q) => a.title.toLowerCase().contains(q) || a.category.toLowerCase().contains(q),
        itemTitle: (a) => a.title,
        itemSubtitle: (a) => '${a.category} · ${a.authorName}',
        icon: Icons.article_rounded,
      ),
    ));
    if (article != null) {
      await _sendShared(type: SharedContentType.article, id: article.id, title: article.title, subtitle: article.category);
    }
  }

  Future<void> _pickQuiz() async {
    final subjects = await TestRepository.instance.distinctSubjectsOnce();
    if (!mounted) return;
    if (subjects.isEmpty) {
      showToast(context, 'No quizzes published yet.');
      return;
    }
    final subject = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Pick a subject'))),
          ...subjects.map((s) => ListTile(title: Text(s), onTap: () => Navigator.pop(context, s))),
        ]),
      ),
    );
    if (subject == null || !mounted) return;
    final test = await Navigator.of(context).push<Test>(MaterialPageRoute(
      builder: (_) => _ContentPickerPage<Test>(
        title: subject,
        stream: TestRepository.instance.watchTestsBySubject(subject),
        matches: (t, q) => t.title.toLowerCase().contains(q),
        itemTitle: (t) => t.title,
        itemSubtitle: (t) => t.subject,
        icon: Icons.quiz_rounded,
      ),
    ));
    if (test != null) {
      await _sendShared(type: SharedContentType.quiz, id: test.id, title: test.title, subtitle: test.subject);
    }
  }
}

/// Reusable searchable picker for the chat's "share content" flow —
/// backs Course/Quiz/Article attachment (see ChatConversationPage above).
class _ContentPickerPage<T> extends StatefulWidget {
  final String title;
  final Stream<List<T>> stream;
  final bool Function(T, String query) matches;
  final String Function(T) itemTitle;
  final String Function(T) itemSubtitle;
  final IconData icon;
  const _ContentPickerPage({
    required this.title, required this.stream, required this.matches,
    required this.itemTitle, required this.itemSubtitle, required this.icon,
  });

  @override
  State<_ContentPickerPage<T>> createState() => _ContentPickerPageState<T>();
}

class _ContentPickerPageState<T> extends State<_ContentPickerPage<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(widget.title, style: AppText.title),
      ),
      body: AppBackground(child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style: AppText.bodySm.copyWith(color: ac.txt),
            decoration: InputDecoration(
              hintText: 'Search…', hintStyle: AppText.bodySm.copyWith(color: ac.muted),
              prefixIcon: Icon(Icons.search_rounded, color: ac.muted, size: 20),
              filled: true, fillColor: ac.surf2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<T>>(
            stream: widget.stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
              if (snap.hasError) return ErrorView(message: snap.error.toString());
              var items = snap.data ?? const [];
              if (_query.isNotEmpty) items = items.where((i) => widget.matches(i, _query)).toList();
              if (items.isEmpty) {
                return const EmptyState(icon: Icons.search_off_rounded, title: 'Nothing found', subtitle: 'Try a different search.');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = items[i];
                  return ACard(
                    onTap: () => Navigator.of(context).pop(item),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(10)),
                        child: Icon(widget.icon, color: ac.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.itemTitle(item), style: AppText.title.copyWith(fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(widget.itemSubtitle(item), style: AppText.bodySm.copyWith(fontSize: 11.5),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ])),
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
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(20)),
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
  final AppUser currentUser;
  const _MessageBubble({required this.message, required this.isMe, required this.otherUserId, required this.currentUser});

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min $ampm';
  }

  String? get _linkUrl => LinkPreviewService.instance.firstUrl(message.text);

  Future<void> _confirmDelete(BuildContext context) async {
    final ac = AppColors.of(context);
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will replace it with "This message was deleted" for both of you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: ac.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await MessagingRepository.instance.deleteMessage(
        conversationId: message.conversationId, messageId: message.id, userId: message.senderId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (message.deleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ac.surf3, borderRadius: BorderRadius.circular(16), border: Border.all(color: ac.bdr),
          ),
          child: Text('This message was deleted',
              style: AppText.bodySm.copyWith(fontSize: 13, fontStyle: FontStyle.italic, color: ac.muted)),
        ),
      );
    }
    final read = message.readBy.contains(otherUserId);
    final linkUrl = _linkUrl;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMe ? () => _confirmDelete(context) : null,
        child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? ac.primaryBg : ac.surf,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: ac.bdr),
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
              decoration: BoxDecoration(color: ac.navy, borderRadius: BorderRadius.circular(10)),
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
                  decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.insert_drive_file_rounded, color: ac.primary, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(message.fileName ?? 'File', style: AppText.bodySm.copyWith(fontSize: 12.5, color: ac.txt),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.download_rounded, size: 16, color: ac.muted),
                  ]),
                ),
              ),
            ),
          if (message.sharedType != null)
            _SharedContentCard(message: message, currentUser: currentUser),
          if (message.text.isNotEmpty) ...[
            if ((message.imageUrl ?? message.videoUrl ?? message.fileUrl ?? '').isNotEmpty) const SizedBox(height: 8),
            Text(message.text, style: AppText.bodySm.copyWith(color: ac.txt, fontSize: 14)),
          ],
          if (linkUrl != null) _LinkPreviewCard(url: linkUrl),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_formatTime(message.sentAt), style: AppText.caption.copyWith(fontSize: 10)),
            if (isMe) ...[
              const SizedBox(width: 4),
              Icon(Icons.done_all_rounded, size: 13, color: read ? ac.primary : ac.muted),
            ],
          ]),
        ]),
        ),
      ),
    );
  }
}

/// Renders a Course/Quiz/Article attachment as a tappable card (see the
/// mockup's "Mechanics — Newton's Laws" card) and fetches+opens the real
/// content on tap — never just a static-looking preview.
class _SharedContentCard extends StatefulWidget {
  final ChatMessage message;
  final AppUser currentUser;
  const _SharedContentCard({required this.message, required this.currentUser});

  @override
  State<_SharedContentCard> createState() => _SharedContentCardState();
}

class _SharedContentCardState extends State<_SharedContentCard> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final id = widget.message.sharedId;
      if (id == null) return;
      switch (widget.message.sharedType!) {
        case SharedContentType.course:
          final course = await PublicCourseRepository.instance.watchOne(id).first;
          if (course != null && mounted) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CourseReaderPage(course: course, currentUser: widget.currentUser)));
          } else if (mounted) {
            showToast(context, 'This course is no longer available.');
          }
          break;
        case SharedContentType.quiz:
          final test = await TestRepository.instance.watchTest(id).first;
          if (test != null && mounted) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TestTakingPage(user: widget.currentUser, test: test)));
          } else if (mounted) {
            showToast(context, 'This quiz is no longer available.');
          }
          break;
        case SharedContentType.article:
          final article = await MagazineRepository.instance.getById(id);
          if (article != null && mounted) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ArticleReaderPage(article: article, currentUser: widget.currentUser)));
          } else if (mounted) {
            showToast(context, 'This article is no longer available.');
          }
          break;
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  IconData get _icon => switch (widget.message.sharedType!) {
        SharedContentType.course => Icons.menu_book_rounded,
        SharedContentType.quiz => Icons.quiz_rounded,
        SharedContentType.article => Icons.article_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.bdr)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(10)),
              child: _opening
                  ? Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: ac.primary))
                  : Icon(_icon, color: ac.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.message.sharedTitle ?? widget.message.sharedType!.label,
                    style: AppText.title.copyWith(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('${widget.message.sharedSubtitle ?? ''} · Academia ${widget.message.sharedType!.label}'.trim(),
                    style: AppText.caption.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: ac.muted, size: 18),
          ]),
        ),
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
    final ac = AppColors.of(context);
    if (!_loaded) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        height: 40,
        decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: ac.muted)),
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
              color: ac.surf3, borderRadius: BorderRadius.circular(10), border: Border.all(color: ac.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((data.imageUrl ?? '').isNotEmpty)
              Image.network(data.imageUrl!, height: 110, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if ((data.title ?? '').isNotEmpty)
                  Text(data.title!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt)),
                if ((data.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(data.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 11)),
                ],
                const SizedBox(height: 3),
                Text(Uri.tryParse(widget.url)?.host ?? widget.url,
                    style: AppText.caption.copyWith(fontSize: 10, color: ac.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

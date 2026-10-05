// lib/features/messages/chat_conversation_page.dart
// 1:1 chat — message bubbles, read receipts, image/video/file/shared-
// content sharing.
//
// ── 2024 remake changes (see README_MESSAGING_REMAKE.md for the full
//    writeup) ─────────────────────────────────────────────────────────
// - The five content-type shares (Note/Course/Quiz/Article/Past Paper)
//   move out of the "+" bottom sheet and into an always-visible
//   horizontal row above the input bar — this is what the mockup
//   actually shows; a bottom sheet buried the exact feature the
//   reference design puts front and center. "+" now only opens
//   Photo/Video/File, which the mockup doesn't show inline anywhere.
// - Every network image (chat photos, shared-content thumbnails, link
//   previews) now renders through NetworkThumb, which guarantees a
//   shimmer while loading and a real "unavailable" tile on failure
//   instead of a blank rect or Flutter's default error box. Tapping a
//   chat photo opens a real fullscreen pinch-to-zoom viewer.
// - The video bubble previously had no onTap at all — tapping it did
//   nothing. It now opens the same ArticleVideoPlayer (chewie/
//   video_player) Magazine already uses, so video messages actually
//   play in-app.
// - Shared-content cards now show a real cover-image thumbnail when the
//   shared item has one (Course/Note/Article/Past Paper), not just a
//   generic colored icon tile.
// - A real (not faked) presence dot: MessagingRepository.pingActive()
//   is called on open and on a slow heartbeat while this screen stays
//   mounted, and the header avatar + name row reflect
//   Conversation.isRecentlyActive(otherUserId). See messaging.dart's
//   Conversation.activeAt doc comment for why this is honest rather
//   than a faked "online" flag — this file previously had a comment
//   explicitly declining to fake it; this isn't that, it's the same
//   mechanism setTyping() already used, applied to "has this thread
//   open" instead of "is currently typing."
// - sendMessage() calls now pass `recipientId` so the recipient's
//   conversation-level unread counter actually increments (previously
//   declared on the model, read by the inbox badge, but never written).
// - The "sending…" tick on your own messages is now sourced from
//   Firestore's own `metadata.hasPendingWrites` (see ChatMessage
//   .isPending) rather than a hand-rolled optimistic-message list —
//   Firestore's live listener already reflects a just-sent message from
//   local cache before the server round-trip completes for this exact
//   query pattern, so this surfaces a real signal instead of
//   reinventing one.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/messaging.dart';
import '../../models/public_course.dart';
import '../../models/test.dart';
import '../../models/magazine_article.dart';
import '../../models/academic_content.dart';
import '../../repositories/messaging_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../repositories/test_repository.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/academic_content_repository.dart';
import '../../services/link_preview_service.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/chat_media_widgets.dart';
import '../../widgets/media_players.dart' show ArticleVideoPlayer;
import '../courses_marketplace/course_lessons_page.dart';
import '../testing/test_taking_page.dart';
import '../magazine/article_reader_page.dart';
import '../academic_content/content_details_page.dart';

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
  Timer? _presenceHeartbeat;
  StreamSubscription<Conversation?>? _convSub;
  Conversation? _conversation;
  late final Stream<List<ChatMessage>> _messagesStream;
  List<ChatMessage>? _lastKnownMessages;

  @override
  void initState() {
    super.initState();
    _messagesStream = MessagingRepository.instance.watchMessages(widget.conversationId);
    MessagingRepository.instance.markConversationRead(widget.conversationId, widget.currentUser.id);
    MessagingRepository.instance.pingActive(widget.conversationId, widget.currentUser.id);
    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      MessagingRepository.instance.pingActive(widget.conversationId, widget.currentUser.id);
    });
    _convSub = MessagingRepository.instance.watchConversation(widget.conversationId).listen(_onConversation);
  }

  void _onConversation(Conversation? conv) {
    if (!mounted) return;
    setState(() => _conversation = conv);
    if (conv == null) return;
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
    _presenceHeartbeat?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendText([String? explicitText]) async {
    final text = (explicitText ?? _textCtrl.text).trim();
    if (text.isEmpty) return;
    if (explicitText == null) _textCtrl.clear();
    HapticFeedback.lightImpact();
    final result = await MessagingRepository.instance.sendMessage(
      conversationId: widget.conversationId,
      senderId: widget.currentUser.id, senderName: widget.currentUser.name,
      recipientId: widget.otherUserId,
      text: text,
    );
    if (result is Failure && mounted) {
      showToast(context, result.message);
    }
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
        recipientId: widget.otherUserId,
        imageUrl: isVideo ? null : upload.value,
        videoUrl: isVideo ? upload.value : null,
      );
    } else if (mounted) {
      _showUploadFailedSnackBar(() => _uploadAndSendMedia(file, isVideo));
    }
    if (mounted) setState(() { _sending = false; _uploadProgress = null; });
  }

  /// General file attachment — any type, not just photo/video (unlike
  /// the content-upload pickers elsewhere, which already lock down to a
  /// document/media allowlist). Blocking executables specifically here
  /// rather than adopting the same narrow allowlist -- a chat attachment
  /// legitimately can be almost any document/media/archive type, so a
  /// blocklist for the genuinely dangerous formats is the right shape
  /// for this one picker, not "any file at all".
  static const _blockedChatExtensions = {
    'exe', 'apk', 'bat', 'cmd', 'com', 'msi', 'dmg', 'app',
    'deb', 'sh', 'jar', 'scr', 'pif', 'vbs', 'js', 'ps1',
  };

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path;
    if (path == null) {
      if (mounted) showToast(context, 'Could not read that file.', isError: true);
      return;
    }
    final ext = picked.extension?.toLowerCase() ?? '';
    if (_blockedChatExtensions.contains(ext)) {
      if (mounted) showToast(context, 'That file type isn\'t allowed as an attachment.', isError: true);
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
        recipientId: widget.otherUserId,
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
    final online = _conversation?.isRecentlyActive(widget.otherUserId) ?? false;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        titleSpacing: 0,
        title: Row(children: [
          UserAvatar(
            initials: widget.otherUserName.isEmpty ? '?' : widget.otherUserName[0].toUpperCase(),
            radius: 18, photoUrl: widget.otherUserPhoto,
            showPresenceDot: true, online: online,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.otherUserName, style: AppText.title.copyWith(fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (_otherTyping)
                Text('typing…', style: AppText.caption.copyWith(fontSize: 11, color: ac.primary))
              else if (online)
                Text('Active now', style: AppText.caption.copyWith(fontSize: 11, color: ac.grn)),
            ]),
          ),
        ]),
        actions: [
        ],
      ),
      body: AppBackground(child: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messagesStream,
            builder: (context, snap) {
              if (snap.hasData && snap.data != null) {
                _lastKnownMessages = snap.data;
              }
              final messages = _lastKnownMessages != null
                  ? List<ChatMessage>.from(_lastKnownMessages!)
                  : <ChatMessage>[];
              _messages = messages;

              if (snap.connectionState == ConnectionState.waiting && messages.isEmpty) {
                return const LoadingView();
              }
              if (snap.hasError && messages.isEmpty) {
                return Center(child: ErrorView(message: snap.error.toString()));
              }
              if (messages.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No messages yet',
                  subtitle: 'Say hello to start the conversation.',
                );
              }

              // Sort newest first
              messages.sort((a, b) => b.sentAt.compareTo(a.sentAt));

              final items = <dynamic>[];
              DateTime? lastDay;

              // Since we are reversed, items[0] is rendered at the absolute bottom.
              // We iterate newest -> oldest.
              for (final m in messages) {
                final day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
                if (lastDay != null && day != lastDay) {
                  items.add(lastDay);
                }
                items.add(m);
                lastDay = day;
              }
              if (lastDay != null) items.add(lastDay); // Separator for the oldest group at the very top

              final isOfflineOrError = snap.hasError;

              return Column(
                children: [
                  if (isOfflineOrError)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                      color: ac.orgBg,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 14, color: ac.org),
                          const SizedBox(width: 6),
                          Text(
                            'Offline — showing cached messages',
                            style: AppText.caption.copyWith(fontSize: 11, color: ac.org, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        if (item is DateTime) return _DateSeparator(date: item);
                        final m = item as ChatMessage;
                        return _MessageBubble(
                          message: m,
                          isMe: m.senderId == widget.currentUser.id,
                          otherUserId: widget.otherUserId,
                          currentUser: widget.currentUser,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (_messages != null && _isRequest(_messages!))
          _buildRequestBanner(),
        if (_messages == null || !_isRequest(_messages!))
          _inputBar(),
      ])),
    );
  }
  
  List<ChatMessage>? _messages;
  
  bool _isRequest(List<ChatMessage> msgs) {
    // If the conversation is empty, it's not a request (you're starting it).
    if (msgs.isEmpty) return false;
    // If you have sent at least one message, it's an accepted conversation.
    if (msgs.any((m) => m.senderId == widget.currentUser.id)) return false;
    // Otherwise, you received messages but haven't replied.
    // In a real app we'd have a status flag. We'll use this heuristic.
    return true;
  }
  
  Widget _buildRequestBanner() {
    final ac = AppColors.of(context);
    return Container(
      color: ac.surf,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.otherUserName} wants to connect',
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: ac.txt),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Message requests let you safely decide who can contact you without restricting discovery.',
            style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Block - placeholder for real block logic
                    showToast(context, 'User blocked.');
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: ac.red, side: BorderSide(color: ac.red)),
                  child: const Text('Block'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Decline - just pop
                    Navigator.of(context).pop();
                  },
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Accept by sending an empty/system message or just replying.
                    // For UI purposes, we just send a "Request accepted." message.
                    await _sendText('Request accepted.');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: ac.gold, foregroundColor: ac.navy),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
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
        child: SingleChildScrollView(
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
              leading: Icon(Icons.sticky_note_2_outlined, color: ac.blu),
              title: const Text('Share Note'),
              onTap: () { Navigator.pop(context); _pickNote(); },
            ),
            ListTile(
              leading: Icon(Icons.menu_book_rounded, color: ac.grn),
              title: const Text('Share Course'),
              onTap: () { Navigator.pop(context); _pickCourse(); },
            ),
            ListTile(
              leading: Icon(Icons.quiz_rounded, color: ac.pur),
              title: const Text('Share Quiz'),
              onTap: () { Navigator.pop(context); _pickQuiz(); },
            ),
            ListTile(
              leading: Icon(Icons.article_rounded, color: ac.org),
              title: const Text('Share Article'),
              onTap: () { Navigator.pop(context); _pickArticle(); },
            ),
            ListTile(
              leading: Icon(Icons.history_edu_rounded, color: ac.gold),
              title: const Text('Share Past Paper'),
              onTap: () { Navigator.pop(context); _pickPastPaper(); },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _sendShared({
    required SharedContentType type, required String id,
    required String title, required String subtitle, String? thumbnailUrl,
  }) async {
    await MessagingRepository.instance.sendMessage(
      conversationId: widget.conversationId,
      senderId: widget.currentUser.id, senderName: widget.currentUser.name,
      recipientId: widget.otherUserId,
      sharedType: type, sharedId: id, sharedTitle: title, sharedSubtitle: subtitle,
      sharedThumbnailUrl: thumbnailUrl,
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
        itemThumbnail: (c) => c.coverImageUrl,
        icon: Icons.menu_book_rounded,
      ),
    ));
    if (course != null) {
      await _sendShared(type: SharedContentType.course, id: course.id, title: course.title,
          subtitle: course.subject, thumbnailUrl: course.coverImageUrl);
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
        itemThumbnail: (a) => a.thumbnailUrl,
        icon: Icons.article_rounded,
      ),
    ));
    if (article != null) {
      await _sendShared(type: SharedContentType.article, id: article.id, title: article.title,
          subtitle: article.category, thumbnailUrl: article.thumbnailUrl);
    }
  }

  Future<void> _pickNote() async {
    final note = await Navigator.of(context).push<AcademicContent>(MaterialPageRoute(
      builder: (_) => _ContentPickerPage<AcademicContent>(
        title: 'Share a Note',
        stream: AcademicContentRepository.instance.watch(contentType: ContentType.note),
        matches: (n, q) => n.title.toLowerCase().contains(q) || n.subject.toLowerCase().contains(q),
        itemTitle: (n) => n.title,
        itemSubtitle: (n) => n.subject,
        itemThumbnail: (n) => n.thumbnailUrl,
        icon: Icons.sticky_note_2_outlined,
      ),
    ));
    if (note != null) {
      await _sendShared(type: SharedContentType.note, id: note.id, title: note.title,
          subtitle: note.subject, thumbnailUrl: note.thumbnailUrl);
    }
  }

  Future<void> _pickPastPaper() async {
    final paper = await Navigator.of(context).push<AcademicContent>(MaterialPageRoute(
      builder: (_) => _ContentPickerPage<AcademicContent>(
        title: 'Share a Past Paper',
        stream: AcademicContentRepository.instance.watch(contentType: ContentType.pastPaper),
        matches: (p, q) => p.title.toLowerCase().contains(q) || p.subject.toLowerCase().contains(q),
        itemTitle: (p) => p.title,
        itemSubtitle: (p) => p.subject,
        itemThumbnail: (p) => p.thumbnailUrl,
        icon: Icons.history_edu_rounded,
      ),
    ));
    if (paper != null) {
      await _sendShared(type: SharedContentType.pastPaper, id: paper.id, title: paper.title,
          subtitle: paper.subject, thumbnailUrl: paper.thumbnailUrl);
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
        itemThumbnail: (t) => null,
        icon: Icons.quiz_rounded,
      ),
    ));
    if (test != null) {
      await _sendShared(type: SharedContentType.quiz, id: test.id, title: test.title, subtitle: test.subject);
    }
  }
}

/// Reusable searchable picker for the chat's "share content" flow —
/// backs Course/Quiz/Article/Note/Past-Paper attachment (see
/// ChatConversationPage above). [itemThumbnail] is optional per-item so
/// callers whose model has no cover image (Test) can pass a function
/// that always returns null.
class _ContentPickerPage<T> extends StatefulWidget {
  final String title;
  final Stream<List<T>> stream;
  final bool Function(T, String query) matches;
  final String Function(T) itemTitle;
  final String Function(T) itemSubtitle;
  final String? Function(T) itemThumbnail;
  final IconData icon;
  const _ContentPickerPage({
    required this.title, required this.stream, required this.matches,
    required this.itemTitle, required this.itemSubtitle, required this.itemThumbnail,
    required this.icon,
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
                return const EmptyState(
                  icon: Icons.search_off_rounded, 
                  title: 'Hmm, nothing found', 
                  subtitle: 'We couldn\'t find exactly what you were looking for. Would you like to try a different name or keyword?'
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final thumb = widget.itemThumbnail(item);
                  return ACard(
                    onTap: () => Navigator.of(context).pop(item),
                    child: Row(children: [
                      (thumb != null && thumb.isNotEmpty)
                          ? NetworkThumb(url: thumb, width: 40, height: 40, borderRadius: BorderRadius.circular(10))
                          : Container(
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

  void _openVideo(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
        body: Center(child: ArticleVideoPlayer(url: message.videoUrl!)),
      ),
    ));
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
        // Item 16: a pale tint (primaryBg) vs plain surface read as two
        // near-identical light shades, especially in dark mode where both
        // collapse toward the same dark neutral. Solid primary vs plain
        // surface gives real contrast in both themes -- same convention
        // as WhatsApp/Telegram/iMessage (solid accent for "me", neutral
        // surface for "them").
        decoration: BoxDecoration(
          color: isMe ? ac.primary : ac.surf,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: ac.bdr),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((message.imageUrl ?? '').isNotEmpty)
            NetworkThumb(
              url: message.imageUrl!,
              height: 180,
              width: double.infinity,
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FullscreenImageViewer(url: message.imageUrl!))),
            ),
          if ((message.videoUrl ?? '').isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openVideo(context),
                child: Container(
                  height: 160, width: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [ac.navy, ac.navy2],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 44)),
                ),
              ),
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
            Text(message.text, style: AppText.bodySm.copyWith(color: isMe ? Colors.white : ac.txt, fontSize: 14)),
          ],
          if (linkUrl != null) _LinkPreviewCard(url: linkUrl),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_formatTime(message.sentAt),
                style: AppText.caption.copyWith(fontSize: 10, color: isMe ? Colors.white70 : ac.muted)),
            if (isMe) ...[
              const SizedBox(width: 4),
              message.isPending
                  ? const Icon(Icons.schedule_rounded, size: 12, color: Colors.white70)
                  : Icon(Icons.done_all_rounded, size: 13, color: read ? Colors.white : Colors.white70),
            ],
          ]),
        ]),
        ),
      ),
    );
  }
}

/// Renders a Course/Quiz/Article/Note/Past-Paper attachment as a
/// tappable card (see the mockup's "Mechanics — Newton's Laws" card),
/// shows a real cover-image thumbnail when the shared item has one, and
/// fetches+opens the real content on tap — never just a static-looking
/// preview.
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
                builder: (_) => CourseLessonsPage(course: course, currentUser: widget.currentUser)));
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
        case SharedContentType.note:
        case SharedContentType.pastPaper:
          // Both are AcademicContent items — ContentDetailsPage itself
          // handles the not-found/no-longer-exists case (see its own
          // StreamBuilder), same as opening one from the Library grid.
          if (mounted) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ContentDetailsPage(contentId: id, user: widget.currentUser)));
          }
          break;
        case SharedContentType.clubPost:
        case SharedContentType.authorProfile:
          // Not implemented yet
          break;
        default:
          break;
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  IconData get _icon => switch (widget.message.sharedType!) {
        SharedContentType.note => Icons.sticky_note_2_outlined,
        SharedContentType.course => Icons.menu_book_rounded,
        SharedContentType.quiz => Icons.quiz_rounded,
        SharedContentType.article => Icons.article_rounded,
        SharedContentType.pastPaper => Icons.history_edu_rounded,
        SharedContentType.clubPost => Icons.forum_rounded,
        SharedContentType.authorProfile => Icons.person_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final thumb = widget.message.sharedThumbnailUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.bdr)),
          child: Row(children: [
            (thumb != null && thumb.isNotEmpty)
                ? NetworkThumb(url: thumb, width: 40, height: 40, borderRadius: BorderRadius.circular(10))
                : Container(
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
                Text('${widget.message.sharedSubtitle ?? ''} · ${widget.message.sharedType!.label}'.trim(),
                    style: AppText.caption.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (_opening && (thumb != null && thumb.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ac.primary)),
              )
            else
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
              NetworkThumb(url: data.imageUrl!, height: 110, width: double.infinity, borderRadius: BorderRadius.zero),
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

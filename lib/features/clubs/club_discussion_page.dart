// lib/features/clubs/club_discussion_page.dart
// Ask a question / full discussion thread — the Discussions tab's detail
// screens. XP is awarded server-repository-side (ClubRepository), not
// here; this file is purely UI + the calls that trigger those awards.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../repositories/club_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class AskQuestionPage extends StatefulWidget {
  final Club club;
  final AppUser user;
  const AskQuestionPage({super.key, required this.club, required this.user});

  @override
  State<AskQuestionPage> createState() => _AskQuestionPageState();
}

class _AskQuestionPageState extends State<AskQuestionPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      showToast(context, 'Add a question title and some detail first.');
      return;
    }
    setState(() => _posting = true);
    final result = await ClubRepository.instance.createDiscussion(widget.club.id, ClubDiscussion(
      id: '', clubId: widget.club.id, authorId: widget.user.id, authorName: widget.user.name,
      authorPhotoUrl: widget.user.photoUrl, title: title, body: body,
      tag: _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _posting = false);
    if (result is Success) {
      showToast(context, '+${XpSource.clubQuestion.baseXp} XP earned!');
      Navigator.pop(context);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0, iconTheme: const IconThemeData(color: C.txt),
          title: Text('Ask a Question', style: AppText.title)),
      body: AppBackground(child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Posting a question earns +${XpSource.clubQuestion.baseXp} XP. '
              'If your answer gets marked best, you earn +${XpSource.clubBestAnswer.baseXp} more.',
              style: AppText.bodySm.copyWith(fontSize: 12.5)),
          const SizedBox(height: 16),
          TextField(controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Question title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _bodyCtrl, minLines: 4, maxLines: 8,
              decoration: const InputDecoration(labelText: 'Add detail', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _tagCtrl,
              decoration: const InputDecoration(labelText: 'Topic (optional, e.g. Mechanics)', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _posting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: C.navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Post Question'),
            ),
          ),
        ]),
      ))),
    );
  }
}

class ClubDiscussionDetailPage extends StatefulWidget {
  final Club club;
  final AppUser user;
  final ClubDiscussion discussion;
  const ClubDiscussionDetailPage({super.key, required this.club, required this.user, required this.discussion});

  @override
  State<ClubDiscussionDetailPage> createState() => _ClubDiscussionDetailPageState();
}

class _ClubDiscussionDetailPageState extends State<ClubDiscussionDetailPage> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    ClubRepository.instance.incrementDiscussionView(widget.club.id, widget.discussion.id);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    final result = await ClubRepository.instance.addReply(widget.club.id, widget.discussion.id, ClubDiscussionReply(
      id: '', authorId: widget.user.id, authorName: widget.user.name, authorPhotoUrl: widget.user.photoUrl,
      body: body, createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _sending = false);
    if (result is Success) {
      _replyCtrl.clear();
      showToast(context, '+${XpSource.clubAnswer.baseXp} XP earned!');
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0, iconTheme: const IconThemeData(color: C.txt),
          title: Text('Discussion', style: AppText.title)),
      body: AppBackground(child: Column(children: [
        Expanded(
          child: StreamBuilder<ClubDiscussion?>(
            stream: ClubRepository.instance.watchDiscussion(widget.club.id, widget.discussion.id),
            initialData: widget.discussion,
            builder: (context, discSnap) {
              final discussion = discSnap.data ?? widget.discussion;
              final canMarkBest = widget.user.id == discussion.authorId;
              return StreamBuilder<ClubRole>(
                stream: ClubRepository.instance.watchUserRole(widget.club.id, widget.user.id),
                builder: (context, roleSnap) {
                  final isStaff = roleSnap.data == ClubRole.admin || roleSnap.data == ClubRole.moderator;
                  return StreamBuilder<List<ClubDiscussionReply>>(
                    stream: ClubRepository.instance.watchReplies(widget.club.id, widget.discussion.id),
                    builder: (context, repliesSnap) {
                      final replies = List<ClubDiscussionReply>.from(repliesSnap.data ?? const []);
                      replies.sort((a, b) {
                        if (a.isBestAnswer != b.isBestAnswer) return a.isBestAnswer ? -1 : 1;
                        return a.createdAt.compareTo(b.createdAt);
                      });
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _QuestionHeader(discussion: discussion),
                          const SizedBox(height: 20),
                          Text('${replies.length} ${replies.length == 1 ? "Answer" : "Answers"}',
                              style: AppText.h2.copyWith(fontSize: 15)),
                          const SizedBox(height: 10),
                          if (replies.isEmpty)
                            Text('No answers yet — be the first to help.', style: AppText.bodySm)
                          else
                            ...replies.map((r) => _ReplyCard(
                              reply: r,
                              canMarkBest: (canMarkBest || isStaff) && !r.isBestAnswer,
                              onMarkBest: () => _markBest(discussion, r),
                            )),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        _replyBar(),
      ])),
    );
  }

  Future<void> _markBest(ClubDiscussion discussion, ClubDiscussionReply reply) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as best answer?'),
        content: Text('${reply.authorName} will earn +${XpSource.clubBestAnswer.baseXp} bonus XP.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark Best')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ClubRepository.instance.markBestAnswer(
      clubId: widget.club.id, discussionId: widget.discussion.id,
      replyId: reply.id, replyAuthorId: reply.authorId,
      previousBestAnswerReplyId: discussion.bestAnswerReplyId,
    );
    if (!mounted) return;
    if (result is Failure) showToast(context, result.message, isError: true);
  }

  Widget _replyBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.bdr)),
              child: TextField(
                controller: _replyCtrl,
                minLines: 1, maxLines: 4,
                decoration: const InputDecoration(hintText: 'Share your thoughts…', border: InputBorder.none, isDense: true),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: C.primary),
            onPressed: _sending ? null : _sendReply,
          ),
        ]),
      ),
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  final ClubDiscussion discussion;
  const _QuestionHeader({required this.discussion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(initials: discussion.authorName.isEmpty ? '?' : discussion.authorName[0].toUpperCase(),
              radius: 16, photoUrl: discussion.authorPhotoUrl),
          const SizedBox(width: 10),
          Expanded(child: Text(discussion.authorName, style: AppText.title.copyWith(fontSize: 13))),
          StatusBadge(label: '+${XpSource.clubQuestion.baseXp} XP', color: C.grn),
        ]),
        const SizedBox(height: 12),
        Text(discussion.title, style: AppText.h2.copyWith(fontSize: 17)),
        const SizedBox(height: 8),
        Text(discussion.body, style: AppText.bodySm.copyWith(fontSize: 13.5, height: 1.4)),
        if ((discussion.tag ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          StatusBadge(label: discussion.tag!, color: C.pur),
        ],
      ]),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final ClubDiscussionReply reply;
  final bool canMarkBest;
  final VoidCallback onMarkBest;
  const _ReplyCard({required this.reply, required this.canMarkBest, required this.onMarkBest});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: reply.isBestAnswer ? C.grnb : C.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: reply.isBestAnswer ? C.grn : C.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (reply.isBestAnswer)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: C.grn, size: 16),
              const SizedBox(width: 6),
              Text('Best Answer', style: AppText.label.copyWith(fontSize: 11, color: C.grn)),
            ]),
          ),
        Row(children: [
          UserAvatar(initials: reply.authorName.isEmpty ? '?' : reply.authorName[0].toUpperCase(),
              radius: 14, photoUrl: reply.authorPhotoUrl),
          const SizedBox(width: 8),
          Expanded(child: Text(reply.authorName, style: AppText.title.copyWith(fontSize: 12.5))),
          if (canMarkBest)
            TextButton(onPressed: onMarkBest, child: Text('Mark Best', style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: C.primary))),
        ]),
        const SizedBox(height: 8),
        Text(reply.body, style: AppText.bodySm.copyWith(fontSize: 13, height: 1.4)),
      ]),
    );
  }
}

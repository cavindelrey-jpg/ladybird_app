// lib/features/clubs/club_discussion_page.dart
// Ask a question / full discussion thread — the Discussions tab's detail
// screens. XP is awarded server-repository-side (ClubRepository), not
// here; this file is purely UI + the calls that trigger those awards.
//
// ── Clubs remake changes ────────────────────────────────────────────────
// - _QuestionHeader gained a real like button. ClubDiscussion.likeCount
//   and ClubRepository.toggleDiscussionLike/watchIsDiscussionLiked
//   already existed and worked — this page just never rendered a like
//   button or the count anywhere, so the feature was invisible.
// - _ReplyCard gained a real like button too. ClubDiscussionReply
//   .likeCount had NO write path anywhere in the repository before this
//   change (every reply's toFirestore() hardcoded likeCount: 0) — see
//   ClubRepository.toggleReplyLike's doc comment.
// - The reply composer gained the mockup's Poll/Resource/Mention/More
//   row. Resource (attach an existing ClubResource to your reply) and
//   Mention (insert "@Name " for a club member) are real. Poll is an
//   honest "not built yet" toast — matching this codebase's own existing
//   pattern for unbuilt features (see chat_conversation_page.dart's
//   voice/video call buttons), not a fabricated feature.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../repositories/club_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../config/branding.dart';
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(backgroundColor: ac.bg, elevation: 0, iconTheme: IconThemeData(color: ac.txt),
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
              style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white,
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

  /// Set by the composer row's "Resource" action; cleared after send or
  /// if the user removes the chip. See _AttachedResourceChip below.
  ClubResource? _attachedResource;

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
    if (body.isEmpty && _attachedResource == null) return;
    setState(() => _sending = true);
    final result = await ClubRepository.instance.addReply(widget.club.id, widget.discussion.id, ClubDiscussionReply(
      id: '', authorId: widget.user.id, authorName: widget.user.name, authorPhotoUrl: widget.user.photoUrl,
      body: body, createdAt: DateTime.now(),
      attachedResourceId: _attachedResource?.id,
      attachedResourceTitle: _attachedResource?.title,
      attachedResourceUrl: _attachedResource?.url,
    ));
    if (!mounted) return;
    setState(() => _sending = false);
    if (result is Success) {
      _replyCtrl.clear();
      setState(() => _attachedResource = null);
      showToast(context, '+${XpSource.clubAnswer.baseXp} XP earned!');
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  void _insertMention(String name) {
    final text = _replyCtrl.text;
    final selection = _replyCtrl.selection;
    final insertAt = selection.isValid ? selection.start : text.length;
    final mention = '@$name ';
    final newText = text.replaceRange(insertAt, selection.isValid ? selection.end : text.length, mention);
    _replyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + mention.length),
    );
  }

  Future<void> _pickResource() async {
    final resource = await showModalBottomSheet<ClubResource>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ResourcePickerSheet(club: widget.club),
    );
    if (resource != null) setState(() => _attachedResource = resource);
  }

  Future<void> _pickMention() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MentionPickerSheet(club: widget.club),
    );
    if (name != null) _insertMention(name);
  }

  void _shareDiscussion() {
    HapticFeedback.selectionClick();
    final appName = Branding.current.appName;
    Share.share('"${widget.discussion.title}" — a discussion in ${widget.club.name} on $appName.\n\n'
        'Open the $appName app, go to Groups > ${widget.club.name} > Discussions to join in.');
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(backgroundColor: ac.bg, elevation: 0, iconTheme: IconThemeData(color: ac.txt),
          title: Text('Discussion', style: AppText.title),
          actions: [
            IconButton(icon: const Icon(Icons.ios_share_rounded), onPressed: _shareDiscussion, tooltip: 'Share'),
          ]),
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
                          _QuestionHeader(club: widget.club, user: widget.user, discussion: discussion),
                          const SizedBox(height: 20),
                          Text('${replies.length} ${replies.length == 1 ? "Answer" : "Answers"}',
                              style: AppText.h2.copyWith(fontSize: 15)),
                          const SizedBox(height: 10),
                          if (replies.isEmpty)
                            Text('No answers yet — be the first to help.', style: AppText.bodySm)
                          else
                            ...replies.map((r) => _ReplyCard(
                              club: widget.club, discussion: discussion, user: widget.user, reply: r,
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
        _composerRow(),
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

  /// The mockup's Poll / Resource / Mention / More row, sitting just
  /// above the text field. Poll is an honest stub — see file header.
  Widget _composerRow() {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _composerAction(icon: Icons.bar_chart_rounded, label: 'Poll', color: ac.blu,
              onTap: () => showToast(context, "Polls aren't built yet.")),
          _composerAction(icon: Icons.description_outlined, label: 'Resource', color: ac.grn, onTap: _pickResource),
          _composerAction(icon: Icons.alternate_email_rounded, label: 'Mention', color: ac.pur, onTap: _pickMention),
          _composerAction(icon: Icons.more_horiz_rounded, label: 'More', color: ac.txt2, onTap: _shareDiscussion),
        ]),
      ),
    );
  }

  Widget _composerAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _replyBar() {
    final ac = AppColors.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_attachedResource != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _AttachedResourceChip(
                resource: _attachedResource!,
                onRemove: () => setState(() => _attachedResource = null),
              ),
            ),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(24), border: Border.all(color: ac.bdr)),
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
                  : Icon(Icons.send_rounded, color: ac.primary),
              onPressed: _sending ? null : _sendReply,
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Bottom sheet listing the club's existing resources — picking one
/// attaches it to the reply being composed. Deliberately doesn't offer
/// "add a new resource" here too (that's the Resources tab's job — see
/// _AddResourceSheet in clubs_page.dart); this is purely a picker.
class _ResourcePickerSheet extends StatelessWidget {
  final Club club;
  const _ResourcePickerSheet({required this.club});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('Attach a Resource', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
          Expanded(
            child: StreamBuilder<List<ClubResource>>(
              stream: ClubRepository.instance.watchResources(club.id),
              builder: (context, snap) {
                final ac = AppColors.of(context);
                final resources = snap.data ?? const <ClubResource>[];
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (resources.isEmpty) {
                  return const EmptyState(icon: Icons.folder_open_outlined, title: 'No resources yet',
                      subtitle: 'Add one from the group\'s Resources tab first.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: resources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = resources[i];
                    return ACard(
                      onTap: () => Navigator.pop(context, r),
                      child: Row(children: [
                        Icon(r.isFile ? Icons.insert_drive_file_outlined : Icons.link_rounded, color: ac.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: AppText.title.copyWith(fontSize: 13.5))),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Bottom sheet listing club members — picking one inserts "@Name " into
/// the reply text at the cursor. Not a full inline typeahead (that would
/// need a text-field overlay watching every keystroke); a real, simple
/// picker instead of a fabricated autocomplete.
class _MentionPickerSheet extends StatelessWidget {
  final Club club;
  const _MentionPickerSheet({required this.club});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('Mention Someone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
          Expanded(
            child: StreamBuilder<List<ClubMember>>(
              stream: ClubRepository.instance.watchMembers(club.id),
              builder: (context, snap) {
                final members = snap.data ?? const <ClubMember>[];
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    return ACard(
                      onTap: () => Navigator.pop(context, m.name),
                      child: Row(children: [
                        UserAvatar(initials: m.name.isEmpty ? '?' : m.name[0].toUpperCase(), radius: 16, photoUrl: m.photoUrl),
                        const SizedBox(width: 10),
                        Expanded(child: Text(m.name, style: AppText.title.copyWith(fontSize: 13.5))),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AttachedResourceChip extends StatelessWidget {
  final ClubResource resource;
  final VoidCallback onRemove;
  const _AttachedResourceChip({required this.resource, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: ac.grnBg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.description_outlined, size: 14, color: ac.grn),
        const SizedBox(width: 6),
        Flexible(child: Text(resource.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: ac.grn))),
        const SizedBox(width: 4),
        InkWell(onTap: onRemove, child: Icon(Icons.close_rounded, size: 14, color: ac.grn)),
      ]),
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  final Club club;
  final AppUser user;
  final ClubDiscussion discussion;
  const _QuestionHeader({required this.club, required this.user, required this.discussion});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(initials: discussion.authorName.isEmpty ? '?' : discussion.authorName[0].toUpperCase(),
              radius: 16, photoUrl: discussion.authorPhotoUrl),
          const SizedBox(width: 10),
          Expanded(child: Text(discussion.authorName, style: AppText.title.copyWith(fontSize: 13))),
          StatusBadge(label: '+${XpSource.clubQuestion.baseXp} XP', color: ac.grn),
        ]),
        const SizedBox(height: 12),
        Text(discussion.title, style: AppText.h2.copyWith(fontSize: 17)),
        const SizedBox(height: 8),
        Text(discussion.body, style: AppText.bodySm.copyWith(fontSize: 13.5, height: 1.4)),
        if ((discussion.tag ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          StatusBadge(label: discussion.tag!, color: ac.pur),
        ],
        const SizedBox(height: 12),
        Row(children: [
          _DiscussionLikeButton(club: club, discussion: discussion, user: user),
          const SizedBox(width: 16),
          Icon(Icons.mode_comment_outlined, size: 15, color: ac.muted),
          const SizedBox(width: 4),
          Text('${discussion.replyCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
          const SizedBox(width: 16),
          Icon(Icons.visibility_outlined, size: 15, color: ac.muted),
          const SizedBox(width: 4),
          Text('${discussion.viewCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
        ]),
      ]),
    );
  }
}

/// The like button ClubDiscussion.likeCount always had data for but this
/// page never rendered — wired to ClubRepository.toggleDiscussionLike/
/// watchIsDiscussionLiked, both of which already existed and worked.
class _DiscussionLikeButton extends StatelessWidget {
  final Club club;
  final ClubDiscussion discussion;
  final AppUser user;
  const _DiscussionLikeButton({required this.club, required this.discussion, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (user.isGuest) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.favorite_border_rounded, size: 15, color: ac.muted),
        const SizedBox(width: 4),
        Text('${discussion.likeCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
      ]);
    }
    return StreamBuilder<bool>(
      stream: ClubRepository.instance.watchIsDiscussionLiked(club.id, discussion.id, user.id),
      builder: (context, snap) {
        final liked = snap.data ?? false;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.xs),
            onTap: () {
              HapticFeedback.lightImpact();
              ClubRepository.instance.toggleDiscussionLike(club.id, discussion.id, user.id);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 15, color: liked ? ac.red : ac.muted),
              const SizedBox(width: 4),
              Text('${discussion.likeCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
            ]),
          ),
        );
      },
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final Club club;
  final ClubDiscussion discussion;
  final AppUser user;
  final ClubDiscussionReply reply;
  final bool canMarkBest;
  final VoidCallback onMarkBest;
  const _ReplyCard({
    required this.club, required this.discussion, required this.user, required this.reply,
    required this.canMarkBest, required this.onMarkBest,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: reply.isBestAnswer ? ac.grnBg : ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: reply.isBestAnswer ? ac.grn : ac.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (reply.isBestAnswer)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: ac.grn, size: 16),
              const SizedBox(width: 6),
              Text('Best Answer', style: AppText.label.copyWith(fontSize: 11, color: ac.grn)),
            ]),
          ),
        Row(children: [
          UserAvatar(initials: reply.authorName.isEmpty ? '?' : reply.authorName[0].toUpperCase(),
              radius: 14, photoUrl: reply.authorPhotoUrl),
          const SizedBox(width: 8),
          Expanded(child: Text(reply.authorName, style: AppText.title.copyWith(fontSize: 12.5))),
          if (canMarkBest)
            TextButton(onPressed: onMarkBest, child: Text('Mark Best', style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: ac.primary))),
        ]),
        const SizedBox(height: 8),
        Text(reply.body, style: AppText.bodySm.copyWith(fontSize: 13, height: 1.4)),
        if (reply.attachedResourceId != null) ...[
          const SizedBox(height: 8),
          _AttachedResourceChip(
            resource: ClubResource(
              id: reply.attachedResourceId!, clubId: club.id,
              title: reply.attachedResourceTitle ?? 'Resource', url: reply.attachedResourceUrl ?? '',
              uploaderId: '', uploaderName: '', createdAt: reply.createdAt,
            ),
            // Read-only on a posted reply — this X just doesn't do
            // anything meaningful once the reply already exists.
            onRemove: () {},
          ),
        ],
        const SizedBox(height: 8),
        _ReplyLikeButton(club: club, discussion: discussion, reply: reply, user: user),
      ]),
    );
  }
}

/// Gives ClubDiscussionReply.likeCount its first real write path — see
/// this file's header and ClubRepository.toggleReplyLike's doc comment.
class _ReplyLikeButton extends StatelessWidget {
  final Club club;
  final ClubDiscussion discussion;
  final ClubDiscussionReply reply;
  final AppUser user;
  const _ReplyLikeButton({required this.club, required this.discussion, required this.reply, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (user.isGuest) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.favorite_border_rounded, size: 14, color: ac.muted),
        const SizedBox(width: 4),
        Text('${reply.likeCount}', style: AppText.caption.copyWith(fontSize: 11)),
      ]);
    }
    return StreamBuilder<bool>(
      stream: ClubRepository.instance.watchIsReplyLiked(club.id, discussion.id, reply.id, user.id),
      builder: (context, snap) {
        final liked = snap.data ?? false;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.xs),
            onTap: () {
              HapticFeedback.lightImpact();
              ClubRepository.instance.toggleReplyLike(club.id, discussion.id, reply.id, user.id);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 14, color: liked ? ac.red : ac.muted),
              const SizedBox(width: 4),
              Text('${reply.likeCount}', style: AppText.caption.copyWith(fontSize: 11)),
            ]),
          ),
        );
      },
    );
  }
}

// lib/features/magazine/article_reader_page.dart
// Full article render, author byline, comment thread, read counter fired
// once per view. Body renders the Quill rich-text delta (with inline
// images) when present, via read-only QuillEditor with the same embed
// builders the composer uses — falls back to plain paragraphs for
// older articles saved before rich text existed.
//
// Design pass: reading text now uses AppText.body (15px / 1.65 line
// height) instead of a tight 1.7-height inline style picked ad hoc — this
// is the single biggest lever on whether reading here feels like Substack
// or a form. Whole page fades in on open rather than popping in flat.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'author_profile_page.dart';
import 'article_composer_page.dart';

import '../../widgets/app_background.dart';
class ArticleReaderPage extends StatefulWidget {
  final MagazineArticle article;
  final AppUser? currentUser;
  const ArticleReaderPage({super.key, required this.article, this.currentUser});

  @override
  State<ArticleReaderPage> createState() => _ArticleReaderPageState();
}

class _ArticleReaderPageState extends State<ArticleReaderPage> with SingleTickerProviderStateMixin {
  final _commentCtrl = TextEditingController();
  bool _postingComment = false;
  bool _countedRead = false;

  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _entryRise = Tween<Offset>(
    begin: const Offset(0, 0.03), end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
    // Fire once per view, after a short minimum dwell time rather than
    // immediately on open. This is a PARTIAL mitigation only — it stops
    // pure drive-by/instant-bounce farming (open, count, close) but does
    // nothing against someone genuinely waiting out the delay, and
    // nothing at all against sock-puppet accounts reading for real. See
    // recordRead()'s doc comment in MagazineRepository for the fuller
    // picture of what is and isn't defended against here.
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted || _countedRead) return;
      _countedRead = true;
      MagazineRepository.instance.recordRead(
        widget.article.id,
        readerId: widget.currentUser?.id,
        authorId: widget.article.authorId,
      );
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  bool get _isOwnArticle => widget.currentUser?.id == widget.article.authorId;

  Future<void> _postComment() async {
    final user = widget.currentUser;
    final body = _commentCtrl.text.trim();
    if (user == null || body.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _postingComment = true);
    final comment = ArticleComment(
      id: '', articleId: widget.article.id,
      authorId: user.id, authorName: user.name, authorPhotoUrl: user.photoUrl,
      body: body,
    );
    await MagazineRepository.instance.postComment(comment);
    // The author (and, for replies, the parent commenter) is notified
    // server-side by trg_notify_on_article_comment.
    _commentCtrl.clear();
    if (mounted) setState(() => _postingComment = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        actions: [
          if (_isOwnArticle)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: ac.txt),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ArticleComposerPage(user: widget.currentUser!, existing: a))),
            ),
        ],
      ),
      body: AppBackground(child: FadeTransition(
        opacity: _entryFade,
        child: SlideTransition(
          position: _entryRise,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if ((a.thumbnailUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(Rad.md),
                  child: Image.network(a.thumbnailUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 20),
              Wrap(spacing: 6, runSpacing: 6, children: [
                StatusBadge(label: a.category, color: ac.primary),
                ...a.tags.map((t) => StatusBadge(label: t, color: ac.gold, bg: ac.goldBg)),
              ]),
              const SizedBox(height: 10),
              Text(a.title, style: AppText.h1),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.sm),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AuthorProfilePage(authorId: a.authorId, currentUser: widget.currentUser)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      UserAvatar(initials: a.authorName.isEmpty ? '?' : a.authorName[0].toUpperCase(),
                          radius: 18, photoUrl: a.authorPhotoUrl),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.authorName, style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 13.5)),
                        Text(_formatDate(a.createdAt), style: AppText.caption),
                      ]),
                      const Spacer(),
                      Icon(Icons.visibility_outlined, size: 15, color: ac.muted),
                      const SizedBox(width: 4),
                      Text('${a.readCount}', style: AppText.caption),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: ac.bdr2),
              const SizedBox(height: 20),
              _ArticleBody(article: a),
              const SizedBox(height: 24),
              _ActionRow(article: a, currentUser: widget.currentUser),
              const SizedBox(height: 24),
              Divider(color: ac.bdr2),
              const SizedBox(height: 16),
              Text('Comments (${a.commentCount})', style: AppText.h2.copyWith(fontSize: 15)),
              const SizedBox(height: 14),
              if (widget.currentUser != null)
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: InputDecoration(
                        hintText: 'Add a comment…',
                        filled: true, fillColor: ac.surf3,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _postingComment
                      ? const SizedBox(width: 40, height: 40,
                          child: Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))))
                      : Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: Icon(Icons.send_rounded, color: ac.primary),
                            onPressed: _postComment,
                          ),
                        ),
                ])
              else
                Text('Sign in to join the discussion.', style: AppText.bodySm),
              const SizedBox(height: 16),
              StreamBuilder<List<ArticleComment>>(
                stream: MagazineRepository.instance.watchComments(a.id),
                builder: (context, snap) {
                  final comments = snap.data ?? const <ArticleComment>[];
                  if (comments.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No comments yet — start the discussion.', style: AppText.bodySm),
                    );
                  }
                  return Column(children: comments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AuthorProfilePage(authorId: c.authorId, currentUser: widget.currentUser))),
                        child: UserAvatar(initials: c.authorName.isEmpty ? '?' : c.authorName[0].toUpperCase(),
                            radius: 14, photoUrl: c.authorPhotoUrl),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(c.authorName, style: AppText.subtitle.copyWith(color: ac.txt)),
                            const SizedBox(width: 6),
                            Text(_formatDate(c.createdAt), style: AppText.caption),
                          ]),
                          const SizedBox(height: 3),
                          Text(c.body, style: AppText.bodySm.copyWith(height: 1.4)),
                        ]),
                      ),
                    ]),
                  )).toList());
                },
              ),
            ],
          ),
        ),
      )),
    );
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _formatDate(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Renders the article body. Prefers the Quill delta (so inline images
/// embedded in the text show up in place); falls back to plain paragraphs
/// for articles saved before rich text existed or if the delta is corrupt.
class _ArticleBody extends StatelessWidget {
  final MagazineArticle article;
  const _ArticleBody({required this.article});

  @override
  Widget build(BuildContext context) {
    final deltaJson = article.bodyDelta;
    if (deltaJson == null || deltaJson.isEmpty) {
      return Text(article.body, style: AppText.body);
    }
    quill.QuillController controller;
    try {
      final doc = quill.Document.fromJson(jsonDecode(deltaJson));
      controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      return Text(article.body, style: AppText.body);
    }

    return quill.QuillEditor.basic(
      controller: controller,
      config: quill.QuillEditorConfig(
        showCursor: false,
        autoFocus: false,
        placeholder: '',
        embedBuilders: FlutterQuillEmbeds.editorBuilders(),
      ),
    );
  }
}

// ── Like / Bookmark / Share ─────────────────────────────────
// Like and bookmark backends already existed in MagazineRepository but
// were never wired to any UI — real working code nobody could reach.
class _ActionRow extends StatelessWidget {
  final MagazineArticle article;
  final AppUser? currentUser;
  const _ActionRow({required this.article, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final u = currentUser;
    final repo = MagazineRepository.instance;
    final ac = AppColors.of(context);
    return Row(children: [
      if (u == null)
        Text('Sign in to like or save this article.', style: AppText.caption)
      else ...[
        StreamBuilder<bool>(
          stream: repo.watchIsLiked(article.id, u.id),
          builder: (context, snap) {
            final liked = snap.data ?? false;
            return _ActionChip(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? ac.red : ac.txt2,
              label: '${article.likeCount}',
              onTap: () {
                HapticFeedback.selectionClick();
                repo.toggleLike(article.id, u.id);
              },
            );
          },
        ),
        const SizedBox(width: 18),
        StreamBuilder<bool>(
          stream: repo.watchIsBookmarked(article.id, u.id),
          builder: (context, snap) {
            final saved = snap.data ?? false;
            return _ActionChip(
              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved ? ac.gold : ac.txt2,
              label: saved ? 'Saved' : 'Save',
              onTap: () {
                HapticFeedback.selectionClick();
                repo.toggleBookmark(article.id, u.id);
              },
            );
          },
        ),
      ],
      const Spacer(),
      _ActionChip(
        icon: Icons.share_outlined, color: ac.txt2, label: 'Share',
        onTap: () {
          HapticFeedback.selectionClick();
          Share.share('${article.title}\n\nRead it on Academia Magazine.');
          if (u != null) repo.recordShare(article.id, u.id);
        },
      ),
    ]);
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

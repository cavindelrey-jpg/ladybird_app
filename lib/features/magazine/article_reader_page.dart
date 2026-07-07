// lib/features/magazine/article_reader_page.dart
// Full article render, author byline, comment thread, read counter fired
// once per view. Body renders as plain paragraphs — see the composer's
// header comment for the block-editor upgrade path.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'author_profile_page.dart';
import 'article_composer_page.dart';

class ArticleReaderPage extends StatefulWidget {
  final MagazineArticle article;
  final AppUser? currentUser;
  const ArticleReaderPage({super.key, required this.article, this.currentUser});

  @override
  State<ArticleReaderPage> createState() => _ArticleReaderPageState();
}

class _ArticleReaderPageState extends State<ArticleReaderPage> {
  final _commentCtrl = TextEditingController();
  bool _postingComment = false;
  bool _countedRead = false;

  @override
  void initState() {
    super.initState();
    // Fire once per view, don't block render on it.
    if (!_countedRead) {
      _countedRead = true;
      MagazineRepository.instance.incrementReads(widget.article.id);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _isOwnArticle => widget.currentUser?.id == widget.article.authorId;

  Future<void> _postComment() async {
    final user = widget.currentUser;
    final body = _commentCtrl.text.trim();
    if (user == null || body.isEmpty) return;
    setState(() => _postingComment = true);
    final comment = ArticleComment(
      id: '', articleId: widget.article.id,
      authorId: user.id, authorName: user.name, authorPhotoUrl: user.photoUrl,
      body: body,
    );
    await MagazineRepository.instance.postComment(comment);
    // Best-effort notify — never blocks the comment success path.
    if (widget.article.authorId != user.id) {
      NotificationRepository.instance.create(
        uid: widget.article.authorId,
        type: NotificationType.comment,
        title: 'New comment on "${widget.article.title}"',
        body: '${user.name}: $body',
        deepLinkId: widget.article.id,
      );
    }
    _commentCtrl.clear();
    if (mounted) setState(() => _postingComment = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        actions: [
          if (_isOwnArticle)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: C.txt),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ArticleComposerPage(user: widget.currentUser!, existing: a))),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if ((a.thumbnailUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.md),
              child: Image.network(a.thumbnailUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 20),
          Text(a.title, style: GoogleFonts.sora(
              fontSize: 22, fontWeight: FontWeight.w800, color: C.txt, height: 1.3)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AuthorProfilePage(authorId: a.authorId, currentUser: widget.currentUser))),
            child: Row(children: [
              UserAvatar(initials: a.authorName.isEmpty ? '?' : a.authorName[0].toUpperCase(),
                  radius: 18, photoUrl: a.authorPhotoUrl),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.authorName, style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: C.txt)),
                Text(_formatDate(a.createdAt), style: GoogleFonts.inter(fontSize: 11.5, color: C.muted)),
              ]),
              const Spacer(),
              Icon(Icons.visibility_outlined, size: 15, color: C.muted),
              const SizedBox(width: 4),
              Text('${a.readCount}', style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
            ]),
          ),
          const SizedBox(height: 20),
          const Divider(color: C.bdr2),
          const SizedBox(height: 20),
          Text(a.body, style: GoogleFonts.inter(fontSize: 15, color: C.txt, height: 1.7)),
          const SizedBox(height: 32),
          const Divider(color: C.bdr2),
          const SizedBox(height: 16),
          Text('Comments (${a.commentCount})', style: GoogleFonts.sora(
              fontSize: 15, fontWeight: FontWeight.w700, color: C.txt)),
          const SizedBox(height: 14),
          if (widget.currentUser != null)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    filled: true, fillColor: C.surf3,
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
                  : IconButton(
                      icon: const Icon(Icons.send_rounded, color: C.primary),
                      onPressed: _postComment,
                    ),
            ])
          else
            Text('Sign in to join the discussion.',
                style: GoogleFonts.inter(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 16),
          StreamBuilder<List<ArticleComment>>(
            stream: MagazineRepository.instance.watchComments(a.id),
            builder: (context, snap) {
              final comments = snap.data ?? const <ArticleComment>[];
              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No comments yet — start the discussion.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: C.muted)),
                );
              }
              return Column(children: comments.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  UserAvatar(initials: c.authorName.isEmpty ? '?' : c.authorName[0].toUpperCase(),
                      radius: 14, photoUrl: c.authorPhotoUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(c.authorName, style: GoogleFonts.inter(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: C.txt)),
                        const SizedBox(width: 6),
                        Text(_formatDate(c.createdAt),
                            style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
                      ]),
                      const SizedBox(height: 3),
                      Text(c.body, style: GoogleFonts.inter(fontSize: 13, color: C.txt2, height: 1.4)),
                    ]),
                  ),
                ]),
              )).toList());
            },
          ),
        ],
      ),
    );
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _formatDate(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

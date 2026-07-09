// lib/features/magazine/article_composer_page.dart
// Create/edit an article: title, cover image, body, draft vs published.
//
// Design pass: title/body fields now use the same AppText.h1 / AppText.body
// styles as the reader page renders them in — what you type looks like
// what readers will see, rather than a generic form font.
//
// Body is plain text for this MVP — MagazineArticle.body is a single
// String field, so mixed text+image ordering (a true Substack block
// editor) needs a follow-up model change (a List<ContentBlock> field) per
// the audit's Part 3B note. Cover image + title + text already covers the
// large majority of real articles; upgrade the editor without touching
// this screen's save/publish flow when that's wanted.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ArticleComposerPage extends StatefulWidget {
  final AppUser user;
  final MagazineArticle? existing;
  const ArticleComposerPage({super.key, required this.user, this.existing});

  @override
  State<ArticleComposerPage> createState() => _ArticleComposerPageState();
}

class _ArticleComposerPageState extends State<ArticleComposerPage> {
  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
  File? _pickedCover;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    HapticFeedback.selectionClick();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedCover = File(picked.path));
  }

  Future<void> _save({required bool publish}) async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title and body are required.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _saving = true; _error = null; });

    final repo = MagazineRepository.instance;
    var article = widget.existing ?? MagazineArticle(
      id: '', authorId: widget.user.id, authorName: widget.user.name,
      authorPhotoUrl: widget.user.photoUrl, title: '', body: '',
    );
    article.title = _titleCtrl.text.trim();
    article.body = _bodyCtrl.text.trim();
    article.published = publish;

    if (_isNew) {
      final result = await repo.publish(article);
      if (result is Failure<String>) {
        setState(() { _error = result.message; _saving = false; });
        return;
      }
      // article.id is final — rebuild with the id Firestore assigned.
      article = MagazineArticle(
        id: (result as Success<String>).value,
        authorId: article.authorId, authorName: article.authorName,
        authorPhotoUrl: article.authorPhotoUrl,
        title: article.title, body: article.body,
        thumbnailUrl: article.thumbnailUrl,
        published: article.published,
      );
    }

    if (_pickedCover != null) {
      final uploadResult = await repo.uploadThumbnail(articleId: article.id, imageFile: _pickedCover!);
      if (uploadResult is Success<String>) {
        article.thumbnailUrl = uploadResult.value;
      }
    }

    final saveResult = await repo.update(article);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saveResult is Failure) {
      setState(() => _error = (saveResult).message);
      return;
    }
    showToast(context, publish ? 'Article published.' : 'Draft saved.');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete article?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: C.red))),
        ],
      ),
    );
    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      await MagazineRepository.instance.delete(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text(_isNew ? 'Write an Article' : 'Edit Article', style: AppText.title),
        actions: [
          if (!_isNew)
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: C.red), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Rad.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.md),
              onTap: _pickCover,
              child: Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(
                  color: C.navy, borderRadius: BorderRadius.circular(Rad.md),
                  image: _pickedCover != null
                      ? DecorationImage(image: FileImage(_pickedCover!), fit: BoxFit.cover)
                      : (widget.existing?.thumbnailUrl != null
                          ? DecorationImage(image: NetworkImage(widget.existing!.thumbnailUrl!), fit: BoxFit.cover)
                          : null),
                ),
                child: (_pickedCover == null && widget.existing?.thumbnailUrl == null)
                    ? const Center(child: Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 32))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            style: AppText.h1,
            decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
          ),
          const Divider(color: C.bdr2),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            style: AppText.body,
            maxLines: null,
            minLines: 12,
            decoration: const InputDecoration(
              hintText: 'Tell your story…', border: InputBorder.none),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Text(_error!, style: AppText.bodySm.copyWith(color: C.red)),
            ),
          ],
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: SecondaryBtn(
                label: 'Save Draft',
                onTap: _saving ? () {} : () => _save(publish: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryBtn(
                label: 'Publish',
                loading: _saving,
                onTap: () => _save(publish: true),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// lib/features/magazine/article_composer_page.dart
// Create/edit an article: title, cover image, category, body, draft vs
// published.
//
// Body is a real flutter_quill rich-text editor — bold/italic/headings/
// lists/inline images — mirroring the Courses composer, not just a plain
// TextField with a separate cover-image picker. MagazineArticle.body
// stays populated with the delta's plain text (used for excerpts/search);
// bodyDelta carries the actual rich content or is null for old
// plain-text articles, which the reader falls back to `body` for.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../models/app_notification.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/follow_repository.dart';
import '../../repositories/notification_repository.dart';
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
  late String _category = widget.existing?.category ?? kArticleCategories.first;
  late final quill.QuillController _quillCtrl = _initQuillController();
  final _editorFocusNode = FocusNode();
  final _editorScrollCtrl = ScrollController();
  File? _pickedCover;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  quill.QuillController _initQuillController() {
    final existingDelta = widget.existing?.bodyDelta;
    if (existingDelta != null && existingDelta.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(jsonDecode(existingDelta));
        return quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      } catch (_) {
        // Corrupt/old-format delta fallback
      }
    }
    final plain = widget.existing?.body ?? '';
    final controller = quill.QuillController.basic();
    if (plain.isNotEmpty) controller.document.insert(0, plain);
    return controller;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _quillCtrl.dispose();
    _editorFocusNode.dispose();
    _editorScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    HapticFeedback.selectionClick();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedCover = File(picked.path));
  }

  Future<String?> _onEmbedImagePick(File file) async {
    final articleId = widget.existing?.id ?? 'draft_${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}';
    final result = await MagazineRepository.instance.uploadThumbnail(
        articleId: '${articleId}_inline_${DateTime.now().millisecondsSinceEpoch}', imageFile: file);
    if (result is Success<String>) return result.value;
    return null;
  }

  Future<void> _save({required bool publish}) async {
    final plainText = _quillCtrl.document.toPlainText().trim();
    if (_titleCtrl.text.trim().isEmpty || plainText.isEmpty) {
      setState(() => _error = 'Title and body are required.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _saving = true; _error = null; });

    final repo = MagazineRepository.instance;
    final wasAlreadyPublished = widget.existing?.published ?? false;
    var article = widget.existing ?? MagazineArticle(
      id: '', authorId: widget.user.id, authorName: widget.user.name,
      authorPhotoUrl: widget.user.photoUrl, title: '', body: '',
      schoolId: widget.user.schoolId,
    );
    article.title = _titleCtrl.text.trim();
    article.body = plainText;
    article.bodyDelta = jsonEncode(_quillCtrl.document.toDelta().toJson());
    article.category = _category;
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
        title: article.title, body: article.body, bodyDelta: article.bodyDelta,
        category: article.category, schoolId: article.schoolId,
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

    // Notify followers on the transition into "published" — not on every
    // draft save, and not a second time if it was already published.
    if (publish && !wasAlreadyPublished) {
      _notifyFollowers(article);
    }

    showToast(context, publish ? 'Article published.' : 'Draft saved.');
    Navigator.of(context).pop();
  }

  /// Best-effort fan-out — never blocks the publish success path. Fine at
  /// current scale; a Cloud Function trigger is the right home for this
  /// once a writer's follower count gets large (fan-out writes scale with
  /// follower count, done client-side here).
  Future<void> _notifyFollowers(MagazineArticle article) async {
    try {
      final followerIds = await FollowRepository.instance.watchFollowerIds(widget.user.id).first;
      for (final followerId in followerIds) {
        await NotificationRepository.instance.create(
          uid: followerId,
          type: NotificationType.articlePublished,
          title: '${widget.user.name} published a new article',
          body: article.title,
          deepLinkId: article.id,
        );
      }
    } catch (_) {
      // best-effort — swallow, publishing already succeeded
    }
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
      body: Column(children: [
        Expanded(
          child: ListView(
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kArticleCategories.map((cat) {
              final active = cat == _category;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _category = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? C.primary : C.surf2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? C.primary : C.bdr),
                    ),
                    child: Text(cat, style: AppText.caption.copyWith(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: active ? Colors.white : C.txt2)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            style: AppText.h1,
            decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
          ),
          const Divider(color: C.bdr2),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 280),
            decoration: BoxDecoration(
                color: C.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: C.bdr)),
            padding: const EdgeInsets.all(8),
            child: quill.QuillEditor.basic(
              controller: _quillCtrl,
              focusNode: _editorFocusNode,
              scrollController: _editorScrollCtrl,
              config: quill.QuillEditorConfig(
                placeholder: 'Tell your story…',
                embedBuilders: FlutterQuillEmbeds.editorBuilders(),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Text(_error!, style: AppText.bodySm.copyWith(color: C.red)),
            ),
          ],
          const SizedBox(height: 100),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(color: C.surf, border: Border(top: BorderSide(color: C.bdr))),
          child: quill.QuillSimpleToolbar(
            controller: _quillCtrl,
            config: quill.QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              embedButtons: FlutterQuillEmbeds.toolbarButtons(
                imageButtonOptions: QuillToolbarImageButtonOptions(
                  imageButtonConfig: QuillToolbarImageConfig(
                    onRequestPickImage: (context) async {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (picked == null) return null;
                      return _onEmbedImagePick(File(picked.path));
                    },
                    onImageInsertCallback: (image, controller) async {
                      final index = controller.selection.baseOffset;
                      controller.document.insert(index, quill.BlockEmbed.image(image));
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(children: [
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
          ),
        ),
      ]),
    );
  }
}

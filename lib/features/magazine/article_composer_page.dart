// lib/features/magazine/article_composer_page.dart
// Create/edit an article. New articles start on a "Create New" content-type
// chooser (Text/Video/Audio/Image) — each type gets a composer tailored to
// what it actually needs, instead of forcing every post through the same
// rich-text editor. Editing an existing article skips the chooser and goes
// straight to the form for its saved type.
//
// Text bodies use flutter_quill (unchanged from before) so writers can embed
// images inline. Image/Video/Audio articles use the cover picker / file
// picker instead — see MagazineArticleType for the full shape.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
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

import '../../widgets/app_background.dart';
class ArticleComposerPage extends StatefulWidget {
  final AppUser user;
  final MagazineArticle? existing;
  const ArticleComposerPage({super.key, required this.user, this.existing});

  @override
  State<ArticleComposerPage> createState() => _ArticleComposerPageState();
}

class _ArticleComposerPageState extends State<ArticleComposerPage> {
  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final _descriptionCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late String _category = widget.existing?.category ?? kArticleCategories.first;
  late List<String> _tags = List<String>.from(widget.existing?.tags ?? const []);
  late final quill.QuillController _quillCtrl = _initQuillController();
  final _editorFocusNode = FocusNode();
  final _editorScrollCtrl = ScrollController();

  /// Content type this composer is collecting. Null only while a brand-new
  /// article hasn't had its type picked yet — the "Create New" chooser is
  /// shown in that state instead of the form. Editing an existing article
  /// always starts pinned to its saved type and never sees the chooser.
  MagazineArticleType? _type;

  /// The article this composer is persisting to. Starts as `widget.existing`
  /// when editing, or a blank unsaved article when writing new — but once
  /// autosave (or a manual Save Draft) creates the Firestore doc for a new
  /// article, this is replaced with the id-bearing copy so every subsequent
  /// save (autosave or manual) updates that same doc instead of creating a
  /// new one each time.
  late MagazineArticle _workingArticle = widget.existing ?? MagazineArticle(
    id: '', authorId: widget.user.id, authorName: widget.user.name,
    authorPhotoUrl: widget.user.photoUrl, title: '', body: '',
    schoolId: widget.user.schoolId,
  );

  File? _pickedCover;
  File? _pickedMedia;       // source file for video/audio articles
  String? _pickedMediaName;
  bool _saving = false;
  bool _autoSaving = false;
  String? _error;
  DateTime? _lastAutoSavedAt;
  String _lastAutoSaveSignature = '';
  Timer? _autoSaveTimer;

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
  void initState() {
    super.initState();
    if (widget.existing != null) _type = widget.existing!.type;
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 45), (_) => _autoSaveDraft());
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _quillCtrl.dispose();
    _editorFocusNode.dispose();
    _editorScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedCover = File(picked.path));
  }

  Future<void> _pickMedia() async {
    HapticFeedback.selectionClick();
    final isVideo = _type == MagazineArticleType.video;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isVideo ? ['mp4', 'mov', 'avi'] : ['mp3', 'wav', 'm4a'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _pickedMedia = File(result.files.single.path!);
      _pickedMediaName = result.files.single.name;
    });
  }

  Future<String?> _onEmbedImagePick(File file) async {
    final articleId = widget.existing?.id ?? 'draft_${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}';
    final result = await MagazineRepository.instance.uploadThumbnail(
        articleId: '${articleId}_inline_${DateTime.now().millisecondsSinceEpoch}', imageFile: file);
    if (result is Success<String>) return result.value;
    return null;
  }

  Future<void> _save({required bool publish}) async {
    final type = _type ?? MagazineArticleType.text;
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    switch (type) {
      case MagazineArticleType.text:
        if (_quillCtrl.document.toPlainText().trim().isEmpty) {
          setState(() => _error = 'Body is required.');
          return;
        }
        break;
      case MagazineArticleType.image:
        if (_pickedCover == null && widget.existing?.thumbnailUrl == null) {
          setState(() => _error = 'An image is required.');
          return;
        }
        break;
      case MagazineArticleType.video:
      case MagazineArticleType.audio:
        if (_pickedMedia == null && widget.existing?.mediaUrl == null) {
          setState(() => _error = 'A ${type == MagazineArticleType.video ? "video" : "audio"} file is required.');
          return;
        }
        break;
    }
    HapticFeedback.mediumImpact();
    setState(() { _saving = true; _error = null; });

    final wasAlreadyPublished = _workingArticle.published;
    final ok = await _persist(publish: publish);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;

    // Notify followers on the transition into "published" — not on every
    // draft save, and not a second time if it was already published.
    if (publish && !wasAlreadyPublished) {
      _notifyFollowers(_workingArticle);
    }

    showToast(context, publish ? 'Article published.' : 'Draft saved.');
    Navigator.of(context).pop();
  }

  /// Periodic silent save so in-progress work survives a crash/kill —
  /// deliberately never flips `published` (only the explicit Save
  /// Draft/Publish buttons do that), so autosaving mid-edit can't
  /// accidentally unpublish an already-live article.
  Future<void> _autoSaveDraft() async {
    if (_type == null) return; // chooser still showing — nothing to save yet
    if (_saving || _autoSaving) return;
    final plainText = _type == MagazineArticleType.text
        ? _quillCtrl.document.toPlainText().trim()
        : _descriptionCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    if (title.isEmpty && plainText.isEmpty) return;

    final signature = '$title|${_descriptionCtrl.text.trim()}|$plainText|$_category|${_tags.join(",")}|${_type!.name}';
    if (signature == _lastAutoSaveSignature) return;

    _autoSaving = true;
    final ok = await _persist(publish: _workingArticle.published);
    _autoSaving = false;
    if (!mounted || !ok) return;
    _lastAutoSaveSignature = signature;
    setState(() => _lastAutoSavedAt = DateTime.now());
  }

  /// Shared create-or-update path for both the manual Save/Publish buttons
  /// and the autosave timer. Mutates `_workingArticle` in place.
  Future<bool> _persist({required bool publish}) async {
    final repo = MagazineRepository.instance;
    final type = _type ?? MagazineArticleType.text;
    _workingArticle.title = _titleCtrl.text.trim();
    _workingArticle.description = _descriptionCtrl.text.trim();
    _workingArticle.type = type;

    if (type == MagazineArticleType.text) {
      _workingArticle.body = _quillCtrl.document.toPlainText().trim();
      _workingArticle.bodyDelta = jsonEncode(_quillCtrl.document.toDelta().toJson());
    } else {
      // Image/Video/Audio articles have no rich editor — the description
      // field doubles as the body, and the reader's existing plain-text
      // fallback (see bodyDelta's doc comment) renders it as-is.
      _workingArticle.body = _descriptionCtrl.text.trim();
      _workingArticle.bodyDelta = null;
    }
    _workingArticle.category = _category;
    _workingArticle.tags = _tags;
    _workingArticle.published = publish;

    if (_workingArticle.id.isEmpty) {
      final result = await repo.publish(_workingArticle);
      if (result is Failure<String>) {
        if (mounted) setState(() => _error = result.message);
        return false;
      }
      // id is final — rebuild with the id Firestore assigned.
      _workingArticle = MagazineArticle(
        id: (result as Success<String>).value,
        authorId: _workingArticle.authorId, authorName: _workingArticle.authorName,
        authorPhotoUrl: _workingArticle.authorPhotoUrl,
        title: _workingArticle.title, body: _workingArticle.body,
        description: _workingArticle.description,
        bodyDelta: _workingArticle.bodyDelta,
        type: _workingArticle.type,
        category: _workingArticle.category, tags: _workingArticle.tags,
        schoolId: _workingArticle.schoolId,
        thumbnailUrl: _workingArticle.thumbnailUrl,
        mediaUrl: _workingArticle.mediaUrl,
        published: _workingArticle.published,
      );
    }

    if (_pickedCover != null) {
      final uploadResult = await repo.uploadThumbnail(
          articleId: _workingArticle.id, imageFile: _pickedCover!);
      if (uploadResult is Success<String>) {
        _workingArticle.thumbnailUrl = uploadResult.value;
        _pickedCover = null; // consumed — don't re-upload the same file every autosave tick
      } else if (uploadResult is Failure) {
        if (mounted) setState(() => _error = (uploadResult as Failure).message);
        return false;
      }
    }

    if (_pickedMedia != null) {
      final ext = _pickedMediaName?.contains('.') == true
          ? _pickedMediaName!.split('.').last
          : (type == MagazineArticleType.video ? 'mp4' : 'mp3');
      final uploadResult = await repo.uploadMedia(
          articleId: _workingArticle.id, file: _pickedMedia!, extension: ext);
      if (uploadResult is Success<String>) {
        _workingArticle.mediaUrl = uploadResult.value;
        _pickedMedia = null; // consumed — don't re-upload every autosave tick
      } else if (uploadResult is Failure) {
        if (mounted) setState(() => _error = (uploadResult as Failure).message);
        return false;
      }
    }

    final saveResult = await repo.update(_workingArticle);
    if (saveResult is Failure) {
      final message = saveResult.message;
      if (mounted) setState(() => _error = message);
      return false;
    }
    return true;
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

  String get _pageTitle {
    if (!_isNew) return 'Edit Article';
    switch (_type!) {
      case MagazineArticleType.text:  return 'Write an Article';
      case MagazineArticleType.image: return 'New Image';
      case MagazineArticleType.video: return 'New Video';
      case MagazineArticleType.audio: return 'New Audio';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isNew && _type == null) return _buildTypePicker();
    return _buildComposer(_type!);
  }

  Widget _buildTypePicker() {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Create New', style: AppText.title),
      ),
      body: AppBackground(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What would you like to create?', style: AppText.bodySm.copyWith(color: C.txt2)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              ContentTypeTile(
                icon: Icons.article_outlined, color: C.primary, title: 'Text',
                subtitle: 'Articles, essays & stories',
                onTap: () => setState(() => _type = MagazineArticleType.text),
              ),
              ContentTypeTile(
                icon: Icons.videocam_outlined, color: C.red, title: 'Video',
                subtitle: 'Upload, edit & share videos',
                onTap: () => setState(() => _type = MagazineArticleType.video),
              ),
              ContentTypeTile(
                icon: Icons.mic_none_rounded, color: C.grn, title: 'Audio',
                subtitle: 'Record or upload audio content',
                onTap: () => setState(() => _type = MagazineArticleType.audio),
              ),
              ContentTypeTile(
                icon: Icons.image_outlined, color: C.org, title: 'Image',
                subtitle: 'Upload and share images',
                onTap: () => setState(() => _type = MagazineArticleType.image),
              ),
            ],
          ),
        ]),
      )),
    );
  }

  Widget _buildComposer(MagazineArticleType type) {
    final isText = type == MagazineArticleType.text;
    final isMedia = type == MagazineArticleType.video || type == MagazineArticleType.audio;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        leading: _isNew
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _type = null),
              )
            : null,
        title: Text(_pageTitle, style: AppText.title),
        actions: [
          if (!_isNew)
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: C.red), onPressed: _delete),
        ],
      ),
      body: AppBackground(child: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ComposerCoverPicker(
                pickedFile: _pickedCover,
                existingUrl: widget.existing?.thumbnailUrl,
                onTap: _pickCover,
                label: type == MagazineArticleType.image
                    ? 'Upload image'
                    : (isMedia ? 'Add thumbnail (optional)' : 'Add cover image'),
              ),
              const SizedBox(height: 16),
              CategoryChipSelector(
                options: kArticleCategories, selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 14),
              TagMultiSelect(
                selected: _tags, suggestions: kArticleTags,
                onChanged: (next) => setState(() => _tags = next),
              ),
              const SizedBox(height: 20),
              ComposerField(controller: _titleCtrl, hint: 'Add a compelling title…', style: AppText.h1, maxLength: 100),
              const SizedBox(height: 10),
              ComposerField(
                controller: _descriptionCtrl,
                hint: isText ? 'Write a short summary (optional)' : 'Write a caption or description…',
                style: AppText.bodySm.copyWith(color: C.txt2),
                maxLines: isText ? 2 : 4,
                maxLength: 160,
              ),
              if (isMedia) ...[
                const SizedBox(height: 14),
                _buildMediaPicker(type),
              ],
              if (isText) ...[
                const SizedBox(height: 12),
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
              ],
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
        if (isText)
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
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_lastAutoSavedAt != null) ...[
                Text('Autosaved ${_lastAutoSavedAt!.hour.toString().padLeft(2, '0')}:'
                    '${_lastAutoSavedAt!.minute.toString().padLeft(2, '0')}',
                    style: AppText.caption.copyWith(fontSize: 10.5, color: C.muted)),
                const SizedBox(height: 6),
              ],
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
            ]),
          ),
        ),
      ])),
    );
  }

  Widget _buildMediaPicker(MagazineArticleType type) {
    final isVideo = type == MagazineArticleType.video;
    final hasFile = _pickedMedia != null || widget.existing?.mediaUrl != null;
    final fileLabel = _pickedMediaName ?? (widget.existing?.mediaUrl != null ? 'Uploaded ${isVideo ? "video" : "audio"} on file' : null);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: _pickMedia,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isVideo ? C.redb : C.grnb,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: C.bdr),
          ),
          child: Row(children: [
            Icon(isVideo ? Icons.videocam_rounded : Icons.mic_rounded, color: isVideo ? C.red : C.grn),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  hasFile ? (fileLabel ?? 'File selected') : 'Choose ${isVideo ? "video" : "audio"} file',
                  style: AppText.title.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(isVideo ? 'MP4, MOV, AVI' : 'MP3, WAV, M4A', style: AppText.caption),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      ),
    );
  }
}

// lib/features/magazine/article_composer_page.dart
// Create/edit an article: title, cover image, category, body, draft vs
// published.
//
// Body is a real rich-text editor (flutter_quill) so writers can embed
// images inline within the text — not just a single cover-image field —
// mirroring the same flutter_quill_extensions wiring already used by
// CourseComposerPage/CourseReaderPage.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
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

    final wasAlreadyPublished = _workingArticle.published;
    final ok = await _persist(publish: publish);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;

    // Notify followers on the transition into "published" — not on every
    // draft save, and not a second time if it was already published.
    if (publish && !wasAlreadyPublished) {
        // Followers are notified server-side (trg_notify_on_article_published).
    }

    showToast(context, publish ? 'Article published.' : 'Draft saved.');
    Navigator.of(context).pop();
  }

  /// Periodic silent save so in-progress work survives a crash/kill —
  /// deliberately never flips `published` (only the explicit Save
  /// Draft/Publish buttons do that), so autosaving mid-edit can't
  /// accidentally unpublish an already-live article.
  Future<void> _autoSaveDraft() async {
    if (_saving || _autoSaving) return;
    final plainText = _quillCtrl.document.toPlainText().trim();
    final title = _titleCtrl.text.trim();
    if (title.isEmpty && plainText.isEmpty) return;

    final signature = '$title|${_descriptionCtrl.text.trim()}|$plainText|$_category|${_tags.join(",")}';
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
    _workingArticle.title = _titleCtrl.text.trim();
    _workingArticle.description = _descriptionCtrl.text.trim();
    _workingArticle.body = _quillCtrl.document.toPlainText().trim();
    _workingArticle.bodyDelta = jsonEncode(_quillCtrl.document.toDelta().toJson());
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
        category: _workingArticle.category, tags: _workingArticle.tags,
        schoolId: _workingArticle.schoolId,
        thumbnailUrl: _workingArticle.thumbnailUrl,
        published: _workingArticle.published,
      );
    }

    if (_pickedCover != null) {
      final uploadResult = await repo.uploadThumbnail(
          articleId: _workingArticle.id, imageFile: _pickedCover!);
      if (uploadResult is Success<String>) {
        _workingArticle.thumbnailUrl = uploadResult.value;
        _pickedCover = null; // consumed — don't re-upload the same file every autosave tick
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



  Future<void> _delete() async {
    if (widget.existing == null) return;
    final ac = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete article?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: TextStyle(color: ac.red))),
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(_isNew ? 'Write an Article' : 'Edit Article', style: AppText.title),
        actions: [
          if (!_isNew)
            IconButton(icon: Icon(Icons.delete_outline_rounded, color: ac.red), onPressed: _delete),
        ],
      ),
      body: AppBackground(child: Column(children: [
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
                      color: ac.navy, borderRadius: BorderRadius.circular(Rad.md),
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
                          color: active ? ac.primary : ac.surf2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? ac.primary : ac.bdr),
                        ),
                        child: Text(cat, style: AppText.caption.copyWith(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: active ? Colors.white : ac.txt2)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TagMultiSelect(
                selected: _tags,
                suggestions: kArticleTags,
                onChanged: (next) => setState(() => _tags = next),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleCtrl,
                style: AppText.h1,
                decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _descriptionCtrl,
                style: AppText.bodySm.copyWith(color: ac.txt2),
                maxLines: 2,
                maxLength: 160,
                decoration: const InputDecoration(
                  hintText: 'Short summary shown on feed cards (optional)',
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
              Divider(color: ac.bdr2),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 280),
                decoration: BoxDecoration(
                    color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
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
                  decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm)),
                  child: Text(_error!, style: AppText.bodySm.copyWith(color: ac.red)),
                ),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: ac.surf, border: Border(top: BorderSide(color: ac.bdr))),
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
                    style: AppText.caption.copyWith(fontSize: 10.5, color: ac.muted)),
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
}

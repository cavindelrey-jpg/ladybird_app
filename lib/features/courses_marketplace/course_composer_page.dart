// lib/features/courses_marketplace/course_composer_page.dart
// Create/edit a marketplace course — now a real rich text editor
// (flutter_quill) instead of a plain TextField, so bold/italic/headings/
// lists/inline images are all real formatting, not just typed characters.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../core/docx_parser.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

import '../../widgets/app_background.dart';
class CourseComposerPage extends StatefulWidget {
  final AppUser user;
  final PublicCourse? existing;
  const CourseComposerPage({super.key, required this.user, this.existing});

  @override
  State<CourseComposerPage> createState() => _CourseComposerPageState();
}

class _CourseComposerPageState extends State<CourseComposerPage> {
  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late String _category = widget.existing?.category ?? kCourseCategories.first;
  late List<String> _tags = List<String>.from(widget.existing?.tags ?? const []);
  late final quill.QuillController _quillCtrl = _initQuillController();
  final _editorFocusNode = FocusNode();
  final _editorScrollCtrl = ScrollController();

  /// The course this composer is persisting to — see the identical field on
  /// ArticleComposerPage for why this has to be mutable state rather than a
  /// value rebuilt from `widget.existing` on every save.
  late PublicCourse _workingCourse = widget.existing ?? PublicCourse(
    id: '', creatorId: widget.user.id, creatorName: widget.user.name,
    creatorPhotoUrl: widget.user.photoUrl, title: '',
  );

  File? _pickedCover;
  bool _saving = false;
  bool _autoSaving = false;
  bool _importing = false;
  String? _error;
  DateTime? _lastAutoSavedAt;
  String _lastAutoSaveSignature = '';
  Timer? _autoSaveTimer;

  bool get _isNew => widget.existing == null;
  bool get _canImportDocx => widget.user.isSuperAdmin;

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
    _descCtrl.dispose();
    _quillCtrl.dispose();
    _editorFocusNode.dispose();
    _editorScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedCover = File(picked.path));
  }

  Future<void> _importDocx() async {
    HapticFeedback.mediumImpact();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['docx'], withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      if (mounted) showToast(context, 'Could not read that file.', isError: true);
      return;
    }

    setState(() => _importing = true);
    try {
      // Zip-decode + XML-parse is CPU-bound and was previously running
      // straight on the UI isolate — a large .docx froze the whole app
      // (no frames, no input) until it finished. compute() runs it on a
      // background isolate instead.
      final parsed = await compute(DocxParser.parse, bytes);
      final delta = quill.Document.fromJson(jsonDecode(parsed.deltaJson));
      setState(() {
        _quillCtrl.document = delta;
        _importing = false;
      });
      if (parsed.warnings.isNotEmpty && mounted) {
        showToast(context, parsed.warnings.join(' '));
      } else if (mounted) {
        showToast(context, 'Document imported — review before publishing.');
      }
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) showToast(context, 'Could not convert this file: $e', isError: true);
    }
  }

  Future<void> _save({required bool publish}) async {
    final plainText = _quillCtrl.document.toPlainText().trim();
    if (_titleCtrl.text.trim().isEmpty || plainText.isEmpty) {
      setState(() => _error = 'Title and body are required.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _saving = true; _error = null; });

    final ok = await _persist(publish: publish);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;

    showToast(context, publish ? 'Course published.' : 'Draft saved.');
    Navigator.of(context).pop();
  }

  /// Periodic silent save so in-progress work survives a crash/kill —
  /// deliberately never flips `published` (only the explicit Save
  /// Draft/Publish buttons do that), so autosaving mid-edit can't
  /// accidentally unpublish an already-live course.
  Future<void> _autoSaveDraft() async {
    if (_saving || _autoSaving) return;
    final plainText = _quillCtrl.document.toPlainText().trim();
    final title = _titleCtrl.text.trim();
    if (title.isEmpty && plainText.isEmpty) return;

    final signature = '$title|${_descCtrl.text.trim()}|$plainText|$_category|${_tags.join(",")}';
    if (signature == _lastAutoSaveSignature) return;

    _autoSaving = true;
    final ok = await _persist(publish: _workingCourse.published);
    _autoSaving = false;
    if (!mounted || !ok) return;
    _lastAutoSaveSignature = signature;
    setState(() => _lastAutoSavedAt = DateTime.now());
  }

  /// Shared create-or-update path for both the manual Save/Publish buttons
  /// and the autosave timer. Mutates `_workingCourse` in place.
  Future<bool> _persist({required bool publish}) async {
    final repo = PublicCourseRepository.instance;
    _workingCourse.title = _titleCtrl.text.trim();
    _workingCourse.description = _descCtrl.text.trim();
    _workingCourse.body = _quillCtrl.document.toPlainText().trim();
    _workingCourse.bodyDelta = jsonEncode(_quillCtrl.document.toDelta().toJson());
    _workingCourse.category = _category;
    _workingCourse.tags = _tags;
    _workingCourse.published = publish;

    if (_workingCourse.id.isEmpty) {
      final result = await repo.create(_workingCourse);
      if (result is Failure<String>) {
        if (mounted) setState(() => _error = result.message);
        return false;
      }
      _workingCourse = PublicCourse(
        id: (result as Success<String>).value,
        creatorId: _workingCourse.creatorId, creatorName: _workingCourse.creatorName,
        creatorPhotoUrl: _workingCourse.creatorPhotoUrl,
        title: _workingCourse.title, description: _workingCourse.description,
        body: _workingCourse.body, bodyDelta: _workingCourse.bodyDelta,
        category: _workingCourse.category, tags: _workingCourse.tags,
        coverImageUrl: _workingCourse.coverImageUrl,
        published: _workingCourse.published,
      );
    }

    if (_pickedCover != null) {
      final upload = await repo.uploadCover(courseId: _workingCourse.id, imageFile: _pickedCover!);
      if (upload is Success<String>) {
        _workingCourse.coverImageUrl = upload.value;
        _pickedCover = null; // consumed — don't re-upload the same file every autosave tick
      }
    }

    final saveResult = await repo.update(_workingCourse);
    if (saveResult is Failure) {
      final message = saveResult.message;
      if (mounted) setState(() => _error = message);
      return false;
    }
    return true;
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete course?'),
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
      await PublicCourseRepository.instance.delete(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<String?> _onEmbedImagePick(File file) async {
    final courseId = widget.existing?.id ?? 'draft_${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}';
    final result = await PublicCourseRepository.instance.uploadCover(
        courseId: '${courseId}_inline_${DateTime.now().millisecondsSinceEpoch}', imageFile: file);
    if (result is Success<String>) return result.value;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text(_isNew ? 'Create Course' : 'Edit Course', style: AppText.title),
        actions: [
          if (_canImportDocx)
            IconButton(
              icon: _importing
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded, color: C.txt),
              tooltip: 'Import Word document (Super Admin)',
              onPressed: _importing ? null : _importDocx,
            ),
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
                existingUrl: widget.existing?.coverImageUrl,
                onTap: _pickCover,
                height: 150,
              ),
              if (_canImportDocx) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(Rad.sm)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: C.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        'As Super Admin, you can import a .docx to fill the editor below — '
                            'review and add any diagrams before publishing.',
                        style: AppText.caption.copyWith(fontSize: 11, color: C.primary))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              CategoryChipSelector(
                options: kCourseCategories, selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 14),
              TagMultiSelect(
                selected: _tags,
                suggestions: kCourseTags,
                onChanged: (next) => setState(() => _tags = next),
              ),
              const SizedBox(height: 20),
              ComposerField(controller: _titleCtrl, hint: 'Course title', style: AppText.h1, maxLength: 100),
              const SizedBox(height: 10),
              ComposerField(
                controller: _descCtrl,
                hint: 'Short description (shown on cards)…',
                style: AppText.bodySm.copyWith(color: C.txt),
                maxLines: 2, maxLength: 160,
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(minHeight: 320),
                decoration: BoxDecoration(
                    color: C.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: C.bdr)),
                padding: const EdgeInsets.all(8),
                child: quill.QuillEditor.basic(
                  controller: _quillCtrl,
                  focusNode: _editorFocusNode,
                  scrollController: _editorScrollCtrl,
                  config: quill.QuillEditorConfig(
                    placeholder: 'Course content…',
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
                  child: SecondaryBtn(label: 'Save Draft',
                      onTap: _saving ? () {} : () => _save(publish: false)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryBtn(label: 'Publish', loading: _saving,
                      onTap: () => _save(publish: true)),
                ),
              ]),
            ]),
          ),
        ),
      ])),
    );
  }
}
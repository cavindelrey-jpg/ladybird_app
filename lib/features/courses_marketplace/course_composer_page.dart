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
import '../../theme/app_colors.dart';
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

  // ── Curriculum placement ──────────────────────────────────────────
  // Subject/Level/Topic are free text with autocomplete against what
  // already exists (see HierarchyPicker); Difficulty is a fixed picker.
  // None of this is required — an author can skip it and the course
  // just won't appear in the hierarchy browser, only the flat feed.
  late String _subject = widget.existing?.subject ?? '';
  late String _level = widget.existing?.level ?? '';
  late String _topic = widget.existing?.topic ?? '';
  late String _difficulty = widget.existing?.difficulty ?? '';
  late List<String> _prerequisiteIds = List<String>.from(widget.existing?.prerequisiteIds ?? const []);

  /// Icons picked while creating a brand-new Subject/Level/Topic this
  /// session — empty means "don't touch the existing assignment".
  String _newSubjectIcon = '';
  String _newLevelIcon = '';
  String _newTopicIcon = '';

  /// Photos picked while creating a brand-new Subject/Level/Topic this
  /// session — uploaded on save, mutually exclusive with the emoji above.
  File? _newSubjectImage;
  File? _newLevelImage;
  File? _newTopicImage;

  /// All existing node->look assignments, loaded once; chip display
  /// only needs the slice for the current scope, computed on the fly.
  Map<String, CurriculumIcon> _iconMap = {};

  List<String> _subjectSuggestions = [];
  List<String> _levelSuggestions = [];
  List<String> _topicSuggestions = [];

  /// The existing lesson sequence for the current Subject/Level/Topic —
  /// used both for the Before/Between/After placement picker and the
  /// prerequisites picker. Excludes this course itself when editing.
  List<PublicCourse> _topicSequence = [];
  bool _loadingSequence = false;

  /// null = not placed yet / at the very start; otherwise the index in
  /// `_topicSequence` this lesson comes immediately after. Length of
  /// `_topicSequence` means "at the end".
  int? _placementAfterIndex;
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
    _loadSubjectSuggestions();
    _loadIconMap();
    if (_subject.isNotEmpty) _loadLevelSuggestions();
    if (_level.isNotEmpty) _loadTopicSuggestions();
    if (widget.existing?.hasCurriculumPlacement ?? false) _loadTopicSequence();
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

  Future<void> _loadIconMap() async {
    final icons = await PublicCourseRepository.instance.curriculumIconsOnce();
    if (mounted) setState(() => _iconMap = icons);
  }

  /// Subject label -> look, scoped to the current category.
  Map<String, CurriculumIcon> get _subjectIcons => {
        for (final s in _subjectSuggestions)
          s: _iconMap[PublicCourseRepository.subjectIconKey(_category, s)] ?? CurriculumIcon.none,
      };

  /// Level label -> look, scoped to the current category+subject.
  Map<String, CurriculumIcon> get _levelIcons => {
        for (final l in _levelSuggestions)
          l: _iconMap[PublicCourseRepository.levelIconKey(_category, _subject, l)] ?? CurriculumIcon.none,
      };

  /// Topic label -> look, scoped to the current category+subject+level.
  Map<String, CurriculumIcon> get _topicIcons => {
        for (final t in _topicSuggestions)
          t: _iconMap[PublicCourseRepository.topicIconKey(_category, _subject, _level, t)] ?? CurriculumIcon.none,
      };

  Future<void> _loadSubjectSuggestions() async {
    final subjects = await PublicCourseRepository.instance.subjectsIn(_category);
    if (mounted) setState(() => _subjectSuggestions = subjects);
  }

  Future<void> _loadLevelSuggestions() async {
    if (_subject.trim().isEmpty) {
      setState(() => _levelSuggestions = []);
      return;
    }
    final levels = await PublicCourseRepository.instance.levelsIn(_category, _subject.trim());
    if (mounted) setState(() => _levelSuggestions = levels);
  }

  Future<void> _loadTopicSuggestions() async {
    if (_subject.trim().isEmpty || _level.trim().isEmpty) {
      setState(() => _topicSuggestions = []);
      return;
    }
    final topics = await PublicCourseRepository.instance
        .topicsIn(_category, _subject.trim(), _level.trim());
    if (mounted) setState(() => _topicSuggestions = topics);
  }

  /// Loads the sibling lessons already in this topic — the source of
  /// truth for both the placement picker and the prerequisites list.
  /// Re-run whenever Subject/Level/Topic changes.
  Future<void> _loadTopicSequence() async {
    if (_subject.trim().isEmpty || _level.trim().isEmpty || _topic.trim().isEmpty) {
      setState(() { _topicSequence = []; _placementAfterIndex = null; });
      return;
    }
    setState(() => _loadingSequence = true);
    final sequence = await PublicCourseRepository.instance.topicSequence(
        _category, _subject.trim(), _level.trim(), _topic.trim());
    sequence.removeWhere((c) => c.id == _workingCourse.id && c.id.isNotEmpty);
    if (!mounted) return;
    setState(() {
      _topicSequence = sequence;
      _loadingSequence = false;
      // Default to "at the end" for a new lesson in this topic.
      _placementAfterIndex ??= sequence.length;
      if (_placementAfterIndex! > sequence.length) _placementAfterIndex = sequence.length;
      // A prerequisite that's no longer in this topic (topic changed) is dropped.
      _prerequisiteIds.removeWhere((id) => !sequence.any((c) => c.id == id));
    });
  }

  void _onSubjectChanged(String v) {
    setState(() { _subject = v; _level = ''; _topic = ''; _newLevelIcon = ''; _newTopicIcon = ''; _newLevelImage = null; _newTopicImage = null; });
    _loadLevelSuggestions();
    _loadTopicSuggestions();
    _loadTopicSequence();
  }

  void _onLevelChanged(String v) {
    setState(() { _level = v; _topic = ''; _newTopicIcon = ''; _newTopicImage = null; });
    _loadTopicSuggestions();
    _loadTopicSequence();
  }

  void _onTopicChanged(String v) {
    setState(() => _topic = v);
    _loadTopicSequence();
  }

  Future<void> _pickCover() async {
    HapticFeedback.selectionClick();
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
    _workingCourse.subject = _subject.trim();
    _workingCourse.level = _level.trim();
    _workingCourse.topic = _topic.trim();
    _workingCourse.difficulty = _difficulty;
    _workingCourse.prerequisiteIds = _prerequisiteIds;

    // Compute the hidden sequence position from the Before/Between/After
    // choice — the author never types a number directly (see the
    // repository's positionAtStart/positionBetween/positionAtEnd).
    if (_workingCourse.hasCurriculumPlacement) {
      final repo = PublicCourseRepository.instance;
      final afterIndex = _placementAfterIndex ?? _topicSequence.length;
      if (afterIndex <= 0) {
        _workingCourse.order = repo.positionAtStart(_topicSequence);
      } else if (afterIndex >= _topicSequence.length) {
        _workingCourse.order = repo.positionAtEnd(_topicSequence);
      } else {
        _workingCourse.order = repo.positionBetween(
            _topicSequence[afterIndex - 1], _topicSequence[afterIndex]);
      }
    }

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
        subject: _workingCourse.subject, level: _workingCourse.level,
        topic: _workingCourse.topic, difficulty: _workingCourse.difficulty,
        order: _workingCourse.order, prerequisiteIds: _workingCourse.prerequisiteIds,
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
    await _persistNewIcons(repo);
    return true;
  }

  /// Save whatever look (emoji or photo) was picked while creating a
  /// new Subject/Level/Topic this session. Doesn't touch nodes the
  /// author didn't change anything for.
  Future<void> _persistNewIcons(PublicCourseRepository repo) async {
    if (_subject.isNotEmpty) {
      await _persistOneIcon(repo,
          key: PublicCourseRepository.subjectIconKey(_category, _subject),
          emoji: _newSubjectIcon, image: _newSubjectImage);
    }
    if (_subject.isNotEmpty && _level.isNotEmpty) {
      await _persistOneIcon(repo,
          key: PublicCourseRepository.levelIconKey(_category, _subject, _level),
          emoji: _newLevelIcon, image: _newLevelImage);
    }
    if (_subject.isNotEmpty && _level.isNotEmpty && _topic.isNotEmpty) {
      await _persistOneIcon(repo,
          key: PublicCourseRepository.topicIconKey(_category, _subject, _level, _topic),
          emoji: _newTopicIcon, image: _newTopicImage);
    }
  }

  Future<void> _persistOneIcon(PublicCourseRepository repo,
      {required String key, required String emoji, required File? image}) async {
    if (emoji.isEmpty && image == null) return;
    String imageUrl = '';
    if (image != null) {
      final upload = await repo.uploadCurriculumNodeImage(key: key, imageFile: image);
      if (upload is Success<String>) imageUrl = upload.value;
    }
    await repo.setCurriculumIcon(key, emoji: emoji, imageUrl: imageUrl);
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final ac = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete course?'),
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(_isNew ? 'Create Course' : 'Edit Course', style: AppText.title),
        actions: [
          if (_canImportDocx)
            IconButton(
              icon: _importing
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.upload_file_rounded, color: ac.txt),
              tooltip: 'Import Word document (Super Admin)',
              onPressed: _importing ? null : _importDocx,
            ),
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
                    height: 140, width: double.infinity,
                    decoration: BoxDecoration(
                      color: ac.navy, borderRadius: BorderRadius.circular(Rad.md),
                      image: _pickedCover != null
                          ? DecorationImage(image: FileImage(_pickedCover!), fit: BoxFit.cover)
                          : (widget.existing?.coverImageUrl != null
                          ? DecorationImage(image: NetworkImage(widget.existing!.coverImageUrl!), fit: BoxFit.cover)
                          : null),
                    ),
                    child: (_pickedCover == null && widget.existing?.coverImageUrl == null)
                        ? const Center(child: Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 32))
                        : null,
                  ),
                ),
              ),
              if (_canImportDocx) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.sm)),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: ac.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        'As Super Admin, you can import a .docx to fill the editor below — '
                            'review and add any diagrams before publishing.',
                        style: AppText.caption.copyWith(fontSize: 11, color: ac.primary))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: kCourseCategories.map((cat) {
                  final active = cat == _category;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _category = cat);
                        _loadSubjectSuggestions();
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
                suggestions: kCourseTags,
                onChanged: (next) => setState(() => _tags = next),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr2)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Where does this lesson live?', style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Optional — place it in the curriculum tree so students can browse to it '
                      'even if they never search for it.',
                      style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2)),
                  const SizedBox(height: 12),
                  HierarchyPicker(
                    label: 'Subject',
                    value: _subject, options: _subjectSuggestions,
                    icons: _subjectIcons,
                    onIconPicked: (icon) => setState(() => _newSubjectIcon = icon),
                    onImagePicked: (file) => setState(() => _newSubjectImage = file),
                    pickedImage: _newSubjectImage,
                    onChanged: _onSubjectChanged,
                  ),
                  const SizedBox(height: 10),
                  HierarchyPicker(
                    label: 'Curriculum / Level',
                    value: _level, options: _levelSuggestions,
                    icons: _levelIcons,
                    onIconPicked: (icon) => setState(() => _newLevelIcon = icon),
                    onImagePicked: (file) => setState(() => _newLevelImage = file),
                    pickedImage: _newLevelImage,
                    onChanged: _onLevelChanged,
                  ),
                  const SizedBox(height: 10),
                  HierarchyPicker(
                    label: 'Unit / Topic',
                    value: _topic, options: _topicSuggestions,
                    icons: _topicIcons,
                    onIconPicked: (icon) => setState(() => _newTopicIcon = icon),
                    onImagePicked: (file) => setState(() => _newTopicImage = file),
                    pickedImage: _newTopicImage,
                    onChanged: _onTopicChanged,
                  ),
                  const SizedBox(height: 12),
                  Text('Difficulty', style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.txt2)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: kDifficultyLevels.map((d) {
                    final active = d == _difficulty;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _difficulty = active ? '' : d);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? ac.primary : ac.surf2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: active ? ac.primary : ac.bdr),
                          ),
                          child: Text(d, style: AppText.caption.copyWith(
                              fontSize: 11.5, fontWeight: FontWeight.w700,
                              color: active ? Colors.white : ac.txt2)),
                        ),
                      ),
                    );
                  }).toList()),
                ]),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleCtrl, style: AppText.h1,
                decoration: const InputDecoration(hintText: 'Course title', border: InputBorder.none),
              ),
              Divider(color: ac.bdr2),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl, style: AppText.bodySm.copyWith(color: ac.txt),
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'Short description (shown on cards)…', border: InputBorder.none),
              ),
              const SizedBox(height: 12),
              Divider(color: ac.bdr2),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 320),
                decoration: BoxDecoration(
                    color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
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
              if (_topic.trim().isNotEmpty && _level.trim().isNotEmpty &&
                  _subject.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _PlacementPicker(
                  sequence: _topicSequence,
                  loading: _loadingSequence,
                  afterIndex: _placementAfterIndex ?? _topicSequence.length,
                  onChanged: (i) => setState(() => _placementAfterIndex = i),
                ),
                if (_topicSequence.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _PrerequisitesPicker(
                    sequence: _topicSequence,
                    selected: _prerequisiteIds,
                    onChanged: (next) => setState(() => _prerequisiteIds = next),
                  ),
                ],
              ],
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

/// "Where does this lesson belong?" — the author picks a position
/// relative to the existing sequence in this topic; the hidden
/// numeric `order` is computed from that choice, never typed directly.
class _PlacementPicker extends StatelessWidget {
  final List<PublicCourse> sequence;
  final bool loading;
  final int afterIndex; // 0..sequence.length
  final ValueChanged<int> onChanged;
  const _PlacementPicker({
    required this.sequence, required this.loading, required this.afterIndex, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: ShimmerLine(width: 220, height: 14));
    }
    if (sequence.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm)),
        child: Text('This is the first lesson in this topic.', style: AppText.caption.copyWith(color: ac.txt2)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Where does this lesson belong?', style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...List.generate(sequence.length + 1, (i) {
          final String label;
          if (i == 0) {
            label = 'Before "${sequence.first.title}"';
          } else if (i == sequence.length) {
            label = 'After "${sequence.last.title}"';
          } else {
            label = 'Between "${sequence[i - 1].title}" and "${sequence[i].title}"';
          }
          return RadioListTile<int>(
            value: i,
            groupValue: afterIndex,
            onChanged: (v) { if (v != null) onChanged(v); },
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: ac.primary,
            title: Text(label, style: AppText.bodySm),
          );
        }),
      ]),
    );
  }
}

/// Purely advisory "read these first" links, picked from lessons
/// already in the same topic sequence.
class _PrerequisitesPicker extends StatelessWidget {
  final List<PublicCourse> sequence;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  const _PrerequisitesPicker({required this.sequence, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prerequisites (optional)', style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.txt2)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: sequence.map((c) {
            final active = selected.contains(c.id);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.selectionClick();
                  final next = List<String>.from(selected);
                  active ? next.remove(c.id) : next.add(c.id);
                  onChanged(next);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? ac.goldBg : ac.surf2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? ac.gold : ac.bdr),
                  ),
                  child: Text(c.title, style: AppText.caption.copyWith(
                      fontSize: 11.5, fontWeight: FontWeight.w700,
                      color: active ? ac.gold : ac.txt2)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
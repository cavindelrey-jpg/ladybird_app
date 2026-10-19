// lib/features/courses_marketplace/lesson_composer_page.dart
// Create/edit one lesson inside a course — video URL OR quill text
// (mutually exclusive, same rule lesson_reader_page.dart renders by), plus
// a cover thumbnail and its position in the course's lesson sequence.
//
// Video stays a pasted URL, not an uploaded file — same as the course-level
// field this replaces (course_composer_page.dart's old _videoUrlCtrl).
// Attaching one isn't gated for creators (see that field's original
// comment: "any signed-in creator may attach one") — only READERS need
// Premium Gold to watch it (see lesson_reader_page.dart's _LockedVideoCard,
// core/feature_access.dart#AppFeature.coursesVideoLessons).
// ignore_for_file: deprecated_member_use

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
import '../../models/course_lesson.dart';
import '../../core/docx_parser.dart';
import '../../core/result.dart';
import '../../repositories/course_lesson_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/formula_embed_builder.dart';

class LessonComposerPage extends StatefulWidget {
  final AppUser user;
  final String courseId;
  final CourseLesson? existing;

  /// The course's other lessons (excluding [existing]) — used for the
  /// Before/Between/After placement picker, same gap-of-100 pattern as
  /// course placement within a topic.
  final List<CourseLesson> existingSequence;

  const LessonComposerPage({
    super.key, required this.user, required this.courseId, this.existing, this.existingSequence = const [],
  });

  @override
  State<LessonComposerPage> createState() => _LessonComposerPageState();
}

class _LessonComposerPageState extends State<LessonComposerPage> {
  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final _videoUrlCtrl = TextEditingController(text: widget.existing?.videoUrl ?? '');
  late final quill.QuillController _quillCtrl = _initQuillController();

  File? _pickedCover;
  late String? _existingCoverUrl = widget.existing?.coverImageUrl;

  late final List<CourseLesson> _sequence = List<CourseLesson>.from(widget.existingSequence)
    ..removeWhere((l) => l.id == widget.existing?.id);
  late int _placementAfterIndex = _sequence.length;

  bool _saving = false;
  bool _importing = false;
  String? _error;

  bool get _isNew => widget.existing == null;
  bool get _canImportDocx => widget.user.isSuperAdmin;
  bool get _hasVideo => _videoUrlCtrl.text.trim().isNotEmpty;

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
    _titleCtrl.addListener(() => setState(() {}));
    _videoUrlCtrl.addListener(() => setState(() {}));
    final existing = widget.existing;
    if (existing != null) {
      final index = widget.existingSequence.indexWhere((l) => l.id == existing.id);
      _placementAfterIndex = index > 0 ? index : 0;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _videoUrlCtrl.dispose();
    _quillCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    HapticFeedback.selectionClick();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() { _pickedCover = File(picked.path); _existingCoverUrl = null; });
  }

  Future<void> _importDocx() async {
    HapticFeedback.mediumImpact();
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['docx'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      if (mounted) showToast(context, 'Could not read that file.', isError: true);
      return;
    }
    setState(() => _importing = true);
    try {
      final parsed = await compute(DocxParser.parse, bytes);
      final delta = quill.Document.fromJson(jsonDecode(parsed.deltaJson));
      setState(() { _quillCtrl.document = delta; _importing = false; });
      if (mounted) showToast(context, 'Document imported — review before saving.');
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) showToast(context, 'Could not convert this file: $e', isError: true);
    }
  }

  double _computeOrder() {
    final repo = CourseLessonRepository.instance;
    if (_sequence.isEmpty) return repo.positionAtStart(_sequence);
    if (_placementAfterIndex <= 0) return repo.positionAtStart(_sequence);
    if (_placementAfterIndex >= _sequence.length) return repo.positionAtEnd(_sequence);
    return repo.positionBetween(_sequence[_placementAfterIndex - 1], _sequence[_placementAfterIndex]);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final plainText = _quillCtrl.document.toPlainText().trim();
    final videoUrl = _videoUrlCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (videoUrl.isEmpty && plainText.isEmpty) {
      setState(() => _error = 'Add a video URL or write some content for this lesson.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _saving = true; _error = null; });

    final repo = CourseLessonRepository.instance;
    var lesson = CourseLesson(
      id: widget.existing?.id ?? '',
      courseId: widget.courseId,
      title: title,
      videoUrl: videoUrl.isEmpty ? null : videoUrl,
      body: videoUrl.isNotEmpty ? '' : plainText,
      bodyDelta: videoUrl.isNotEmpty ? null : jsonEncode(_quillCtrl.document.toDelta().toJson()),
      viewCount: widget.existing?.viewCount ?? 0,
      order: _computeOrder(),
      coverImageUrl: _existingCoverUrl,
    );

    if (lesson.id.isEmpty) {
      final result = await repo.create(lesson);
      if (result is Failure<String>) {
        if (mounted) setState(() { _saving = false; _error = result.message; });
        return;
      }
      lesson = CourseLesson(
        id: (result as Success<String>).value, courseId: lesson.courseId, title: lesson.title,
        videoUrl: lesson.videoUrl, body: lesson.body, bodyDelta: lesson.bodyDelta,
        viewCount: lesson.viewCount, order: lesson.order, coverImageUrl: lesson.coverImageUrl,
      );
    }

    if (_pickedCover != null) {
      final upload = await repo.uploadCover(lessonId: lesson.id, imageFile: _pickedCover!);
      if (upload is Success<String>) lesson.coverImageUrl = upload.value;
    }

    final saveResult = await repo.update(lesson);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saveResult is Failure) {
      setState(() => _error = saveResult.message);
      return;
    }
    showToast(context, _isNew ? 'Lesson added.' : 'Lesson saved.');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final ac = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: ac.red))),
        ],
      ),
    );
    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      await CourseLessonRepository.instance.delete(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hasThumbnail = _pickedCover != null || (_existingCoverUrl ?? '').isNotEmpty;
    return ApplicationShell(
      user: widget.user,
      currentTitle: _isNew ? 'Add Lesson' : 'Edit Lesson',
      subtitle: _isNew
          ? 'Compose video or rich text lesson content'
          : (_titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Lesson Composer'),
      currentDestination: AppNavDestination.academicCourses,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        if (_canImportDocx)
          IconButton(
            icon: _importing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_rounded),
            tooltip: 'Import Word document (Super Admin)',
            onPressed: _importing ? null : _importDocx,
          ),
        if (!_isNew)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: ac.red),
            tooltip: 'Delete Lesson',
            onPressed: _delete,
          ),
      ],
      contextualPanel: _LessonComposerRightPanel(
        title: _titleCtrl.text,
        hasVideo: _hasVideo,
        videoUrl: _videoUrlCtrl.text.trim(),
        hasThumbnail: hasThumbnail,
        sequencePosition: _placementAfterIndex,
        totalLessons: _sequence.length,
        canImportDocx: _canImportDocx,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          TextField(
            controller: _titleCtrl, style: AppText.h1,
            decoration: const InputDecoration(hintText: 'Lesson title', border: InputBorder.none),
          ),
          Divider(color: ac.bdr2),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Rad.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.sm),
              onTap: _pickCover,
              child: Container(
                height: 90, width: double.infinity,
                decoration: BoxDecoration(
                  color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr),
                  image: _pickedCover != null
                      ? DecorationImage(image: FileImage(_pickedCover!), fit: BoxFit.cover)
                      : (_existingCoverUrl != null ? DecorationImage(image: NetworkImage(_existingCoverUrl!), fit: BoxFit.cover) : null),
                ),
                child: (_pickedCover == null && _existingCoverUrl == null)
                    ? Center(child: Text('Add a thumbnail (optional)', style: AppText.caption.copyWith(color: ac.muted)))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Video Lesson — optional, a pasted URL just like the course-level
          // field this replaces. Gated Gold-only for READERS (see
          // lesson_reader_page.dart's _LockedVideoCard); attaching one here
          // doesn't require any particular tier from the creator.
          TextField(
            controller: _videoUrlCtrl,
            style: AppText.bodySm.copyWith(color: ac.txt),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'Video lesson URL (optional, Premium Gold only)',
              prefixIcon: const Icon(Icons.videocam_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide(color: ac.bdr)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide(color: ac.bdr)),
            ),
          ),
          if (!_hasVideo) ...[
            const SizedBox(height: 16),
            Text('Lesson content', style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.txt2)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 220),
              decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
              padding: const EdgeInsets.all(8),
              child: quill.QuillEditor.basic(
                controller: _quillCtrl,
                config: quill.QuillEditorConfig(
                  placeholder: 'Lesson content…',
                  embedBuilders: [...FlutterQuillEmbeds.editorBuilders(), const FormulaEmbedBuilder()],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: ac.bdr))),
              child: quill.QuillSimpleToolbar(controller: _quillCtrl, config: const quill.QuillSimpleToolbarConfig(multiRowsDisplay: false)),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('This lesson has a video, so it has no separate text content — remove the URL to write one instead.',
                  style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2)),
            ),
          if (_sequence.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LessonPlacementPicker(
              sequence: _sequence, afterIndex: _placementAfterIndex,
              onChanged: (i) => setState(() => _placementAfterIndex = i),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Text(_error!, style: AppText.bodySm.copyWith(color: ac.red)),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryBtn(label: _isNew ? 'Add Lesson' : 'Save Lesson', loading: _saving, onTap: _save),
        ],
      ),
    );
  }
}

class _LessonPlacementPicker extends StatelessWidget {
  final List<CourseLesson> sequence;
  final int afterIndex;
  final ValueChanged<int> onChanged;
  const _LessonPlacementPicker({required this.sequence, required this.afterIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr2)),
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
            value: i, groupValue: afterIndex,
            onChanged: (v) { if (v != null) onChanged(v); },
            dense: true, contentPadding: EdgeInsets.zero, activeColor: ac.primary,
            title: Text(label, style: AppText.bodySm),
          );
        }),
      ]),
    );
  }
}

class _LessonComposerRightPanel extends StatelessWidget {
  final String title;
  final bool hasVideo;
  final String videoUrl;
  final bool hasThumbnail;
  final int sequencePosition;
  final int totalLessons;
  final bool canImportDocx;

  const _LessonComposerRightPanel({
    required this.title,
    required this.hasVideo,
    required this.videoUrl,
    required this.hasThumbnail,
    required this.sequencePosition,
    required this.totalLessons,
    required this.canImportDocx,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hasTitle = title.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasVideo ? Icons.videocam_rounded : Icons.article_rounded,
                    size: 18,
                    color: ac.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lesson Format',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasVideo ? ac.goldBg : ac.primaryBg,
                  borderRadius: BorderRadius.circular(Rad.sm),
                ),
                child: Text(
                  hasVideo ? 'Video Lesson (Streaming)' : 'Rich Text Document',
                  style: AppText.caption.copyWith(
                    color: hasVideo ? ac.gold : ac.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hasVideo
                    ? 'Video lessons are streamed directly from your entered URL. Available to readers with Premium Gold access.'
                    : 'Interactive formatted reading with rich typography, bullet lists, and embedded mathematical formulas.',
                style: AppText.caption.copyWith(color: ac.txt2, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 18, color: hasTitle ? Colors.green : ac.muted),
                  const SizedBox(width: 8),
                  Text(
                    'Lesson Status',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CheckItem(label: 'Title provided', complete: hasTitle),
              const SizedBox(height: 8),
              _CheckItem(label: 'Content / Video linked', complete: hasVideo || !hasVideo),
              const SizedBox(height: 8),
              _CheckItem(label: 'Thumbnail image', complete: hasThumbnail, optional: true),
              const SizedBox(height: 8),
              _CheckItem(
                label: 'Sequence position: #${sequencePosition + 1} of ${totalLessons + 1}',
                complete: true,
              ),
            ],
          ),
        ),
        if (canImportDocx) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.upload_file_rounded, size: 18, color: ac.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Super Admin Import',
                      style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Upload a Word .docx document using the button in the top bar to automatically parse formatted chapters, lists, and LaTeX equations.',
                  style: AppText.caption.copyWith(color: ac.txt2, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool complete;
  final bool optional;

  const _CheckItem({
    required this.label,
    required this.complete,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Icon(
          complete ? Icons.check_circle_rounded : (optional ? Icons.radio_button_unchecked_rounded : Icons.cancel_outlined),
          size: 16,
          color: complete ? Colors.green : (optional ? ac.muted : ac.org),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppText.caption.copyWith(
              color: complete ? ac.txt : ac.txt2,
              fontWeight: complete ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}


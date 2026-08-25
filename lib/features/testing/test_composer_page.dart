// lib/features/testing/test_composer_page.dart
// Authoring UI for the Testing & Quiz system — create or edit a Test and
// its questions. Gated behind AppUser.canUploadContent (lecturer+) at the
// call site (AppDrawer); TestRepository's own header carries the honest
// note that firestore.rules doesn't yet mirror that gate for `tests`.
//
// WHY THIS EXISTS: TestRepository.createTest()/updateTest() shipped with
// zero callers — there was no way to author a test from inside the app at
// all, so the Essay question's 7–9 essential key points (production_plan
// .md §3 Quiz Type 3) had nowhere to be defined. A key-points data model
// with no authoring surface would have been unusable, so the composer is
// part of that change, not a separate feature.
//
// It covers all three question formats rather than Essay alone: a
// composer that could only add Essay questions couldn't produce a
// realistic mixed test, which is the shape models/test.dart is explicitly
// designed around. Structured questions (§3 Quiz Type 2) also get an
// authoring surface for TestQuestion.expectedPoints here — optional,
// unlike Essay's mandatory 7–9, since the spec sets no point count for
// Structural; leaving it empty keeps a question fully human-graded
// exactly as before.
//
// Scope, stated honestly: this is a functional authoring form, not a
// full-blown question-bank manager. There's no reordering, no duplication
// of an existing test, and no draft autosave — a test is built, saved,
// and can be reopened to edit. Those are real omissions, not hidden ones.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/test.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'quiz_icon_editor.dart';

/// Mutable working copy of one question while it's being edited. The
/// immutable TestQuestion is only built at save time.
class _QuestionDraft {
  final String id;
  QuestionType type;
  final TextEditingController prompt = TextEditingController();
  final TextEditingController points = TextEditingController(text: '10');

  // MCQ
  final List<TextEditingController> options = [];
  int correctIndex = 0;

  // Structured
  final TextEditingController lineCount = TextEditingController(text: '4');
  final TextEditingController rubric = TextEditingController();
  /// Optional expected answer/key points (production_plan.md §3 Quiz
  /// Type 2) — reuses the same [_KeyPointDraft] shape as Essay's
  /// [keyPoints] since an expected point IS an [EssayKeyPoint]. Left
  /// empty, this question stays fully human-graded exactly like before;
  /// filled in, it auto-grades the same way an Essay does.
  final List<_KeyPointDraft> expectedPoints = [];

  // Essay
  final List<_KeyPointDraft> keyPoints = [];

  // Optional question image (architecture brief item 9) -- real photos/
  // diagrams, type-independent (any of the three formats can attach
  // one). Same pick-then-upload-after-id-exists pattern as the test's
  // own thumbnail just above in this file.
  File? pickedImage;
  String? existingImageUrl;

  _QuestionDraft({required this.id, required this.type});

  factory _QuestionDraft.fromQuestion(TestQuestion q) {
    final d = _QuestionDraft(id: q.id, type: q.type);
    d.prompt.text = q.prompt;
    d.points.text = q.points.toString();
    for (final o in q.options) {
      d.options.add(TextEditingController(text: o));
    }
    d.correctIndex = q.correctIndex;
    d.lineCount.text = q.lineCount.toString();
    d.rubric.text = q.rubricGuidance ?? '';
    d.existingImageUrl = q.imageUrl;
    for (final k in q.expectedPoints) {
      d.expectedPoints.add(_KeyPointDraft.fromKeyPoint(k));
    }
    for (final k in q.keyPoints) {
      d.keyPoints.add(_KeyPointDraft.fromKeyPoint(k));
    }
    return d;
  }

  void dispose() {
    prompt.dispose();
    points.dispose();
    for (final o in options) {
      o.dispose();
    }
    lineCount.dispose();
    rubric.dispose();
    for (final k in expectedPoints) {
      k.dispose();
    }
    for (final k in keyPoints) {
      k.dispose();
    }
  }

  TestQuestion toQuestion() => TestQuestion(
        id: id,
        type: type,
        prompt: prompt.text.trim(),
        points: int.tryParse(points.text.trim()) ?? 10,
        options: type == QuestionType.mcq
            ? options.map((o) => o.text.trim()).toList()
            : const [],
        correctIndex: correctIndex,
        lineCount: int.tryParse(lineCount.text.trim()) ?? 4,
        rubricGuidance: rubric.text.trim().isEmpty ? null : rubric.text.trim(),
        // Blank rows (an "Add point" click never followed by typing) are
        // dropped rather than saved as empty-text points, which would
        // otherwise silently count toward expectedPoints.length (and so
        // toward TestQuestion.maxPoints) without ever being matchable.
        expectedPoints: type == QuestionType.structured
            ? (expectedPoints
                .map((k) => k.toKeyPoint())
                .where((k) => k.text.isNotEmpty)
                .toList())
            : const [],
        keyPoints: type == QuestionType.longForm
            ? keyPoints.map((k) => k.toKeyPoint()).toList()
            : const [],
        imageUrl: existingImageUrl,
      );
}

class _KeyPointDraft {
  final String id;
  final TextEditingController text = TextEditingController();
  final TextEditingController keywords = TextEditingController();

  _KeyPointDraft({required this.id});

  factory _KeyPointDraft.fromKeyPoint(EssayKeyPoint k) {
    final d = _KeyPointDraft(id: k.id);
    d.text.text = k.text;
    d.keywords.text = k.keywords.join(', ');
    return d;
  }

  void dispose() {
    text.dispose();
    keywords.dispose();
  }

  EssayKeyPoint toKeyPoint() => EssayKeyPoint(
        id: id,
        text: text.text.trim(),
        keywords: keywords.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

class TestComposerPage extends StatefulWidget {
  final AppUser author;

  /// Pass an existing test to edit it; null creates a new one.
  final Test? existing;

  const TestComposerPage({super.key, required this.author, this.existing});

  @override
  State<TestComposerPage> createState() => _TestComposerPageState();
}

class _TestComposerPageState extends State<TestComposerPage> {
  AppColors get ac => AppColors.of(context);

  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _topic = TextEditingController();
  final _description = TextEditingController();
  TestDifficulty _difficulty = TestDifficulty.medium;
  bool _published = true;
  bool _restrictToSchool = false;
  bool _saving = false;

  List<QuizCategory> _categories = [];
  String _category = '';
  File? _pickedThumbnail;
  String? _existingThumbnailUrl;

  final List<_QuestionDraft> _questions = [];
  var _idSeed = 0;

  String _newId(String prefix) {
    _idSeed++;
    return '$prefix${DateTime.now().microsecondsSinceEpoch}_$_idSeed';
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _subject.text = existing.subject;
      _topic.text = existing.topic;
      _description.text = existing.description;
      _difficulty = existing.difficulty;
      _published = existing.published;
      _restrictToSchool = existing.institutionId != null;
      _category = existing.category;
      _existingThumbnailUrl = existing.thumbnailUrl;
      for (final q in existing.questions) {
        _questions.add(_QuestionDraft.fromQuestion(q));
      }
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await TestRepository.instance.quizCategoriesOnce();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      // A brand-new test with nothing picked yet defaults to the first
      // category rather than staying blank — every quiz needs a place in
      // the tree the moment it's created, and the author can still
      // change it before saving.
      if (_category.isEmpty && categories.isNotEmpty) _category = categories.first.name;
    });
  }

  Future<void> _addCategory() async {
    final name = await showAddQuizCategoryDialog(context);
    if (name == null || name.trim().isEmpty) return;
    final order = _categories.isEmpty
        ? 0.0
        : (_categories.map((c) => c.order).reduce((a, b) => a > b ? a : b) + 100);
    final result = await TestRepository.instance.addQuizCategory(name: name, order: order);
    if (!mounted) return;
    if (result case Failure(:final message)) {
      showToast(context, message, isError: true);
      return;
    }
    setState(() => _category = name);
    _loadCategories();
  }

  Future<void> _pickThumbnail() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pickedThumbnail = File(picked.path));
  }

  Future<void> _pickQuestionImage(_QuestionDraft q) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => q.pickedImage = File(picked.path));
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _topic.dispose();
    _description.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  // ── Question list management ───────────────────────────────────────────

  void _addQuestion(QuestionType type) {
    final draft = _QuestionDraft(id: _newId('q'), type: type);
    if (type == QuestionType.mcq) {
      for (var i = 0; i < 4; i++) {
        draft.options.add(TextEditingController());
      }
    } else if (type == QuestionType.longForm) {
      // Start at the spec's minimum so the author is filling in a
      // correctly-shaped question from the first keystroke rather than
      // discovering the 7–9 rule only when they try to save.
      for (var i = 0; i < kMinEssayKeyPoints; i++) {
        draft.keyPoints.add(_KeyPointDraft(id: _newId('kp')));
      }
    }
    setState(() => _questions.add(draft));
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index).dispose();
    });
  }

  // ── Validation & save ──────────────────────────────────────────────────

  /// Returns the first problem found, or null when the test is saveable.
  /// Essay rules are the strict ones here: the spec names 7–9 essential
  /// points, and a key point is meant to be a short phrase, so an empty
  /// or essay-length one is rejected rather than silently accepted and
  /// then mis-matched at grading time.
  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Give the test a title.';
    if (_category.trim().isEmpty) return 'Pick a section (e.g. Senior Secondary School).';
    if (_subject.text.trim().isEmpty) return 'Enter the subject.';
    if (_topic.text.trim().isEmpty) return 'Enter the topic this quiz belongs to.';
    if (_questions.isEmpty) return 'Add at least one question.';

    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final label = 'Question ${i + 1}';
      if (q.prompt.text.trim().isEmpty) return '$label needs a prompt.';

      switch (q.type) {
        case QuestionType.mcq:
          final filled = q.options.where((o) => o.text.trim().isNotEmpty).length;
          if (filled < 2) return '$label needs at least 2 options.';
          if (q.correctIndex >= q.options.length ||
              q.options[q.correctIndex].text.trim().isEmpty) {
            return '$label needs its correct answer marked on a filled option.';
          }
          break;
        case QuestionType.structured:
          final points = int.tryParse(q.points.text.trim()) ?? 0;
          if (points <= 0) return '$label needs a points value above 0.';
          // Expected points are optional (unlike Essay's mandatory 7–9 —
          // the spec doesn't set a count for Structural), but any that
          // ARE entered get the same paragraph-length sanity check Essay
          // key points get, for the same reason: a long "point" matches
          // badly at grading time.
          final expectedTexts = q.expectedPoints
              .map((k) => k.text.text.trim())
              .where((t) => t.isNotEmpty);
          if (expectedTexts.any((t) => t.length > 200)) {
            return '$label has an expected point that reads like a '
                'paragraph. Keep each one to a short phrase or sentence.';
          }
          break;
        case QuestionType.longForm:
          final texts =
              q.keyPoints.map((k) => k.text.text.trim()).where((t) => t.isNotEmpty);
          if (texts.length < kMinEssayKeyPoints ||
              texts.length > kMaxEssayKeyPoints) {
            return '$label is an Essay: it needs between $kMinEssayKeyPoints '
                'and $kMaxEssayKeyPoints essential key points '
                '(currently ${texts.length}).';
          }
          if (texts.any((t) => t.length > 200)) {
            return '$label has a key point that reads like a paragraph. '
                'Each one should be a short phrase or single sentence.';
          }
          break;
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      showToast(context, problem, isError: true);
      return;
    }
    setState(() => _saving = true);

    TestQuestion finalizeQuestion(_QuestionDraft q) {
      final built = q.toQuestion();
      if (built.type != QuestionType.mcq) return built;
      // Drop blank trailing MCQ options, keeping the correct index
      // pointing at the same option text it was pointing at before.
      final kept = <String>[];
      var correct = built.correctIndex;
      for (var i = 0; i < built.options.length; i++) {
        if (built.options[i].isNotEmpty) {
          kept.add(built.options[i]);
        } else if (i < built.correctIndex) {
          correct--;
        }
      }
      return TestQuestion(
        id: built.id,
        type: built.type,
        prompt: built.prompt,
        points: built.points,
        options: kept,
        correctIndex: correct.clamp(0, kept.isEmpty ? 0 : kept.length - 1),
        lineCount: built.lineCount,
        rubricGuidance: built.rubricGuidance,
        expectedPoints: built.expectedPoints,
        keyPoints: built.keyPoints,
        imageUrl: built.imageUrl,
      );
    }

    var questions = _questions.map(finalizeQuestion).toList();

    Test buildTest({required String id, String? thumbnailUrl}) => Test(
          id: id,
          subject: _subject.text.trim(),
          title: _title.text.trim(),
          description: _description.text.trim(),
          difficulty: _difficulty,
          questions: questions,
          createdBy: widget.existing?.createdBy ?? widget.author.id,
          createdByName: widget.existing?.createdByName ?? widget.author.name,
          institutionId: _restrictToSchool ? widget.author.schoolId : null,
          published: _published,
          createdAt: widget.existing?.createdAt ?? DateTime.now(),
          category: _category.trim(),
          topic: _topic.text.trim(),
          thumbnailUrl: thumbnailUrl,
        );

    // A brand-new test needs an id before a thumbnail can be uploaded to
    // it (the storage path is `test_thumbnails/{testId}.jpg`) — same
    // create-then-attach-media order PublicCourseRepository's composer
    // uses for a course's cover photo.
    var testId = widget.existing?.id ?? '';
    if (testId.isEmpty) {
      final createResult =
          await TestRepository.instance.createTest(buildTest(id: '', thumbnailUrl: _existingThumbnailUrl));
      if (!mounted) return;
      if (createResult case Failure(:final message)) {
        setState(() => _saving = false);
        showToast(context, message, isError: true);
        return;
      }
      testId = (createResult as Success<String>).value;
    }

    var thumbnailUrl = _existingThumbnailUrl;
    if (_pickedThumbnail != null) {
      final upload =
          await TestRepository.instance.uploadTestThumbnail(testId: testId, imageFile: _pickedThumbnail!);
      if (upload is Success<String>) thumbnailUrl = upload.value;
    }

    // Same reasoning as the thumbnail above: a question image also needs
    // a real testId in its storage path, so this can only happen once
    // testId is resolved -- then the final question list is rebuilt with
    // the resolved URLs before the update call below.
    var anyImageUploaded = false;
    for (final q in _questions) {
      if (q.pickedImage == null) continue;
      final upload = await TestRepository.instance
          .uploadQuestionImage(testId: testId, questionId: q.id, imageFile: q.pickedImage!);
      if (upload is Success<String>) {
        q.existingImageUrl = upload.value;
        anyImageUploaded = true;
      }
    }
    if (anyImageUploaded) questions = _questions.map(finalizeQuestion).toList();

    final result =
        await TestRepository.instance.updateTest(testId, buildTest(id: testId, thumbnailUrl: thumbnailUrl));

    if (!mounted) return;
    setState(() => _saving = false);
    if (result case Failure(:final message)) {
      showToast(context, message, isError: true);
      return;
    }
    showToast(context, widget.existing == null ? 'Test created' : 'Test updated');
    Navigator.of(context).pop(true);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Create Test' : 'Edit Test',
            style: AppText.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          _detailsCard(),
          const SizedBox(height: 16),
          SectionHeader(title: 'Questions (${_questions.length})'),
          const SizedBox(height: 10),
          for (var i = 0; i < _questions.length; i++) ...[
            _questionCard(i, _questions[i]),
            const SizedBox(height: 12),
          ],
          if (_questions.isEmpty)
            ACard(
              child: Text(
                'No questions yet. Add a Multiple Choice, Structured or Essay '
                'question below.',
                style: AppText.caption,
              ),
            ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _addBtn('MCQ', Icons.radio_button_checked_rounded,
                () => _addQuestion(QuestionType.mcq))),
            const SizedBox(width: 8),
            Expanded(child: _addBtn('Structured', Icons.notes_rounded,
                () => _addQuestion(QuestionType.structured))),
            const SizedBox(width: 8),
            Expanded(child: _addBtn('Essay', Icons.checklist_rounded,
                () => _addQuestion(QuestionType.longForm))),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryBtn(
            label: widget.existing == null ? 'Create Test' : 'Save Changes',
            loading: _saving,
            onTap: _save,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap, {bool outline = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? ac.primary : (outline ? Colors.transparent : ac.surf2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? ac.primary : ac.bdr),
          ),
          child: Text(label, style: AppText.caption.copyWith(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: active ? Colors.white : (outline ? ac.primary : ac.txt2))),
        ),
      ),
    );
  }

  Widget _addBtn(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: ac.surf2,
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: ac.primary),
            const SizedBox(height: 4),
            Text(label, style: AppText.caption, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _detailsCard() {
    return ACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: GestureDetector(
            onTap: _pickThumbnail,
            child: HierarchyAvatar(
              label: _title.text.isEmpty ? 'Quiz' : _title.text,
              imageUrl: _pickedThumbnail == null ? (_existingThumbnailUrl ?? '') : '',
              localImage: _pickedThumbnail,
              size: 72,
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _pickThumbnail,
            child: Text('Set thumbnail', style: AppText.caption.copyWith(color: ac.primary)),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          onChanged: (_) => setState(() {}), // keeps the thumbnail letter-fallback in sync while typing
          decoration: const InputDecoration(labelText: 'Test title'),
        ),
        const SizedBox(height: 14),
        Text('Section', style: AppText.subtitle),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in _categories)
            _chip(c.name, c.name == _category, () => setState(() => _category = c.name)),
          _chip('+ New section', false, _addCategory, outline: true),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _subject,
          decoration: const InputDecoration(
            labelText: 'Subject',
            hintText: 'e.g. Biology',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _topic,
          decoration: const InputDecoration(
            labelText: 'Topic',
            hintText: 'e.g. The French Revolution',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Description (optional)'),
        ),
        const SizedBox(height: 14),
        Text('Difficulty', style: AppText.subtitle),
        const SizedBox(height: 8),
        Row(children: [
          for (final d in TestDifficulty.values) ...[
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.sm),
                  onTap: () => setState(() => _difficulty = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _difficulty == d ? ac.primaryBg : ac.surf2,
                      borderRadius: BorderRadius.circular(Rad.sm),
                      border: Border.all(
                          color: _difficulty == d ? ac.primary : ac.bdr),
                    ),
                    child: Text(
                      d.label,
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        color: _difficulty == d ? ac.primary : ac.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (d != TestDifficulty.values.last) const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _published,
          onChanged: (v) => setState(() => _published = v),
          title: Text('Published', style: AppText.bodySm),
          subtitle: Text('Students can find and take this test',
              style: AppText.caption),
        ),
        if ((widget.author.schoolId ?? '').isNotEmpty)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _restrictToSchool,
            onChanged: (v) => setState(() => _restrictToSchool = v),
            title: Text('My school only', style: AppText.bodySm),
            subtitle: Text(
                'Off means every student studying this subject can take it',
                style: AppText.caption),
          ),
      ]),
    );
  }

  Widget _questionCard(int index, _QuestionDraft q) {
    return ACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusBadge(label: 'Q${index + 1}', color: ac.primary),
          const SizedBox(width: 8),
          StatusBadge(label: q.type.label, color: ac.pur),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: ac.red, size: 20),
            tooltip: 'Remove question',
            onPressed: () => _removeQuestion(index),
          ),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: q.prompt,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Question'),
        ),
        const SizedBox(height: 8),
        _questionImagePicker(q),
        const SizedBox(height: 12),
        if (q.type == QuestionType.mcq) _mcqEditor(q),
        if (q.type == QuestionType.structured) _structuredEditor(q),
        if (q.type == QuestionType.longForm) _essayEditor(q),
      ]),
    );
  }

  /// Optional real photo/diagram for one question (item 9) -- shown for
  /// every question type, not just MCQ, since a Structured or Essay
  /// prompt can just as legitimately ask the learner to analyse an image.
  Widget _questionImagePicker(_QuestionDraft q) {
    final hasImage = q.pickedImage != null || (q.existingImageUrl ?? '').isNotEmpty;
    if (!hasImage) {
      return OutlinedButton.icon(
        onPressed: () => _pickQuestionImage(q),
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
        label: const Text('Add image'),
      );
    }
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Rad.sm),
        child: q.pickedImage != null
            ? Image.file(q.pickedImage!, height: 140, width: double.infinity, fit: BoxFit.cover)
            : Image.network(q.existingImageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      ),
      Positioned(
        top: 4, right: 4,
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
            onPressed: () => setState(() {
              q.pickedImage = null;
              q.existingImageUrl = null;
            }),
          ),
        ),
      ),
    ]);
  }

  Widget _mcqEditor(_QuestionDraft q) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tap the circle to mark the correct answer', style: AppText.caption),
      const SizedBox(height: 8),
      for (var i = 0; i < q.options.length; i++) ...[
        Row(children: [
          IconButton(
            icon: Icon(
              q.correctIndex == i
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: q.correctIndex == i ? ac.grn : ac.muted,
              size: 20,
            ),
            onPressed: () => setState(() => q.correctIndex = i),
          ),
          Expanded(
            child: TextField(
              controller: q.options[i],
              decoration: InputDecoration(hintText: 'Option ${i + 1}'),
            ),
          ),
        ]),
        const SizedBox(height: 6),
      ],
      TextButton.icon(
        onPressed: () =>
            setState(() => q.options.add(TextEditingController())),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add option'),
      ),
      TextField(
        controller: q.points,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Points'),
      ),
    ]);
  }

  Widget _structuredEditor(_QuestionDraft q) {
    final filled =
        q.expectedPoints.where((k) => k.text.text.trim().isNotEmpty).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: q.lineCount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Answer lines'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: q.points,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Points'),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: q.rubric,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Grading guidance (optional)',
          hintText: 'Shown to whoever grades this answer',
        ),
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ac.primaryBg,
          borderRadius: BorderRadius.circular(Rad.sm),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.checklist_rounded, size: 16, color: ac.primary),
            const SizedBox(width: 6),
            Text('Expected answer points (optional)',
                style: AppText.subtitle.copyWith(color: ac.primary)),
          ]),
          const SizedBox(height: 6),
          Text(
            filled == 0
                ? 'Add the short points a correct answer should contain '
                    'and this question is marked automatically, the same '
                    'way an Essay question is. Leave this empty and it '
                    'stays fully human-graded, using the guidance above.'
                : 'Scored out of $filled point${filled == 1 ? '' : 's'} — '
                    'one mark per expected point the student captures in '
                    'their own words.',
            style: AppText.caption,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < q.expectedPoints.length; i++) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24, height: 24,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: ac.surf2, shape: BoxShape.circle),
            child: Center(child: Text('${i + 1}', style: AppText.label)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(children: [
              TextField(
                controller: q.expectedPoints[i].text,
                maxLines: 2,
                minLines: 1,
                onChanged: (_) => setState(() {}),
                decoration:
                    InputDecoration(hintText: 'Expected point ${i + 1}'),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: q.expectedPoints[i].keywords,
                style: AppText.caption,
                decoration: const InputDecoration(
                  hintText: 'Alternative wordings, comma separated (optional)',
                ),
              ),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: ac.muted, size: 18),
            tooltip: 'Remove point',
            onPressed: () => setState(() {
              q.expectedPoints.removeAt(i).dispose();
            }),
          ),
        ]),
        const SizedBox(height: 8),
      ],
      TextButton.icon(
        onPressed: () => setState(
            () => q.expectedPoints.add(_KeyPointDraft(id: _newId('ep')))),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add expected point'),
      ),
    ]);
  }

  Widget _essayEditor(_QuestionDraft q) {
    final filled =
        q.keyPoints.where((k) => k.text.text.trim().isNotEmpty).length;
    final withinRange =
        filled >= kMinEssayKeyPoints && filled <= kMaxEssayKeyPoints;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ac.primaryBg,
          borderRadius: BorderRadius.circular(Rad.sm),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Essential points', style: AppText.subtitle.copyWith(color: ac.primary)),
          const SizedBox(height: 6),
          Text(
            'List the $kMinEssayKeyPoints–$kMaxEssayKeyPoints points a strong '
            'answer must contain, one short phrase each. Students are scored on '
            'how many of these they capture in their own words — so keep each '
            'point to a single idea, not a paragraph.',
            style: AppText.caption,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < q.keyPoints.length; i++) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24, height: 24,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: ac.surf2, shape: BoxShape.circle),
            child: Center(child: Text('${i + 1}', style: AppText.label)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(children: [
              TextField(
                controller: q.keyPoints[i].text,
                maxLines: 2,
                minLines: 1,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: 'Essential point ${i + 1}'),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: q.keyPoints[i].keywords,
                style: AppText.caption,
                decoration: const InputDecoration(
                  hintText: 'Alternative wordings, comma separated (optional)',
                ),
              ),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: ac.muted, size: 18),
            tooltip: 'Remove point',
            onPressed: () => setState(() {
              q.keyPoints.removeAt(i).dispose();
            }),
          ),
        ]),
        const SizedBox(height: 8),
      ],
      Row(children: [
        if (q.keyPoints.length < kMaxEssayKeyPoints)
          TextButton.icon(
            onPressed: () => setState(
                () => q.keyPoints.add(_KeyPointDraft(id: _newId('kp')))),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add point'),
          ),
        const Spacer(),
        Text(
          '$filled of $kMinEssayKeyPoints–$kMaxEssayKeyPoints',
          style: AppText.caption.copyWith(
            color: withinRange ? ac.grn : ac.org,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Text(
        'Scored out of $filled point${filled == 1 ? '' : 's'} — one mark per '
        'essential point captured.',
        style: AppText.caption,
      ),
    ]);
  }
}

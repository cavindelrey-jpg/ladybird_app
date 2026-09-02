// lib/features/courses_marketplace/course_composer_page.dart
// Create/edit a marketplace Course's metadata and curriculum placement.
// A course no longer holds its own content — that moved to CourseLesson
// (see models/course_lesson.dart) — so this screen is title/description/
// cover/placement plus a Lessons manager; actual lesson content (including
// the optional Video Lesson URL) is authored in lesson_composer_page.dart.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/course_lesson.dart';
import '../../models/public_course.dart';
import '../../repositories/course_lesson_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'lesson_composer_page.dart';

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

  // "Subject" in the Level -> Subject -> Topic -> Course hierarchy is
  // courses.category — kCourseCategories are suggestions, not a hard enum.
  late String _subject = widget.existing?.category ?? kCourseCategories.first;
  late List<String> _tags = List<String>.from(widget.existing?.tags ?? const []);

  late String _level = widget.existing?.level ?? '';
  late String _topic = widget.existing?.topic ?? '';
  late String _difficulty = widget.existing?.difficulty ?? '';
  late List<String> _prerequisiteIds = List<String>.from(widget.existing?.prerequisiteIds ?? const []);

  List<CourseLevelInfo> _levels = [];
  List<String> _topicSuggestions = [];
  Map<String, CurriculumIcon> _iconMap = {};
  String _newTopicIcon = '';
  File? _newTopicImage;

  /// Sibling courses already in this Level/Subject/Topic — same
  /// before/between/after placement + prerequisites picker as before.
  List<PublicCourse> _topicSequence = [];
  bool _loadingSequence = false;
  int? _placementAfterIndex;

  late PublicCourse _workingCourse = widget.existing ?? PublicCourse(
    id: '', creatorId: widget.user.id, creatorName: widget.user.name,
    creatorPhotoUrl: widget.user.photoUrl, title: '',
  );

  List<CourseLesson> _lessons = [];
  bool _loadingLessons = false;

  File? _pickedCover;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;
  bool get _hasPlacement => _level.isNotEmpty && _subject.isNotEmpty && _topic.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadLevels();
    _loadIconMap();
    if (_level.isNotEmpty) _loadTopicSuggestions();
    if (widget.existing?.hasCurriculumPlacement ?? false) _loadTopicSequence();
    if (!_isNew) _loadLessons();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLevels() async {
    final levels = await PublicCourseRepository.instance.levelsOnce();
    if (mounted) setState(() => _levels = levels);
  }

  Future<void> _loadIconMap() async {
    final icons = await PublicCourseRepository.instance.curriculumIconsOnce();
    if (mounted) setState(() => _iconMap = icons);
  }

  Map<String, CurriculumIcon> get _topicIcons => {
        for (final t in _topicSuggestions)
          t: _iconMap[PublicCourseRepository.eduTopicIconKey(_level, _subject, t)] ?? CurriculumIcon.none,
      };

  Future<void> _loadTopicSuggestions() async {
    if (_level.isEmpty) {
      setState(() => _topicSuggestions = []);
      return;
    }
    final topics = await PublicCourseRepository.instance.topicsInSubject(_level, _subject);
    if (mounted) setState(() => _topicSuggestions = topics);
  }

  Future<void> _loadTopicSequence() async {
    if (_level.isEmpty || _topic.trim().isEmpty) {
      setState(() { _topicSequence = []; _placementAfterIndex = null; });
      return;
    }
    setState(() => _loadingSequence = true);
    final sequence = await PublicCourseRepository.instance.coursesInTopic(_level, _subject, _topic.trim());
    sequence.removeWhere((c) => c.id == _workingCourse.id && c.id.isNotEmpty);
    if (!mounted) return;
    setState(() {
      _topicSequence = sequence;
      _loadingSequence = false;
      _placementAfterIndex ??= sequence.length;
      if (_placementAfterIndex! > sequence.length) _placementAfterIndex = sequence.length;
      _prerequisiteIds.removeWhere((id) => !sequence.any((c) => c.id == id));
    });
  }

  Future<void> _loadLessons() async {
    setState(() => _loadingLessons = true);
    final lessons = await CourseLessonRepository.instance.lessonsOnce(_workingCourse.id);
    if (mounted) setState(() { _lessons = lessons; _loadingLessons = false; });
  }

  void _onLevelChanged(String v) {
    setState(() { _level = v; _topic = ''; _newTopicIcon = ''; _newTopicImage = null; });
    _loadTopicSuggestions();
    _loadTopicSequence();
  }

  void _onSubjectChanged(String v) {
    setState(() { _subject = v; _topic = ''; _newTopicIcon = ''; _newTopicImage = null; });
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

  Future<void> _save({required bool publish}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _saving = true; _error = null; });
    final ok = await _persist(publish: publish);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    if (_isNew) {
      // A brand-new course needs at least one lesson before it's really
      // usable — keep composing instead of popping straight back out.
      showToast(context, 'Course created — now add its lessons.');
      await _loadLessons();
    } else {
      showToast(context, publish ? 'Course published.' : 'Draft saved.');
      Navigator.of(context).pop();
    }
  }

  Future<bool> _persist({required bool publish}) async {
    final repo = PublicCourseRepository.instance;
    _workingCourse.title = _titleCtrl.text.trim();
    _workingCourse.description = _descCtrl.text.trim();
    _workingCourse.category = _subject;
    _workingCourse.tags = _tags;
    _workingCourse.published = publish;
    _workingCourse.level = _level.trim();
    _workingCourse.topic = _topic.trim();
    _workingCourse.difficulty = _difficulty;
    _workingCourse.prerequisiteIds = _prerequisiteIds;

    if (_hasPlacement) {
      final afterIndex = _placementAfterIndex ?? _topicSequence.length;
      if (afterIndex <= 0) {
        _workingCourse.order = repo.positionAtStart(_topicSequence);
      } else if (afterIndex >= _topicSequence.length) {
        _workingCourse.order = repo.positionAtEnd(_topicSequence);
      } else {
        _workingCourse.order = repo.positionBetween(_topicSequence[afterIndex - 1], _topicSequence[afterIndex]);
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
        category: _workingCourse.category, tags: _workingCourse.tags,
        level: _workingCourse.level, topic: _workingCourse.topic, difficulty: _workingCourse.difficulty,
        order: _workingCourse.order, prerequisiteIds: _workingCourse.prerequisiteIds,
        coverImageUrl: _workingCourse.coverImageUrl, published: _workingCourse.published,
      );
    }

    if (_pickedCover != null) {
      final upload = await repo.uploadCover(courseId: _workingCourse.id, imageFile: _pickedCover!);
      if (upload is Success<String>) {
        _workingCourse.coverImageUrl = upload.value;
        _pickedCover = null;
      }
    }

    final saveResult = await repo.update(_workingCourse);
    if (saveResult is Failure) {
      if (mounted) setState(() => _error = saveResult.message);
      return false;
    }
    if (_newTopicIcon.isNotEmpty || _newTopicImage != null) {
      String imageUrl = '';
      if (_newTopicImage != null) {
        final upload = await repo.uploadCurriculumNodeImage(
            key: PublicCourseRepository.eduTopicIconKey(_level, _subject, _topic), imageFile: _newTopicImage!);
        if (upload is Success<String>) imageUrl = upload.value;
      }
      await repo.setCurriculumIcon(
          PublicCourseRepository.eduTopicIconKey(_level, _subject, _topic), emoji: _newTopicIcon, imageUrl: imageUrl);
    }
    return true;
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final ac = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete course?'),
        content: const Text('This deletes all of its lessons too. This cannot be undone.'),
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

  Future<void> _openLesson([CourseLesson? lesson]) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LessonComposerPage(
            user: widget.user, courseId: _workingCourse.id, existing: lesson, existingSequence: _lessons)));
    if (mounted) _loadLessons();
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
          if (!_isNew)
            IconButton(icon: Icon(Icons.delete_outline_rounded, color: ac.red), onPressed: _delete),
        ],
      ),
      body: AppBackground(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
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
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl, style: AppText.h1,
            decoration: const InputDecoration(hintText: 'Course title', border: InputBorder.none),
          ),
          Divider(color: ac.bdr2),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl, style: AppText.bodySm.copyWith(color: ac.txt),
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Short description (shown on cards)…', border: InputBorder.none),
          ),
          const SizedBox(height: 16),
          Text('Subject', style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.txt2)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kCourseCategories.map((s) {
              final active = s == _subject;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _onSubjectChanged(s);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? ac.primary : ac.surf2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? ac.primary : ac.bdr),
                    ),
                    child: Text(s, style: AppText.caption.copyWith(
                        fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : ac.txt2)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TagMultiSelect(selected: _tags, suggestions: kCourseTags, onChanged: (next) => setState(() => _tags = next)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Where does this course live?', style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Required — this is what puts the course under a level/subject/topic '
                  'so students can browse to it.', style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2)),
              const SizedBox(height: 12),
              Text('Education Level', style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.txt2)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: _levels.map((l) {
                final active = l.name == _level;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () { HapticFeedback.selectionClick(); _onLevelChanged(l.name); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? ac.primary : ac.surf2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? ac.primary : ac.bdr),
                      ),
                      child: Text(l.name, style: AppText.caption.copyWith(
                          fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? Colors.white : ac.txt2)),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 10),
              HierarchyPicker(
                label: 'Topic',
                value: _topic, options: _topicSuggestions,
                icons: _topicIcons,
                enabled: _level.isNotEmpty,
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
                    onTap: () { HapticFeedback.selectionClick(); setState(() => _difficulty = active ? '' : d); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? ac.primary : ac.surf2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? ac.primary : ac.bdr),
                      ),
                      child: Text(d, style: AppText.caption.copyWith(
                          fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? Colors.white : ac.txt2)),
                    ),
                  ),
                );
              }).toList()),
            ]),
          ),
          if (_hasPlacement) ...[
            const SizedBox(height: 16),
            _PlacementPicker(
              sequence: _topicSequence, loading: _loadingSequence,
              afterIndex: _placementAfterIndex ?? _topicSequence.length,
              onChanged: (i) => setState(() => _placementAfterIndex = i),
            ),
            if (_topicSequence.isNotEmpty) ...[
              const SizedBox(height: 16),
              _PrerequisitesPicker(
                sequence: _topicSequence, selected: _prerequisiteIds,
                onChanged: (next) => setState(() => _prerequisiteIds = next),
              ),
            ],
          ],
          if (!_isNew) ...[
            const SizedBox(height: 24),
            _LessonsSection(
              lessons: _lessons, loading: _loadingLessons,
              onAdd: () => _openLesson(),
              onEdit: (l) => _openLesson(l),
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
          Row(children: [
            Expanded(child: SecondaryBtn(label: 'Save Draft', onTap: _saving ? () {} : () => _save(publish: false))),
            const SizedBox(width: 12),
            Expanded(child: PrimaryBtn(label: 'Publish', loading: _saving, onTap: () => _save(publish: true))),
          ]),
        ],
      )),
    );
  }
}

class _LessonsSection extends StatelessWidget {
  final List<CourseLesson> lessons;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<CourseLesson> onEdit;
  const _LessonsSection({required this.lessons, required this.loading, required this.onAdd, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Lessons', style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700))),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Add lesson', style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: ShimmerLine(width: 200, height: 14))
        else if (lessons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No lessons yet — add the first one.', style: AppText.caption.copyWith(color: ac.txt2)),
          )
        else
          ...lessons.map((l) => Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.xs),
                  onTap: () => onEdit(l),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon((l.videoUrl ?? '').isNotEmpty ? Icons.play_circle_outline_rounded : Icons.article_outlined,
                          size: 18, color: ac.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l.title, style: AppText.bodySm)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: ac.muted),
                    ]),
                  ),
                ),
              )),
      ]),
    );
  }
}

class _PlacementPicker extends StatelessWidget {
  final List<PublicCourse> sequence;
  final bool loading;
  final int afterIndex;
  final ValueChanged<int> onChanged;
  const _PlacementPicker({required this.sequence, required this.loading, required this.afterIndex, required this.onChanged});

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
        child: Text('This is the first course in this topic.', style: AppText.caption.copyWith(color: ac.txt2)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Where does this course belong?', style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700)),
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
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? ac.gold : ac.txt2)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

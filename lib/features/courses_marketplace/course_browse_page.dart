// lib/features/courses_marketplace/course_browse_page.dart
// The "table of contents" view for marketplace Courses, scoped to one
// Academic Section — lets students navigate Subject > Topic > ordered
// Lessons within that section, instead of only finding a lesson via
// search. Reached from CourseNavigationPage (the section grid); courses
// without full curriculum placement simply don't appear here. Mirrors
// the Quiz system's TestsSubjectPickerPage + TestsTopicPickerPage
// (combined into one file here, same as before this page was rescoped
// to a section) so the two browse experiences feel like one consistent
// pattern rather than two different ones.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../testing/quiz_icon_editor.dart';
import 'course_reader_page.dart';

class CourseBrowsePage extends StatefulWidget {
  final String section;
  final AppUser? currentUser;
  final String? initialSubject;
  final String? initialTopic;
  const CourseBrowsePage({
    super.key,
    required this.section,
    this.currentUser,
    this.initialSubject,
    this.initialTopic,
  });

  @override
  State<CourseBrowsePage> createState() => _CourseBrowsePageState();
}

/// One tree level for the drill-down: subject → topic → lesson list.
enum _BrowseLevel { subject, topic }

class _CourseBrowsePageState extends State<CourseBrowsePage> {
  Map<String, Map<String, List<PublicCourse>>> _tree = {};
  Map<String, CurriculumIcon> _icons = {};
  bool _loading = true;

  String? _subject;
  String? _topic;

  bool get _canManage => widget.currentUser?.canUploadContent ?? false;

  @override
  void initState() {
    super.initState();
    _subject = widget.initialSubject;
    _topic = widget.initialTopic;
    _load();
  }

  Future<void> _load() async {
    final repo = PublicCourseRepository.instance;
    try {
      final subjects = await repo.subjectsInSection(widget.section);
      final tree = <String, Map<String, List<PublicCourse>>>{};
      for (final subject in subjects) {
        final topics = await repo.topicsInSection(widget.section, subject);
        final byTopic = <String, List<PublicCourse>>{};
        for (final topic in topics) {
          byTopic[topic] = await repo.topicSequenceInSection(widget.section, subject, topic);
        }
        tree[subject] = byTopic;
      }
      final icons = await repo.curriculumIconsOnce();
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _icons = icons;
        _loading = false;
      });
    } catch (e, st) {
      // A failure here previously left the page spinning forever (no
      // catch at all) -- fall back to an empty tree so the page at least
      // reaches its real "nothing here yet" empty state instead of
      // hanging, and record the failure rather than swallowing it.
      CrashService.instance.recordError(e, st, context: 'CourseBrowsePage._load');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  _BrowseLevel get _currentLevel => _subject == null ? _BrowseLevel.subject : _BrowseLevel.topic;

  void _goBack() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_topic != null) { _topic = null; return; }
      _subject = null;
    });
  }

  String get _title {
    switch (_currentLevel) {
      case _BrowseLevel.subject: return widget.section;
      case _BrowseLevel.topic: return _subject!;
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
        leading: (_subject != null)
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _goBack)
            : null,
        title: Text(_title, style: AppText.title),
      ),
      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, ac),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppColors ac) {
    if (_tree.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No courses have been placed under "${widget.section}" yet. '
            'Give a course this Section, a Subject and a Topic when creating it to see it here.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(color: ac.txt2),
          ),
        ),
      );
    }

    if (_topic != null) {
      return _buildLessonList(context, _topic!, ac);
    }

    switch (_currentLevel) {
      case _BrowseLevel.subject:
        return _buildList(context, _tree.keys.toList()..sort(), (v) => setState(() => _subject = v), ac);
      case _BrowseLevel.topic:
        final topics = (_tree[_subject!] ?? {}).keys.toList()..sort();
        return _buildList(context, topics, (v) => setState(() => _topic = v), ac, isTopic: true);
    }
  }

  /// Icon lookup for the level currently being browsed — falls back to a
  /// letter-avatar wherever nothing was set.
  CurriculumIcon _iconFor(String label) {
    switch (_currentLevel) {
      case _BrowseLevel.subject:
        return _icons[PublicCourseRepository.navSubjectIconKey(widget.section, label)] ?? CurriculumIcon.none;
      case _BrowseLevel.topic:
        return _icons[PublicCourseRepository.navTopicIconKey(widget.section, _subject!, label)] ?? CurriculumIcon.none;
    }
  }

  Future<void> _editLook(String label) async {
    final key = _currentLevel == _BrowseLevel.subject
        ? PublicCourseRepository.navSubjectIconKey(widget.section, label)
        : PublicCourseRepository.navTopicIconKey(widget.section, _subject!, label);
    final current = _iconFor(label);
    final repo = PublicCourseRepository.instance;
    await showQuizIconEditor(
      context,
      label: label,
      currentEmoji: current.emoji,
      currentImageUrl: current.imageUrl,
      onSave: (emoji, image) async {
        String imageUrl = '';
        if (image != null) {
          final upload = await repo.uploadCurriculumNodeImage(key: key, imageFile: image);
          if (upload is Success<String>) imageUrl = upload.value;
        }
        await repo.setCurriculumIcon(key, emoji: emoji, imageUrl: imageUrl);
      },
    );
    _load();
  }

  Widget _buildList(BuildContext context, List<String> items, ValueChanged<String> onTap, AppColors ac, {bool isTopic = false}) {
    if (items.isEmpty) {
      return Center(child: Text('Nothing here yet.', style: AppText.bodySm.copyWith(color: ac.txt2)));
    }
    // Icon tiles rather than plain text rows — a picture (or at least a
    // colored letter) is easier to scan and recognize on a second visit
    // than a line of text, closer to how a Wikipedia topic list reads.
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.92,
      ),
      itemBuilder: (context, i) {
        final label = items[i];
        final count = isTopic ? (_tree[_subject!]?[label]?.length ?? 0) : null;
        final icon = _iconFor(label);
        return Material(
          color: ac.surf,
          borderRadius: BorderRadius.circular(Rad.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.md),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(label);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
              child: Stack(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  HierarchyAvatar(label: label, icon: icon.emoji, imageUrl: icon.imageUrl, size: 48),
                  const Spacer(),
                  Text(label, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (count != null) ...[
                    const SizedBox(height: 2),
                    Text('$count lesson${count == 1 ? '' : 's'}', style: AppText.caption.copyWith(color: ac.txt2)),
                  ],
                ]),
                if (_canManage)
                  Positioned(
                    top: 0, right: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _editLook(label),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: ac.surf2, shape: BoxShape.circle, border: Border.all(color: ac.bdr2)),
                        child: Icon(Icons.edit_rounded, size: 14, color: ac.txt2),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonList(BuildContext context, String topic, AppColors ac) {
    final lessons = _tree[_subject!]?[topic] ?? [];
    if (lessons.isEmpty) {
      return Center(child: Text('No lessons in this topic yet.', style: AppText.bodySm.copyWith(color: ac.txt2)));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(topic, style: AppText.h1.copyWith(fontSize: 18)),
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          itemCount: lessons.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final lesson = lessons[i];
            return Material(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.md),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CourseReaderPage(course: lesson, currentUser: widget.currentUser)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
                  child: Row(children: [
                    // The lesson's own thumbnail is its primary visual
                    // identity (coverImageUrl, set on the composer) — the
                    // numbered chip is just sequence order, not a
                    // replacement for a real thumbnail.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: (lesson.coverImageUrl ?? '').isNotEmpty
                          ? Image.network(lesson.coverImageUrl!, width: 40, height: 40, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _lessonNumberChip(ac, i))
                          : _lessonNumberChip(ac, i),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lesson.title, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700)),
                        if (lesson.difficulty.isNotEmpty)
                          Text(lesson.difficulty, style: AppText.caption.copyWith(color: ac.txt2)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _lessonNumberChip(AppColors ac, int i) => Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(8)),
        child: Text('${i + 1}', style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.primary)),
      );
}

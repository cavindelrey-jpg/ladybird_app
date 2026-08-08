// lib/features/courses_marketplace/course_browse_page.dart
// The "table of contents" view for marketplace Courses — lets students
// navigate Category → Subject → Curriculum/Level → Topic → ordered
// Lessons, instead of only finding a lesson via search. Complements
// (doesn't replace) the flat feed in courses_marketplace_page.dart;
// courses without full curriculum placement simply don't appear here.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'course_reader_page.dart';

class CourseBrowsePage extends StatefulWidget {
  final AppUser? currentUser;
  final String? initialCategory;
  final String? initialSubject;
  final String? initialLevel;
  final String? initialTopic;
  const CourseBrowsePage({
    super.key,
    this.currentUser,
    this.initialCategory,
    this.initialSubject,
    this.initialLevel,
    this.initialTopic,
  });

  @override
  State<CourseBrowsePage> createState() => _CourseBrowsePageState();
}

/// One tree level for the drill-down: category → subject → level → topic.
enum _BrowseLevel { category, subject, level, topic }

class _CourseBrowsePageState extends State<CourseBrowsePage> {
  // Full tree: category -> subject -> level -> topic -> ordered lessons.
  Map<String, Map<String, Map<String, Map<String, List<PublicCourse>>>>> _tree = {};
  Map<String, CurriculumIcon> _icons = {};
  bool _loading = true;

  String? _category;
  String? _subject;
  String? _level;
  String? _topic;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _subject = widget.initialSubject;
    _level = widget.initialLevel;
    _topic = widget.initialTopic;
    _load();
  }

  Future<void> _load() async {
    final repo = PublicCourseRepository.instance;
    try {
      final results = await Future.wait([repo.curriculumTreeOnce(), repo.curriculumIconsOnce()]);
      if (!mounted) return;
      setState(() {
        _tree = results[0] as Map<String, Map<String, Map<String, Map<String, List<PublicCourse>>>>>;
        _icons = results[1] as Map<String, CurriculumIcon>;
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

  _BrowseLevel get _currentLevel {
    if (_category == null) return _BrowseLevel.category;
    if (_subject == null) return _BrowseLevel.subject;
    if (_level == null) return _BrowseLevel.level;
    return _BrowseLevel.topic;
  }

  void _goBack() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_topic != null) { _topic = null; return; }
      if (_level != null) { _level = null; return; }
      if (_subject != null) { _subject = null; return; }
      _category = null;
    });
  }

  String get _title {
    switch (_currentLevel) {
      case _BrowseLevel.category: return 'Browse Courses';
      case _BrowseLevel.subject: return _category!;
      case _BrowseLevel.level: return _subject!;
      case _BrowseLevel.topic: return _level!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        leading: (_category != null)
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _goBack)
            : null,
        title: Text(_title, style: AppText.title),
      ),
      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_tree.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No courses have been placed in the curriculum tree yet. '
            'Give a course a Subject, Level and Topic when creating it to see it here.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(color: C.txt2),
          ),
        ),
      );
    }

    if (_breadcrumbTopic != null) {
      return _buildLessonList(_breadcrumbTopic!);
    }

    switch (_currentLevel) {
      case _BrowseLevel.category:
        return _buildList(_tree.keys.toList()..sort(), (v) => setState(() => _category = v));
      case _BrowseLevel.subject:
        final subjects = (_tree[_category!] ?? {}).keys.toList()..sort();
        return _buildList(subjects, (v) => setState(() => _subject = v));
      case _BrowseLevel.level:
        final levels = (_tree[_category!]?[_subject!] ?? {}).keys.toList()..sort();
        return _buildList(levels, (v) => setState(() => _level = v));
      case _BrowseLevel.topic:
        final topics = (_tree[_category!]?[_subject!]?[_level!] ?? {}).keys.toList()..sort();
        return _buildList(topics, (v) => setState(() => _topic = v), isTopic: true);
    }
  }

  /// Once a topic is picked we go straight to the lesson list rather
  /// than tracking a 5th enum level — `_topic` doubles as "show lessons".
  String? get _breadcrumbTopic => _topic;

  /// Icon lookup for the level currently being browsed — categories
  /// fall back to a letter-avatar (they already have their own iconography
  /// elsewhere in the app); subject/level/topic use whatever was assigned
  /// via the composer, same fallback otherwise.
  CurriculumIcon _iconFor(String label) {
    switch (_currentLevel) {
      case _BrowseLevel.category:
        return CurriculumIcon.none;
      case _BrowseLevel.subject:
        return _icons[PublicCourseRepository.subjectIconKey(_category!, label)] ?? CurriculumIcon.none;
      case _BrowseLevel.level:
        return _icons[PublicCourseRepository.levelIconKey(_category!, _subject!, label)] ?? CurriculumIcon.none;
      case _BrowseLevel.topic:
        return _icons[PublicCourseRepository.topicIconKey(_category!, _subject!, _level!, label)] ?? CurriculumIcon.none;
    }
  }

  Widget _buildList(List<String> items, ValueChanged<String> onTap, {bool isTopic = false}) {
    if (items.isEmpty) {
      return Center(child: Text('Nothing here yet.', style: AppText.bodySm.copyWith(color: C.txt2)));
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
        final count = isTopic ? (_tree[_category!]?[_subject!]?[_level!]?[label]?.length ?? 0) : null;
        return Material(
          color: C.surf,
          borderRadius: BorderRadius.circular(Rad.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.md),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(label);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr2)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                HierarchyAvatar(label: label, icon: _iconFor(label).emoji, imageUrl: _iconFor(label).imageUrl, size: 48),
                const Spacer(),
                Text(label, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (count != null) ...[
                  const SizedBox(height: 2),
                  Text('$count lesson${count == 1 ? '' : 's'}', style: AppText.caption.copyWith(color: C.txt2)),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonList(String topic) {
    final lessons = _tree[_category!]?[_subject!]?[_level!]?[topic] ?? [];
    if (lessons.isEmpty) {
      return Center(child: Text('No lessons in this topic yet.', style: AppText.bodySm.copyWith(color: C.txt2)));
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
              color: C.surf,
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
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr2)),
                  child: Row(children: [
                    Container(
                      width: 26, height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(8)),
                      child: Text('${i + 1}', style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: C.primary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lesson.title, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700)),
                        if (lesson.difficulty.isNotEmpty)
                          Text(lesson.difficulty, style: AppText.caption.copyWith(color: C.txt2)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: C.muted),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// lib/features/courses_marketplace/subject_topics_page.dart
// Third tier: topics available within one Level+Subject (e.g. Mathematics
// -> Algebra, Geometry, ...). Topic = courses.topic.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart' show CurriculumIcon;
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'hierarchy_browse_scaffold.dart';
import 'topic_courses_page.dart';
import 'curriculum_icon_editor.dart';

class SubjectTopicsPage extends StatefulWidget {
  final String level;
  final String subject;
  final AppUser? user;
  const SubjectTopicsPage({super.key, required this.level, required this.subject, this.user});

  @override
  State<SubjectTopicsPage> createState() => _SubjectTopicsPageState();
}

class _SubjectTopicsPageState extends State<SubjectTopicsPage> {
  bool _loading = true;
  Map<String, int> _counts = {};
  Map<String, CurriculumIcon> _icons = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = PublicCourseRepository.instance;
    final results = await Future.wait([
      repo.topicCountsInSubject(widget.level, widget.subject),
      repo.curriculumIconsOnce(),
    ]);
    if (!mounted) return;
    setState(() {
      _counts = results[0] as Map<String, int>;
      _icons = results[1] as Map<String, CurriculumIcon>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topics = _counts.keys.toList()..sort();
    return HierarchyBrowseScaffold<String>(
      title: widget.subject,
      subtitle: '${_counts.values.fold<int>(0, (a, b) => a + b)} courses',
      searchHint: 'Search topics…',
      loading: _loading,
      items: topics,
      searchableText: (t) => t,
      emptyMessage: 'No topics have courses placed under this subject yet.',
      gridTileBuilder: (context, topic) => _TopicTile(
        level: widget.level, subject: widget.subject, topic: topic, count: _counts[topic] ?? 0,
        icon: _icons[PublicCourseRepository.eduTopicIconKey(widget.level, widget.subject, topic)] ?? CurriculumIcon.none,
        isGrid: true, canManage: widget.user?.canUploadContent ?? false,
        onTap: () => _open(context, topic), onChanged: _load,
      ),
      listTileBuilder: (context, topic) => _TopicTile(
        level: widget.level, subject: widget.subject, topic: topic, count: _counts[topic] ?? 0,
        icon: _icons[PublicCourseRepository.eduTopicIconKey(widget.level, widget.subject, topic)] ?? CurriculumIcon.none,
        isGrid: false, canManage: widget.user?.canUploadContent ?? false,
        onTap: () => _open(context, topic), onChanged: _load,
      ),
    );
  }

  void _open(BuildContext context, String topic) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TopicCoursesPage(level: widget.level, subject: widget.subject, topic: topic, user: widget.user)));
  }
}

class _TopicTile extends StatelessWidget {
  final String level;
  final String subject;
  final String topic;
  final int count;
  final CurriculumIcon icon;
  final bool isGrid;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onChanged;
  const _TopicTile({
    required this.level, required this.subject, required this.topic, required this.count, required this.icon,
    required this.isGrid, required this.canManage, required this.onTap, required this.onChanged,
  });

  String get _iconKey => PublicCourseRepository.eduTopicIconKey(level, subject, topic);

  void _showMenu(BuildContext context) {
    final ac = AppColors.of(context);
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.image_outlined, color: ac.primary),
            title: const Text('Edit thumbnail'),
            onTap: () { Navigator.pop(sheetContext); editCurriculumThumbnail(context, iconKey: _iconKey, onChanged: onChanged); },
          ),
          if (icon.imageUrl.isNotEmpty)
            ListTile(
              leading: Icon(Icons.close_rounded, color: ac.muted),
              title: const Text('Remove thumbnail'),
              onTap: () { Navigator.pop(sheetContext); removeCurriculumThumbnail(context, iconKey: _iconKey, emoji: icon.emoji, onChanged: onChanged); },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (isGrid) {
      return Material(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.md),
          onTap: onTap,
          onLongPress: canManage ? () => _showMenu(context) : null,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: HierarchyAvatar(label: topic, icon: icon.emoji, imageUrl: icon.imageUrl, fill: true),
              ),
              const SizedBox(height: 6),
              Text(topic, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('$count course${count == 1 ? '' : 's'}', style: AppText.caption.copyWith(fontSize: 10.5)),
            ]),
          ),
        ),
      );
    }
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onTap,
        onLongPress: canManage ? () => _showMenu(context) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
          child: Row(children: [
            HierarchyAvatar(label: topic, icon: icon.emoji, imageUrl: icon.imageUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(topic, style: AppText.title.copyWith(fontSize: 14)),
                Text('$count course${count == 1 ? '' : 's'}', style: AppText.caption.copyWith(fontSize: 11)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
          ]),
        ),
      ),
    );
  }
}

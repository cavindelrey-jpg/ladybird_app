// lib/features/courses_marketplace/level_subjects_page.dart
// Second tier of the hierarchy: subjects available within one education
// level (e.g. Junior Secondary -> Mathematics, English Language, ...).
// Subject = courses.category — see the IA redesign notes in
// public_course_repository.dart for why.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart' show CurriculumIcon;
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'hierarchy_browse_scaffold.dart';
import 'subject_topics_page.dart';
import 'curriculum_icon_editor.dart';

class LevelSubjectsPage extends StatefulWidget {
  final String level;
  final AppUser? user;
  const LevelSubjectsPage({super.key, required this.level, this.user});

  @override
  State<LevelSubjectsPage> createState() => _LevelSubjectsPageState();
}

class _LevelSubjectsPageState extends State<LevelSubjectsPage> {
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
      repo.subjectCountsInLevel(widget.level),
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
    final subjects = _counts.keys.toList()..sort();
    final totalCourses = _counts.values.fold<int>(0, (a, b) => a + b);
    return HierarchyBrowseScaffold<String>(
      user: widget.user,
      destination: AppNavDestination.academicCourses,
      title: widget.level,
      subtitle: '$totalCourses courses',
      contextualPanel: _LevelSubjectsRightPanel(
        level: widget.level,
        subjectCount: subjects.length,
        totalCourses: totalCourses,
      ),
      searchHint: 'Search subjects…',
      loading: _loading,
      items: subjects,
      searchableText: (s) => s,
      emptyMessage: 'No subjects have courses placed under this level yet.',
      gridTileBuilder: (context, subject) => _SubjectTile(
        level: widget.level, subject: subject, count: _counts[subject] ?? 0,
        icon: _icons[PublicCourseRepository.eduSubjectIconKey(widget.level, subject)] ?? CurriculumIcon.none,
        isGrid: true, canManage: widget.user?.canUploadContent ?? false,
        onTap: () => _open(context, subject), onChanged: _load,
      ),
      listTileBuilder: (context, subject) => _SubjectTile(
        level: widget.level, subject: subject, count: _counts[subject] ?? 0,
        icon: _icons[PublicCourseRepository.eduSubjectIconKey(widget.level, subject)] ?? CurriculumIcon.none,
        isGrid: false, canManage: widget.user?.canUploadContent ?? false,
        onTap: () => _open(context, subject), onChanged: _load,
      ),
    );
  }

  void _open(BuildContext context, String subject) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SubjectTopicsPage(level: widget.level, subject: subject, user: widget.user)));
  }
}

class _SubjectTile extends StatelessWidget {
  final String level;
  final String subject;
  final int count;
  final CurriculumIcon icon;
  final bool isGrid;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onChanged;
  const _SubjectTile({
    required this.level, required this.subject, required this.count, required this.icon, required this.isGrid,
    required this.canManage, required this.onTap, required this.onChanged,
  });

  String get _iconKey => PublicCourseRepository.eduSubjectIconKey(level, subject);

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
                child: HierarchyAvatar(label: subject, icon: icon.emoji, imageUrl: icon.imageUrl, fill: true),
              ),
              const SizedBox(height: 6),
              Text(subject, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
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
            HierarchyAvatar(label: subject, icon: icon.emoji, imageUrl: icon.imageUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subject, style: AppText.title.copyWith(fontSize: 14)),
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

class _LevelSubjectsRightPanel extends StatelessWidget {
  final String level;
  final int subjectCount;
  final int totalCourses;

  const _LevelSubjectsRightPanel({
    required this.level,
    required this.subjectCount,
    required this.totalCourses,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_rounded, size: 18, color: Color(0xFFE5A93C)),
                  const SizedBox(width: 8),
                  Text('CURRICULUM LEVEL',
                      style: AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                level,
                style: AppText.title.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$subjectCount Subject${subjectCount == 1 ? '' : 's'}',
                      style: AppText.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE5A93C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ac.surf2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$totalCourses Courses',
                      style: AppText.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ac.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Explore all subjects under $level. Select any subject to view detailed topic modules and verified courses.',
                style: AppText.caption.copyWith(color: ac.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


// lib/features/courses_marketplace/topic_courses_page.dart
// Fourth tier: the actual courses inside one Level+Subject+Topic (e.g.
// Algebra -> Linear Equations, Quadratic Equations, ...).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'hierarchy_browse_scaffold.dart';
import 'course_lessons_page.dart';

class TopicCoursesPage extends StatefulWidget {
  final String level;
  final String subject;
  final String topic;
  final AppUser? user;
  const TopicCoursesPage({
    super.key, required this.level, required this.subject, required this.topic, this.user,
  });

  @override
  State<TopicCoursesPage> createState() => _TopicCoursesPageState();
}

class _TopicCoursesPageState extends State<TopicCoursesPage> {
  bool _loading = true;
  List<PublicCourse> _courses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final courses = await PublicCourseRepository.instance
        .coursesInTopic(widget.level, widget.subject, widget.topic);
    if (mounted) setState(() { _courses = courses; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return HierarchyBrowseScaffold<PublicCourse>(
      title: widget.topic,
      subtitle: '${_courses.length} course${_courses.length == 1 ? '' : 's'}',
      searchHint: 'Search courses…',
      loading: _loading,
      items: _courses,
      searchableText: (c) => c.title,
      emptyMessage: 'No courses in this topic yet.',
      gridTileBuilder: (context, course) => _CourseTile(course: course, isGrid: true, onTap: () => _open(context, course)),
      listTileBuilder: (context, course) => _CourseTile(course: course, isGrid: false, onTap: () => _open(context, course)),
    );
  }

  void _open(BuildContext context, PublicCourse course) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CourseLessonsPage(course: course, currentUser: widget.user)));
  }
}

class _CourseTile extends StatelessWidget {
  final PublicCourse course;
  final bool isGrid;
  final VoidCallback onTap;
  const _CourseTile({required this.course, required this.isGrid, required this.onTap});

  Widget _thumb(AppColors ac, {required double? size}) {
    final hasCover = (course.coverImageUrl ?? '').isNotEmpty;
    final child = hasCover
        ? Image.network(course.coverImageUrl!, fit: BoxFit.cover,
            width: size, height: size, errorBuilder: (_, __, ___) => _fallbackThumb(ac, size))
        : _fallbackThumb(ac, size);
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: child);
  }

  Widget _fallbackThumb(AppColors ac, double? size) => Container(
      width: size, height: size, color: ac.primaryBg,
      alignment: Alignment.center,
      child: Icon(Icons.menu_book_rounded, color: ac.primary, size: 26));

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
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: SizedBox(width: double.infinity, child: _thumb(ac, size: null))),
              const SizedBox(height: 6),
              Text(course.title, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('Course', style: AppText.caption.copyWith(fontSize: 10.5)),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
          child: Row(children: [
            _thumb(ac, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(course.title, style: AppText.title.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Course', style: AppText.caption.copyWith(fontSize: 11)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
          ]),
        ),
      ),
    );
  }
}

// lib/features/courses_marketplace/course_lessons_page.dart
// Fifth tier: the lessons inside one Course. Where the user actually
// enters the learning content — see LessonReaderPage.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/course_lesson.dart';
import '../../models/public_course.dart';
import '../../repositories/course_lesson_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'hierarchy_browse_scaffold.dart';
import 'lesson_reader_page.dart';

class CourseLessonsPage extends StatefulWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const CourseLessonsPage({super.key, required this.course, this.currentUser});

  @override
  State<CourseLessonsPage> createState() => _CourseLessonsPageState();
}

class _CourseLessonsPageState extends State<CourseLessonsPage> {
  @override
  void initState() {
    super.initState();
    if (widget.currentUser != null) {
      PublicCourseRepository.instance.recordCourseView(widget.course.id, widget.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CourseLesson>>(
      stream: CourseLessonRepository.instance.watchLessons(widget.course.id),
      builder: (context, snap) {
        final lessons = snap.data ?? const <CourseLesson>[];
        final loading = snap.connectionState == ConnectionState.waiting;
        return HierarchyBrowseScaffold<CourseLesson>(
          title: widget.course.title,
          subtitle: '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}',
          searchHint: 'Search lessons…',
          loading: loading,
          items: lessons,
          searchableText: (l) => l.title,
          emptyMessage: 'No lessons have been added to this course yet.',
          gridTileBuilder: (context, lesson, isSelected, isSelectionMode, toggleSelection) => _LessonTile(
            lesson: lesson, isGrid: true, isSelected: isSelected, isSelectionMode: isSelectionMode,
            onTap: isSelectionMode ? toggleSelection : () => _open(context, lesson),
            onLongPress: isSelectionMode ? null : toggleSelection,
          ),
          listTileBuilder: (context, lesson, isSelected, isSelectionMode, toggleSelection) => _LessonTile(
            lesson: lesson, isGrid: false, isSelected: isSelected, isSelectionMode: isSelectionMode,
            onTap: isSelectionMode ? toggleSelection : () => _open(context, lesson),
            onLongPress: isSelectionMode ? null : toggleSelection,
          ),
        );
      },
    );
  }

  void _open(BuildContext context, CourseLesson lesson) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LessonReaderPage(course: widget.course, lesson: lesson, currentUser: widget.currentUser)));
  }
}

class _LessonTile extends StatelessWidget {
  final CourseLesson lesson;
  final bool isGrid;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _LessonTile({
    required this.lesson, required this.isGrid,
    required this.isSelected, required this.isSelectionMode,
    required this.onTap, this.onLongPress,
  });

  String get _meta {
    final parts = <String>[];
    if (lesson.durationSeconds != null && lesson.durationSeconds! > 0) {
      final m = lesson.durationSeconds! ~/ 60;
      final s = lesson.durationSeconds! % 60;
      parts.add('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
    }
    parts.add('${lesson.viewCount} student${lesson.viewCount == 1 ? '' : 's'}');
    return parts.join(' • ');
  }

  Widget _thumb(AppColors ac, {required double? size}) {
    final hasCover = (lesson.coverImageUrl ?? '').isNotEmpty;
    final child = hasCover
        ? Image.network(lesson.coverImageUrl!, fit: BoxFit.cover, width: size, height: size,
            errorBuilder: (_, __, ___) => _fallback(ac, size))
        : _fallback(ac, size);
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: child);
  }

  Widget _fallback(AppColors ac, double? size) => Container(
      width: size, height: size, color: ac.primaryBg,
      alignment: Alignment.center,
      child: Icon(
          (lesson.videoUrl ?? '').isNotEmpty ? Icons.play_circle_outline_rounded : Icons.article_outlined,
          color: ac.primary, size: 26));

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final border = isSelected ? Border.all(color: ac.primary, width: 2) : Border.all(color: ac.bdr);
    
    Widget check() => isSelectionMode
        ? Positioned(
            top: 8, right: 8,
            child: Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? ac.primary : ac.muted, size: 24),
          )
        : const SizedBox.shrink();

    if (isGrid) {
      return Material(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.md),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: border),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: SizedBox(width: double.infinity, child: _thumb(ac, size: null))),
                const SizedBox(height: 10),
                Text(lesson.title, style: AppText.title.copyWith(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_meta, style: AppText.caption.copyWith(fontSize: 10.5, color: ac.muted)),
              ]),
              check(),
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
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: border),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (isSelectionMode) ...[
              Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? ac.primary : ac.muted, size: 24),
              const SizedBox(width: 12),
            ],
            _thumb(ac, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lesson.title, style: AppText.title.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_meta, style: AppText.caption.copyWith(fontSize: 11.5, color: ac.muted)),
              ]),
            ),
            if (!isSelectionMode)
              Icon(Icons.chevron_right_rounded, size: 20, color: ac.muted),
          ]),
        ),
      ),
    );
  }
}

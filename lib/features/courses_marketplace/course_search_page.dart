// lib/features/courses_marketplace/course_search_page.dart
// Full-text search across all published courses — the search bar shown on
// Courses Home opens here rather than filtering the home screen itself,
// since Recommended/Recent Reads are discovery, not the searchable catalog.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'course_lessons_page.dart';

class CourseSearchPage extends StatefulWidget {
  final AppUser? user;
  const CourseSearchPage({super.key, this.user});

  @override
  State<CourseSearchPage> createState() => _CourseSearchPageState();
}

class _CourseSearchPageState extends State<CourseSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _applyFilter(String cat) {
    _searchController.text = cat;
    setState(() => _query = cat);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final effectiveUser = widget.user ?? AuthService.instance.lastKnownUser;

    return ApplicationShell(
      user: effectiveUser,
      currentTitle: 'Course Search',
      subtitle: 'Browse and discover courses across subjects and levels',
      currentDestination: AppNavDestination.academicCourses,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      contextualPanel: _CourseSearchRightPanel(
        query: _query,
        onSelectFilter: _applyFilter,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              style: AppText.bodySm.copyWith(color: ac.txt),
              decoration: InputDecoration(
                hintText: 'Search courses, topics, subjects…',
                hintStyle: AppText.bodySm.copyWith(color: ac.muted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: ac.muted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: ac.surf2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Rad.md),
                  borderSide: BorderSide(color: ac.bdr2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Rad.md),
                  borderSide: BorderSide(color: ac.bdr2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Rad.md),
                  borderSide: BorderSide(color: ac.primary),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PublicCourse>>(
              stream: PublicCourseRepository.instance.watchLatest(limit: 200),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, __) => const ShimmerBlock(width: double.infinity, height: 72),
                  );
                }
                var courses = snap.data ?? const <PublicCourse>[];
                if (_query.isNotEmpty) {
                  final q = _query.toLowerCase();
                  courses = courses.where((c) =>
                      c.title.toLowerCase().contains(q) ||
                      c.description.toLowerCase().contains(q) ||
                      c.category.toLowerCase().contains(q) ||
                      c.topic.toLowerCase().contains(q)).toList();
                }
                if (_query.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, size: 48, color: ac.muted),
                          const SizedBox(height: 12),
                          Text(
                            'Start typing to search courses, topics, and subjects.',
                            textAlign: TextAlign.center,
                            style: AppText.bodySm.copyWith(color: ac.txt2),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (courses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: ac.muted),
                          const SizedBox(height: 12),
                          Text(
                            'No courses match "$_query".',
                            textAlign: TextAlign.center,
                            style: AppText.bodySm.copyWith(color: ac.txt2),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final course = courses[i];
                    final meta = [course.level, course.category, course.topic]
                        .where((s) => s.isNotEmpty)
                        .join(' • ');
                    return Material(
                      color: ac.surf,
                      borderRadius: BorderRadius.circular(Rad.md),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Rad.md),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CourseLessonsPage(
                              course: course,
                              currentUser: effectiveUser,
                            ),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Rad.md),
                            border: Border.all(color: ac.bdr2),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: (course.coverImageUrl ?? '').isNotEmpty
                                      ? Image.network(
                                          course.coverImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(color: ac.primaryBg),
                                        )
                                      : Container(
                                          color: ac.primaryBg,
                                          child: Icon(Icons.menu_book_rounded, color: ac.primary),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.title,
                                      style: AppText.title.copyWith(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (meta.isNotEmpty)
                                      Text(
                                        meta,
                                        style: AppText.caption.copyWith(fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseSearchRightPanel extends StatelessWidget {
  final String query;
  final ValueChanged<String> onSelectFilter;

  const _CourseSearchRightPanel({
    required this.query,
    required this.onSelectFilter,
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
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.manage_search_rounded, size: 18, color: ac.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Search Parameters',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Full catalog search scans published course titles, descriptions, curriculum subjects, and topic tags.',
                style: AppText.caption.copyWith(color: ac.txt2, height: 1.4),
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ac.primaryBg,
                    borderRadius: BorderRadius.circular(Rad.sm),
                    border: Border.all(color: ac.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt_rounded, size: 14, color: ac.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Filtered by: "$query"',
                          style: AppText.caption.copyWith(
                            color: ac.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  Icon(Icons.category_outlined, size: 18, color: ac.gold),
                  const SizedBox(width: 8),
                  Text(
                    'Curriculum Subjects',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kCourseCategories.take(8).map((cat) {
                  final isSelected = query.toLowerCase() == cat.toLowerCase();
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelectFilter(cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? ac.primary : ac.surf2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? ac.primary : ac.bdr),
                        ),
                        child: Text(
                          cat,
                          style: AppText.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : ac.txt2,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: ac.muted),
                  const SizedBox(width: 8),
                  Text(
                    'Search Guidelines',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _TipItem(icon: Icons.title_rounded, text: 'Search by course name (e.g. Algebra)'),
              const SizedBox(height: 6),
              const _TipItem(icon: Icons.school_outlined, text: 'Search by grade level (e.g. Grade 10)'),
              const SizedBox(height: 6),
              const _TipItem(icon: Icons.tag_rounded, text: 'Search by topic keyword or concept'),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: ac.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppText.caption.copyWith(color: ac.txt2, height: 1.3),
          ),
        ),
      ],
    );
  }
}

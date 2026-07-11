// lib/features/courses_marketplace/courses_marketplace_page.dart
// The general-app Courses experience — genuinely separate from
// features/courses/courses_page.dart (school-scoped catalog, still
// powering Attendance/Assignments, untouched). Any signed-in user can
// create and publish a course here; browsing is by category, not school.
//
// Matches the reference layout: hero banner, category chips, Featured
// Courses (computed — most-rated/enrolled, not manually curated),
// Popular Topics (real counts from the catalogue), Latest from
// Contributors (article-style cards with like/comment/bookmark).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../pages/notifications_page.dart';
import 'course_reader_page.dart';
import 'course_composer_page.dart';
import 'course_creator_profile_page.dart';

const _kCategoryIcons = <String, IconData>{
  'Mathematics':      Icons.functions_rounded,
  'Science':          Icons.science_rounded,
  'Languages':        Icons.translate_rounded,
  'Computer Science': Icons.code_rounded,
  'Arts':             Icons.palette_rounded,
  'Business':         Icons.trending_up_rounded,
  'Social Studies':   Icons.public_rounded,
  'Other':            Icons.more_horiz_rounded,
};

class CoursesMarketplacePage extends StatefulWidget {
  final AppUser? user;
  const CoursesMarketplacePage({super.key, this.user});

  @override
  State<CoursesMarketplacePage> createState() => _CoursesMarketplacePageState();
}

class _CoursesMarketplacePageState extends State<CoursesMarketplacePage> {
  String? _category; // null = All
  bool _searchOpen = false;
  String _searchQuery = '';

  bool get _canCreate => widget.user != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(children: [
          _header(context),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: AppText.bodySm.copyWith(color: C.txt),
                decoration: InputDecoration(
                  hintText: 'Search courses…',
                  hintStyle: AppText.bodySm.copyWith(color: C.muted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: C.muted),
                  filled: true, fillColor: C.surf2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _heroBanner(context),
                const SizedBox(height: 18),
                _categoryChips(),
                const SizedBox(height: 20),
                if (_category == null) ...[
                  _sectionHeader('Featured Courses', onSeeAll: () {}),
                  const SizedBox(height: 12),
                  _featuredRow(context),
                  const SizedBox(height: 24),
                  _sectionHeader('Popular Topics', onSeeAll: () {}),
                  const SizedBox(height: 12),
                  _popularTopics(),
                  const SizedBox(height: 24),
                  _sectionHeader('Latest from Contributors', onSeeAll: () {}),
                  const SizedBox(height: 12),
                  _contributorFeed(context, stream: PublicCourseRepository.instance.watchLatest(), searchQuery: _searchQuery),
                ] else ...[
                  _sectionHeader(_category!, onSeeAll: () {}),
                  const SizedBox(height: 12),
                  _contributorFeed(context,
                      stream: PublicCourseRepository.instance.watchByCategory(_category!), searchQuery: _searchQuery),
                ],
                if (_canCreate) _createCourseCta(context),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Courses', style: AppText.h1.copyWith(fontSize: 22)),
            Text('Learn. Share. Grow.', style: AppText.caption.copyWith(fontSize: 12)),
          ]),
        ),
        IconButton(icon: const Icon(Icons.search_rounded, color: C.txt2),
            onPressed: () => setState(() => _searchOpen = !_searchOpen)),
        if (widget.user != null)
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: C.txt2),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationsPage(userId: widget.user!.id))),
          ),
        UserAvatar(
          initials: (widget.user?.name.isNotEmpty ?? false) ? widget.user!.name[0].toUpperCase() : '?',
          radius: 18, photoUrl: widget.user?.photoUrl,
        ),
      ]),
    );
  }

  Widget _heroBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [C.navy, C.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(Rad.lg),
          boxShadow: Shad.md,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Share knowledge.\nTeach the world.',
              style: AppText.h1.copyWith(color: Colors.white, fontSize: 20, height: 1.25)),
          const SizedBox(height: 8),
          Text('Create and publish courses in your area of expertise.',
              style: AppText.bodySm.copyWith(color: Colors.white.withValues(alpha: .8))),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton.icon(
              onPressed: _canCreate ? () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CourseComposerPage(user: widget.user!)));
              } : () => showToast(context, 'Sign in to create a course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: C.navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Create Course', style: AppText.caption.copyWith(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: C.navy)),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text('How it works', style: AppText.caption.copyWith(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _categoryChips() {
    final cats = ['All', ...kCourseCategories];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = cats[i];
          final active = (cat == 'All' && _category == null) || cat == _category;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _category = cat == 'All' ? null : cat);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? C.navy : C.surf2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? C.navy : C.bdr),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (cat != 'All')
                    Icon(_kCategoryIcons[cat] ?? Icons.circle, size: 14,
                        color: active ? C.gold : C.txt2),
                  if (cat != 'All') const SizedBox(width: 6),
                  Text(cat, style: AppText.caption.copyWith(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? C.gold : C.txt2)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 16))),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSeeAll,
            child: Text('See all', style: AppText.subtitle.copyWith(
                color: C.primary, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
      ]),
    );
  }

  Widget _featuredRow(BuildContext context) {
    return FutureBuilder<List<PublicCourse>>(
      future: PublicCourseRepository.instance.watchFeaturedOnce(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const ShimmerBlock(width: 220, height: 210),
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Failed to load: ${snap.error}',
                style: AppText.caption.copyWith(color: C.red, fontSize: 11)),
          );
        }
        final courses = snap.data ?? const <PublicCourse>[];
        if (courses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No courses yet — be the first to publish one.', style: AppText.bodySm),
          );
        }
        return SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _FeaturedCourseCard(
              course: courses[i],
              currentUser: widget.user,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourseReaderPage(course: courses[i], currentUser: widget.user))),
            ),
          ),
        );
      },
    );
  }

  Widget _popularTopics() {
    return FutureBuilder<Map<String, int>>(
      future: PublicCourseRepository.instance.categoryCountsOnce(),
      builder: (context, snap) {
        final counts = snap.data ?? const <String, int>{};
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10, runSpacing: 10,
            children: kCourseCategories.map((cat) {
              final count = counts[cat] ?? 0;
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(Rad.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.md),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _category = cat);
                  },
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
                    child: Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(9)),
                        child: Icon(_kCategoryIcons[cat] ?? Icons.circle, size: 17, color: C.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(cat, style: AppText.subtitle.copyWith(color: C.txt, fontSize: 12.5),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('$count course${count == 1 ? '' : 's'}', style: AppText.caption.copyWith(fontSize: 10.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _contributorFeed(BuildContext context, {required Stream<List<PublicCourse>> stream, String searchQuery = ''}) {
    return StreamBuilder<List<PublicCourse>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              const ShimmerBlock(width: 84, height: 84, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                ShimmerLine(height: 14), SizedBox(height: 8), ShimmerLine(width: 120, height: 12),
              ])),
            ]),
          )));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Failed to load: ${snap.error}',
                style: AppText.caption.copyWith(color: C.red, fontSize: 11)),
          );
        }
        var courses = snap.data ?? const <PublicCourse>[];
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          courses = courses.where((c) =>
              c.title.toLowerCase().contains(q) || c.description.toLowerCase().contains(q)).toList();
        }
        if (courses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(searchQuery.isNotEmpty ? 'No courses match "$searchQuery".' : 'No courses here yet.',
                style: AppText.bodySm),
          );
        }
        return Column(children: courses.map((c) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _ContributorCard(
            course: c,
            currentUser: widget.user,
            onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CourseReaderPage(course: c, currentUser: widget.user))),
            onOpenCreator: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CourseCreatorProfilePage(creatorId: c.creatorId, currentUser: widget.user))),
          ),
        )).toList());
      },
    );
  }

  Widget _createCourseCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CourseComposerPage(user: widget.user!)));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: C.navy, foregroundColor: C.gold,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: Text('Create Course', style: AppText.button.copyWith(fontSize: 14, color: C.gold)),
        ),
      ),
    );
  }
}

class _FeaturedCourseCard extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  final VoidCallback onTap;
  const _FeaturedCourseCard({required this.course, required this.currentUser, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        child: Container(
          width: 210,
          decoration: BoxDecoration(
              color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              SizedBox(
                height: 100, width: double.infinity,
                child: (course.coverImageUrl ?? '').isNotEmpty
                    ? Image.network(course.coverImageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: C.navy))
                    : Container(
                        color: C.navy,
                        child: Icon(_kCategoryIcons[course.category] ?? Icons.school_rounded,
                            color: C.gold, size: 32)),
              ),
              Positioned(
                top: 8, right: 8,
                child: _BookmarkButton(course: course, currentUser: currentUser, dark: true),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusBadge(label: course.category, color: _categoryColor(course.category)),
                const SizedBox(height: 6),
                Text(course.title, style: AppText.title.copyWith(fontSize: 13.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(course.description, style: AppText.caption.copyWith(fontSize: 11),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  UserAvatar(initials: course.creatorName.isEmpty ? '?' : course.creatorName[0].toUpperCase(),
                      radius: 8, photoUrl: course.creatorPhotoUrl),
                  const SizedBox(width: 5),
                  Expanded(child: Text('By ${course.creatorName}', style: AppText.caption.copyWith(fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.star_rounded, size: 13, color: C.gold),
                  const SizedBox(width: 2),
                  Text(course.avgRating > 0 ? course.avgRating.toStringAsFixed(1) : '—',
                      style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Icon(Icons.people_alt_outlined, size: 12, color: C.muted),
                  const SizedBox(width: 2),
                  Text(_formatCount(course.enrolledCount), style: AppText.caption.copyWith(fontSize: 10.5)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ContributorCard extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  final VoidCallback onOpen, onOpenCreator;
  const _ContributorCard({
    required this.course, required this.currentUser,
    required this.onOpen, required this.onOpenCreator,
  });

  bool get _isOwn => currentUser?.id == course.creatorId;

  String _readTime() {
    final words = course.body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return '${(words / 200).ceil().clamp(1, 999)} min read';
  }

  @override
  Widget build(BuildContext context) {
    return ACard(
      onTap: onOpen,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 84, height: 84,
            child: (course.coverImageUrl ?? '').isNotEmpty
                ? Image.network(course.coverImageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: C.surf3))
                : Container(color: _categoryColor(course.category).withValues(alpha: .12),
                    child: Icon(_kCategoryIcons[course.category] ?? Icons.school_rounded,
                        color: _categoryColor(course.category), size: 26)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: StatusBadge(label: course.category, color: _categoryColor(course.category))),
              if (_isOwn)
                const Icon(Icons.more_horiz_rounded, size: 18, color: C.muted)
              else
                _BookmarkButton(course: course, currentUser: currentUser, dark: false),
            ]),
            const SizedBox(height: 4),
            Text(course.title, style: AppText.title.copyWith(fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(course.description, style: AppText.bodySm.copyWith(fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () { HapticFeedback.selectionClick(); onOpenCreator(); },
                  child: Row(children: [
                    UserAvatar(initials: course.creatorName.isEmpty ? '?' : course.creatorName[0].toUpperCase(),
                        radius: 9, photoUrl: course.creatorPhotoUrl),
                    const SizedBox(width: 5),
                    Text('By ${course.creatorName}', style: AppText.caption.copyWith(fontSize: 10.5, color: C.txt)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Text('· ${_readTime()}', style: AppText.caption.copyWith(fontSize: 10)),
              const Spacer(),
              const Icon(Icons.favorite_border_rounded, size: 13, color: C.muted),
              const SizedBox(width: 3),
              Text('${course.likeCount}', style: AppText.caption.copyWith(fontSize: 10.5)),
              const SizedBox(width: 8),
              const Icon(Icons.mode_comment_outlined, size: 13, color: C.muted),
              const SizedBox(width: 3),
              Text('${course.commentCount}', style: AppText.caption.copyWith(fontSize: 10.5)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  final bool dark;
  const _BookmarkButton({required this.course, required this.currentUser, required this.dark});

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Icon(Icons.bookmark_border_rounded, size: 18, color: dark ? Colors.white : C.muted);
    }
    return StreamBuilder<bool>(
      stream: PublicCourseRepository.instance.watchIsBookmarked(course.id, currentUser!.id),
      builder: (context, snap) {
        final saved = snap.data ?? false;
        return Material(
          color: dark ? Colors.black38 : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.lightImpact();
              PublicCourseRepository.instance.toggleBookmark(course.id, currentUser!.id);
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 18, color: saved ? C.gold : (dark ? Colors.white : C.muted)),
            ),
          ),
        );
      },
    );
  }
}

const _kCategoryColorMap = <String, Color>{
  'Mathematics':      C.pur,
  'Science':          C.grn,
  'Languages':        C.blu,
  'Computer Science': C.navy,
  'Arts':             C.red,
  'Business':         C.org,
  'Social Studies':   C.primary,
  'Other':            C.muted,
};

Color _categoryColor(String cat) => _kCategoryColorMap[cat] ?? C.primary;

String _formatCount(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

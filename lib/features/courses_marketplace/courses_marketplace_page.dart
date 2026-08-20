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
import '../../repositories/recommendation_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/category_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import 'course_reader_page.dart';
import 'course_composer_page.dart';
import 'course_creator_profile_page.dart';
import 'course_navigation_page.dart';

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

  // Cached per-category, NOT recreated on every build. Typing in the
  // search box calls setState() on every keystroke to update
  // _searchQuery -- previously that rebuilt this whole page and called
  // PublicCourseRepository.instance.watchLatest()/watchByCategory()
  // fresh inline, handing StreamBuilder a brand-new Stream identity each
  // time. That resets it to its "waiting" state on every keystroke,
  // flashing the shimmer skeleton and reconnecting to Firestore
  // needlessly (same bug class as the Clubs search bar fix). Only
  // recompute when the category actually changes.
  String? _feedStreamCategory;
  Stream<List<PublicCourse>>? _cachedFeedStream;
  Stream<List<PublicCourse>> get _feedStream {
    if (_cachedFeedStream == null || _feedStreamCategory != _category) {
      _feedStreamCategory = _category;
      _cachedFeedStream = _category == null
          ? PublicCourseRepository.instance.watchLatest()
          : PublicCourseRepository.instance.watchByCategory(_category!);
    }
    return _cachedFeedStream!;
  }

  // Same "don't recreate on every build" reasoning as _feedStream above —
  // these two also render only in the _category == null view, exactly
  // when search-box keystrokes rebuild the page, so they were being
  // re-fetched from Firestore on every keystroke too.
  Future<List<PublicCourse>>? _cachedFeaturedFuture;
  Future<List<PublicCourse>> get _featuredFuture =>
      _cachedFeaturedFuture ??= PublicCourseRepository.instance.watchFeaturedOnce();

  Future<Map<String, int>>? _cachedCategoryCountsFuture;
  Future<Map<String, int>> get _categoryCountsFuture =>
      _cachedCategoryCountsFuture ??= PublicCourseRepository.instance.categoryCountsOnce();

  // production_plan.md §7B — contextual Courses recommendations ("Courses
  // → recommends relevant Courses"). Cached for exactly the same reason
  // as _featuredFuture/_categoryCountsFuture above: this rail renders in
  // the _category == null view, which is precisely when search-box
  // keystrokes rebuild the page, so an inline Future would re-query
  // Firestore and flash the shimmer on every keypress.
  Future<List<PublicCourse>>? _cachedRecommendedFuture;
  Future<List<PublicCourse>> get _recommendedFuture =>
      _cachedRecommendedFuture ??= RecommendationRepository.instance.forCourses(
          favoriteSubjects: widget.user?.favoriteSubjects ?? const <String>[]);

  /// Mirrors the Library rail's gate (academic_content_page.dart's
  /// _LibraryDiscovery): only offer "Recommended for You" to a signed-in
  /// user who has actually set favorite subjects, so the label is backed
  /// by a real personalization signal rather than dressing up the generic
  /// recent-courses fallback as a personal pick.
  bool get _showRecommended {
    final u = widget.user;
    return u != null && !u.isGuest && u.favoriteSubjects.isNotEmpty;
  }

  bool get _canCreate => widget.user != null;

  /// Switches category and clears any active search. Every entry point that
  /// changes _category (banner section-jump, category chips, popular
  /// topics) must go through this -- otherwise a leftover _searchQuery
  /// keeps filtering the newly-selected category's feed, which can make it
  /// render empty even though the category has courses.
  void _selectCategory(String? category) {
    setState(() {
      _category = category;
      _searchQuery = '';
      _searchOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: AppBackground(child: SafeArea(
        child: Column(children: [
          _header(context, ac),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: InputDecoration(
                  hintText: 'Search courses…',
                  hintStyle: AppText.bodySm.copyWith(color: ac.muted),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: ac.muted),
                  filled: true, fillColor: ac.surf2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _categoryChips(ac),
                const SizedBox(height: 14),
                _browseByCurriculumCta(context, ac),
                const SizedBox(height: 20),
                if (_category == null) ...[
                  if (_showRecommended) ...[
                    _sectionHeader('Recommended for You', ac, onSeeAll: null),
                    const SizedBox(height: 12),
                    _recommendedRow(context, ac),
                    const SizedBox(height: 24),
                  ],
                  _sectionHeader('Featured Courses', ac,
                      onSeeAll: () => showToast(context, 'A dedicated Featured page is coming soon.')),
                  const SizedBox(height: 12),
                  _featuredRow(context, ac),
                  const SizedBox(height: 24),
                  _sectionHeader('Popular Topics', ac,
                      onSeeAll: () => showToast(context, 'Tap any topic above to browse it.')),
                  const SizedBox(height: 12),
                  _popularTopics(ac),
                  const SizedBox(height: 24),
                  _sectionHeader('Latest from Contributors', ac,
                      onSeeAll: () => showToast(context, 'Scroll down for more — a dedicated feed is coming soon.')),
                  const SizedBox(height: 12),
                  _contributorFeed(context, ac, stream: _feedStream, searchQuery: _searchQuery),
                ] else ...[
                  _sectionHeader(_category!, ac,
                      onSeeAll: () => showToast(context, 'Scroll down for more — a dedicated feed is coming soon.')),
                  const SizedBox(height: 12),
                  _contributorFeed(context, ac, stream: _feedStream, searchQuery: _searchQuery),
                ],
                if (_canCreate) _createCourseCta(context, ac),
              ],
            ),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _header(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Courses', style: AppText.h1.copyWith(fontSize: 22)),
            Text('Learn. Share. Grow.', style: AppText.caption.copyWith(fontSize: 12)),
          ]),
        ),
        IconButton(icon: Icon(Icons.search_rounded, color: ac.txt2),
            onPressed: () => setState(() => _searchOpen = !_searchOpen)),
        if (widget.user != null)
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: ac.txt2),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationsPage(userId: widget.user!.id))),
          ),
        UserAvatar(
          initials: (widget.user?.name.isNotEmpty ?? false) ? widget.user!.name[0].toUpperCase() : '?',
          radius: 18, photoUrl: widget.user?.photoUrl,
          onTap: widget.user == null ? null : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfilePage(user: widget.user!))),
        ),
      ]),
    );
  }

  /// Entry point into the Course Navigation tree
  /// (course_navigation_page.dart: Academic Section > Subject > Topic >
  /// Lessons) — deliberately big and colorful, not a slim row, since
  /// it's an equally valid front door into the marketplace as search or
  /// the category chips above it.
  Widget _browseByCurriculumCta(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Rad.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.lg),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CourseNavigationPage(currentUser: widget.user)));
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [ac.gold, ac.gold.withOpacity(0.75)],
              ),
              borderRadius: BorderRadius.circular(Rad.lg),
            ),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.travel_explore_rounded, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Course Navigation', style: AppText.h2.copyWith(fontSize: 17, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text('Section → Subject → Topic → Lessons',
                      style: AppText.bodySm.copyWith(fontSize: 12.5, color: Colors.white.withOpacity(0.9))),
                ]),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 22, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _categoryChips(AppColors ac) {
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
                _selectCategory(cat == 'All' ? null : cat);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? ac.navy : ac.surf2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? ac.navy : ac.bdr),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (cat != 'All')
                    Icon(_kCategoryIcons[cat] ?? Icons.circle, size: 14,
                        color: active ? ac.gold : ac.txt2),
                  if (cat != 'All') const SizedBox(width: 6),
                  Text(cat, style: AppText.caption.copyWith(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? ac.gold : ac.txt2)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  /// `onSeeAll` is nullable so a section with nowhere to drill into (the
  /// §7B "Recommended for You" rail — it IS the whole list, there's no
  /// bigger page behind it) can omit the affordance rather than show a
  /// "See all" that only fires a toast. Same shape as the Library's own
  /// section header (academic_content_page.dart's _LibraryDiscovery).
  Widget _sectionHeader(String title, AppColors ac, {required VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 16))),
        if (onSeeAll != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSeeAll,
              child: Text('See all', style: AppText.subtitle.copyWith(
                  color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
      ]),
    );
  }

  /// production_plan.md §7B — real favorite-subject-driven course picks
  /// (RecommendationRepository.forCourses), not a generic list. Hidden
  /// entirely when it resolves empty rather than rendering an empty
  /// "Recommended for You" rail — an empty personalized section is worse
  /// than no section. Same treatment as the Library rail.
  Widget _recommendedRow(BuildContext context, AppColors ac) {
    return FutureBuilder<List<PublicCourse>>(
      future: _recommendedFuture,
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
        final courses = snap.data ?? const <PublicCourse>[];
        if (courses.isEmpty) return const SizedBox.shrink();
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
              onOpenCreator: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourseCreatorProfilePage(creatorId: courses[i].creatorId, currentUser: widget.user))),
            ),
          ),
        );
      },
    );
  }

  Widget _featuredRow(BuildContext context, AppColors ac) {
    return FutureBuilder<List<PublicCourse>>(
      future: _featuredFuture,
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
                style: AppText.caption.copyWith(color: ac.red, fontSize: 11)),
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
              onOpenCreator: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourseCreatorProfilePage(creatorId: courses[i].creatorId, currentUser: widget.user))),
            ),
          ),
        );
      },
    );
  }

  Widget _popularTopics(AppColors ac) {
    return FutureBuilder<Map<String, int>>(
      future: _categoryCountsFuture,
      builder: (context, snap) {
        final counts = snap.data ?? const <String, int>{};
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kCourseCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.7,
            ),
            itemBuilder: (context, i) {
              final cat = kCourseCategories[i];
              final count = counts[cat] ?? 0;
              final color = _categoryColor(cat, ac);
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(Rad.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.md),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _selectCategory(cat);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
                    child: Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(9)),
                        child: Icon(_kCategoryIcons[cat] ?? Icons.circle, size: 17, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(cat, style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 12.5),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('$count course${count == 1 ? '' : 's'}', style: AppText.caption.copyWith(fontSize: 10.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _contributorFeed(BuildContext context, AppColors ac, {required Stream<List<PublicCourse>> stream, String searchQuery = ''}) {
    return StreamBuilder<List<PublicCourse>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(children: List.generate(3, (_) => const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              ShimmerBlock(width: 84, height: 84, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShimmerLine(height: 14), SizedBox(height: 8), ShimmerLine(width: 120, height: 12),
              ])),
            ]),
          )));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Failed to load: ${snap.error}',
                style: AppText.caption.copyWith(color: ac.red, fontSize: 11)),
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

  Widget _createCourseCta(BuildContext context, AppColors ac) {
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
            backgroundColor: ac.navy, foregroundColor: ac.gold,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: Text('Create Course', style: AppText.button.copyWith(fontSize: 14, color: ac.gold)),
        ),
      ),
    );
  }
}

class _FeaturedCourseCard extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  final VoidCallback onTap;
  final VoidCallback onOpenCreator;
  const _FeaturedCourseCard({
    required this.course, required this.currentUser,
    required this.onTap, required this.onOpenCreator,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        child: Container(
          width: 210,
          decoration: BoxDecoration(
              color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              SizedBox(
                height: 100, width: double.infinity,
                child: (course.coverImageUrl ?? '').isNotEmpty
                    ? Image.network(course.coverImageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: ac.navy))
                    : Container(
                        color: ac.navy,
                        child: Icon(_kCategoryIcons[course.category] ?? Icons.school_rounded,
                            color: ac.gold, size: 32)),
              ),
              Positioned(
                top: 8, right: 8,
                child: _BookmarkButton(course: course, currentUser: currentUser, dark: true),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusBadge(label: course.category, color: _categoryColor(course.category, ac)),
                const SizedBox(height: 6),
                Text(course.title, style: AppText.title.copyWith(fontSize: 13.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(course.description, style: AppText.caption.copyWith(fontSize: 11),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.xs),
                    onTap: () { HapticFeedback.selectionClick(); onOpenCreator(); },
                    child: Row(children: [
                      UserAvatar(initials: course.creatorName.isEmpty ? '?' : course.creatorName[0].toUpperCase(),
                          radius: 8, photoUrl: course.creatorPhotoUrl),
                      const SizedBox(width: 5),
                      Expanded(child: Text('By ${course.creatorName}', style: AppText.caption.copyWith(fontSize: 10),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.star_rounded, size: 13, color: ac.gold),
                  const SizedBox(width: 2),
                  Text(course.avgRating > 0 ? course.avgRating.toStringAsFixed(1) : '—',
                      style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Icon(Icons.people_alt_outlined, size: 12, color: ac.muted),
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
    final ac = AppColors.of(context);
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
                    errorBuilder: (_, __, ___) => Container(color: ac.surf3))
                : Container(color: _categoryColor(course.category, ac).withValues(alpha: .12),
                    child: Icon(_kCategoryIcons[course.category] ?? Icons.school_rounded,
                        color: _categoryColor(course.category, ac), size: 26)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: StatusBadge(label: course.category, color: _categoryColor(course.category, ac))),
              if (_isOwn)
                Icon(Icons.more_horiz_rounded, size: 18, color: ac.muted)
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
                    Text('By ${course.creatorName}', style: AppText.caption.copyWith(fontSize: 10.5, color: ac.txt)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Text('· ${_readTime()}', style: AppText.caption.copyWith(fontSize: 10)),
              const Spacer(),
              Icon(Icons.favorite_border_rounded, size: 13, color: ac.muted),
              const SizedBox(width: 3),
              Text('${course.likeCount}', style: AppText.caption.copyWith(fontSize: 10.5)),
              const SizedBox(width: 8),
              Icon(Icons.mode_comment_outlined, size: 13, color: ac.muted),
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
    final ac = AppColors.of(context);
    if (currentUser == null) {
      return Icon(Icons.bookmark_border_rounded, size: 18, color: dark ? Colors.white : ac.muted);
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
                  size: 18, color: saved ? ac.gold : (dark ? Colors.white : ac.muted)),
            ),
          ),
        );
      },
    );
  }
}

CategoryColorMap _kCategoryColorMap(AppColors ac) => CategoryColorMap({
  'Mathematics':      ac.pur,
  'Science':          ac.grn,
  'Languages':        ac.blu,
  'Computer Science': ac.navy,
  'Arts':             ac.red,
  'Business':         ac.org,
  'Social Studies':   ac.primary,
  'Other':            ac.muted,
}, fallback: ac.primary);

Color _categoryColor(String cat, AppColors ac) => _kCategoryColorMap(ac).of(cat);

String _formatCount(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

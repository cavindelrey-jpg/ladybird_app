// lib/features/courses_marketplace/courses_home_page.dart
// Entry point for Academia Courses — replaces the old CoursesMarketplacePage
// (hero banner + category chips + featured/popular/contributor rails) with
// the strict hierarchy: 5 education levels, then Recommended for You and
// Recent Reads as secondary discovery, not extra organizational layers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import 'level_subjects_page.dart';
import 'course_lessons_page.dart';
import 'course_search_page.dart';

class CoursesHomePage extends StatefulWidget {
  final AppUser? user;
  const CoursesHomePage({super.key, this.user});

  @override
  State<CoursesHomePage> createState() => _CoursesHomePageState();
}

class _CoursesHomePageState extends State<CoursesHomePage> {
  final _recommendedScrollCtrl = ScrollController();
  int _recommendedPage = 0;
  int _recommendedPageCount = 1;
  late final Future<List<PublicCourse>> _recommendedFuture =
      PublicCourseRepository.instance.recommendedForUser(widget.user?.id, limit: 5);
  late final Future<Map<String, CurriculumIcon>> _iconsFuture =
      PublicCourseRepository.instance.curriculumIconsOnce();

  @override
  void initState() {
    super.initState();
    _recommendedScrollCtrl.addListener(_onRecommendedScroll);
    _recommendedFuture.then((courses) {
      if (mounted) setState(() => _recommendedPageCount = courses.length.clamp(1, 999));
    });
  }

  @override
  void dispose() {
    _recommendedScrollCtrl.dispose();
    super.dispose();
  }

  void _onRecommendedScroll() {
    if (_recommendedPageCount <= 1) return;
    final maxScroll = _recommendedScrollCtrl.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final page = (_recommendedScrollCtrl.offset / (maxScroll / (_recommendedPageCount - 1))).round();
    if (page != _recommendedPage) setState(() => _recommendedPage = page.clamp(0, _recommendedPageCount - 1));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: AppBackground(child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _header(context, ac),
            _searchBar(context, ac),
            const SizedBox(height: 18),
            _levelRow(context, ac),
            const SizedBox(height: 26),
            _sectionHeader('Recommended for You', ac, showNav: true),
            const SizedBox(height: 12),
            _recommendedRow(context, ac),
            const SizedBox(height: 24),
            _sectionHeader('Recent Reads', ac),
            const SizedBox(height: 12),
            _recentReads(context, ac),
          ],
        ),
      )),
    );
  }

  Widget _header(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(children: [
        Expanded(child: Text('Academia Courses', style: AppText.h1.copyWith(fontSize: 22, color: ac.txt))),
        IconButton(
          icon: Icon(Icons.search_rounded, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CourseSearchPage(user: widget.user))),
        ),
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

  Widget _searchBar(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Rad.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.sm),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CourseSearchPage(user: widget.user))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
            child: Row(children: [
              Icon(Icons.search_rounded, size: 18, color: ac.muted),
              const SizedBox(width: 8),
              Expanded(child: Text('Search courses, topics, subjects…',
                  style: AppText.bodySm.copyWith(color: ac.muted))),
              Icon(Icons.tune_rounded, size: 18, color: ac.muted),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _levelRow(BuildContext context, AppColors ac) {
    return FutureBuilder<List<CourseLevelInfo>>(
      future: PublicCourseRepository.instance.levelsOnce(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => const ShimmerBlock(width: 108, height: 118, borderRadius: 16),
            ),
          );
        }
        final levels = snap.data ?? const <CourseLevelInfo>[];
        if (levels.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No education levels configured yet.', style: AppText.bodySm.copyWith(color: ac.txt2)),
          );
        }
        return FutureBuilder<Map<String, CurriculumIcon>>(
          future: _iconsFuture,
          builder: (context, iconSnap) {
            final icons = iconSnap.data ?? const <String, CurriculumIcon>{};
            return SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: levels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _LevelCard(
                  level: levels[i],
                  icon: icons[PublicCourseRepository.eduLevelIconKey(levels[i].name)] ?? CurriculumIcon.none,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LevelSubjectsPage(level: levels[i].name, user: widget.user)));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionHeader(String title, AppColors ac, {bool showNav = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: ac.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 16, color: ac.txt))),
        if (showNav && _recommendedPageCount > 1) ...[
          _navArrow(ac, Icons.chevron_left_rounded, () => _scrollRecommended(-1)),
          const SizedBox(width: 6),
          _navArrow(ac, Icons.chevron_right_rounded, () => _scrollRecommended(1)),
        ],
      ]),
    );
  }

  Widget _navArrow(AppColors ac, IconData icon, VoidCallback onTap) {
    return Material(
      color: ac.surf2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18, color: ac.txt2)),
      ),
    );
  }

  void _scrollRecommended(int direction) {
    if (!_recommendedScrollCtrl.hasClients) return;
    final target = (_recommendedScrollCtrl.offset + direction * 240)
        .clamp(0.0, _recommendedScrollCtrl.position.maxScrollExtent);
    _recommendedScrollCtrl.animateTo(target, duration: Dur.med, curve: Dur.curve);
  }

  Widget _recommendedRow(BuildContext context, AppColors ac) {
    return FutureBuilder<List<PublicCourse>>(
      future: _recommendedFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const ShimmerBlock(width: 160, height: 190),
            ),
          );
        }
        final courses = snap.data ?? const <PublicCourse>[];
        if (courses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No courses to recommend yet — check back soon.', style: AppText.bodySm.copyWith(color: ac.txt2)),
          );
        }
        return SizedBox(
          height: 190,
          child: ListView.separated(
            controller: _recommendedScrollCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _RecommendedCard(
              course: courses[i],
              currentUser: widget.user,
              onTap: () => _openCourse(context, courses[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _recentReads(BuildContext context, AppColors ac) {
    final user = widget.user;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Sign in to keep track of what you’ve recently opened.', style: AppText.bodySm.copyWith(color: ac.txt2)),
      );
    }
    return StreamBuilder<List<PublicCourse>>(
      stream: PublicCourseRepository.instance.watchRecentlyViewedCourses(user.id, limit: 5),
      builder: (context, recentSnap) {
        final recent = recentSnap.data ?? const <PublicCourse>[];
        if (recentSnap.connectionState == ConnectionState.waiting) {
          return Column(children: List.generate(3, (_) => const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              ShimmerBlock(width: 56, height: 56, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShimmerLine(height: 13), SizedBox(height: 8), ShimmerLine(width: 100, height: 11),
              ])),
            ]),
          )));
        }
        if (recent.isNotEmpty) {
          return Column(children: recent.map((c) => _RecentReadTile(
            course: c, onTap: () => _openCourse(context, c),
          )).toList());
        }
        return FutureBuilder<List<PublicCourse>>(
          future: _recommendedFuture,
          builder: (context, fillSnap) {
            final fill = fillSnap.data ?? const <PublicCourse>[];
            if (fill.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Nothing here yet — open a course to see it appear.', style: AppText.bodySm.copyWith(color: ac.txt2)),
              );
            }
            return Column(children: fill.map((c) => _RecentReadTile(
              course: c, onTap: () => _openCourse(context, c),
            )).toList());
          },
        );
      },
    );
  }

  void _openCourse(BuildContext context, PublicCourse course) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CourseLessonsPage(course: course, currentUser: widget.user)));
  }
}

class _LevelCard extends StatelessWidget {
  final CourseLevelInfo level;
  final CurriculumIcon icon;
  final VoidCallback onTap;
  const _LevelCard({required this.level, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onTap,
        child: Container(
          width: 108,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: HierarchyAvatar(label: level.name, icon: icon.emoji, imageUrl: icon.imageUrl, fill: true),
            ),
            const SizedBox(height: 6),
            Text(level.name, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${level.courseCount} course${level.courseCount == 1 ? '' : 's'}',
                style: AppText.caption.copyWith(fontSize: 10.5)),
          ]),
        ),
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  final VoidCallback onTap;
  const _RecommendedCard({required this.course, required this.currentUser, required this.onTap});

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
          width: 160,
          decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              SizedBox(
                height: 96, width: double.infinity,
                child: (course.coverImageUrl ?? '').isNotEmpty
                    ? Image.network(course.coverImageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: ac.navy))
                    : Container(color: ac.navy, child: Icon(Icons.school_rounded, color: ac.gold, size: 28)),
              ),
              if (currentUser != null)
                Positioned(top: 6, right: 6, child: _BookmarkDot(course: course, userId: currentUser!.id)),
            ]),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (course.category.isNotEmpty) StatusBadge(label: course.category, color: ac.primary),
                const SizedBox(height: 6),
                Text(course.title, style: AppText.title.copyWith(fontSize: 12.5),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('By ${course.creatorName}', style: AppText.caption.copyWith(fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BookmarkDot extends StatelessWidget {
  final PublicCourse course;
  final String userId;
  const _BookmarkDot({required this.course, required this.userId});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<bool>(
      stream: PublicCourseRepository.instance.watchIsBookmarked(course.id, userId),
      builder: (context, snap) {
        final saved = snap.data ?? false;
        return Material(
          color: Colors.black38,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.lightImpact();
              PublicCourseRepository.instance.toggleBookmark(course.id, userId);
            },
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 15, color: saved ? ac.gold : Colors.white),
            ),
          ),
        );
      },
    );
  }
}

class _RecentReadTile extends StatelessWidget {
  final PublicCourse course;
  final VoidCallback onTap;
  const _RecentReadTile({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final meta = [course.category, course.topic].where((s) => s.isNotEmpty).join(' • ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Rad.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.sm),
          onTap: () { HapticFeedback.selectionClick(); onTap(); },
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56, height: 56,
                child: (course.coverImageUrl ?? '').isNotEmpty
                    ? Image.network(course.coverImageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: ac.surf3))
                    : Container(color: ac.primaryBg, child: Icon(Icons.menu_book_rounded, color: ac.primary, size: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(course.title, style: AppText.title.copyWith(fontSize: 13.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: AppText.caption.copyWith(fontSize: 11)),
                ],
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
          ]),
        ),
      ),
    );
  }
}

// lib/pages/bookmarks_page.dart
// "My Bookmarks" — the missing other half of the Like/Bookmark work.
// watchBookmarkedCourses() and watchBookmarkedArticles() already existed
// in their repositories but had zero UI consumer anywhere; this is that
// consumer. Two tabs, both backed by real Firestore streams, no demo data.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../models/public_course.dart';
import '../repositories/public_course_repository.dart';
import '../repositories/magazine_repository.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../features/courses_marketplace/course_lessons_page.dart';
import '../features/magazine/article_reader_page.dart';

import '../widgets/app_background.dart';
class BookmarksPage extends StatefulWidget {
  final AppUser user;
  const BookmarksPage({super.key, required this.user});
  @override State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        title: Text('My Bookmarks', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
        bottom: TabBar(controller: _tc, labelColor: ac.primary, unselectedLabelColor: ac.txt2,
            indicatorColor: ac.primary, tabs: const [Tab(text: 'Courses'), Tab(text: 'Magazine')]),
      ),
      body: AppBackground(child: TabBarView(controller: _tc, children: [
        StreamBuilder<List<PublicCourse>>(
          stream: PublicCourseRepository.instance.watchBookmarkedCourses(widget.user.id),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final courses = snap.data!;
            if (courses.isEmpty) {
              return const _Empty(icon: Icons.bookmark_border_rounded, text: 'No saved courses yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = courses[i];
                return _BookmarkTile(
                  title: c.title, subtitle: c.creatorName, imageUrl: c.coverImageUrl,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CourseLessonsPage(course: c, currentUser: widget.user))),
                );
              },
            );
          },
        ),
        StreamBuilder<List<MagazineArticle>>(
          stream: MagazineRepository.instance.watchBookmarkedArticles(widget.user.id),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final articles = snap.data!;
            if (articles.isEmpty) {
              return const _Empty(icon: Icons.bookmark_border_rounded, text: 'No saved articles yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = articles[i];
                return _BookmarkTile(
                  title: a.title, subtitle: a.authorName, imageUrl: a.thumbnailUrl,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArticleReaderPage(article: a, currentUser: widget.user))),
                );
              },
            );
          },
        ),
      ])),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final String title, subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  const _BookmarkTile({required this.title, required this.subtitle, this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf, borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (imageUrl ?? '').isNotEmpty
                  ? Image.network(imageUrl!, width: 56, height: 56, fit: BoxFit.cover)
                  : Container(width: 56, height: 56, color: ac.surf3,
                      child: Icon(Icons.menu_book_outlined, color: ac.muted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.subtitle.copyWith(color: ac.txt), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: ac.muted),
          ]),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: ac.muted),
        const SizedBox(height: 10),
        Text(text, style: AppText.bodySm.copyWith(color: ac.txt2)),
      ]),
    );
  }
}

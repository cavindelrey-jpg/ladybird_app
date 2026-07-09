// lib/features/magazine/author_profile_page.dart
// A writer's article list. If viewing your own profile, drafts show too
// (with a DRAFT badge) alongside published work; viewing someone else's
// profile shows only what's published.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'article_reader_page.dart';
import 'article_composer_page.dart';

class AuthorProfilePage extends StatelessWidget {
  final String authorId;
  final AppUser? currentUser;
  const AuthorProfilePage({super.key, required this.authorId, this.currentUser});

  bool get _isOwnProfile => currentUser?.id == authorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text(_isOwnProfile ? 'Your Articles' : 'Writer Profile', style: AppText.title),
      ),
      body: StreamBuilder<List<MagazineArticle>>(
        stream: MagazineRepository.instance.watchByAuthor(authorId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _AuthorSkeleton();
          }
          var articles = snap.data ?? const <MagazineArticle>[];
          if (!_isOwnProfile) {
            articles = articles.where((a) => a.published).toList();
          }
          if (articles.isEmpty) {
            return EmptyState(
              icon: Icons.auto_stories_outlined,
              title: _isOwnProfile ? "You haven't written anything yet" : 'No published articles yet',
              subtitle: _isOwnProfile ? 'Tap Write on the Magazine feed to start.' : null,
            );
          }
          final headerName = articles.first.authorName;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                UserAvatar(
                  initials: headerName.isEmpty ? '?' : headerName[0].toUpperCase(),
                  radius: 26, photoUrl: articles.first.authorPhotoUrl,
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(headerName, style: AppText.h2),
                  Text('${articles.length} article${articles.length == 1 ? '' : 's'}',
                      style: AppText.bodySm),
                ]),
              ]),
              const SizedBox(height: 20),
              ...articles.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ACard(
                  onTap: () {
                    if (a.published || _isOwnProfile) {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ArticleReaderPage(article: a, currentUser: currentUser)));
                    }
                  },
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(a.title, style: AppText.title.copyWith(fontSize: 14),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          if (!a.published)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: StatusBadge(label: 'DRAFT', color: C.org, bg: C.orgb),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.visibility_outlined, size: 13, color: C.muted),
                          const SizedBox(width: 3),
                          Text('${a.readCount}', style: AppText.caption),
                          const SizedBox(width: 10),
                          Icon(Icons.mode_comment_outlined, size: 13, color: C.muted),
                          const SizedBox(width: 3),
                          Text('${a.commentCount}', style: AppText.caption),
                        ]),
                      ]),
                    ),
                    if (_isOwnProfile)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: C.txt2),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ArticleComposerPage(user: currentUser!, existing: a))),
                      ),
                  ]),
                ),
              )),
            ],
          );
        },
      ),
    );
  }
}

/// Header + list skeleton matching the loaded layout's silhouette.
class _AuthorSkeleton extends StatelessWidget {
  const _AuthorSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const ShimmerCircle(size: 52),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            ShimmerLine(width: 120, height: 16),
            SizedBox(height: 6),
            ShimmerLine(width: 70, height: 12),
          ]),
        ]),
        const SizedBox(height: 20),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShimmerLine(height: 15),
                SizedBox(height: 10),
                ShimmerLine(width: 100, height: 12),
              ]),
            ),
          ),
      ],
    );
  }
}

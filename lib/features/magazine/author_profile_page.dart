// lib/features/magazine/author_profile_page.dart
// A writer's article list. If viewing your own profile, drafts show too
// (with a DRAFT badge) alongside published work; viewing someone else's
// profile shows only what's published.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../repositories/follow_repository.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'article_reader_page.dart';
import 'article_composer_page.dart';
import '../../core/realtime_tolerant.dart';

/// One-time-ish lookup of the full user profile (for bio) — the
/// article-derived header fields (name/photo) already come from
/// MagazineArticle, so this only backs the extra bio field.
Stream<AppUser?> _watchAuthorUser(String authorId) => Supabase.instance.client
    .from('users')
    .stream(primaryKey: ['id'])
    .eq('id', authorId)
    .realtimeTolerant()
    .map((rows) => rows.isNotEmpty ? AppUser.fromSupabase(rows.first) : null);

class AuthorProfilePage extends StatelessWidget {
  final String authorId;
  final AppUser? currentUser;
  const AuthorProfilePage({super.key, required this.authorId, this.currentUser});

  bool get _isOwnProfile => currentUser?.id == authorId;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(_isOwnProfile ? 'Your Articles' : 'Writer Profile', style: AppText.title),
      ),
      body: AppBackground(child: StreamBuilder<List<MagazineArticle>>(
        stream: MagazineRepository.instance.watchByAuthor(authorId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _AuthorSkeleton();
          }
          if (snap.hasError) {
            CrashService.instance.recordError(snap.error, snap.stackTrace,
                context: 'AuthorProfilePage.watchByAuthor($authorId)');
            return ErrorView(message: "Couldn't load this profile — ${snap.error}");
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
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(headerName, style: AppText.h2),
                    Row(children: [
                      Text('${articles.length} article${articles.length == 1 ? '' : 's'}',
                          style: AppText.bodySm),
                      Text('  ·  ', style: AppText.bodySm),
                      StreamBuilder<int>(
                        stream: FollowRepository.instance.watchFollowerCount(authorId),
                        builder: (context, s) => Text(
                            '${s.data ?? 0} follower${(s.data ?? 0) == 1 ? '' : 's'}',
                            style: AppText.bodySm),
                      ),
                      Text('  ·  ', style: AppText.bodySm),
                      StreamBuilder<int>(
                        stream: FollowRepository.instance.watchFollowingCount(authorId),
                        builder: (context, s) => Text(
                            '${s.data ?? 0} following', style: AppText.bodySm),
                      ),
                    ]),
                  ]),
                ),
                if (!_isOwnProfile && currentUser != null)
                  _FollowButton(currentUserId: currentUser!.id, authorId: authorId),
              ]),
              StreamBuilder<AppUser?>(
                stream: _watchAuthorUser(authorId),
                builder: (context, s) {
                  final u = s.data;
                  if (u == null || u.bio.isEmpty) {
                    return const SizedBox(height: 20);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    child: Text(u.bio, style: AppText.bodySm.copyWith(height: 1.4)),
                  );
                },
              ),
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
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: StatusBadge(label: 'DRAFT', color: ac.org, bg: ac.orgBg),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.visibility_outlined, size: 13, color: ac.muted),
                          const SizedBox(width: 3),
                          Text('${a.readCount}', style: AppText.caption),
                          const SizedBox(width: 10),
                          Icon(Icons.mode_comment_outlined, size: 13, color: ac.muted),
                          const SizedBox(width: 3),
                          Text('${a.commentCount}', style: AppText.caption),
                        ]),
                      ]),
                    ),
                    if (_isOwnProfile)
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 18, color: ac.txt2),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ArticleComposerPage(user: currentUser!, existing: a))),
                      ),
                  ]),
                ),
              )),
            ],
          );
        },
      )),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final String currentUserId;
  final String authorId;
  const _FollowButton({required this.currentUserId, required this.authorId});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<bool>(
      stream: FollowRepository.instance.watchIsFollowing(currentUserId, authorId),
      builder: (context, snap) {
        final following = snap.data ?? false;
        return SizedBox(
          height: 34,
          child: following
              ? OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    FollowRepository.instance.unfollow(currentUserId, authorId);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ac.txt2,
                    side: BorderSide(color: ac.bdr),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text('Following', style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
                )
              : ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    FollowRepository.instance.follow(currentUserId, authorId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text('Follow', style: AppText.caption.copyWith(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
        );
      },
    );
  }
}

/// Header + list skeleton matching the loaded layout's silhouette.
class _AuthorSkeleton extends StatelessWidget {
  const _AuthorSkeleton();

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(children: [
          ShimmerCircle(size: 52),
          SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
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

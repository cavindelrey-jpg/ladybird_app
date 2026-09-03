// lib/features/academic_content/library_home_page.dart
// Entry point for the Academia Library — a discovery page, not the File
// Explorer itself. Structure (per the user's final spec):
//   1. File Explorer — the top-level folders (Past Papers, Notes,
//      Documents, Books, + whatever an admin has added; never hardcoded,
//      see library_folder_repository.dart). Tapping one opens
//      LibraryFolderPage, a genuine admin-editable folder tree.
//   2. Recommended for You — individual resources, horizontal cards, no
//      "See all" (a small rotating selection, not another folder system).
//   3. Recent Reads — vertical list of the user's actual reading history,
//      padded with recommended items if there isn't enough real history.
//
// Deliberately visually distinct from Academia Courses' home page (square
// "folder" tiles here vs. Courses' rounded rail cards) so Library doesn't
// read as a reskin of Courses, per the user's explicit instruction.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/library_folder.dart';
import '../../models/academic_content.dart';
import '../../repositories/library_folder_repository.dart';
import '../../repositories/academic_content_repository.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/xp_widgets.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import 'library_folder_page.dart';
import 'library_search_page.dart';
import 'content_details_page.dart';
import 'content_upload_page.dart';

class LibraryHomePage extends StatelessWidget {
  final AppUser user;
  const LibraryHomePage({super.key, required this.user});

  bool get _canUpload => user.canUploadContent;

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
            const SizedBox(height: 8),
            _sectionHeader('File Explorer', ac),
            const SizedBox(height: 12),
            _fileExplorer(context, ac),
            const SizedBox(height: 26),
            _sectionHeader('Recommended for You', ac),
            const SizedBox(height: 12),
            _recommendedRow(context, ac),
            const SizedBox(height: 24),
            _sectionHeader('Recent Reads', ac),
            const SizedBox(height: 12),
            _recentReads(context, ac),
          ],
        ),
      )),
      floatingActionButton: _canUpload
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => ContentUploadPage(user: user)));
              },
              backgroundColor: ac.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text('Upload', style: AppText.button.copyWith(fontSize: 15)),
            )
          : null,
    );
  }

  Widget _header(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(children: [
        Expanded(child: Text('Academia Library', style: AppText.h1.copyWith(fontSize: 22, color: ac.txt))),
        XpBalanceBadge(userId: user.id),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.search_rounded, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibrarySearchPage(user: user))),
        ),
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsPage(userId: user.id))),
        ),
        UserAvatar(
          initials: user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
          radius: 18, photoUrl: user.photoUrl,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(user: user))),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: ac.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 16, color: ac.txt))),
      ]),
    );
  }

  Widget _fileExplorer(BuildContext context, AppColors ac) {
    return StreamBuilder<List<LibraryFolder>>(
      stream: LibraryFolderRepository.instance.watchRootFolders(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8,
              children: List.generate(4, (_) => const ShimmerBlock(borderRadius: 14)),
            ),
          );
        }
        if (snap.hasError) {
          CrashService.instance.recordError(snap.error, null, context: 'LibraryHomePage._fileExplorer');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text("Couldn't load folders — ${snap.error}", style: AppText.caption.copyWith(color: ac.red, fontSize: 11)),
          );
        }
        final folders = snap.data ?? const <LibraryFolder>[];
        if (folders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No folders configured yet.', style: AppText.bodySm.copyWith(color: ac.txt2)),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8,
            children: folders.map((f) => _FolderCard(
              folder: f,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LibraryFolderPage(folderId: f.id, folderName: f.name, user: user)));
              },
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _recommendedRow(BuildContext context, AppColors ac) {
    return FutureBuilder<List<AcademicContent>>(
      future: AcademicContentRepository.instance.recommendedForUser(user.id.isEmpty ? null : user.id, limit: 5),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const ShimmerBlock(width: 140, height: 168),
            ),
          );
        }
        final items = snap.data ?? const <AcademicContent>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No resources to recommend yet — check back soon.', style: AppText.bodySm.copyWith(color: ac.txt2)),
          );
        }
        return SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _RecommendedCard(
              item: items[i],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ContentDetailsPage(contentId: items[i].id, user: user))),
            ),
          ),
        );
      },
    );
  }

  Widget _recentReads(BuildContext context, AppColors ac) {
    return StreamBuilder<List<AcademicContent>>(
      stream: AcademicContentRepository.instance.watchRecentlyViewed(user.id, limit: 6),
      builder: (context, recentSnap) {
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
        if (recentSnap.hasError) {
          CrashService.instance.recordError(recentSnap.error, null, context: 'LibraryHomePage._recentReads');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text("Couldn't load: ${recentSnap.error}", style: AppText.caption.copyWith(color: ac.red, fontSize: 11)),
          );
        }
        final recent = recentSnap.data ?? const <AcademicContent>[];
        if (recent.isNotEmpty) {
          return Column(children: recent.map((c) => _RecentReadTile(
            item: c, recentlyOpened: true,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ContentDetailsPage(contentId: c.id, user: user))),
          )).toList());
        }
        return FutureBuilder<List<AcademicContent>>(
          future: AcademicContentRepository.instance.recommendedForUser(user.id.isEmpty ? null : user.id, limit: 5),
          builder: (context, fillSnap) {
            final fill = fillSnap.data ?? const <AcademicContent>[];
            if (fill.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Nothing here yet — open something from the Library and it\'ll show up here.',
                    style: AppText.bodySm.copyWith(color: ac.txt2)),
              );
            }
            return Column(children: fill.map((c) => _RecentReadTile(
              item: c, recentlyOpened: false,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ContentDetailsPage(contentId: c.id, user: user))),
            )).toList());
          },
        );
      },
    );
  }
}

class _FolderCard extends StatelessWidget {
  final LibraryFolder folder;
  final VoidCallback onTap;
  const _FolderCard({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: ac.bdr2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Expanded(child: HierarchyAvatar(label: folder.name, icon: folder.emoji, imageUrl: folder.imageUrl, fill: true)),
            const SizedBox(height: 4),
            Text(folder.name, textAlign: TextAlign.center,
                style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.txt),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final AcademicContent item;
  final VoidCallback onTap;
  const _RecommendedCard({required this.item, required this.onTap});

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
          width: 140,
          decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 90, width: double.infinity,
              child: (item.thumbnailUrl ?? '').isNotEmpty
                  ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(ac))
                  : _placeholder(ac),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: AppText.title.copyWith(fontSize: 12, color: ac.txt), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(item.contentType.label, style: AppText.caption.copyWith(fontSize: 10, color: ac.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(AppColors ac) => Container(color: ac.surf3, alignment: Alignment.center,
      child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 24)));
}

class _RecentReadTile extends StatelessWidget {
  final AcademicContent item;
  final bool recentlyOpened;
  final VoidCallback onTap;
  const _RecentReadTile({required this.item, required this.recentlyOpened, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
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
                child: (item.thumbnailUrl ?? '').isNotEmpty
                    ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: ac.surf3))
                    : Container(color: ac.primaryBg, child: Center(child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 22)))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: AppText.title.copyWith(fontSize: 13.5, color: ac.txt), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.contentType.label, style: AppText.caption.copyWith(fontSize: 11, color: ac.muted)),
                if (recentlyOpened) ...[
                  const SizedBox(height: 1),
                  Text('Recently opened', style: AppText.caption.copyWith(fontSize: 10, color: ac.primary)),
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

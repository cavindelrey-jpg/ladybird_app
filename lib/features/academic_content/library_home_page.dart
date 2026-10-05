// lib/features/academic_content/library_home_page.dart
// Entry point for the Academia Library — a discovery page, not the File
// Explorer itself. Structure (per the user's final spec):
//   1. File Explorer — the top-level folders (Past Papers, Notes,
//      Documents, Books, + whatever an admin has added; never hardcoded,
//      see library_folder_repository.dart). Tapping one opens
//      LibraryFolderPage, a genuine admin-editable folder tree.
//   2. Recommended for You — individual resources, horizontal cards you
//      can slide through, plus a "See all" into the full list.
//   3. Recent Reads — vertical list of the user's actual reading history,
//      padded with recommended items if there isn't enough real history.
//
// Deliberately visually distinct from Academia Courses' home page (square
// "folder" tiles here vs. Courses' rounded rail cards) so Library doesn't
// read as a reskin of Courses, per the user's explicit instruction.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/library_folder.dart';
import '../../models/academic_content.dart';
import '../../repositories/library_folder_repository.dart';
import '../../repositories/academic_content_repository.dart';
import '../../services/connectivity_service.dart';
import 'bulk_past_paper_upload_page.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import 'library_folder_page.dart';
import 'library_search_page.dart';
import 'content_details_page.dart';
import 'content_upload_page.dart';
import 'recommended_library_page.dart';
import 'folder_thumbnail_editor.dart';
import 'content_viewer_page.dart';

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
            _sectionHeader('Recommended for You', ac, onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RecommendedLibraryPage(user: user)))),
            const SizedBox(height: 12),
            // Re-built (and so re-fetched) whenever connectivity flips, so
            // "needs an internet connection" clears by itself on reconnect.
            StreamBuilder<bool>(
              stream: ConnectivityService().watchOffline(),
              builder: (context, net) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _recommendedRow(context, ac),
                  const SizedBox(height: 24),
                  _sectionHeader('Recent Reads', ac),
                  const SizedBox(height: 12),
                  _recentReads(context, ac),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('Available Offline', ac, badge: 'Downloaded'),
            const SizedBox(height: 12),
            _offlineSection(context, ac),
          ],
        ),
      )),
      floatingActionButton: _canUpload
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showUploadChoices(context, ac);
              },
              backgroundColor: ac.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text('Upload', style: AppText.button.copyWith(fontSize: 15)),
            )
          : null,
    );
  }

  void _showUploadChoices(BuildContext context, AppColors ac) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.lg))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ac.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.upload_file_rounded, color: ac.primary),
              ),
              title: Text('Single Item Upload', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14, color: ac.txt)),
              subtitle: Text('Upload single note, book, video, or paper', style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ContentUploadPage(user: user)));
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ac.gold.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.drive_folder_upload_rounded, color: ac.gold),
              ),
              title: Text('Mass Upload Past Papers', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14, color: ac.txt)),
              subtitle: Text('Batch upload multiple PDFs with auto-parsed metadata & shared covers', style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BulkPastPaperUploadPage(user: user)));
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(children: [
        Expanded(child: Text('Academia Library', style: AppText.h1.copyWith(fontSize: 22, color: ac.txt))),
        if (_canUpload)
          IconButton(
            icon: Icon(Icons.drive_folder_upload_rounded, color: ac.primary),
            tooltip: 'Mass Upload Past Papers',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BulkPastPaperUploadPage(user: user),
              ));
            },
          ),
        IconButton(
          icon: Icon(Icons.search_rounded, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibrarySearchPage(user: user))),
        ),
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsPage(user: user))),
        ),
        UserAvatar(
          initials: user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
          radius: 18, photoUrl: user.photoUrl,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(user: user))),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, AppColors ac, {VoidCallback? onSeeAll, String? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: ac.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Row(
          children: [
            Text(title, style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: ac.grnBg, borderRadius: BorderRadius.circular(10)),
                child: Text(badge, style: AppText.label.copyWith(fontSize: 9.5, color: ac.grn, fontWeight: FontWeight.bold, letterSpacing: 0)),
              ),
            ],
          ],
        )),
        if (onSeeAll != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.xs),
              onTap: onSeeAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('See all', style: AppText.subtitle.copyWith(color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ),
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
        if (folders.isEmpty && !_canUpload) {
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
            children: [
              ...folders.map((f) => _FolderCard(
                folder: f,
                canManage: _canUpload,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LibraryFolderPage(folderId: f.id, folderName: f.name, user: user)));
                },
              )),
              if (_canUpload) _AddFolderTile(onTap: () => _createRootFolder(context)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createRootFolder(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dCtx, ctrl.text), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final result = await LibraryFolderRepository.instance.createFolder(parentId: null, name: name);
    if (context.mounted && result is Failure) showToast(context, (result as Failure).message);
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
            child: Text(
                'No resources to recommend yet — check your offline downloads below.',
                style: AppText.bodySm.copyWith(color: ac.txt2)),
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
        final recent = recentSnap.data ?? const <AcademicContent>[];
        if (recent.isNotEmpty) {
          return Column(children: recent.map((c) => _RecentReadTile(
            item: c, recentlyOpened: true,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ContentDetailsPage(contentId: c.id, user: user))),
          )).toList());
        }
        if (recentSnap.hasError) {
          CrashService.instance.recordError(recentSnap.error, null, context: 'LibraryHomePage._recentReads');
        }
        return FutureBuilder<List<AcademicContent>>(
          future: AcademicContentRepository.instance.recommendedForUser(user.id.isEmpty ? null : user.id, limit: 5),
          builder: (context, fillSnap) {
            final fill = fillSnap.data ?? const <AcademicContent>[];
            if (fill.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                    'Nothing here yet — open something from the Library and it will show up here.',
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

  Widget _offlineSection(BuildContext context, AppColors ac) {
    return StreamBuilder<List<AcademicContent>>(
      stream: AcademicContentRepository.instance.watchOfflineContent(),
      builder: (context, snap) {
        final items = snap.data ?? const <AcademicContent>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ac.surf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ac.bdr),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ac.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.cloud_download_outlined, color: ac.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No offline downloads yet',
                          style: AppText.title.copyWith(fontSize: 14, color: ac.txt),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Save books, past papers, and documents to access them anywhere without internet.',
                          style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return _OfflineContentCard(
                item: item,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final path = await AcademicContentRepository.instance.offlineFilePath(item.id);
                  if (!context.mounted) return;
                  final kind = viewableKindFor(path ?? item.fileUrl ?? '') ?? ViewableFileKind.pdf;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ContentViewerPage(
                      fileUrl: item.fileUrl ?? path ?? '',
                      title: item.title,
                      kind: kind,
                      contentId: item.id,
                      userId: user.id,
                      localFilePath: path,
                    ),
                  ));
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Appended to the File Explorer grid for admins — "a new place to put
/// [files]" at the top level, matching the same add-a-folder capability
/// already available one level down inside LibraryFolderPage.
class _AddFolderTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFolderTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ac.bdr2, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: ac.primary, size: 22),
            const SizedBox(height: 2),
            Text('Add', style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary)),
          ]),
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final LibraryFolder folder;
  final bool canManage;
  final VoidCallback onTap;
  const _FolderCard({required this.folder, required this.canManage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: canManage ? () => _showMenu(context) : null,
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

  void _showMenu(BuildContext context) {
    final ac = AppColors.of(context);
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.image_outlined, color: ac.primary),
            title: const Text('Edit thumbnail'),
            onTap: () { Navigator.pop(sheetContext); editFolderThumbnail(context, folder); },
          ),
          if ((folder.imageUrl ?? '').isNotEmpty)
            ListTile(
              leading: Icon(Icons.close_rounded, color: ac.muted),
              title: const Text('Remove thumbnail'),
              onTap: () { Navigator.pop(sheetContext); removeFolderThumbnail(context, folder); },
            ),
        ]),
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

class _OfflineContentCard extends StatelessWidget {
  final AcademicContent item;
  final VoidCallback onTap;
  const _OfflineContentCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hasThumb = (item.thumbnailUrl ?? '').isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 148,
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ac.bdr),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 84,
                    width: double.infinity,
                    child: FutureBuilder<String?>(
                      future: AcademicContentRepository.instance.offlineThumbnailPath(item.id),
                      builder: (context, thumbSnap) {
                        final localThumb = thumbSnap.data;
                        if (localThumb != null && File(localThumb).existsSync()) {
                          return Image.file(File(localThumb), fit: BoxFit.cover);
                        }
                        return hasThumb
                            ? Image.network(
                                item.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _thumbFallback(ac),
                              )
                            : _thumbFallback(ac);
                      },
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: ac.grnBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.offline_pin_rounded, size: 10, color: ac.grn),
                          const SizedBox(width: 3),
                          Text(
                            'Offline',
                            style: AppText.label.copyWith(fontSize: 8.5, color: ac.grn, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppText.title.copyWith(fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subject.isNotEmpty ? item.subject : item.contentType.label,
                      style: AppText.caption.copyWith(fontSize: 10, color: ac.txt2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback(AppColors ac) {
    return Container(
      color: ac.surf2,
      alignment: Alignment.center,
      child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 26)),
    );
  }
}


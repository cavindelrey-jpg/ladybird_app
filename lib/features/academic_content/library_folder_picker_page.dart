// lib/features/academic_content/library_folder_picker_page.dart
// Folder-only navigator for moving a file between folders — the "move
// files" half of the admin's "create folders, rename them, move files,
// reorganize" capability. Drill into any depth, then "Move here".

import 'package:flutter/material.dart';
import '../../models/library_folder.dart';
import '../../repositories/library_folder_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class LibraryFolderPickerPage extends StatelessWidget {
  final String? folderId;
  final String title;

  /// Folders that can't be picked as a destination — when moving a folder
  /// itself, this is that folder plus everything nested under it, so an
  /// admin can't create a cycle by moving a folder into its own subtree.
  final Set<String> disabledFolderIds;

  const LibraryFolderPickerPage({
    super.key, required this.folderId, this.title = 'Move to…',
    this.disabledFolderIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hereDisabled = folderId != null && disabledFolderIds.contains(folderId);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(title, style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
        actions: [
          TextButton(
            onPressed: hereDisabled ? null : () => Navigator.of(context).pop(folderId),
            child: Text('Move here', style: AppText.button.copyWith(fontSize: 13, color: hereDisabled ? ac.muted : ac.primary)),
          ),
        ],
      ),
      body: AppBackground(child: SafeArea(
        child: StreamBuilder<List<LibraryFolder>>(
          stream: folderId == null
              ? LibraryFolderRepository.instance.watchRootFolders()
              : LibraryFolderRepository.instance.watchChildFolders(folderId!),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final folders = snap.data ?? const <LibraryFolder>[];
            if (folders.isEmpty) {
              return Center(
                child: Text('No subfolders here.', style: AppText.bodySm.copyWith(color: ac.txt2)),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: folders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final f = folders[i];
                final disabled = disabledFolderIds.contains(f.id);
                return Opacity(
                  opacity: disabled ? 0.4 : 1,
                  child: Material(
                    color: ac.surf,
                    borderRadius: BorderRadius.circular(Rad.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Rad.md),
                      onTap: disabled ? null : () async {
                        final picked = await Navigator.of(context).push<String?>(MaterialPageRoute(
                            builder: (_) => LibraryFolderPickerPage(
                                folderId: f.id, title: f.name, disabledFolderIds: disabledFolderIds)));
                        if (picked != null && context.mounted) Navigator.of(context).pop(picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
                        child: Row(children: [
                          HierarchyAvatar(label: f.name, icon: f.emoji, imageUrl: f.imageUrl, size: 40),
                          const SizedBox(width: 12),
                          Expanded(child: Text(f.name, style: AppText.title.copyWith(fontSize: 14, color: ac.txt))),
                          Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      )),
    );
  }
}

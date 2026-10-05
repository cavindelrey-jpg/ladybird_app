// lib/features/academic_content/library_folder_page.dart
// One level of the Academia Library's File Explorer: shows this folder's
// subfolders and the items filed directly in it. Supports grid/list modes
// and multi-select mode with batch offline downloads.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
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
import '../courses_marketplace/hierarchy_browse_scaffold.dart';
import 'content_details_page.dart';
import 'content_upload_page.dart';
import 'bulk_past_paper_upload_page.dart';
import 'library_folder_picker_page.dart';
import 'folder_thumbnail_editor.dart';

class LibraryFolderPage extends StatefulWidget {
  final String folderId;
  final String folderName;
  final AppUser user;
  const LibraryFolderPage({super.key, required this.folderId, required this.folderName, required this.user});

  @override
  State<LibraryFolderPage> createState() => _LibraryFolderPageState();
}

class _Entry {
  final LibraryFolder? folder;
  final AcademicContent? content;
  const _Entry.folder(this.folder) : content = null;
  const _Entry.content(this.content) : folder = null;
  bool get isFolder => folder != null;
  String get sortKey => isFolder ? folder!.name : content!.title;
}

class _LibraryFolderPageState extends State<LibraryFolderPage> {
  bool get _canManage => widget.user.canUploadContent;

  bool _isSelecting = false;
  final Set<String> _selectedIds = {};
  bool _batchDownloading = false;

  late final Stream<List<LibraryFolder>> _foldersStream;
  late final Stream<List<AcademicContent>> _itemsStream;

  @override
  void initState() {
    super.initState();
    _foldersStream = LibraryFolderRepository.instance.watchChildFolders(widget.folderId);
    _itemsStream = LibraryFolderRepository.instance.watchItemsInFolder(widget.folderId);
  }

  void _enterSelection(String? initialId) {
    HapticFeedback.selectionClick();
    setState(() {
      _isSelecting = true;
      _selectedIds.clear();
      if (initialId != null) _selectedIds.add(initialId);
    });
  }

  void _exitSelection() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleItem(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _batchDownloadOffline(List<AcademicContent> allItems) async {
    final toDownload = allItems.where((i) => _selectedIds.contains(i.id)).toList();
    if (toDownload.isEmpty) return;

    setState(() => _batchDownloading = true);
    int successCount = 0;

    for (final item in toDownload) {
      if ((item.fileUrl ?? '').isNotEmpty) {
        try {
          await AcademicContentRepository.instance.downloadForOffline(item);
          successCount++;
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _batchDownloading = false;
        _exitSelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded $successCount item${successCount == 1 ? '' : 's'} for offline access.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<LibraryFolder>>(
      stream: _foldersStream,
      builder: (context, folderSnap) {
        final folders = folderSnap.data ?? const <LibraryFolder>[];
        return StreamBuilder<List<AcademicContent>>(
          stream: _itemsStream,
          builder: (context, itemSnap) {
            final items = itemSnap.data ?? const <AcademicContent>[];
            if ((folderSnap.hasError || itemSnap.hasError) && folders.isEmpty && items.isEmpty) {
              CrashService.instance.recordError(folderSnap.error ?? itemSnap.error, null,
                  context: 'LibraryFolderPage(${widget.folderId})');
              return Scaffold(
                backgroundColor: ac.bg,
                appBar: AppBar(
                  backgroundColor: ac.bg,
                  elevation: 0,
                  iconTheme: IconThemeData(color: ac.txt),
                  title: Text(widget.folderName, style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
                ),
                body: AppBackground(
                  child: ErrorView(message: "Couldn't load this folder — ${folderSnap.error ?? itemSnap.error}"),
                ),
              );
            }
            final loading = (!folderSnap.hasData && folderSnap.connectionState == ConnectionState.waiting) ||
                (!itemSnap.hasData && itemSnap.connectionState == ConnectionState.waiting);
            final entries = <_Entry>[
              ...folders.map((f) => _Entry.folder(f)),
              ...items.map((c) => _Entry.content(c)),
            ]..sort((a, b) {
                if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
                return a.sortKey.toLowerCase().compareTo(b.sortKey.toLowerCase());
              });

            return HierarchyBrowseScaffold<_Entry>(
              title: widget.folderName,
              subtitle: '${folders.length} folder${folders.length == 1 ? '' : 's'} · '
                  '${items.length} file${items.length == 1 ? '' : 's'}',
              searchHint: 'Search this folder…',
              loading: loading,
              items: entries,
              searchableText: (e) => e.sortKey,
              emptyMessage: _canManage ? 'Empty — use + below to add a folder or file.' : 'Nothing here yet.',
              isSelecting: _isSelecting,
              selectionTitle: '${_selectedIds.length} selected',
              onCancelSelection: _exitSelection,
              selectionActions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIds.addAll(items.map((i) => i.id));
                    });
                  },
                  child: const Text('Select All'),
                ),
                if (_batchDownloading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    tooltip: 'Save selected offline',
                    onPressed: _selectedIds.isEmpty ? null : () => _batchDownloadOffline(items),
                  ),
              ],
              gridTileBuilder: (context, e) => _EntryTile(
                entry: e,
                isGrid: true,
                canManage: _canManage,
                isSelecting: _isSelecting,
                isSelected: e.content != null && _selectedIds.contains(e.content!.id),
                onOpen: () {
                  if (_isSelecting && e.content != null) {
                    _toggleItem(e.content!.id);
                  } else {
                    _open(context, e);
                  }
                },
                onLongPress: e.content != null ? () => _enterSelection(e.content!.id) : null,
                onRename: () => _renameFolder(context, e.folder!),
                onDelete: () => _deleteFolder(context, e.folder!),
                onMoveFolder: () => _moveFolder(context, e.folder!),
                onMove: () => _moveItem(context, e.content!),
              ),
              listTileBuilder: (context, e) => _EntryTile(
                entry: e,
                isGrid: false,
                canManage: _canManage,
                isSelecting: _isSelecting,
                isSelected: e.content != null && _selectedIds.contains(e.content!.id),
                onOpen: () {
                  if (_isSelecting && e.content != null) {
                    _toggleItem(e.content!.id);
                  } else {
                    _open(context, e);
                  }
                },
                onLongPress: e.content != null ? () => _enterSelection(e.content!.id) : null,
                onRename: () => _renameFolder(context, e.folder!),
                onDelete: () => _deleteFolder(context, e.folder!),
                onMoveFolder: () => _moveFolder(context, e.folder!),
                onMove: () => _moveItem(context, e.content!),
              ),
              floatingActionButton: _canManage
                  ? FloatingActionButton(
                      heroTag: 'library_folder_add_${widget.folderId}',
                      backgroundColor: ac.primary,
                      onPressed: () => _showAddSheet(context),
                      child: const Icon(Icons.add_rounded, color: Colors.white),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  void _open(BuildContext context, _Entry e) {
    HapticFeedback.selectionClick();
    if (e.isFolder) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LibraryFolderPage(
              folderId: e.folder!.id, folderName: e.folder!.name, user: widget.user)));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ContentDetailsPage(contentId: e.content!.id, user: widget.user)));
    }
  }

  void _showAddSheet(BuildContext context) {
    final ac = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.create_new_folder_outlined, color: ac.primary),
            title: const Text('New folder'),
            onTap: () {
              Navigator.pop(sheetContext);
              _createFolder(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.upload_file_rounded, color: ac.primary),
            title: const Text('Upload a file here'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ContentUploadPage(user: widget.user, initialFolderId: widget.folderId)));
            },
          ),
          ListTile(
            leading: Icon(Icons.drive_folder_upload_rounded, color: ac.primary),
            title: const Text('Bulk upload past papers'),
            subtitle: const Text('Select many PDFs at once, filed here'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BulkPastPaperUploadPage(
                      user: widget.user, folderId: widget.folderId)));
            },
          ),
          ListTile(
            leading: Icon(Icons.checklist_rounded, color: ac.primary),
            title: const Text('Select multiple files'),
            onTap: () {
              Navigator.pop(sheetContext);
              _enterSelection(null);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _createFolder(BuildContext context) async {
    final name = await _promptName(context, title: 'New folder', initial: '');
    if (name == null || name.trim().isEmpty) return;
    final result = await LibraryFolderRepository.instance.createFolder(parentId: widget.folderId, name: name);
    if (!context.mounted) return;
    if (result is Failure) showToast(context, (result as Failure).message);
  }

  Future<void> _renameFolder(BuildContext context, LibraryFolder folder) async {
    final name = await _promptName(context, title: 'Rename folder', initial: folder.name);
    if (name == null || name.trim().isEmpty || name.trim() == folder.name) return;
    final result = await LibraryFolderRepository.instance.renameFolder(folder.id, name);
    if (!context.mounted) return;
    if (result is Failure) showToast(context, (result as Failure).message);
  }

  Future<void> _deleteFolder(BuildContext context, LibraryFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text('"${folder.name}" and any subfolders will be removed. '
            'Files inside stay safe — they\'ll become Unfiled instead of being deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await LibraryFolderRepository.instance.deleteFolder(folder.id);
    if (!context.mounted) return;
    if (result is Failure) showToast(context, (result as Failure).message);
  }

  Future<void> _moveFolder(BuildContext context, LibraryFolder folder) async {
    final blocked = await LibraryFolderRepository.instance.descendantIdsIncludingSelf(folder.id);
    if (!context.mounted) return;
    final destination = await Navigator.of(context).push<String?>(MaterialPageRoute(
        builder: (_) => LibraryFolderPickerPage(folderId: null, title: 'Move "${folder.name}"', disabledFolderIds: blocked)));
    if (!context.mounted || destination == null) return;
    final result = await LibraryFolderRepository.instance.moveFolder(folder.id, destination);
    if (!context.mounted) return;
    if (result is Failure) showToast(context, (result as Failure).message);
  }

  Future<void> _moveItem(BuildContext context, AcademicContent item) async {
    final destination = await Navigator.of(context).push<String?>(MaterialPageRoute(
        builder: (_) => LibraryFolderPickerPage(folderId: null, title: 'Move "${item.title}"')));
    if (destination == null) return;
    final result = await LibraryFolderRepository.instance.moveItem(item.id, destination);
    if (!context.mounted) return;
    if (result is Failure) showToast(context, (result as Failure).message);
  }

  Future<String?> _promptName(BuildContext context, {required String title, required String initial}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dCtx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final _Entry entry;
  final bool isGrid;
  final bool canManage;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onOpen;
  final VoidCallback? onLongPress;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onMoveFolder;
  final VoidCallback onMove;

  const _EntryTile({
    required this.entry,
    required this.isGrid,
    required this.canManage,
    this.isSelecting = false,
    this.isSelected = false,
    required this.onOpen,
    this.onLongPress,
    required this.onRename,
    required this.onDelete,
    required this.onMoveFolder,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    if (entry.isFolder) return _folderTile(context, entry.folder!);
    return _fileTile(context, entry.content!);
  }

  Widget _folderTile(BuildContext context, LibraryFolder folder) {
    final ac = AppColors.of(context);
    final tile = isGrid
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: HierarchyAvatar(label: folder.name, icon: folder.emoji, imageUrl: folder.imageUrl, fill: true)),
            const SizedBox(height: 6),
            Text(folder.name, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5, color: ac.txt),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])
        : Row(children: [
            HierarchyAvatar(label: folder.name, icon: folder.emoji, imageUrl: folder.imageUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Text(folder.name, style: AppText.title.copyWith(fontSize: 14, color: ac.txt))),
            Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
          ]);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onOpen,
        onLongPress: canManage ? () => _showFolderMenu(context, folder) : null,
        child: Container(
          padding: EdgeInsets.all(isGrid ? 10 : 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
          child: tile,
        ),
      ),
    );
  }

  void _showFolderMenu(BuildContext context, LibraryFolder folder) {
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
          ListTile(
            leading: Icon(Icons.drive_file_rename_outline_rounded, color: ac.primary),
            title: const Text('Rename'),
            onTap: () { Navigator.pop(sheetContext); onRename(); },
          ),
          ListTile(
            leading: Icon(Icons.folder_open_rounded, color: ac.primary),
            title: const Text('Move to folder…'),
            onTap: () { Navigator.pop(sheetContext); onMoveFolder(); },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: ac.red),
            title: const Text('Delete'),
            onTap: () { Navigator.pop(sheetContext); onDelete(); },
          ),
        ]),
      ),
    );
  }

  void _showFileMenu(BuildContext context) {
    final ac = AppColors.of(context);
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.folder_open_rounded, color: ac.primary),
            title: const Text('Move to folder…'),
            onTap: () { Navigator.pop(sheetContext); onMove(); },
          ),
        ]),
      ),
    );
  }

  Widget _fileTile(BuildContext context, AcademicContent item) {
    final ac = AppColors.of(context);
    if (isGrid) {
      return Material(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.md),
          onTap: onOpen,
          onLongPress: onLongPress ?? (canManage ? () => _showFileMenu(context) : null),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(
                color: isSelected ? ac.primary : ac.bdr2,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (item.thumbnailUrl ?? '').isNotEmpty
                          ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover, width: double.infinity,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => _filePlaceholder(ac, item))
                          : _filePlaceholder(ac, item),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.title, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5, color: ac.txt),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
                if (isSelecting)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? ac.primary : Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        isSelected ? Icons.check : Icons.circle_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onOpen,
        onLongPress: onLongPress ?? (canManage ? () => _showFileMenu(context) : null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(
              color: isSelected ? ac.primary : ac.bdr2,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            if (isSelecting)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? ac.primary : ac.muted,
                  size: 20,
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 44, height: 44,
                  child: (item.thumbnailUrl ?? '').isNotEmpty
                      ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => _filePlaceholder(ac, item))
                      : _filePlaceholder(ac, item)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: AppText.title.copyWith(fontSize: 14, color: ac.txt), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(item.contentType.label, style: AppText.caption.copyWith(fontSize: 11, color: ac.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
          ]),
        ),
      ),
    );
  }

  Widget _filePlaceholder(AppColors ac, AcademicContent item) =>
      Container(color: ac.surf2, alignment: Alignment.center,
          child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 26)));
}

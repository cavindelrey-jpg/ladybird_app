// lib/features/library/library_page.dart
// Redesigned library: search bar, animated filter chips, card grid with content type badges.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/library_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class LibraryPage extends StatefulWidget {
  final AppUser user;
  const LibraryPage({super.key, required this.user});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  ContentType? _filter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        // Header + search
        Container(
          color: C.surf,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('Library',
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700,
                      color: C.txt))),
              if (widget.user.canUploadContent)
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded, color: C.primary, size: 26),
                  tooltip: 'Upload content',
                  onPressed: () {
                    // TODO: navigate to upload page
                  },
                ),
            ]),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search resources…',
                prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
                filled: true, fillColor: C.surf3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Rad.sm),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Rad.sm),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ]),
        ),
        // Filter chips
        _FilterBar(current: _filter, onChanged: (t) => setState(() => _filter = t)),
        // Content
        Expanded(
          child: StreamBuilder<List<LibraryItem>>(
            stream: LibraryRepository.instance.watchItems(
                schoolId: widget.user.schoolId, type: _filter),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingView(message: 'Loading resources…');
              }
              if (snap.hasError) {
                return ErrorView(message: snap.error.toString(), onRetry: () => setState(() {}));
              }
              var items = snap.data ?? [];
              if (_search.isNotEmpty) {
                items = items.where((i) =>
                    i.title.toLowerCase().contains(_search)).toList();
              }
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No resources found',
                  subtitle: 'Resources uploaded by teachers will appear here',
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200, crossAxisSpacing: 12,
                    mainAxisSpacing: 12, childAspectRatio: 0.78),
                itemCount: items.length,
                itemBuilder: (_, i) => _ResourceCard(
                  item: items[i],
                  isPremiumUser: widget.user.isPremium || widget.user.canUploadContent,
                  onTap: () => LibraryRepository.instance.incrementViews(items[i].id),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final ContentType? current;
  final ValueChanged<ContentType?> onChanged;
  const _FilterBar({required this.current, required this.onChanged});

  Map<String, ContentType?> get _items {
    return {
      'All': null,
      'Notes': ContentType.note,
      'Videos': ContentType.video,
      'Past Papers': ContentType.pastPaper,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: C.surf,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: _items.entries.map((e) {
          final sel = e.value == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () => onChanged(e.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? C.navy : C.surf3,
                    borderRadius: BorderRadius.circular(Rad.xl),
                    border: Border.all(color: sel ? C.navy : C.bdr),
                  ),
                  child: Text(e.key, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : C.txt2)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final LibraryItem item;
  final bool isPremiumUser;
  final VoidCallback onTap;
  const _ResourceCard({required this.item, required this.isPremiumUser, required this.onTap});

  Map<String, dynamic> get _typeAssets {
    switch (item.type) {
      case ContentType.video:     return {'icon': Icons.play_circle_fill_rounded, 'color': C.red};
      case ContentType.pastPaper: return {'icon': Icons.history_edu_rounded, 'color': C.pur};
      case ContentType.note:
      default:                    return {'icon': Icons.article_rounded, 'color': C.primary};
    }
  }

  bool get _isLocked => item.isPremium && !isPremiumUser;

  @override
  Widget build(BuildContext context) {
    final assets = _typeAssets;
    final IconData icon = assets['icon'];
    final Color color = assets['color'];

    return GestureDetector(
      onTap: _isLocked ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
            color: C.surf, borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: C.bdr), boxShadow: Shad.sm),
        child: Stack(children: [
          // Thumbnail area
          Container(
            height: 100,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.md))),
            child: Center(child: Icon(icon, size: 40, color: color.withValues(alpha: .7))),
          ),
          // Content info
          Positioned(left: 0, right: 0, bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: GoogleFonts.sora(
                    fontSize: 12, fontWeight: FontWeight.w700, color: C.txt),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.visibility_outlined, size: 10, color: C.muted),
                  const SizedBox(width: 3),
                  Text('${item.views}', style: GoogleFonts.inter(
                      fontSize: 10, color: C.muted)),
                ]),
              ]),
            ),
          ),
          // Lock overlay
          if (_isLocked)
            Positioned.fill(child: Container(
              decoration: BoxDecoration(
                  color: C.txt.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(Rad.md)),
              // FIXED: Added const to the top-level Column layout widget to fix performance warning
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                SizedBox(height: 6),
                Text('Premium', style: TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            )),
          // Type badge
          Positioned(top: 8, left: 8,
              child: StatusBadge(
                  label: item.type.name.toUpperCase().substring(0, 3),
                  color: color)),
        ]),
      ),
    );
  }
}
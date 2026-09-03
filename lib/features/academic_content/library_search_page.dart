// lib/features/academic_content/library_search_page.dart
// Backs the Academia Library home header's search icon — real search
// against AcademicContentRepository.search() (already existed, just
// wasn't reachable from the redesigned home page).

import 'package:flutter/material.dart';
import '../../core/debouncer.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'content_details_page.dart';

class LibrarySearchPage extends StatefulWidget {
  final AppUser user;
  const LibrarySearchPage({super.key, required this.user});

  @override
  State<LibrarySearchPage> createState() => _LibrarySearchPageState();
}

class _LibrarySearchPageState extends State<LibrarySearchPage> {
  final _ctrl = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 350);
  String _query = '';
  bool _loading = false;
  List<AcademicContent>? _results;

  @override
  void dispose() {
    _ctrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    if (v.trim().isEmpty) {
      _debouncer.cancel();
      setState(() { _results = null; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debouncer.run(() => _runSearch(v));
  }

  Future<void> _runSearch(String v) async {
    final results = await AcademicContentRepository.instance.search(v, institutionId: widget.user.schoolId);
    if (!mounted || v != _query) return;
    setState(() { _results = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(20), border: Border.all(color: ac.bdr)),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 18, color: ac.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: InputDecoration(
                  hintText: 'Search past papers, notes, documents…',
                  hintStyle: AppText.bodySm.copyWith(color: ac.muted, fontSize: 12.5),
                  border: InputBorder.none, isDense: true,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              InkWell(onTap: () { _ctrl.clear(); _onChanged(''); },
                  child: Icon(Icons.close_rounded, size: 16, color: ac.muted)),
          ]),
        ),
      ),
      body: AppBackground(child: _body(ac)),
    );
  }

  Widget _body(AppColors ac) {
    if (_query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_rounded, size: 44, color: ac.muted),
            const SizedBox(height: 12),
            Text('Search the Academia Library', style: AppText.title.copyWith(fontSize: 15, color: ac.txt)),
            const SizedBox(height: 6),
            Text('Find resources by title, subject, description, or tag.',
                style: AppText.bodySm.copyWith(color: ac.txt2), textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    if (_loading && _results == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(4, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerBlock(height: 72),
        )),
      );
    }
    final results = _results ?? const <AcademicContent>[];
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches for "$_query"',
        subtitle: 'Try a different word or check the spelling.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: results.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ResultTile(item: results[i], onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ContentDetailsPage(contentId: results[i].id, user: widget.user)))),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final AcademicContent item;
  final VoidCallback onTap;
  const _ResultTile({required this.item, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 44, height: 44,
                  child: (item.thumbnailUrl ?? '').isNotEmpty
                      ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(ac))
                      : _placeholder(ac)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: AppText.title.copyWith(fontSize: 14, color: ac.txt), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${item.contentType.label}${item.subject.isNotEmpty ? ' · ${item.subject}' : ''}',
                    style: AppText.caption.copyWith(fontSize: 11, color: ac.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(AppColors ac) => Container(color: ac.surf2, alignment: Alignment.center,
      child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 20)));
}

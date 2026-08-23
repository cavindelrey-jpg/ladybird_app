// lib/features/magazine/magazine_search_page.dart
// Backs the Magazine feed header's search icon, which previously only
// showed an honest "coming soon" toast. Real search now: debounced
// as-you-type queries against MagazineRepository.searchArticles(), which
// is itself bounded (the most recent 200 published articles, filtered
// client-side) rather than a fabricated full-text index this project has
// no infrastructure for — see that method's doc comment.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../core/debouncer.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'magazine_feed_page.dart' show ArticleListCard;
import 'article_reader_page.dart';
import 'author_profile_page.dart';

class MagazineSearchPage extends StatefulWidget {
  final AppUser? user;
  const MagazineSearchPage({super.key, this.user});

  @override
  State<MagazineSearchPage> createState() => _MagazineSearchPageState();
}

class _MagazineSearchPageState extends State<MagazineSearchPage> {
  final _ctrl = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 350);
  String _query = '';
  bool _loading = false;
  List<MagazineArticle>? _results; // null = no search run yet

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
    final results = await MagazineRepository.instance.searchArticles(v);
    if (!mounted || v != _query) return; // a newer keystroke already superseded this query
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
          decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bdr)),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 18, color: C.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style: AppText.bodySm.copyWith(color: C.txt),
                decoration: InputDecoration(
                  hintText: 'Search articles, topics, writers…',
                  hintStyle: AppText.bodySm.copyWith(color: C.muted, fontSize: 12.5),
                  border: InputBorder.none, isDense: true,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              InkWell(
                onTap: () { _ctrl.clear(); _onChanged(''); },
                child: Icon(Icons.close_rounded, size: 16, color: C.muted),
              ),
          ]),
        ),
      ),
      body: AppBackground(child: _body()),
    );
  }

  Widget _body() {
    if (_query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_rounded, size: 44, color: C.muted),
            const SizedBox(height: 12),
            Text('Search the Magazine', style: AppText.title.copyWith(fontSize: 15)),
            const SizedBox(height: 6),
            Text('Find articles by title, topic, category, or writer.',
                style: AppText.bodySm, textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    if (_loading && _results == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(4, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerBlock(height: 84),
        )),
      );
    }
    final results = _results ?? const <MagazineArticle>[];
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches for "$_query"',
        subtitle: 'Search covers the most recent articles — try a different word.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: results.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ArticleListCard(
          article: results[i],
          currentUser: widget.user,
          onOpen: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ArticleReaderPage(article: results[i], currentUser: widget.user))),
          onOpenAuthor: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AuthorProfilePage(authorId: results[i].authorId, currentUser: widget.user))),
        ),
      ),
    );
  }
}

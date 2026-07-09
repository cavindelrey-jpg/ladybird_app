// lib/features/academic_content/academic_content_page.dart
// Full content library: search, subject filter, content type filter, live stream.
// Replaces the old LibraryPage.
//
// Design pass: named AppText scale, real InkWell ripple + haptic on every
// card/chip tap (was silent GestureDetector everywhere), skeleton grid
// while the stream connects instead of a bare spinner.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/debouncer.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'content_details_page.dart';
import 'content_upload_page.dart';

class AcademicContentPage extends StatefulWidget {
  final AppUser user;
  final ContentType? initialTypeFilter;
  const AcademicContentPage({super.key, required this.user, this.initialTypeFilter});

  @override
  State<AcademicContentPage> createState() => _AcademicContentPageState();
}

class _AcademicContentPageState extends State<AcademicContentPage> {
  late ContentType? _typeFilter = widget.initialTypeFilter;
  String? _subjectFilter;
  bool _isSearching = false;
  List<AcademicContent>? _searchResults;
  bool _searchLoading = false;
  List<String> _subjects = [];

  final _searchCtrl = TextEditingController();
  late final Debouncer _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchDebounce = Debouncer(milliseconds: 400);
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    final list = await AcademicContentRepository.instance
        .getSubjects(institutionId: widget.user.schoolId);
    if (mounted) setState(() => _subjects = list);
  }

  void _onSearchChanged(String q) {
    if (q.trim().isEmpty) {
      setState(() { _isSearching = false; _searchResults = null; });
      return;
    }
    setState(() { _isSearching = true; _searchLoading = true; });
    _searchDebounce.run(() async {
      final results = await AcademicContentRepository.instance.search(
        q,
        institutionId: widget.user.schoolId,
        contentType: _typeFilter,
      );
      if (mounted) setState(() { _searchResults = results; _searchLoading = false; });
    });
  }

  bool get _canUpload => widget.user.canUploadContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        _SearchBar(controller: _searchCtrl, onChanged: _onSearchChanged),
        _FilterRow(
          selectedType: _typeFilter,
          selectedSubject: _subjectFilter,
          subjects: _subjects,
          onTypeChanged: (t) => setState(() {
            _typeFilter = t;
            _searchResults = null;
            _isSearching = false;
            _searchCtrl.clear();
          }),
          onSubjectChanged: (s) =>
              setState(() => _subjectFilter = s == _subjectFilter ? null : s),
        ),
        Expanded(
          child: _isSearching
              ? _SearchResults(loading: _searchLoading, results: _searchResults ?? [], user: widget.user)
              : _LiveFeed(user: widget.user, typeFilter: _typeFilter, subjectFilter: _subjectFilter),
        ),
      ]),
      floatingActionButton: _canUpload
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ContentUploadPage(user: widget.user)))
                    .then((_) => _loadSubjects());
              },
              backgroundColor: C.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text('Upload', style: AppText.button.copyWith(fontSize: 15)),
            )
          : null,
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: C.surf,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppText.bodySm.copyWith(color: C.txt),
        decoration: InputDecoration(
          hintText: 'Search content, subjects, tags…',
          hintStyle: AppText.bodySm.copyWith(color: C.muted),
          prefixIcon: const Icon(Icons.search_rounded, color: C.muted, size: 20),
          filled: true,
          fillColor: C.surf2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final ContentType? selectedType;
  final String? selectedSubject;
  final List<String> subjects;
  final ValueChanged<ContentType?> onTypeChanged;
  final ValueChanged<String> onSubjectChanged;
  const _FilterRow({required this.selectedType, required this.selectedSubject,
      required this.subjects, required this.onTypeChanged, required this.onSubjectChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: C.surf, border: Border(bottom: BorderSide(color: C.bdr))),
      child: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _Chip(label: 'All', value: null, selected: selectedType, onTap: onTypeChanged),
              ...ContentType.values.map((t) =>
                  _Chip(label: '${t.emoji} ${t.label}', value: t, selected: selectedType, onTap: onTypeChanged)),
            ],
          ),
        ),
        if (subjects.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
              children: subjects.map((s) {
                final active = s == selectedSubject;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSubjectChanged(s);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: active ? C.blub : C.surf2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? C.blu : C.bdr, width: active ? 1.5 : 1),
                      ),
                      child: Text(s, style: AppText.caption.copyWith(
                          fontSize: 10, fontWeight: FontWeight.w600, color: active ? C.blu : C.txt2)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final ContentType? value;
  final ContentType? selected;
  final ValueChanged<ContentType?> onTap;
  const _Chip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active ? C.primary : C.surf2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? C.primary : C.bdr, width: active ? 1.5 : 1),
          ),
          child: Text(label, style: AppText.caption.copyWith(
              fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : C.txt2)),
        ),
      ),
    );
  }
}

class _LiveFeed extends StatelessWidget {
  final AppUser user;
  final ContentType? typeFilter;
  final String? subjectFilter;
  const _LiveFeed({required this.user, required this.typeFilter, required this.subjectFilter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AcademicContent>>(
      stream: AcademicContentRepository.instance.watch(
          institutionId: user.schoolId, contentType: typeFilter, subject: subjectFilter),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _ContentGridSkeleton();
        }
        final items = snap.data ?? [];
        if (items.isEmpty) return _EmptyState(typeFilter: typeFilter);
        return _ContentGrid(items: items, user: user);
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  final bool loading;
  final List<AcademicContent> results;
  final AppUser user;
  const _SearchResults({required this.loading, required this.results, required this.user});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _ContentGridSkeleton();
    if (results.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off, size: 48, color: C.muted),
        const SizedBox(height: 12),
        Text('No results found', style: AppText.body.copyWith(color: C.muted, fontSize: 15)),
      ]));
    }
    return _ContentGrid(items: results, user: user);
  }
}

/// Grid-shaped skeleton matching the real card silhouette (thumbnail +
/// badge + title lines), shown while the stream connects or a search runs.
class _ContentGridSkeleton extends StatelessWidget {
  const _ContentGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
            color: C.surf, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bdr)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(aspectRatio: 16 / 9, child: ShimmerBlock(borderRadius: 0)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              ShimmerLine(width: 60, height: 14),
              SizedBox(height: 8),
              ShimmerLine(height: 12),
              SizedBox(height: 4),
              ShimmerLine(width: 80, height: 11),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ContentGrid extends StatelessWidget {
  final List<AcademicContent> items;
  final AppUser user;
  const _ContentGrid({required this.items, required this.user});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
      itemCount: items.length,
      itemBuilder: (_, i) => _ContentCard(
        item: items[i],
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ContentDetailsPage(contentId: items[i].id, user: user))),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final AcademicContent item;
  final VoidCallback onTap;
  const _ContentCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
              color: C.surf, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: item.thumbnailUrl != null
                    ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Placeholder(type: item.contentType))
                    : _Placeholder(type: item.contentType),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: C.purb, borderRadius: BorderRadius.circular(20)),
                    child: Text('${item.contentType.emoji} ${item.contentType.label}',
                        style: AppText.label.copyWith(fontSize: 8, color: C.pur, letterSpacing: 0)),
                  ),
                  const SizedBox(height: 5),
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppText.title.copyWith(fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(item.subject, style: AppText.caption.copyWith(fontSize: 10)),
                  const Spacer(),
                  Row(children: [
                    const Icon(Icons.visibility_outlined, size: 10, color: C.muted),
                    const SizedBox(width: 2),
                    Text('${item.views}', style: AppText.caption.copyWith(fontSize: 9)),
                    const SizedBox(width: 8),
                    const Icon(Icons.download_outlined, size: 10, color: C.muted),
                    const SizedBox(width: 2),
                    Text('${item.downloads}', style: AppText.caption.copyWith(fontSize: 9)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ContentType type;
  const _Placeholder({required this.type});
  @override
  Widget build(BuildContext context) => Container(
    color: C.surf2,
    child: Center(child: Text(type.emoji, style: const TextStyle(fontSize: 28))),
  );
}

class _EmptyState extends StatelessWidget {
  final ContentType? typeFilter;
  const _EmptyState({this.typeFilter});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(typeFilter?.emoji ?? '📚', style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text(typeFilter != null ? 'No ${typeFilter!.label} yet' : 'No content uploaded yet',
          style: AppText.h2.copyWith(fontSize: 16)),
      const SizedBox(height: 6),
      Text('Upload the first resource for your school.',
          style: AppText.bodySm.copyWith(color: C.muted)),
    ]),
  );
}

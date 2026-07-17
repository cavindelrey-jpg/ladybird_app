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
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'content_details_page.dart';
import 'content_upload_page.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import '../../widgets/xp_widgets.dart';

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

  void _selectSubject(String subject) {
    HapticFeedback.selectionClick();
    setState(() {
      _subjectFilter = subject;
      _isSearching = false;
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: AppBackground(child: SafeArea(
        child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Library', style: AppText.h1.copyWith(fontSize: 22)),
                Text('Save. Study. Succeed.', style: AppText.caption.copyWith(fontSize: 12)),
              ]),
            ),
            XpBalanceBadge(userId: widget.user.id),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: C.txt2),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NotificationsPage(userId: widget.user.id))),
            ),
            UserAvatar(
              initials: widget.user.name.isEmpty ? '?' : widget.user.name[0].toUpperCase(),
              radius: 18, photoUrl: widget.user.photoUrl,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProfilePage(user: widget.user))),
            ),
          ]),
        ),
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
              : ((_typeFilter == null && _subjectFilter == null)
                  ? _LibraryDiscovery(user: widget.user, onSubjectTap: _selectSubject)
                  : _LiveFeed(user: widget.user, typeFilter: _typeFilter, subjectFilter: _subjectFilter)),
        ),
      ]),
      ),
      ),
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
        if (snap.hasError) {
          CrashService.instance.recordError(snap.error, snap.stackTrace,
              context: 'AcademicContentPage._LiveFeed.watch(type: $typeFilter, subject: $subjectFilter)');
          return ErrorView(message: "Couldn't load this list — ${snap.error}");
        }
        final items = snap.data ?? [];
        if (items.isEmpty) return _EmptyState(typeFilter: typeFilter, subjectFilter: subjectFilter);
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
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(aspectRatio: 16 / 9, child: ShimmerBlock(borderRadius: 0)),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
  final String? subjectFilter;
  const _EmptyState({this.typeFilter, this.subjectFilter});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(typeFilter?.emoji ?? '📚', style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text(
          typeFilter != null
              ? 'No ${typeFilter!.label}${subjectFilter != null ? ' in $subjectFilter' : ''} yet'
              : (subjectFilter != null ? 'No resources in $subjectFilter yet' : 'No content uploaded yet'),
          style: AppText.h2.copyWith(fontSize: 16)),
      const SizedBox(height: 6),
      Text('Upload the first resource for your school.',
          style: AppText.bodySm.copyWith(color: C.muted)),
    ]),
  );
}

const _kSubjectIcons = <String, IconData>{
  'Mathematics':      Icons.functions_rounded,
  'Science':          Icons.science_rounded,
  'Languages':        Icons.translate_rounded,
  'Social Studies':   Icons.public_rounded,
  'Computer Science': Icons.code_rounded,
  'Arts & Literature':Icons.palette_rounded,
  'Business':         Icons.trending_up_rounded,
};

/// Default Library view — shown when "All" is selected and there's no
/// active search. Hero banner, Continue Learning (real recently-viewed
/// data, no fabricated progress %), Saved for Offline (real save/bookmark
/// list — see the honesty note on AcademicContentRepository about this
/// not being true on-device caching yet), and Categories (real per-
/// subject counts from the actual library, not a fixed hardcoded list).
class _LibraryDiscovery extends StatelessWidget {
  final AppUser user;
  final ValueChanged<String> onSubjectTap;
  const _LibraryDiscovery({required this.user, required this.onSubjectTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _heroBanner(context),
        const SizedBox(height: 20),
        _sectionHeader('Continue Learning', onSeeAll: () {}),
        const SizedBox(height: 12),
        _continueLearning(context),
        const SizedBox(height: 24),
        _sectionHeader('Saved for Offline', onSeeAll: () {}),
        const SizedBox(height: 12),
        _savedForOffline(context),
        const SizedBox(height: 24),
        _sectionHeader('Categories', onSeeAll: null),
        const SizedBox(height: 12),
        _categories(context),
      ],
    );
  }

  Widget _sectionHeader(String title, {required VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 16))),
        if (onSeeAll != null)
          Text('See all', style: AppText.subtitle.copyWith(color: C.primary, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }

  Widget _heroBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(Rad.lg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your learning\nresources in one place',
              style: AppText.h1.copyWith(fontSize: 19, height: 1.25)),
          const SizedBox(height: 8),
          Text('Save content for offline use and access it anytime, anywhere.',
              style: AppText.bodySm.copyWith(fontSize: 12.5)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => showToast(context,
                'Saved items are bookmarked in your account — full on-device '
                'offline caching is a planned upgrade, not built yet.'),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.navy, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text('How offline works', style: AppText.caption.copyWith(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  Widget _continueLearning(BuildContext context) {
    return StreamBuilder<List<AcademicContent>>(
      stream: AcademicContentRepository.instance.watchRecentlyViewed(user.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const ShimmerBlock(width: 150, height: 180),
            ),
          );
        }
        final items = snap.data ?? const <AcademicContent>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Open something from the Library and it\'ll show up here.', style: AppText.bodySm),
          );
        }
        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _ContinueLearningCard(item: items[i], user: user),
          ),
        );
      },
    );
  }

  Widget _savedForOffline(BuildContext context) {
    return StreamBuilder<List<AcademicContent>>(
      stream: AcademicContentRepository.instance.watchSavedContent(user.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(children: List.generate(3, (_) => const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              ShimmerBlock(width: 40, height: 40, borderRadius: 8),
              SizedBox(width: 12),
              Expanded(child: ShimmerLine(height: 14)),
            ]),
          )));
        }
        final items = snap.data ?? const <AcademicContent>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Nothing saved yet — tap the bookmark on anything to save it here.', style: AppText.bodySm),
          );
        }
        return Column(children: items.map((item) => _SavedRow(item: item, user: user)).toList());
      },
    );
  }

  Widget _categories(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: AcademicContentRepository.instance.subjectCountsOnce(institutionId: user.schoolId),
      builder: (context, snap) {
        final counts = snap.data ?? const <String, int>{};
        if (counts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No subjects yet.', style: AppText.bodySm),
          );
        }
        final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10, runSpacing: 10,
            children: sorted.map((entry) {
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(Rad.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.md),
                  onTap: () => onSubjectTap(entry.key),
                  child: Container(
                    width: 155,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
                    child: Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(9)),
                        child: Icon(_kSubjectIcons[entry.key] ?? Icons.book_outlined, size: 17, color: C.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry.key, style: AppText.subtitle.copyWith(color: C.txt, fontSize: 12.5),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${entry.value} item${entry.value == 1 ? '' : 's'}', style: AppText.caption.copyWith(fontSize: 10.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  final AcademicContent item;
  final AppUser user;
  const _ContinueLearningCard({required this.item, required this.user});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => ContentDetailsPage(contentId: item.id, user: user)));
        },
        child: Container(
          width: 150,
          decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              SizedBox(
                height: 90, width: double.infinity,
                child: (item.thumbnailUrl ?? '').isNotEmpty
                    ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: C.surf3))
                    : Container(color: C.surf3, child: Center(child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 24)))),
              ),
              Positioned(
                top: 6, left: 6,
                child: StatusBadge(label: item.contentType.label.toUpperCase(), color: C.primary),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: AppText.title.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('By ${item.uploaderName}', style: AppText.caption.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  final AcademicContent item;
  final AppUser user;
  const _SavedRow({required this.item, required this.user});

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ContentDetailsPage(contentId: item.id, user: user))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: AppText.title.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${item.contentType.label}${item.fileSizeBytes != null ? ' · ${_formatSize(item.fileSizeBytes)}' : ''}',
                    style: AppText.caption.copyWith(fontSize: 11)),
              ]),
            ),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  HapticFeedback.lightImpact();
                  AcademicContentRepository.instance.toggleSave(item.id, user.id);
                },
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.bookmark_rounded, color: C.grn, size: 20),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

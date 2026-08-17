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
import '../../models/hero_slide.dart';
import '../../repositories/academic_content_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/hero_banner_carousel.dart';
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
  String? _levelFilter;
  String? _examBoardFilter;
  int? _yearFilter;
  bool _isSearching = false;
  List<AcademicContent>? _searchResults;
  bool _searchLoading = false;
  List<String> _subjects = [];
  List<int> _years = [];

  final _searchCtrl = TextEditingController();
  late final Debouncer _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchDebounce = Debouncer(milliseconds: 400);
    _loadSubjects();
    _loadYears();
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    final list = await AcademicContentRepository.instance
        .getSubjects(institutionId: widget.user.schoolId);
    if (mounted) setState(() => _subjects = list);
  }

  Future<void> _loadYears() async {
    final list = await AcademicContentRepository.instance
        .yearsInUseOnce(institutionId: widget.user.schoolId);
    if (mounted) setState(() => _years = list);
  }

  void _onSearchChanged(String q) {
    if (q.trim().isEmpty) {
      if (_isSearching) setState(() { _isSearching = false; _searchResults = null; });
      return;
    }
    // Only flip _isSearching on the leading edge (empty -> non-empty) so
    // every subsequent keystroke doesn't force a full-page rebuild ahead
    // of the debounce actually running — that was defeating the point of
    // debouncing in the first place. _searchLoading moves inside the
    // debounced closure below, so it only flips once per pause in typing.
    if (!_isSearching) setState(() => _isSearching = true);
    _searchDebounce.run(() async {
      if (!mounted) return;
      setState(() => _searchLoading = true);
      final results = await AcademicContentRepository.instance.search(
        q,
        institutionId: widget.user.schoolId,
        contentType: _typeFilter,
        subject: _subjectFilter,
        level: _levelFilter,
        examBoard: _examBoardFilter,
        year: _yearFilter,
      );
      if (mounted) setState(() { _searchResults = results; _searchLoading = false; });
    });
  }

  bool get _canUpload => widget.user.canUploadContent;

  int get _activeExtraFilterCount =>
      (_levelFilter != null ? 1 : 0) + (_examBoardFilter != null ? 1 : 0) + (_yearFilter != null ? 1 : 0);

  /// Handles HeroDestination.section taps from the Library banner: a key
  /// matching a ContentType name switches the type filter, anything else
  /// is treated as a subject name (same as tapping a subject tile).
  void _selectLibrarySection(String key) {
    for (final t in ContentType.values) {
      if (t.name == key) {
        HapticFeedback.selectionClick();
        setState(() {
          _typeFilter = t;
          _searchResults = null;
          _isSearching = false;
          _searchCtrl.clear();
        });
        return;
      }
    }
    _selectSubject(key);
  }

  void _selectSubject(String subject) {
    HapticFeedback.selectionClick();
    setState(() {
      _subjectFilter = subject;
      _isSearching = false;
      _searchCtrl.clear();
    });
  }

  Future<void> _openFilterSheet() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<_FilterSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        years: _years,
        level: _levelFilter,
        examBoard: _examBoardFilter,
        year: _yearFilter,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _levelFilter = result.level;
      _examBoardFilter = result.examBoard;
      _yearFilter = result.year;
    });
    if (_isSearching) _onSearchChanged(_searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
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
              icon: Icon(Icons.notifications_outlined, color: ac.txt2),
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
        HeroBannerCarousel(
          placement: HeroPlacement.library,
          user: widget.user,
          onSectionSelect: _selectLibrarySection,
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _SearchBar(controller: _searchCtrl, onChanged: _onSearchChanged)),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: _FilterButton(activeCount: _activeExtraFilterCount, onTap: _openFilterSheet),
          ),
        ]),
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
        if (_activeExtraFilterCount > 0)
          _ActiveExtraFiltersBar(
            level: _levelFilter,
            examBoard: _examBoardFilter,
            year: _yearFilter,
            onClear: () => setState(() {
              _levelFilter = null;
              _examBoardFilter = null;
              _yearFilter = null;
            }),
          ),
        Expanded(
          child: _isSearching
              ? _SearchResults(loading: _searchLoading, results: _searchResults ?? [], user: widget.user)
              : ((_typeFilter == null && _subjectFilter == null && _activeExtraFilterCount == 0)
                  ? _LibraryDiscovery(user: widget.user, onSubjectTap: _selectSubject)
                  : _LiveFeed(
                      user: widget.user,
                      typeFilter: _typeFilter,
                      subjectFilter: _subjectFilter,
                      levelFilter: _levelFilter,
                      examBoardFilter: _examBoardFilter,
                      yearFilter: _yearFilter,
                    )),
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
              backgroundColor: ac.primary,
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
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: ac.surf,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppText.bodySm.copyWith(color: ac.txt),
        decoration: InputDecoration(
          hintText: 'Search content, subjects, tags…',
          hintStyle: AppText.bodySm.copyWith(color: ac.muted),
          prefixIcon: Icon(Icons.search_rounded, color: ac.muted, size: 20),
          filled: true,
          fillColor: ac.surf2,
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
    final ac = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(color: ac.surf, border: Border(bottom: BorderSide(color: ac.bdr))),
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
                        color: active ? ac.bluBg : ac.surf2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? ac.blu : ac.bdr, width: active ? 1.5 : 1),
                      ),
                      child: Text(s, style: AppText.caption.copyWith(
                          fontSize: 10, fontWeight: FontWeight.w600, color: active ? ac.blu : ac.txt2)),
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
    final ac = AppColors.of(context);
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
            color: active ? ac.primary : ac.surf2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? ac.primary : ac.bdr, width: active ? 1.5 : 1),
          ),
          child: Text(label, style: AppText.caption.copyWith(
              fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : ac.txt2)),
        ),
      ),
    );
  }
}

class _LiveFeed extends StatelessWidget {
  final AppUser user;
  final ContentType? typeFilter;
  final String? subjectFilter;
  final String? levelFilter;
  final String? examBoardFilter;
  final int? yearFilter;
  const _LiveFeed({
    required this.user,
    required this.typeFilter,
    required this.subjectFilter,
    this.levelFilter,
    this.examBoardFilter,
    this.yearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AcademicContent>>(
      stream: AcademicContentRepository.instance.watch(
        institutionId: user.schoolId,
        contentType: typeFilter,
        subject: subjectFilter,
        level: levelFilter,
        examBoard: examBoardFilter,
        year: yearFilter,
      ),
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

class _FilterSheetResult {
  final String? level;
  final String? examBoard;
  final int? year;
  const _FilterSheetResult({this.level, this.examBoard, this.year});
}

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const _FilterButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: activeCount > 0 ? ac.primaryBg : ac.surf2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: activeCount > 0 ? ac.primary : ac.bdr),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Icon(Icons.tune_rounded, size: 18, color: activeCount > 0 ? ac.primary : ac.txt2),
            if (activeCount > 0)
              Positioned(
                right: -6, top: -6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: ac.primary, shape: BoxShape.circle),
                  child: Text('$activeCount',
                      style: AppText.caption.copyWith(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _ActiveExtraFiltersBar extends StatelessWidget {
  final String? level;
  final String? examBoard;
  final int? year;
  final VoidCallback onClear;
  const _ActiveExtraFiltersBar({this.level, this.examBoard, this.year, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (level != null) level!,
      if (examBoard != null) examBoard!,
      if (year != null) '$year',
    ];
    final ac = AppColors.of(context);
    return Container(
      color: ac.surf,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Icon(Icons.filter_alt_rounded, size: 14, color: ac.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(parts.join(' · '),
              style: AppText.caption.copyWith(fontSize: 11, color: ac.primary, fontWeight: FontWeight.w600)),
        ),
        InkWell(
          onTap: onClear,
          child: Text('Clear', style: AppText.caption.copyWith(fontSize: 11, color: ac.muted)),
        ),
      ]),
    );
  }
}

/// Scalable filter surface (directive: "Search / Filter: Subject, Level,
/// Type, Examination, Year, Category — then show content", never a wall of
/// per-upload tags). Subject/Type stay as quick inline chips on the main
/// page since kAcademicSubjects/ContentType are both small fixed sets;
/// Level/Examination/Year live here since surfacing all of them inline
/// would be exactly the clutter the directive warns against.
class _FilterSheet extends StatefulWidget {
  final List<int> years;
  final String? level;
  final String? examBoard;
  final int? year;
  const _FilterSheet({required this.years, this.level, this.examBoard, this.year});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _level = widget.level;
  late String? _examBoard = widget.examBoard;
  late int? _year = widget.year;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: ac.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: ac.bdr, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Filters', style: AppText.h2.copyWith(fontSize: 18)),
          const SizedBox(height: 20),
          Text('Level / Class', style: AppText.subtitle.copyWith(fontSize: 13)),
          const SizedBox(height: 10),
          _sheetChips(ac, kAcademicLevels, _level, (v) => setState(() => _level = _level == v ? null : v)),
          const SizedBox(height: 20),
          Text('Examination', style: AppText.subtitle.copyWith(fontSize: 13)),
          const SizedBox(height: 10),
          _sheetChips(ac, kExamBoards, _examBoard, (v) => setState(() => _examBoard = _examBoard == v ? null : v)),
          if (widget.years.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Year', style: AppText.subtitle.copyWith(fontSize: 13)),
            const SizedBox(height: 10),
            _sheetChips(ac, widget.years.map((y) => '$y').toList(), _year?.toString(),
                (v) => setState(() => _year = _year == int.tryParse(v) ? null : int.tryParse(v))),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() { _level = null; _examBoard = null; _year = null; }),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ac.primary, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context,
                    _FilterSheetResult(level: _level, examBoard: _examBoard, year: _year)),
                child: const Text('Apply'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _sheetChips(AppColors ac, List<String> options, String? selected, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: options.map((o) {
        final active = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: active,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onTap(o);
          },
          selectedColor: ac.primary,
          labelStyle: TextStyle(
              color: active ? Colors.white : ac.txt,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400),
          backgroundColor: ac.surf2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: active ? ac.primary : ac.bdr)),
        );
      }).toList(),
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
      final ac = AppColors.of(context);
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off, size: 48, color: ac.muted),
        const SizedBox(height: 12),
        Text('No results found', style: AppText.body.copyWith(color: ac.muted, fontSize: 15)),
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
    final ac = AppColors.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
            color: ac.surf, borderRadius: BorderRadius.circular(16), border: Border.all(color: ac.bdr)),
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
    final ac = AppColors.of(context);
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
              color: ac.surf, borderRadius: BorderRadius.circular(16), border: Border.all(color: ac.bdr)),
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
                    decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(20)),
                    child: Text('${item.contentType.emoji} ${item.contentType.label}',
                        style: AppText.label.copyWith(fontSize: 8, color: ac.pur, letterSpacing: 0)),
                  ),
                  const SizedBox(height: 5),
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppText.title.copyWith(fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(item.subject, style: AppText.caption.copyWith(fontSize: 10)),
                  const Spacer(),
                  Row(children: [
                    Icon(Icons.visibility_outlined, size: 10, color: ac.muted),
                    const SizedBox(width: 2),
                    Text('${item.views}', style: AppText.caption.copyWith(fontSize: 9)),
                    const SizedBox(width: 8),
                    Icon(Icons.download_outlined, size: 10, color: ac.muted),
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
    color: AppColors.of(context).surf2,
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
          style: AppText.bodySm.copyWith(color: AppColors.of(context).muted)),
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
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      children: [
        _sectionHeader(context, 'Continue Learning', onSeeAll: () {}),
        const SizedBox(height: 12),
        _continueLearning(context),
        const SizedBox(height: 24),
        if (!user.isGuest && user.favoriteSubjects.isNotEmpty) ...[
          _sectionHeader(context, 'Recommended for You', onSeeAll: null),
          const SizedBox(height: 12),
          _recommended(context),
          const SizedBox(height: 24),
        ],
        _sectionHeader(context, 'Saved for Offline', onSeeAll: () {}),
        const SizedBox(height: 12),
        _savedForOffline(context),
        const SizedBox(height: 24),
        _sectionHeader(context, 'Categories', onSeeAll: null),
        const SizedBox(height: 12),
        _categories(context),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, {required VoidCallback? onSeeAll}) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 16))),
        if (onSeeAll != null)
          Text('See all', style: AppText.subtitle.copyWith(color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
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
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Failed to load: ${snap.error}',
                style: AppText.caption.copyWith(color: AppColors.of(context).red, fontSize: 11)),
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

  /// production_plan.md §7B — real favorite-subject-driven picks, not a
  /// generic list. Hidden entirely (see the caller's `if`) rather than
  /// shown empty for users with no favorite subjects set — an empty
  /// "Recommended for You" rail is worse than not showing the section.
  Widget _recommended(BuildContext context) {
    return FutureBuilder<List<AcademicContent>>(
      future: RecommendationRepository.instance.forLibrary(
        favoriteSubjects: user.favoriteSubjects, institutionId: user.schoolId,
      ),
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
        if (items.isEmpty) return const SizedBox.shrink();
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
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Failed to load: ${snap.error}',
                style: AppText.caption.copyWith(color: AppColors.of(context).red, fontSize: 11)),
          );
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
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 10, runSpacing: 10,
              children: List.generate(6, (_) => const ShimmerBlock(width: 155, height: 64, borderRadius: 14))),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Failed to load: ${snap.error}',
                style: AppText.caption.copyWith(color: AppColors.of(context).red, fontSize: 11)),
          );
        }
        final counts = snap.data ?? const <String, int>{};
        if (counts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No subjects yet.', style: AppText.bodySm),
          );
        }
        final ac = AppColors.of(context);
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
                    decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
                    child: Row(children: [
                      IconBadge(
                        icon: _kSubjectIcons[entry.key] ?? Icons.book_outlined,
                        color: ac.primary, size: 38, iconSize: 18,
                        radius: BorderRadius.circular(11),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry.key, style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 12.5),
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
    final ac = AppColors.of(context);
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
          decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              SizedBox(
                height: 90, width: double.infinity,
                child: (item.thumbnailUrl ?? '').isNotEmpty
                    ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: ac.surf3))
                    : Container(color: ac.surf3, child: Center(child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 24)))),
              ),
              Positioned(
                top: 6, left: 6,
                child: StatusBadge(label: item.contentType.label.toUpperCase(), color: ac.primary),
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
    final ac = AppColors.of(context);
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
              decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(8)),
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
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.bookmark_rounded, color: ac.grn, size: 20),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


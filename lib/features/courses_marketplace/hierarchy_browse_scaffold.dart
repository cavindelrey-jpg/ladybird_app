// lib/features/courses_marketplace/hierarchy_browse_scaffold.dart
// Shared shell for every "browse one level of the hierarchy" screen
// (Subjects-in-Level, Topics-in-Subject, Courses-in-Topic, Lessons-in-Course,
// Library folders). Supports search, grid/list toggle, and multi-select mode.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../services/courses_view_mode_service.dart';

import '../../models/app_user.dart';
import '../../widgets/application_shell.dart';
export '../../widgets/application_shell.dart' show AppNavDestination;

class HierarchyBrowseScaffold<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String searchHint;
  final bool loading;
  final List<T> items;
  final String Function(T item) searchableText;
  final Widget Function(BuildContext context, T item) gridTileBuilder;
  final Widget Function(BuildContext context, T item) listTileBuilder;
  final String emptyMessage;
  final Widget? floatingActionButton;

  // Global Shell & User integration
  final AppUser? user;
  final AppNavDestination destination;
  final Widget? contextualPanel;

  // Multi-select support
  final bool isSelecting;
  final String? selectionTitle;
  final List<Widget>? selectionActions;
  final VoidCallback? onCancelSelection;

  final List<Widget>? actions;
  final Widget? headerWidget;

  const HierarchyBrowseScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.searchHint,
    required this.loading,
    required this.items,
    required this.searchableText,
    required this.gridTileBuilder,
    required this.listTileBuilder,
    this.emptyMessage = 'Nothing here yet.',
    this.floatingActionButton,
    this.user,
    this.destination = AppNavDestination.academicCourses,
    this.contextualPanel,
    this.actions,
    this.headerWidget,
    this.isSelecting = false,
    this.selectionTitle,
    this.selectionActions,
    this.onCancelSelection,
  });

  @override
  State<HierarchyBrowseScaffold<T>> createState() => _HierarchyBrowseScaffoldState<T>();
}

class _HierarchyBrowseScaffoldState<T> extends State<HierarchyBrowseScaffold<T>> {
  String _query = '';
  bool _isGrid = CoursesViewModeService.isGrid;

  @override
  void initState() {
    super.initState();
    CoursesViewModeService.ensureLoaded().then((_) {
      if (mounted) setState(() => _isGrid = CoursesViewModeService.isGrid);
    });
  }

  List<T> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items.where((i) => widget.searchableText(i).toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isSelecting = widget.isSelecting;

    return ApplicationShell(
      user: widget.user,
      currentTitle: isSelecting ? (widget.selectionTitle ?? 'Select Items') : widget.title,
      subtitle: isSelecting ? null : widget.subtitle,
      currentDestination: widget.destination,
      contextualPanel: widget.contextualPanel,
      showBackButton: true,
      onBack: isSelecting ? widget.onCancelSelection : () => Navigator.of(context).maybePop(),
      floatingActionButton: isSelecting ? null : widget.floatingActionButton,
      child: Column(
        children: [
          if (widget.headerWidget != null) widget.headerWidget!,
          if (isSelecting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: ac.surf2,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onCancelSelection,
                    tooltip: 'Cancel Selection',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.selectionTitle ?? 'Select Items',
                    style: AppText.title.copyWith(fontSize: 15, color: ac.txt),
                  ),
                  const Spacer(),
                  if (widget.selectionActions != null) ...widget.selectionActions!,
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        hintStyle: AppText.bodySm.copyWith(color: ac.muted),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: ac.muted),
                        filled: true,
                        fillColor: ac.surf2,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  if (widget.actions != null) ...widget.actions!,
                  HierarchyViewToggle(
                    isGrid: _isGrid,
                    onChanged: (grid) {
                      setState(() => _isGrid = grid);
                      CoursesViewModeService.setGrid(grid);
                    },
                  ),
                ],
              ),
            ),
          Expanded(child: _body(ac)),
        ],
      ),
    );
  }

  Widget _body(AppColors ac) {
    if (widget.loading) {
      return _isGrid
          ? GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: 8,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
              itemBuilder: (_, __) => const ShimmerBlock(width: double.infinity, height: double.infinity),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const ShimmerBlock(width: double.infinity, height: 72),
            );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_query.isNotEmpty ? 'No matches for "$_query".' : widget.emptyMessage,
              textAlign: TextAlign.center, style: AppText.bodySm.copyWith(color: ac.txt2)),
        ),
      );
    }
    if (_isGrid) {
      return GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
        itemBuilder: (context, i) => widget.gridTileBuilder(context, items[i]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => widget.listTileBuilder(context, items[i]),
    );
  }
}

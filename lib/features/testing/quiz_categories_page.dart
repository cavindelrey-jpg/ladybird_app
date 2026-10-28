// lib/features/testing/quiz_categories_page.dart
// New top-level entry point for the Testing & Quiz system — replaces
// jumping straight to TestsSubjectPickerPage. Shows the education-level
// tree's top tier (Primary School / JSS / SSS / High School /
// Undergraduate, seeded by TestRepository.quizCategoriesOnce, plus
// whatever sections have been added since) as icon-sized tiles, each
// with a real photo if one's been set or a generated letter-avatar
// otherwise (see HierarchyAvatar — an image always wins over the
// letter when both could apply). Tapping a tile drills into
// TestsSubjectPickerPage scoped to that category.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/test.dart';
import '../../repositories/test_repository.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'quiz_icon_editor.dart';
import 'tests_subject_picker_page.dart';
import 'xp_dashboard_page.dart';

class QuizCategoriesPage extends StatefulWidget {
  final AppUser user;
  const QuizCategoriesPage({super.key, required this.user});

  @override
  State<QuizCategoriesPage> createState() => _QuizCategoriesPageState();
}

class _QuizCategoriesPageState extends State<QuizCategoriesPage> {
  AppColors get ac => AppColors.of(context);

  List<QuizCategory> _categories = [];
  Map<String, int> _counts = {};
  bool _loading = true;
  String? _error;

  /// Managing what a section looks like (or adding a new one) is an
  /// authoring action, same gate TestComposerPage/Create-Test already
  /// use (canUploadContent = lecturer+) — see test_repository.dart's own
  /// header note that firestore.rules doesn't separately enforce this,
  /// so the UI gate is the real line of defense today.
  bool get _canManage => widget.user.canUploadContent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        TestRepository.instance.quizCategoriesOnce(),
        TestRepository.instance.categoryTestCountsOnce(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<QuizCategory>;
        _counts = results[1] as Map<String, int>;
        _loading = false;
      });
    } catch (e, st) {
      // Previously had no catch at all -- any failure here (permission-
      // denied, missing index, genuine connectivity loss) left the page
      // spinning forever instead of reaching either real data or an
      // honest error state. Same fix CourseBrowsePage._load() already
      // applies for the identical bug shape.
      CrashService.instance.recordError(e, st, context: 'QuizCategoriesPage._load');
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load Quizzes -- check your connection and try again.";
        _loading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final name = await showAddQuizCategoryDialog(context);
    if (name == null || name.trim().isEmpty) return;
    final order = _categories.isEmpty
        ? 0.0
        : (_categories.map((c) => c.order).reduce((a, b) => a > b ? a : b) + 100);
    final result = await TestRepository.instance.addQuizCategory(name: name, order: order);
    if (!mounted) return;
    if (result case Failure(:final message)) {
      showToast(context, message, isError: true);
      return;
    }
    HapticFeedback.selectionClick();
    _load();
  }

  Future<void> _editCategoryLook(QuizCategory c) async {
    await showQuizIconEditor(
      context,
      label: c.name,
      currentEmoji: c.emoji,
      currentImageUrl: c.imageUrl,
      onSave: (emoji, image) async {
        String imageUrl = c.imageUrl;
        if (image != null) {
          final upload = await TestRepository.instance
              .uploadQuizCategoryImage(categoryId: c.id, imageFile: image);
          switch (upload) {
            case Success(:final value): imageUrl = value;
            // A failed upload must not silently proceed as if nothing
            // was picked -- that's the real bug that made "press edit,
            // pick a photo" look like it does nothing at all.
            case Failure(:final message): throw Exception(message);
          }
        } else {
          // No new photo picked — either an emoji was chosen (mutually
          // exclusive with a photo on a tile) or everything was cleared.
          imageUrl = '';
        }
        final result = await TestRepository.instance
            .updateQuizCategoryIcon(c.id, emoji: emoji, imageUrl: imageUrl);
        if (result case Failure(:final message)) throw Exception(message);
      },
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = widget.user.isGuest;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Academia Quizzes & Tests', style: AppText.h2),
        actions: [
          if (!isGuest)
            IconButton(
              icon: Icon(Icons.bolt_rounded, color: ac.gold),
              tooltip: 'XP Dashboard',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => XpDashboardPage(user: widget.user))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_off_rounded, size: 40, color: ac.muted),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center,
                      style: AppText.bodySm.copyWith(color: ac.muted)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ]),
              ),
            )
          : (_categories.isEmpty && !_canManage)
          // A blank grid (no tiles at all, and no "+ New section" tile
          // since only lecturer+ can add one) is visually indistinguishable
          // from "nothing happened when I tapped Tests" -- spell out why.
          ? RefreshIndicator(
              onRefresh: _load,
              child: ListView(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                  child: Column(children: [
                    Icon(Icons.inbox_outlined, size: 40, color: ac.muted),
                    const SizedBox(height: 12),
                    Text('No test categories yet', style: AppText.title.copyWith(fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('Ask a teacher or admin to add one, or pull down to check again.',
                        style: AppText.bodySm.copyWith(color: ac.txt2), textAlign: TextAlign.center),
                  ]),
                ),
              ]),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _categories.length + (_canManage ? 1 : 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.92,
                ),
                itemBuilder: (context, i) {
                  if (i >= _categories.length) return _addTile();
                  final c = _categories[i];
                  final count = _counts[c.name] ?? 0;
                  return _categoryTile(c, count);
                },
              ),
            ),
    );
  }

  Widget _categoryTile(QuizCategory c, int count) {
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TestsSubjectPickerPage(user: widget.user, category: c.name)));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              HierarchyAvatar(label: c.name, icon: c.emoji, imageUrl: c.imageUrl, size: 48),
              const Spacer(),
              Text(c.name, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$count quiz${count == 1 ? '' : 'zes'}', style: AppText.caption.copyWith(color: ac.txt2)),
            ]),
            if (_canManage)
              Positioned(
                top: 0, right: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _editCategoryLook(c),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: ac.surf2, shape: BoxShape.circle, border: Border.all(color: ac.bdr2)),
                    child: Icon(Icons.edit_rounded, size: 14, color: ac.txt2),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _addTile() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: _addCategory,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr, style: BorderStyle.solid),
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_circle_outline_rounded, color: ac.primary, size: 28),
            const SizedBox(height: 6),
            Text('New section', style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

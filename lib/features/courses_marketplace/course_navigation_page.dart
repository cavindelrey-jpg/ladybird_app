// lib/features/courses_marketplace/course_navigation_page.dart
// Top-level entry point for browsing Courses as a real academic
// curriculum: Academic Section > Subject > Topic > Lessons. Shows the
// education-level tree's top tier (Primary School / Junior Secondary
// School / Senior Secondary School / High School / Undergraduate, seeded
// by AcademicSectionRepository.sectionsOnce, plus whatever sections an
// admin has added since) as icon-sized tiles, each with a real photo if
// one's been set or a generated letter-avatar otherwise (see
// HierarchyAvatar — an image always wins over the letter when both could
// apply). Tapping a tile drills into CourseBrowsePage scoped to that
// section.
//
// This is the SAME section list (same Firestore docs, same photos) the
// Quiz system's QuizCategoriesPage shows — see
// repositories/academic_section_repository.dart's header for why one
// shared list beats a separate near-identical one per feature. The
// section-tile UI itself mirrors QuizCategoriesPage closely on purpose:
// two independent instances of the exact same interaction pattern would
// only confuse users switching between Courses and Quizzes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/academic_section.dart';
import '../../repositories/academic_section_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../testing/quiz_icon_editor.dart';
import 'course_browse_page.dart';

class CourseNavigationPage extends StatefulWidget {
  final AppUser? currentUser;
  const CourseNavigationPage({super.key, this.currentUser});

  @override
  State<CourseNavigationPage> createState() => _CourseNavigationPageState();
}

class _CourseNavigationPageState extends State<CourseNavigationPage> {
  List<AcademicSection> _sections = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  /// Managing what a section looks like (or adding a new one) is an
  /// authoring action — same gate the Quiz section grid and the course
  /// composer already use.
  bool get _canManage => widget.currentUser?.canUploadContent ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      AcademicSectionRepository.instance.sectionsOnce(),
      PublicCourseRepository.instance.courseCountsBySection(),
    ]);
    if (!mounted) return;
    setState(() {
      _sections = results[0] as List<AcademicSection>;
      _counts = results[1] as Map<String, int>;
      _loading = false;
    });
  }

  Future<void> _addSection() async {
    final name = await showAddQuizCategoryDialog(context);
    if (name == null || name.trim().isEmpty) return;
    final order = _sections.isEmpty
        ? 0.0
        : (_sections.map((s) => s.order).reduce((a, b) => a > b ? a : b) + 100);
    final result = await AcademicSectionRepository.instance.addSection(name: name, order: order);
    if (!mounted) return;
    if (result case Failure(:final message)) {
      showToast(context, message, isError: true);
      return;
    }
    HapticFeedback.selectionClick();
    _load();
  }

  Future<void> _editSectionLook(AcademicSection s) async {
    await showQuizIconEditor(
      context,
      label: s.name,
      currentEmoji: s.emoji,
      currentImageUrl: s.imageUrl,
      onSave: (emoji, image) async {
        String imageUrl = s.imageUrl;
        if (image != null) {
          final upload =
              await AcademicSectionRepository.instance.uploadSectionImage(sectionId: s.id, imageFile: image);
          if (upload is Success<String>) imageUrl = upload.value;
        } else {
          imageUrl = '';
        }
        await AcademicSectionRepository.instance.updateSectionIcon(s.id, emoji: emoji, imageUrl: imageUrl);
      },
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Course Navigation', style: AppText.title),
      ),
      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _sections.length + (_canManage ? 1 : 0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, i) {
                    if (i >= _sections.length) return _addTile(ac);
                    final s = _sections[i];
                    return _sectionTile(context, ac, s, _counts[s.name] ?? 0);
                  },
                ),
              ),
      ),
    );
  }

  Widget _sectionTile(BuildContext context, AppColors ac, AcademicSection s, int count) {
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CourseBrowsePage(section: s.name, currentUser: widget.currentUser)));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              HierarchyAvatar(label: s.name, icon: s.emoji, imageUrl: s.imageUrl, size: 48),
              const Spacer(),
              Text(s.name, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$count course${count == 1 ? '' : 's'}', style: AppText.caption.copyWith(color: ac.txt2)),
            ]),
            if (_canManage)
              Positioned(
                top: 0, right: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _editSectionLook(s),
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

  Widget _addTile(AppColors ac) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: _addSection,
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

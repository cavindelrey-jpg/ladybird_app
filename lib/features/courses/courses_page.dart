// lib/features/courses/courses_page.dart
// All roles see the course catalogue. Students enroll/drop. Admins create/delete.
//
// Design pass + the missing piece: cards are now tappable, opening the new
// CourseDetailPage (description, lecturer, live enrollment count, edit).
// Previously a course card did nothing when tapped — enroll/drop/delete
// were the only actions, with no way to actually read about a course.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../repositories/course_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'course_detail_page.dart';

class CoursesPage extends StatelessWidget {
  final AppUser user;
  const CoursesPage({super.key, required this.user});

  String get _sid => user.schoolId ?? '';
  bool get _isIndependent => (user.schoolId ?? '').isEmpty;

  @override
  Widget build(BuildContext context) {
    // Independent (non-school-linked) users have no schoolId, so there's no
    // school-scoped course catalogue for them — querying with an empty
    // schoolId would hit an invalid Firestore path. Show an explanatory
    // state instead of a broken/empty list. Point them at the Content
    // Library, which is where independent-user academic content lives.
    if (_isIndependent) {
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          title: Text('Courses', style: AppText.title),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.school_outlined, size: 48, color: C.muted),
              const SizedBox(height: 12),
              Text('Courses are organized by school',
                  style: AppText.title.copyWith(fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                "Your account isn't linked to a school, so there's no course "
                'catalogue to show yet. Check the Content Library for notes, '
                'past papers, and videos instead.',
                style: AppText.bodySm,
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      );
    }

    final stream = user.isLecturer
        ? CourseRepository.instance.watchForLecturer(_sid, user.id)
        : CourseRepository.instance.watchAll(_sid);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Courses', style: AppText.title),
        automaticallyImplyLeading: false,
        actions: user.canManageSchool
            ? [IconButton(icon: const Icon(Icons.add_rounded),
                onPressed: () => _showCreate(context))]
            : null,
      ),
      body: StreamBuilder<List<Course>>(
        stream: stream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _CourseListSkeleton();
          }
          final courses = snap.data ?? [];
          if (courses.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.school_outlined, size: 48, color: C.muted),
              const SizedBox(height: 12),
              Text('No courses available', style: AppText.bodySm),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: courses.length,
            itemBuilder: (_, i) =>
                _CourseCard(course: courses[i], user: user, sid: _sid),
          );
        },
      ),
    );
  }

  void _showCreate(BuildContext ctx) {
    final codeC = TextEditingController();
    final nameC = TextEditingController();
    final descC = TextEditingController();
    final credC = TextEditingController(text: '3');
    final grpC  = TextEditingController();
    bool saving  = false;
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (dCtx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(dCtx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Create Course', style: AppText.title.copyWith(fontSize: 16)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: codeC,
                decoration: const InputDecoration(labelText: 'Course Code'))),
            const SizedBox(width: 10),
            SizedBox(width: 72, child: TextField(controller: credC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Credits'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: nameC,
              decoration: const InputDecoration(labelText: 'Course Name *')),
          const SizedBox(height: 10),
          TextField(controller: descC, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 10),
          TextField(controller: grpC,
              decoration: const InputDecoration(labelText: 'Class Group (optional)')),
          const SizedBox(height: 16),
          PrimaryBtn(label: 'Create Course', loading: saving, onTap: () async {
            if (nameC.text.trim().isEmpty) return;
            HapticFeedback.mediumImpact();
            setM(() => saving = true);
            final c = Course(
              id: '', schoolId: _sid, code: codeC.text.trim(),
              name: nameC.text.trim(),
              description: descC.text.trim().isEmpty ? null : descC.text.trim(),
              lecturerId: user.id, lecturerName: user.name,
              credits: int.tryParse(credC.text) ?? 3,
              classGroup: grpC.text.trim().isEmpty ? null : grpC.text.trim(),
              currentYear: DateTime.now().year,
            );
            final r = await CourseRepository.instance.create(c);
            if (!dCtx.mounted) return;
            if (r is Failure) {
              // Previously this fell through to Navigator.pop() either way,
              // so a failed save silently closed the sheet with no error
              // and the typed course was lost. Now it stays open, shows
              // what actually went wrong, and lets you retry.
              setM(() => saving = false);
              showToast(dCtx, (r as Failure).message, isError: true);
              return;
            }
            Navigator.pop(dCtx);
            if (ctx.mounted) showToast(ctx, '✅ Course created');
          }),
        ])),
      )),
    );
  }
}

/// Card-shaped skeleton matching the loaded list's silhouette.
class _CourseListSkeleton extends StatelessWidget {
  const _CourseListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: C.surf, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bdr)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShimmerLine(width: 60, height: 12),
          SizedBox(height: 8),
          ShimmerLine(height: 15),
          SizedBox(height: 6),
          ShimmerLine(width: 100, height: 12),
        ]),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final AppUser user;
  final String sid;
  const _CourseCard({required this.course, required this.user, required this.sid});

  static const _palette = [C.primary, C.grn, C.pur, C.org, C.blu, C.red];
  Color get _accent => _palette[course.name.hashCode.abs() % _palette.length];
  bool get _enrolled => user.courseIds.contains(course.id);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: C.surf, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.bdr)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => CourseDetailPage(course: course, user: user)));
          },
          child: Column(children: [
            Container(height: 5, color: _accent),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(course.code.isEmpty ? 'GEN' : course.code,
                          style: AppText.label.copyWith(fontSize: 10, color: _accent, letterSpacing: 0.2))),
                    const SizedBox(width: 8),
                    Text('${course.credits} cr.', style: AppText.caption.copyWith(fontSize: 11)),
                  ]),
                  const SizedBox(height: 4),
                  Text(course.name, style: AppText.title.copyWith(fontSize: 14)),
                  Text(course.lecturerName, style: AppText.bodySm.copyWith(fontSize: 12)),
                  if (course.classGroup != null)
                    Text(course.classGroup!, style: AppText.caption.copyWith(fontSize: 11)),
                ])),
                const SizedBox(width: 10),
                if (user.isStudent)
                  _enrolled
                      ? OutlinedButton(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            await CourseRepository.instance.unenrollStudent(sid, course.id, user.id);
                            if (context.mounted) showToast(context, 'Unenrolled');
                          },
                          style: OutlinedButton.styleFrom(
                              foregroundColor: C.red, side: const BorderSide(color: C.red)),
                          child: const Text('Drop'))
                      : ElevatedButton(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            await CourseRepository.instance.enrollStudent(sid, course.id, user.id);
                            if (context.mounted) showToast(context, '✅ Enrolled in ${course.name}');
                          },
                          child: const Text('Enroll')),
                if (user.canManageSchool)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: C.muted),
                    onPressed: () async {
                      HapticFeedback.heavyImpact();
                      await CourseRepository.instance.delete(sid, course.id);
                      if (context.mounted) showToast(context, 'Course deleted');
                    },
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

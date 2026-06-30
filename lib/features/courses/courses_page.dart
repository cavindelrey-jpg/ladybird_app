// lib/features/courses/courses_page.dart
// All roles see the course catalogue. Students enroll/drop. Admins create/delete.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/course_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class CoursesPage extends StatelessWidget {
  final AppUser user;
  const CoursesPage({super.key, required this.user});

  String get _sid => user.schoolId ?? '';

  @override
  Widget build(BuildContext context) {
    final stream = user.isLecturer
        ? CourseRepository.instance.watchForLecturer(_sid, user.id)
        : CourseRepository.instance.watchAll(_sid);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Courses', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
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
            return const Center(child: CircularProgressIndicator());
          }
          final courses = snap.data ?? [];
          if (courses.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.school_outlined, size: 48, color: C.muted),
              const SizedBox(height: 12),
              Text('No courses available', style: GoogleFonts.inter(color: C.muted)),
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
          Text('Create Course',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
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
            Navigator.pop(dCtx);
            if (r is Success && ctx.mounted) showToast(ctx, '✅ Course created');
          }),
        ])),
      )),
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
      child: Column(children: [
        Container(height: 5, decoration: BoxDecoration(
            color: _accent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
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
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _accent))),
                const SizedBox(width: 8),
                Text('${course.credits} cr.',
                    style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
              ]),
              const SizedBox(height: 4),
              Text(course.name,
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: C.txt)),
              Text(course.lecturerName,
                  style: GoogleFonts.inter(fontSize: 12, color: C.txt2)),
              if (course.classGroup != null)
                Text(course.classGroup!,
                    style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
            ])),
            const SizedBox(width: 10),
            if (user.isStudent)
              _enrolled
                  ? OutlinedButton(
                      onPressed: () async {
                        await CourseRepository.instance.unenrollStudent(sid, course.id, user.id);
                        if (context.mounted) showToast(context, 'Unenrolled');
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: C.red, side: const BorderSide(color: C.red)),
                      child: const Text('Drop'))
                  : ElevatedButton(
                      onPressed: () async {
                        await CourseRepository.instance.enrollStudent(sid, course.id, user.id);
                        if (context.mounted) showToast(context, '✅ Enrolled in ${course.name}');
                      },
                      child: const Text('Enroll')),
            if (user.canManageSchool)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: C.muted),
                onPressed: () async {
                  await CourseRepository.instance.delete(sid, course.id);
                  if (context.mounted) showToast(context, 'Course deleted');
                },
              ),
          ]),
        ),
      ]),
    );
  }
}

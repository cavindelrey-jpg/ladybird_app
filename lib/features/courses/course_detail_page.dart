// lib/features/courses/course_detail_page.dart
// The missing piece for Courses: tapping a course card previously did
// nothing. This is a real detail view — description, lecturer, class
// info, live enrollment count — plus edit (admin/owning lecturer) and
// enroll/drop (students), matching the same actions the list already
// supported but with room to actually read about the course first.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../repositories/course_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

const _kPalette = [C.primary, C.grn, C.pur, C.org, C.blu, C.red];

class CourseDetailPage extends StatelessWidget {
  final Course course;
  final AppUser user;
  const CourseDetailPage({super.key, required this.course, required this.user});

  Color get _accent => _kPalette[course.name.hashCode.abs() % _kPalette.length];

  bool get _canEdit => user.canManageSchool || course.lecturerId == user.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: AppBackground(child: StreamBuilder<Course?>(
        // Live — if a lecturer edits this course while a student has it
        // open, the change appears without a manual refresh.
        stream: CourseRepository.instance.watchOne(course.schoolId, course.id),
        initialData: course,
        builder: (context, snap) {
          final c = snap.data ?? course;
          final enrolled = user.courseIds.contains(c.id);

          return CustomScrollView(slivers: [
            SliverAppBar(
              backgroundColor: C.bg,
              elevation: 0,
              pinned: true,
              iconTheme: const IconThemeData(color: C.txt),
              actions: [
                if (_canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: C.txt),
                    onPressed: () => _showEdit(context, c),
                  ),
                if (user.canManageSchool)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: C.red),
                    onPressed: () => _confirmDelete(context, c),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(c.code.isEmpty ? 'GEN' : c.code,
                          style: AppText.label.copyWith(fontSize: 12, color: _accent, letterSpacing: 0.4)),
                    ),
                    const SizedBox(width: 10),
                    Text('${c.credits} credits', style: AppText.caption.copyWith(fontSize: 12)),
                    if (c.semester != null) ...[
                      const SizedBox(width: 10),
                      Text('· ${c.semester}', style: AppText.caption.copyWith(fontSize: 12)),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  Text(c.name, style: AppText.h1),
                  const SizedBox(height: 10),
                  Row(children: [
                    UserAvatar(
                      initials: c.lecturerName.isEmpty ? '?' : c.lecturerName[0].toUpperCase(),
                      radius: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(c.lecturerName, style: AppText.subtitle.copyWith(color: C.txt)),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    _InfoChip(icon: Icons.calendar_today_outlined, label: '${c.currentYear}'),
                    if (c.classGroup != null) ...[
                      const SizedBox(width: 8),
                      _InfoChip(icon: Icons.groups_outlined, label: c.classGroup!),
                    ],
                    const SizedBox(width: 8),
                    StreamBuilder<int>(
                      stream: CourseRepository.instance.watchEnrollmentCount(c.id),
                      builder: (context, countSnap) => _InfoChip(
                        icon: Icons.person_outline_rounded,
                        label: '${countSnap.data ?? 0} enrolled',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  if ((c.description ?? '').isNotEmpty) ...[
                    Text('About this course', style: AppText.title.copyWith(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(c.description!, style: AppText.body.copyWith(fontSize: 14.5)),
                    const SizedBox(height: 28),
                  ],
                  if (user.isStudent)
                    SizedBox(
                      width: double.infinity,
                      child: enrolled
                          ? SecondaryBtn(
                              label: 'Drop Course',
                              onTap: () => _unenroll(context, c),
                            )
                          : PrimaryBtn(
                              label: 'Enroll in this Course',
                              onTap: () => _enroll(context, c),
                            ),
                    ),
                ]),
              ),
            ),
          ]);
        },
      )),
    );
  }

  Future<void> _enroll(BuildContext context, Course c) async {
    HapticFeedback.mediumImpact();
    await CourseRepository.instance.enrollStudent(c.schoolId, c.id, user.id);
    if (context.mounted) showToast(context, '✅ Enrolled in ${c.name}');
  }

  Future<void> _unenroll(BuildContext context, Course c) async {
    HapticFeedback.lightImpact();
    await CourseRepository.instance.unenrollStudent(c.schoolId, c.id, user.id);
    if (context.mounted) showToast(context, 'Dropped ${c.name}');
  }

  void _confirmDelete(BuildContext context, Course c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete course?'),
        content: Text('This removes "${c.name}" for everyone. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              await CourseRepository.instance.delete(c.schoolId, c.id);
              if (context.mounted) {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // detail page
                showToast(context, 'Course deleted');
              }
            },
            child: const Text('Delete', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
  }

  void _showEdit(BuildContext context, Course c) {
    final nameC = TextEditingController(text: c.name);
    final codeC = TextEditingController(text: c.code);
    final descC = TextEditingController(text: c.description ?? '');
    final credC = TextEditingController(text: '${c.credits}');
    final grpC = TextEditingController(text: c.classGroup ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (dCtx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(dCtx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Edit Course', style: AppText.title.copyWith(fontSize: 16)),
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
          TextField(controller: descC, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 10),
          TextField(controller: grpC,
              decoration: const InputDecoration(labelText: 'Class Group (optional)')),
          const SizedBox(height: 16),
          PrimaryBtn(label: 'Save Changes', loading: saving, onTap: () async {
            if (nameC.text.trim().isEmpty) return;
            HapticFeedback.mediumImpact();
            setM(() => saving = true);
            final updated = Course(
              id: c.id, schoolId: c.schoolId, departmentId: c.departmentId,
              code: codeC.text.trim(), name: nameC.text.trim(),
              description: descC.text.trim().isEmpty ? null : descC.text.trim(),
              lecturerId: c.lecturerId, lecturerName: c.lecturerName,
              credits: int.tryParse(credC.text) ?? c.credits,
              classGroup: grpC.text.trim().isEmpty ? null : grpC.text.trim(),
              currentYear: c.currentYear, semester: c.semester,
            );
            final r = await CourseRepository.instance.update(updated);
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
            if (r is Success && context.mounted) showToast(context, '✅ Course updated');
          }),
        ])),
      )),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: C.surf3, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: C.txt2),
        const SizedBox(width: 5),
        Text(label, style: AppText.caption.copyWith(fontSize: 11.5, color: C.txt2)),
      ]),
    );
  }
}

// lib/features/school/parent_dashboard_page.dart
// Spec item 5: a parent must be able to open the app and see their
// linked student's timetable/marks/homework -- and NOT see anything
// belonging to an unrelated student. Deliberately a separate, read-only
// page rather than reusing UniversalHomePage/MarksPage/etc. with the
// child's AppUser substituted in: those pages call
// AuthService.recordDailyActivity and expose action buttons (Add
// Session, redeem/spend XP, post content...) that must never fire on
// behalf of a child the parent is only viewing. Every read below goes
// through the SAME repositories/tables the student's own screens use
// (SchoolMarksRepository, HomeworkRepository, SchoolTimetableRepository)
// scoped by the child's ids from ParentLinkRepository -- real data, not
// a parallel mock -- gated server-side by the parent-bypass clauses
// added to those tables' RLS in supabase/migrations/
// 20260904000006_parent_student_linking.sql, not merely by this screen
// choosing not to query other students.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/homework.dart';
import '../../models/school_mark.dart';
import '../../models/school_timetable_slot.dart';
import '../../repositories/parent_link_repository.dart';
import '../../repositories/homework_repository.dart';
import '../../repositories/school_marks_repository.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class ParentDashboardPage extends StatefulWidget {
  final AppUser user;
  const ParentDashboardPage({super.key, required this.user});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  late Future<List<LinkedStudent>> _linkedFuture;
  LinkedStudent? _selected;

  @override
  void initState() {
    super.initState();
    _linkedFuture = ParentLinkRepository.instance.getLinkedStudents(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('My Children', style: AppText.title),
      ),
      body: AppBackground(child: FutureBuilder<List<LinkedStudent>>(
        future: _linkedFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 400));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final students = snap.data ?? const <LinkedStudent>[];
          if (students.isEmpty) {
            return const EmptyState(
              icon: Icons.family_restroom_outlined,
              title: 'No linked student yet',
              subtitle: "Redeem the parent voucher your child's school gave you "
                  'to link your account here.',
            );
          }
          _selected ??= students.first;
          return Column(children: [
            if (students.length > 1) _studentPicker(ac, students),
            Expanded(child: _StudentDetail(key: ValueKey(_selected!.studentId), student: _selected!)),
          ]);
        },
      )),
    );
  }

  Widget _studentPicker(AppColors ac, List<LinkedStudent> students) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: students.map((s) {
          final sel = s.studentId == _selected!.studentId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s.studentName),
              selected: sel,
              onSelected: (_) => setState(() => _selected = s),
              selectedColor: ac.primary,
              labelStyle: TextStyle(color: sel ? Colors.white : ac.txt),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StudentDetail extends StatelessWidget {
  final LinkedStudent student;
  const _StudentDetail({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = student.institutionId;
    final classLevel = student.classLevel;
    if (schoolId == null || schoolId.isEmpty || classLevel.isEmpty) {
      return const EmptyState(
        icon: Icons.info_outline_rounded,
        title: 'Not enrolled in a class yet',
        subtitle: 'This student has no school/class assigned yet.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Text(student.studentName, style: AppText.h1.copyWith(fontSize: 18)),
        Text(classLevel, style: AppText.bodySm.copyWith(color: ac.muted)),
        const SizedBox(height: 16),
        Text('Today\'s Timetable', style: AppText.h2.copyWith(fontSize: 15)),
        const SizedBox(height: 8),
        StreamBuilder<List<SchoolTimetableSlot>>(
          stream: SchoolTimetableRepository.instance.watchTodayForClass(schoolId, classLevel),
          builder: (context, snap) {
            final slots = snap.data ?? const <SchoolTimetableSlot>[];
            if (snap.connectionState == ConnectionState.waiting) return const ShimmerBlock(height: 80);
            if (slots.isEmpty) return _emptyRow(ac, 'No timetable slots for today.');
            return Column(children: slots.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ACard(
                child: Row(children: [
                  Container(width: 4, height: 32, decoration: BoxDecoration(color: ac.gold, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.subject, style: AppText.title.copyWith(fontSize: 14)),
                    Text('${s.startTime} – ${s.endTime}', style: AppText.bodySm.copyWith(fontSize: 11.5, color: ac.muted)),
                  ])),
                ]),
              ),
            )).toList());
          },
        ),
        const SizedBox(height: 20),
        Text('Homework', style: AppText.h2.copyWith(fontSize: 15)),
        const SizedBox(height: 8),
        StreamBuilder<List<Homework>>(
          stream: HomeworkRepository.instance.watchForClass(schoolId, classLevel),
          builder: (context, snap) {
            final items = snap.data ?? const <Homework>[];
            if (snap.connectionState == ConnectionState.waiting) return const ShimmerBlock(height: 80);
            if (items.isEmpty) return _emptyRow(ac, 'No homework assigned right now.');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items.take(10).map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ACard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.title, style: AppText.title.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${h.subject} · Due ${_fmtDate(h.dueAt)}', style: AppText.bodySm.copyWith(fontSize: 11.5, color: ac.muted)),
                ]),
              ),
            )).toList());
          },
        ),
        const SizedBox(height: 20),
        Text('Recent Marks', style: AppText.h2.copyWith(fontSize: 15)),
        const SizedBox(height: 8),
        FutureBuilder<List<SchoolMark>>(
          future: SchoolMarksRepository.instance.allMarksOnce(student.studentId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const ShimmerBlock(height: 80);
            if (snap.hasError) return ErrorView(message: snap.error.toString());
            final marks = snap.data ?? const <SchoolMark>[];
            if (marks.isEmpty) return _emptyRow(ac, 'No marks recorded yet.');
            final sorted = [...marks]..sort((a, b) => (b.gradedAt ?? DateTime(0)).compareTo(a.gradedAt ?? DateTime(0)));
            return Column(children: sorted.take(10).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ACard(
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.subject, style: AppText.title.copyWith(fontSize: 14)),
                    Text(m.sequence.label, style: AppText.bodySm.copyWith(fontSize: 11.5, color: ac.muted)),
                  ])),
                  // Never round a child's mark: 6.5 used to read as "7/20".
                  Text('${formatMark(m.score)}/${formatMark(m.maxScore)}',
                      style: AppText.title.copyWith(fontSize: 15, color: ac.primary)),
                ]),
              ),
            )).toList());
          },
        ),
      ],
    );
  }

  Widget _emptyRow(AppColors ac, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: AppText.bodySm.copyWith(color: ac.muted)),
      );

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
}

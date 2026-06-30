// lib/features/attendance/attendance_page.dart
// Lecturers: pick course → pick date → mark P/A/L/E per student.
// Students: see attendance rate per course.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/course_repository.dart';
import '../../core/constants.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class AttendancePage extends StatelessWidget {
  final AppUser user;
  const AttendancePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.isLecturer || user.canManageSchool) {
      return _LecturerView(user: user);
    }
    return _StudentView(user: user);
  }
}

// ── Lecturer ──────────────────────────────────────────────

class _LecturerView extends StatefulWidget {
  final AppUser user;
  const _LecturerView({required this.user});
  @override State<_LecturerView> createState() => _LecturerViewState();
}

class _LecturerViewState extends State<_LecturerView> {
  String get _sid => widget.user.schoolId ?? '';
  List<Course> _courses = [];
  Course? _course;
  DateTime _date = DateTime.now();
  List<AppUser> _students = [];
  Map<String, AttendanceStatus> _marks = {};
  bool _loading = false, _saving = false;

  @override
  void initState() { super.initState(); _loadCourses(); }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    final list = await CourseRepository.instance.watchForLecturer(_sid, widget.user.id).first;
    setState(() { _courses = list; _loading = false; });
  }

  Future<void> _loadStudents() async {
    if (_course == null) return;
    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .where('schoolId', isEqualTo: _sid)
        .where('courseIds', arrayContains: _course!.id)
        .where('role', isEqualTo: UserRole.student.name)
        .get();
    final students = snap.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList();
    final existing = await AttendanceRepository.instance.getForDate(
        schoolId: _sid, courseId: _course!.id, date: _date);
    final em = {for (final r in existing) r.studentId: r.status};
    setState(() {
      _students = students;
      _marks = {for (final s in students) s.id: em[s.id] ?? AttendanceStatus.present};
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_course == null || _students.isEmpty) return;
    setState(() => _saving = true);
    final records = _marks.entries.map((e) {
      final s = _students.firstWhere((u) => u.id == e.key);
      return AttendanceRecord(
        id: '', schoolId: _sid, courseId: _course!.id,
        studentId: e.key, studentName: s.name,
        date: _date, status: e.value, markedById: widget.user.id,
      );
    }).toList();
    final r = await AttendanceRepository.instance.markBatch(schoolId: _sid, records: records);
    setState(() => _saving = false);
    if (!mounted) return;
    if (r is Success) showToast(context, '✅ Attendance saved');
    else showToast(context, '❌ ${(r as Failure).message}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Mark Attendance', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: _students.isNotEmpty
            ? [TextButton(onPressed: _saving ? null : _save,
                child: Text('Save', style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700, color: C.primary)))]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(color: C.surf, padding: const EdgeInsets.all(16), child: Column(children: [
                DropdownButtonFormField<Course>(
                  value: _course,
                  decoration: const InputDecoration(labelText: 'Course'),
                  items: _courses.map((c) =>
                      DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (c) {
                    setState(() { _course = c; _students = []; });
                    _loadStudents();
                  },
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final p = await showDatePicker(context: context,
                        initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (p != null) { setState(() => _date = p); _loadStudents(); }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: C.bg,
                        borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bdr)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: C.primary),
                      const SizedBox(width: 8),
                      Text('${_date.day}/${_date.month}/${_date.year}',
                          style: GoogleFonts.inter(fontSize: 14, color: C.txt)),
                      const Spacer(),
                      const Icon(Icons.edit_outlined, size: 14, color: C.muted),
                    ]),
                  ),
                ),
              ])),
              Expanded(child: _students.isEmpty
                  ? Center(child: Text(
                      _course == null ? 'Select a course to begin' : 'No enrolled students found',
                      style: GoogleFonts.inter(color: C.muted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      itemBuilder: (_, i) => _AttRow(
                        student: _students[i],
                        status: _marks[_students[i].id] ?? AttendanceStatus.present,
                        onChanged: (v) => setState(() => _marks[_students[i].id] = v),
                      ))),
            ]),
    );
  }
}

class _AttRow extends StatelessWidget {
  final AppUser student;
  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;
  const _AttRow({required this.student, required this.status, required this.onChanged});

  static Color _col(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present: return C.grn;
      case AttendanceStatus.absent:  return C.red;
      case AttendanceStatus.late:    return C.org;
      case AttendanceStatus.excused: return C.blu;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
      child: Row(children: [
        CircleAvatar(backgroundColor: C.primaryBg, radius: 18,
            child: Text(student.initials,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.primary))),
        const SizedBox(width: 12),
        Expanded(child: Text(student.name,
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600))),
        Row(children: AttendanceStatus.values.map((s) {
          final sel = s == status;
          return GestureDetector(
            onTap: () => onChanged(s),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: sel ? _col(s) : C.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? _col(s) : C.bdr)),
              child: Text(s.name[0].toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : C.muted)),
            ),
          );
        }).toList()),
      ]),
    );
  }
}

// ── Student ───────────────────────────────────────────────

class _StudentView extends StatefulWidget {
  final AppUser user;
  const _StudentView({required this.user});
  @override State<_StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<_StudentView> {
  List<Course> _courses = [];
  Map<String, AttendanceSummary> _summaries = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final sid     = widget.user.schoolId ?? '';
    final courses = await CourseRepository.instance.getByIds(sid, widget.user.courseIds);
    final sums    = <String, AttendanceSummary>{};
    for (final c in courses) {
      sums[c.id] = await AttendanceRepository.instance.getSummary(
          schoolId: sid, courseId: c.id, studentId: widget.user.id);
    }
    setState(() { _courses = courses; _summaries = sums; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('My Attendance', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(child: Text('Not enrolled in any courses',
                  style: GoogleFonts.inter(color: C.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _courses.length,
                  itemBuilder: (_, i) {
                    final c = _courses[i];
                    final s = _summaries[c.id] ??
                        const AttendanceSummary(total: 0, present: 0, absent: 0, late: 0, excused: 0);
                    return _SummaryCard(course: c, summary: s);
                  }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Course course;
  final AttendanceSummary summary;
  const _SummaryCard({required this.course, required this.summary});

  Color get _rc {
    if (summary.rate >= 0.75) return C.grn;
    if (summary.rate >= 0.5)  return C.org;
    return C.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bdr)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(course.name,
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt)),
          Text(course.code, style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            _chip('${summary.present}', 'Present', C.grn, C.grnb),
            _chip('${summary.absent}', 'Absent', C.red, C.redb),
            _chip('${summary.late}', 'Late', C.org, C.goldp),
          ]),
        ])),
        const SizedBox(width: 16),
        Column(children: [
          Text(summary.rateLabel,
              style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: _rc)),
          Text('Rate', style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
        ]),
      ]),
    );
  }

  Widget _chip(String val, String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text('$val $label',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

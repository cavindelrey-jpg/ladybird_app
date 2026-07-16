// lib/features/assignments/assignments_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/assignment_repository.dart';
import '../../repositories/course_repository.dart';
import '../../core/result.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class AssignmentsPage extends StatelessWidget {
  final AppUser user;
  const AssignmentsPage({super.key, required this.user});

  String get _sid => user.schoolId ?? '';

  @override
  Widget build(BuildContext context) {
    if (user.isLecturer || user.canManageSchool) return _LecView(user: user, sid: _sid);
    return _StuView(user: user, sid: _sid);
  }
}

// ── Lecturer view ─────────────────────────────────────────

class _LecView extends StatelessWidget {
  final AppUser user;
  final String sid;
  const _LecView({required this.user, required this.sid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
          title: Text('Assignments', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          automaticallyImplyLeading: false),
      body: StreamBuilder<List<Assignment>>(
        stream: AssignmentRepository.instance.watchForLecturer(sid, user.id),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            CrashService.instance.recordError(snap.error, snap.stackTrace,
                context: 'AssignmentsPage.watchForLecturer($sid, ${user.id})');
            return ErrorView(message: "Couldn't load assignments — ${snap.error}");
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.assignment_outlined, size: 48, color: C.muted),
              const SizedBox(height: 12),
              Text('No assignments yet', style: GoogleFonts.inter(color: C.muted)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: list.length,
            itemBuilder: (_, i) =>
                _LecCard(a: list[i], user: user, sid: sid),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.gold, foregroundColor: C.navy,
        icon: const Icon(Icons.add),
        label: Text('New', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        onPressed: () => _showCreate(context),
      ),
    );
  }

  void _showCreate(BuildContext ctx) {
    final titleC = TextEditingController();
    final descC  = TextEditingController();
    final maxC   = TextEditingController(text: '20');
    Course? course;
    DateTime due  = DateTime.now().add(const Duration(days: 7));
    bool saving   = false;
    List<Course> courses = [];

    CourseRepository.instance.watchForLecturer(sid, user.id).first.then((c) => courses = c);

    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (dCtx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(dCtx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('New Assignment', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          DropdownButtonFormField<Course>(
            initialValue: course,
            decoration: const InputDecoration(labelText: 'Course *'),
            items: courses.map((c) =>
                DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (c) => setM(() => course = c),
          ),
          const SizedBox(height: 10),
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title *')),
          const SizedBox(height: 10),
          TextField(controller: descC, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Instructions')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: maxC, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Score'))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () async {
                final p = await showDatePicker(context: dCtx,
                    initialDate: due, firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (p != null) setM(() => due = p);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.bg,
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bdr)),
                child: Text('Due: ${due.day}/${due.month}',
                    style: GoogleFonts.inter(fontSize: 13, color: C.txt)),
              ),
            )),
          ]),
          const SizedBox(height: 16),
          PrimaryBtn(label: 'Publish Assignment', loading: saving, onTap: () async {
            if (course == null || titleC.text.trim().isEmpty) return;
            setM(() => saving = true);
            final a = Assignment(
              id: '', schoolId: sid,
              courseId: course!.id, courseName: course!.name,
              title: titleC.text.trim(), description: descC.text.trim(),
              lecturerId: user.id, lecturerName: user.name,
              dueDate: due, maxScore: int.tryParse(maxC.text) ?? 20,
              status: AssignmentStatus.published,
            );
            final r = await AssignmentRepository.instance.create(a);
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
            if (r is Success && ctx.mounted) showToast(ctx, '✅ Assignment published');
          }),
        ])),
      )),
    );
  }
}

class _LecCard extends StatelessWidget {
  final Assignment a;
  final AppUser user;
  final String sid;
  const _LecCard({required this.a, required this.user, required this.sid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: C.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(a.title,
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt))),
          _StatusPill(a.status),
        ]),
        Text(a.courseName, style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(a.isOverdue ? Icons.warning_amber_rounded : Icons.access_time_rounded,
              size: 13, color: a.isOverdue ? C.red : C.muted),
          const SizedBox(width: 4),
          Text(a.isOverdue ? 'Overdue' : 'Due ${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year}',
              style: GoogleFonts.inter(fontSize: 12, color: a.isOverdue ? C.red : C.muted)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => _SubsPage(a: a, sid: sid))),
            child: Text('Submissions',
                style: GoogleFonts.inter(fontSize: 12, color: C.primary, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }
}

class _SubsPage extends StatelessWidget {
  final Assignment a;
  final String sid;
  const _SubsPage({required this.a, required this.sid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(a.title,
          style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700))),
      body: StreamBuilder<List<AssignmentSubmission>>(
        stream: AssignmentRepository.instance.watchSubmissions(sid, a.id),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final subs = snap.data ?? [];
          if (subs.isEmpty) {
            return Center(
                child: Text('No submissions yet', style: GoogleFonts.inter(color: C.muted)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subs.length,
            itemBuilder: (_, i) => _SubCard(sub: subs[i], a: a, sid: sid),
          );
        },
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  final AssignmentSubmission sub;
  final Assignment a;
  final String sid;
  const _SubCard({required this.sub, required this.a, required this.sid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: C.primaryBg, radius: 16,
              child: Text(sub.studentName.isNotEmpty ? sub.studentName[0] : '?',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.primary))),
          const SizedBox(width: 10),
          Expanded(child: Text(sub.studentName,
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700))),
          if (sub.score != null)
            Text('${sub.score}/${a.maxScore}',
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: C.primary)),
        ]),
        if (sub.submissionText != null && sub.submissionText!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(sub.submissionText!,
              style: GoogleFonts.inter(fontSize: 12, color: C.txt2),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        if (sub.status != SubmissionStatus.graded)
          OutlinedButton(
              onPressed: () => _grade(context),
              child: const Text('Grade')),
        if (sub.feedback != null)
          Text('Feedback: ${sub.feedback}',
              style: GoogleFonts.inter(fontSize: 11, color: C.txt2, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  void _grade(BuildContext ctx) {
    final scoreC = TextEditingController(text: sub.score?.toString());
    final fbC    = TextEditingController(text: sub.feedback);
    bool saving  = false;
    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (dCtx, setD) => AlertDialog(
        title: Text('Grade ${sub.studentName}',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: scoreC, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Score (max ${a.maxScore})')),
          const SizedBox(height: 10),
          TextField(controller: fbC, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Feedback')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: saving ? null : () async {
              final score = int.tryParse(scoreC.text);
              if (score == null) return;
              setD(() => saving = true);
              await AssignmentRepository.instance.grade(
                  schoolId: sid, aid: a.id, studentId: sub.studentId,
                  score: score, feedback: fbC.text.trim());
              if (!dCtx.mounted) return;
              Navigator.pop(dCtx);
              if (ctx.mounted) showToast(ctx, '✅ Graded');
            },
            child: const Text('Save')),
        ],
      ),
    ));
  }
}

// ── Student view ──────────────────────────────────────────

class _StuView extends StatelessWidget {
  final AppUser user;
  final String sid;
  const _StuView({required this.user, required this.sid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
          title: Text('My Assignments', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          automaticallyImplyLeading: false),
      body: StreamBuilder<List<Assignment>>(
        stream: AssignmentRepository.instance.watchForStudent(sid, user.courseIds),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            CrashService.instance.recordError(snap.error, snap.stackTrace,
                context: 'AssignmentsPage.watchForStudent($sid, ${user.id})');
            return ErrorView(message: "Couldn't load assignments — ${snap.error}");
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.assignment_outlined, size: 48, color: C.muted),
              const SizedBox(height: 12),
              Text('No assignments yet', style: GoogleFonts.inter(color: C.muted)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: list.length,
            itemBuilder: (_, i) => _StuCard(a: list[i], user: user, sid: sid),
          );
        },
      ),
    );
  }
}

class _StuCard extends StatelessWidget {
  final Assignment a;
  final AppUser user;
  final String sid;
  const _StuCard({required this.a, required this.user, required this.sid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssignmentSubmission?>(
      future: AssignmentRepository.instance.getStudentSubmission(sid, a.id, user.id),
      builder: (ctx, subSnap) {
        final sub = subSnap.data;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: C.surf, borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: a.isOverdue && sub == null ? C.red.withValues(alpha: 0.4) : C.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(a.title,
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt))),
              _StatusPill(a.status),
            ]),
            Text(a.courseName, style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(a.isOverdue ? Icons.warning_amber_rounded : Icons.access_time_rounded,
                  size: 13, color: a.isOverdue ? C.red : C.muted),
              const SizedBox(width: 4),
              Text(
                a.isOverdue ? 'Overdue' : 'Due ${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year}',
                style: GoogleFonts.inter(fontSize: 12, color: a.isOverdue ? C.red : C.muted)),
            ]),
            const SizedBox(height: 10),
            if (sub != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: sub.status == SubmissionStatus.graded ? C.grnb : C.blub,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    sub.status == SubmissionStatus.graded
                        ? Icons.check_circle_outline : Icons.hourglass_empty,
                    size: 14,
                    color: sub.status == SubmissionStatus.graded ? C.grn : C.blu),
                  const SizedBox(width: 6),
                  Text(
                    sub.status == SubmissionStatus.graded
                        ? 'Graded: ${sub.score}/${a.maxScore}'
                        : 'Submitted — awaiting grade',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                        color: sub.status == SubmissionStatus.graded ? C.grn : C.blu)),
                ]),
              ),
              if (sub.feedback != null) ...[
                const SizedBox(height: 4),
                Text('Feedback: ${sub.feedback}',
                    style: GoogleFonts.inter(fontSize: 12, color: C.txt2,
                        fontStyle: FontStyle.italic)),
              ],
            ] else if (!a.isOverdue)
              ElevatedButton(
                  onPressed: () => _submit(context),
                  child: const Text('Submit Work')),
          ]),
        );
      },
    );
  }

  void _submit(BuildContext ctx) {
    final textC = TextEditingController();
    bool saving  = false;
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (dCtx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(dCtx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Submit: ${a.title}',
              style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: textC, maxLines: 6,
              decoration: const InputDecoration(
                  labelText: 'Your answer / notes',
                  hintText: 'Type your response here…')),
          const SizedBox(height: 16),
          PrimaryBtn(label: '📤 Submit', loading: saving, onTap: () async {
            if (textC.text.trim().isEmpty) return;
            setM(() => saving = true);
            final sub = AssignmentSubmission(
              id: '', assignmentId: a.id,
              studentId: user.id, studentName: user.name,
              submissionText: textC.text.trim(),
              submittedAt: DateTime.now(), status: SubmissionStatus.submitted,
            );
            final r = await AssignmentRepository.instance.submit(sid, a.id, sub);
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
            if (r is Success && ctx.mounted) showToast(ctx, '✅ Submitted!');
          }),
        ]),
      )),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final AssignmentStatus s;
  const _StatusPill(this.s);
  @override
  Widget build(BuildContext context) {
    final color = s == AssignmentStatus.published ? C.grn
        : s == AssignmentStatus.closed ? C.muted : C.org;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(s.name,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

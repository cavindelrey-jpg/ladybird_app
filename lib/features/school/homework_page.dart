// lib/features/school/homework_page.dart
// Homework Management (school-operations spec items 3, 5, 6): a teacher
// can only create homework for a (subject, classLevel) pair they're
// actually assigned to -- enforced for real in Postgres RLS, see
// supabase/migrations/20260903160000_homework_and_calendar_events.sql,
// not just hidden client-side. Students get a read-only "My Homework"
// list grouped by due date.
//
// No submission/turn-in tracking exists in this pass (see that migration
// file's own header note) -- "Recently Assigned" shows a real
// due-date-derived Upcoming/Overdue badge, never a fabricated submission
// count like the mockup's "24/28 Submitted". Attachment upload is also
// deferred: the model/table already carry attachmentUrl/attachmentName,
// but wiring FilePicker + storage RLS for a new upload path is left for a
// follow-up pass rather than rushed into this one.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/homework.dart';
import '../../models/test.dart';
import '../../repositories/homework_repository.dart';
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../testing/test_taking_page.dart';
import 'widgets/management_scaffold.dart';
import '../../core/content_quality.dart';
import '../../widgets/application_shell.dart';

class HomeworkPage extends StatefulWidget {
  final AppUser user;
  const HomeworkPage({super.key, required this.user});

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> with SingleTickerProviderStateMixin {
  TabController? _tab;

  @override
  void initState() {
    super.initState();
    if (widget.user.canManageHomework) _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.canManageHomework) return _StudentHomeworkView(user: widget.user);

    final ac = AppColors.of(context);
    final tab = _tab!;
    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Homework',
      currentDestination: AppNavDestination.homework,
      child: Column(
        children: [
          Container(
            color: ac.surf,
            child: TabBar(
              controller: tab,
              labelColor: ac.primary,
              unselectedLabelColor: ac.muted,
              indicatorColor: ac.primary,
              tabs: const [Tab(text: 'Create Homework'), Tab(text: 'Assigned Homework')],
            ),
          ),
          Expanded(
            child: TabBarView(controller: tab, children: [
              _CreateHomeworkTab(user: widget.user),
              _AssignedHomeworkTab(teacherId: widget.user.id),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CreateHomeworkTab extends StatefulWidget {
  final AppUser user;
  const _CreateHomeworkTab({required this.user});

  @override
  State<_CreateHomeworkTab> createState() => _CreateHomeworkTabState();
}

class _CreateHomeworkTabState extends State<_CreateHomeworkTab> {
  String? _classLevel;
  String? _subject;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _materialCtrl = TextEditingController();
  final List<String> _materials = [];
  String _type = 'assignment';
  DateTime _dueAt = DateTime.now().add(const Duration(days: 1));
  bool _notify = true;
  bool _saving = false;
  String? _testId;

  List<String> get _classLevels =>
      widget.user.teachingAssignments.map((a) => a.classLevel).toSet().toList()..sort();

  List<String> _subjectsFor(String classLevel) =>
      widget.user.teachingAssignments.where((a) => a.classLevel == classLevel).map((a) => a.subject).toSet().toList()
        ..sort();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _materialCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate(AppColors ac) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_dueAt));
    if (!mounted) return;
    setState(() => _dueAt = DateTime(date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59));
  }

  Future<void> _save() async {
    final classLevel = _classLevel;
    final subject = _subject;
    if (classLevel == null || subject == null) {
      showToast(context, 'Pick a class and subject first.', isError: true);
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, 'Enter a title.', isError: true);
      return;
    }
    if (_type == 'quiz' && (_testId ?? '').isEmpty) {
      showToast(context, 'Pick a quiz to send as this homework.', isError: true);
      return;
    }
    // Client-side mirror of the real enforcement in the homework RLS
    // policy -- catches the mistake before a wasted round trip, but the
    // policy itself is the actual boundary.
    if (!widget.user.canManageHomeworkFor(subject: subject, classLevel: classLevel)) {
      showToast(context, 'You\'re not assigned to teach $subject in $classLevel.', isError: true);
      return;
    }
    setState(() => _saving = true);
    final homework = Homework(
      id: '',
      schoolId: widget.user.schoolId ?? '',
      classLevel: classLevel,
      subject: subject,
      teacherId: widget.user.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      homeworkType: _type,
      dueAt: _dueAt,
      requiredMaterials: List.of(_materials),
      notify: _notify,
      createdAt: DateTime.now(),
      testId: _type == 'quiz' ? _testId : null,
    );
    final result = await HomeworkRepository.instance.create(homework);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Failure<void>) {
      showToast(context, result.message, isError: true);
    } else {
      showToast(context, 'Homework assigned to $classLevel.');
      _titleCtrl.clear();
      _descCtrl.clear();
      _materialCtrl.clear();
      setState(() {
        _materials.clear();
        _testId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    if (!widget.user.canManageHomework) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('You need a teaching assignment to create homework.',
              textAlign: TextAlign.center, style: GoogleFonts.inter(color: ac.muted)),
        ),
      );
    }

    final classLevels = _classLevels;
    if (_classLevel != null && !classLevels.contains(_classLevel)) _classLevel = null;
    _classLevel ??= classLevels.isNotEmpty ? classLevels.first : null;
    final subjects = _classLevel == null ? const <String>[] : _subjectsFor(_classLevel!);
    if (_subject != null && !subjects.contains(_subject)) _subject = null;
    _subject ??= subjects.isNotEmpty ? subjects.first : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _classLevel,
              decoration: const InputDecoration(labelText: 'Class'),
              items: [for (final c in classLevels) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() {
                _classLevel = v;
                _subject = null;
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [for (final s in subjects) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (v) => setState(() => _subject = v),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDueDate(ac),
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('Due ${_dueAt.day}/${_dueAt.month}/${_dueAt.year} ${TimeOfDay.fromDateTime(_dueAt).format(context)}'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'assignment', child: Text('Assignment')),
                DropdownMenuItem(value: 'reading', child: Text('Reading')),
                DropdownMenuItem(value: 'project', child: Text('Project')),
                DropdownMenuItem(value: 'revision', child: Text('Revision')),
                DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
          ),
        ]),
        if (_type == 'quiz') ...[
          const SizedBox(height: 16),
          Text('Quiz', style: GoogleFonts.inter(fontSize: 12.5, color: ac.muted)),
          const SizedBox(height: 6),
          StreamBuilder<List<Test>>(
            stream: TestRepository.instance.watchTestsByCreator(widget.user.id),
            builder: (context, snap) {
              final all = snap.data ?? const <Test>[];
              final subject = _subject;
              final tests = subject == null ? all : all.where((t) => t.subject == subject).toList();
              if (snap.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (tests.isEmpty) {
                return Text(
                  "You haven't created a quiz for this subject yet — create one in Quizzes first.",
                  style: GoogleFonts.inter(fontSize: 12, color: ac.muted),
                );
              }
              if (_testId != null && !tests.any((t) => t.id == _testId)) _testId = null;
              return DropdownButtonFormField<String>(
                initialValue: _testId,
                decoration: const InputDecoration(labelText: 'Select a quiz to send'),
                items: [for (final t in tests) DropdownMenuItem(value: t.id, child: Text(displayQuizTitle(t)))],
                onChanged: (v) => setState(() => _testId = v),
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        Text('Required Materials (Optional)', style: GoogleFonts.inter(fontSize: 12.5, color: ac.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in _materials)
            Chip(label: Text(m), onDeleted: () => setState(() => _materials.remove(m))),
        ]),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _materialCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Calculator'),
              onSubmitted: (v) {
                if (v.trim().isEmpty) return;
                setState(() {
                  _materials.add(v.trim());
                  _materialCtrl.clear();
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              final v = _materialCtrl.text.trim();
              if (v.isEmpty) return;
              setState(() {
                _materials.add(v);
                _materialCtrl.clear();
              });
            },
          ),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notify students and parents'),
          value: _notify,
          onChanged: (v) => setState(() => _notify = v),
        ),
        const SizedBox(height: 12),
        PrimaryBtn(label: 'Assign Homework', loading: _saving, onTap: _save),
      ],
    );
  }
}

class _AssignedHomeworkTab extends StatelessWidget {
  final String teacherId;
  const _AssignedHomeworkTab({required this.teacherId});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<Homework>>(
      stream: HomeworkRepository.instance.watchByTeacher(teacherId),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return Center(child: Text('You haven\'t assigned any homework yet.', style: GoogleFonts.inter(color: ac.muted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _HomeworkTile(homework: items[i], onDelete: () => HomeworkRepository.instance.delete(items[i].id)),
        );
      },
    );
  }
}

class _StudentHomeworkView extends StatelessWidget {
  final AppUser user;
  const _StudentHomeworkView({required this.user});

  @override
  Widget build(BuildContext context) {
    return ApplicationShell(
      user: user,
      currentTitle: 'Homework',
      currentDestination: AppNavDestination.homework,
      child: StreamBuilder<List<Homework>>(
        stream: HomeworkRepository.instance.watchForClass(user.schoolId ?? '', user.classLevel),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return Center(child: Text('No homework assigned yet.', style: GoogleFonts.inter(color: Colors.grey)));
          }
          final sorted = List.of(items)..sort((a, b) => a.dueAt.compareTo(b.dueAt));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _HomeworkTile(homework: sorted[i], student: user),
          );
        },
      ),
    );
  }
}

class _HomeworkTile extends StatelessWidget {
  final Homework homework;
  final VoidCallback? onDelete;
  /// Set only in the student's own "My Homework" view — enables the
  /// "Take Quiz" action for quiz-type homework (spec item 4B).
  final AppUser? student;
  const _HomeworkTile({required this.homework, this.onDelete, this.student});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final overdue = homework.isOverdue;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(homework.title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 4),
            Text('${homework.classLevel} · ${homework.subject}', style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted)),
            if (homework.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(homework.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
            ],
            const SizedBox(height: 8),
            Text('Due ${homework.dueAt.day}/${homework.dueAt.month}/${homework.dueAt.year}',
                style: GoogleFonts.inter(fontSize: 11, color: ac.muted)),
            if (homework.isQuiz && student != null) ...[
              const SizedBox(height: 10),
              _TakeQuizButton(homework: homework, student: student!),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: overdue ? ac.red.withValues(alpha: 0.12) : ac.primaryBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(overdue ? 'Overdue' : 'Upcoming',
                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: overdue ? ac.red : ac.primary)),
          ),
          if (onDelete != null)
            IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: ac.muted), onPressed: onDelete),
        ]),
      ]),
    );
  }
}

class _TakeQuizButton extends StatefulWidget {
  final Homework homework;
  final AppUser student;
  const _TakeQuizButton({required this.homework, required this.student});

  @override
  State<_TakeQuizButton> createState() => _TakeQuizButtonState();
}

class _TakeQuizButtonState extends State<_TakeQuizButton> {
  late final Future<DateTime?> _effectiveDueAt = HomeworkRepository.instance
      .getEffectiveDueAt(widget.homework.id, widget.student.id);
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    final test = await TestRepository.instance.watchTest(widget.homework.testId!).first;
    if (!mounted) return;
    setState(() => _opening = false);
    if (test == null) {
      showToast(context, 'This quiz is no longer available.', isError: true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TestTakingPage(user: widget.student, test: test, homeworkId: widget.homework.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return FutureBuilder<DateTime?>(
      future: _effectiveDueAt,
      builder: (context, snap) {
        final expired = snap.data != null && DateTime.now().isAfter(snap.data!);
        return SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: expired || _opening ? null : _open,
            icon: Icon(expired ? Icons.lock_clock_outlined : Icons.quiz_outlined, size: 16),
            label: Text(expired ? 'Expired' : 'Take Quiz', style: const TextStyle(fontSize: 12.5)),
            style: OutlinedButton.styleFrom(
              foregroundColor: expired ? ac.muted : ac.primary,
              side: BorderSide(color: expired ? ac.bdr2 : ac.primary),
            ),
          ),
        );
      },
    );
  }
}

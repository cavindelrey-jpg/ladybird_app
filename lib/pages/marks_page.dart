// lib/pages/marks_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../repositories/marks_repository.dart';
import '../core/result.dart';
import '../widgets/widgets.dart';

class MarksPage extends StatelessWidget {
  final AppUser user;
  const MarksPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.isLecturer || user.canManageSchool) return _LecturerMarksView(user: user);
    return _StudentMarksView(user: user);
  }
}

// ── Lecturer view ─────────────────────────────────────────

class _LecturerMarksView extends StatefulWidget {
  final AppUser user;
  const _LecturerMarksView({required this.user});
  @override State<_LecturerMarksView> createState() => _LecturerMarksViewState();
}

class _LecturerMarksViewState extends State<_LecturerMarksView> {
  final _searchCtrl   = TextEditingController();
  final _scoreCtrl    = TextEditingController();
  final _maxCtrl      = TextEditingController(text: '20');
  final _coefCtrl     = TextEditingController(text: '2');
  final _commentCtrl  = TextEditingController();

  List<AppUser> _results = [];
  bool _searching = false;
  AppUser? _selectedStudent;
  String _selectedSequence = MarksRepository.standardSequences.first;
  String? _selectedSubject;
  bool _saving = false;

  String get _sid => widget.user.schoolId ?? '';

  Future<void> _search(String q) async {
    if (q.trim().length < 2) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    final list = await MarksRepository.instance.searchStudents(schoolId: _sid, query: q.trim());
    setState(() { _results = list; _searching = false; });
  }

  Future<void> _save() async {
    if (_selectedStudent == null || _selectedSubject == null) return;
    final score = double.tryParse(_scoreCtrl.text.trim());
    final max   = double.tryParse(_maxCtrl.text.trim());
    final coef  = int.tryParse(_coefCtrl.text.trim());
    if (score == null || max == null || coef == null || max <= 0 || score < 0 || score > max) {
      showToast(context, 'Please enter valid score values.');
      return;
    }
    setState(() => _saving = true);
    final mark = SubjectMark(
      subjectName: _selectedSubject!,
      score: score, maxScore: max, coefficient: coef,
      teacherComment: _commentCtrl.text.trim(),
    );
    final result = await MarksRepository.instance.saveSubjectMark(
      schoolId: _sid, studentId: _selectedStudent!.id,
      sequenceId: _selectedSequence, mark: mark,
    );
    setState(() => _saving = false);
    if (!mounted) return;
    if (result is Success) {
      showToast(context, '✅ Mark saved for ${_selectedStudent!.name}');
      _scoreCtrl.clear(); _commentCtrl.clear();
    } else {
      showToast(context, '❌ ${(result as Failure).message}');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); _scoreCtrl.dispose();
    _maxCtrl.dispose(); _coefCtrl.dispose(); _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Enter Marks', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Label('1. Find Student'),
          const SizedBox(height: 8),
          if (_selectedStudent != null) ...[
            _SelectedStudentChip(
              student: _selectedStudent!,
              onClear: () => setState(() { _selectedStudent = null; _searchCtrl.clear(); _results = []; }),
            ),
            const SizedBox(height: 16),
          ] else ...[
            TextField(
              controller: _searchCtrl, onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by student name…',
                prefixIcon: _searching
                    ? const Padding(padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.search),
              ),
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: C.surf,
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bdr)),
                child: ListView.separated(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                  itemBuilder: (_, i) {
                    final s = _results[i];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: C.primaryBg,
                          child: Text(s.initials,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.primary))),
                      title: Text(s.name, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.classLevel} · ${s.roleLabel}',
                          style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
                      onTap: () => setState(() {
                        _selectedStudent = s; _results = []; _searchCtrl.text = s.name;
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],

          const _Label('2. Sequence'),
          const SizedBox(height: 8),
          SizedBox(height: 38, child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: MarksRepository.standardSequences.length,
            itemBuilder: (_, i) {
              final seq = MarksRepository.standardSequences[i];
              final sel = seq == _selectedSequence;
              return GestureDetector(
                onTap: () => setState(() => _selectedSequence = seq),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: sel ? C.primary : C.surf,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? C.primary : C.bdr)),
                  child: Text(seq, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : C.txt2)),
                ),
              );
            },
          )),
          const SizedBox(height: 20),

          const _Label('3. Subject'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedSubject,
            items: MarksRepository.commonSubjects.map((s) =>
                DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _selectedSubject = v),
            decoration: const InputDecoration(hintText: 'Select subject'),
          ),
          const SizedBox(height: 20),

          const _Label('4. Score'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: _scoreCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Score'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _maxCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Max Score'))),
            const SizedBox(width: 10),
            SizedBox(width: 72, child: TextField(
              controller: _coefCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Coef.'))),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _commentCtrl, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Teacher Comment (optional)')),
          const SizedBox(height: 20),
          PrimaryBtn(label: 'Save Mark', loading: _saving, onTap: _save),
        ]),
      ),
    );
  }
}

// ── Student view ──────────────────────────────────────────

class _StudentMarksView extends StatefulWidget {
  final AppUser user;
  const _StudentMarksView({required this.user});
  @override State<_StudentMarksView> createState() => _StudentMarksViewState();
}

class _StudentMarksViewState extends State<_StudentMarksView> {
  List<String> _seqs = [];
  String? _selSeq;
  bool _loading = true;
  String get _sid => widget.user.schoolId ?? '';

  @override
  void initState() { super.initState(); _loadSeqs(); }

  Future<void> _loadSeqs() async {
    final seqs = await MarksRepository.instance.getAvailableSequences(
        schoolId: _sid, studentId: widget.user.id);
    setState(() {
      _seqs = seqs;
      _selSeq = seqs.isNotEmpty ? seqs.first : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
          title: Text('My Marks', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          automaticallyImplyLeading: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _seqs.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.grade_outlined, size: 48, color: C.muted),
                  const SizedBox(height: 12),
                  Text('No marks recorded yet', style: GoogleFonts.inter(color: C.muted)),
                ]))
              : Column(children: [
                  // Sequence tabs
                  Container(
                    color: C.surf, height: 46,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: _seqs.length,
                      itemBuilder: (_, i) {
                        final seq = _seqs[i];
                        final sel = seq == _selSeq;
                        return GestureDetector(
                          onTap: () => setState(() => _selSeq = seq),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                                color: sel ? C.primary : C.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? C.primary : C.bdr)),
                            child: Text(seq, style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : C.txt2)),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(child: _selSeq == null
                      ? const SizedBox.shrink()
                      : StreamBuilder<SequenceReport?>(
                          stream: MarksRepository.instance.watchSequenceReport(
                              schoolId: _sid, studentId: widget.user.id, sequenceId: _selSeq!),
                          builder: (ctx, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final report = snap.data;
                            if (report == null || report.subjects.isEmpty) {
                              return Center(child: Text('No marks for $_selSeq',
                                  style: GoogleFonts.inter(color: C.muted)));
                            }
                            return ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _AvgCard(average: report.average),
                                const SizedBox(height: 12),
                                ...report.subjects.map((m) => _MarkRow(mark: m)),
                              ],
                            );
                          },
                        )),
                ]),
    );
  }
}

class _AvgCard extends StatelessWidget {
  final double average;
  const _AvgCard({required this.average});

  Color get _color {
    if (average >= 16) return C.grn;
    if (average >= 13) return C.blu;
    if (average >= 10) return C.gold;
    return C.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_color, _color.withValues(alpha: .7)]),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sequence Average', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
          Text(average.toStringAsFixed(2), style: GoogleFonts.sora(
              fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('out of 20', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
        ])),
        Icon(Icons.school_rounded, size: 48, color: Colors.white.withValues(alpha: .3)),
      ]),
    );
  }
}

class _MarkRow extends StatelessWidget {
  final SubjectMark mark;
  const _MarkRow({required this.mark});

  Color get _color {
    final n = mark.outOf20;
    if (n >= 16) return C.grn;
    if (n >= 13) return C.blu;
    if (n >= 10) return C.gold;
    if (n >= 7)  return C.org;
    return C.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mark.subjectName,
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt)),
          Text('${mark.score}/${mark.maxScore} · Coef ${mark.coefficient}',
              style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
          if (mark.teacherComment.isNotEmpty)
            Text(mark.teacherComment,
                style: GoogleFonts.inter(fontSize: 11, color: C.txt2, fontStyle: FontStyle.italic)),
        ])),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(mark.outOf20.toStringAsFixed(1),
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: _color)),
          Text('/20', style: GoogleFonts.inter(fontSize: 10, color: C.muted)),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(mark.grade,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color))),
        ]),
      ]),
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: C.txt2, letterSpacing: .5));
}

class _SelectedStudentChip extends StatelessWidget {
  final AppUser student;
  final VoidCallback onClear;
  const _SelectedStudentChip({required this.student, required this.onClear});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: C.primaryBg,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: C.primary.withValues(alpha: .3))),
      child: Row(children: [
        CircleAvatar(backgroundColor: C.primary, radius: 16,
            child: Text(student.initials,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(student.name, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.primary)),
          Text('${student.classLevel} · ${student.roleLabel}',
              style: GoogleFonts.inter(fontSize: 11, color: C.txt2)),
        ])),
        IconButton(onPressed: onClear, icon: const Icon(Icons.close, size: 16, color: C.primary)),
      ]),
    );
  }
}

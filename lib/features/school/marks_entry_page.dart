// lib/features/school/marks_entry_page.dart
// Staff-only entry point for real marks -- without this, MarksPage would
// have no way to ever show real data. Gated to isSchoolMember + an actual
// teaching assignment/class-master/admin standing, matching the marks/{id}
// Firestore rule's canRecordMarksFor() exactly (architecture brief items
// 22-24: a Physics teacher for Form 5 must not be able to enter Form 4
// Math marks just because they hold the lecturer role). Search reuses
// MessagingRepository.searchUsers (the same name-prefix search already
// used to find people to message) rather than inventing a second
// user-search implementation.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/academic_content.dart' show kAcademicSubjects;
import '../../models/app_user.dart';
import '../../models/school_mark.dart';
import '../../repositories/messaging_repository.dart';
import '../../repositories/school_marks_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

class MarksEntryPage extends StatefulWidget {
  final AppUser staff;
  const MarksEntryPage({super.key, required this.staff});

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedStudent;
  AcademicSequence _sequence = AcademicSequence.t1s1;
  String _subject = kAcademicSubjects.first;
  final _scoreCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  late final _yearCtrl = TextEditingController(text: DateTime.now().year.toString());
  double _maxScore = 20;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _teacherCtrl.text = widget.staff.name;
  }

  @override
  void dispose() {
    _teacherCtrl.dispose();
    _searchCtrl.dispose();
    _scoreCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  /// Subjects the CURRENT student may have marks entered for by this
  /// staff member -- item 22 (own teaching assignments only) plus item
  /// 23 (a class master may enter any subject for their own class,
  /// regardless of what they personally teach). School admins see the
  /// full subject list, matching item 24's school-wide reach.
  List<String> _allowedSubjectsFor(String studentClassLevel) {
    if (widget.staff.hasMinRole(UserRole.schoolAdmin)) return kAcademicSubjects;
    final allowed = <String>{
      if (widget.staff.classMasterOfClass == studentClassLevel && studentClassLevel.isNotEmpty)
        ...kAcademicSubjects,
      for (final a in widget.staff.teachingAssignments)
        if (a.classLevel == studentClassLevel) a.subject,
    };
    return allowed.toList()..sort();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await MessagingRepository.instance.searchUsers(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _save() async {
    final student = _selectedStudent;
    if (student == null) {
      showToast(context, 'Pick a student first.', isError: true);
      return;
    }
    final classLevel = (student['class_level'] as String?) ?? '';
    // Client-side mirror of the real enforcement in firestore.rules'
    // canRecordMarksFor() -- catches the mistake before a wasted round
    // trip, but the rule itself is the actual boundary (item 25: never
    // rely on the UI alone).
    if (!widget.staff.canRecordMarksFor(subject: _subject, classLevel: classLevel)) {
      showToast(context, 'You\'re not assigned to teach $_subject in $classLevel.', isError: true);
      return;
    }
    final score = double.tryParse(_scoreCtrl.text.trim());
    if (score == null) {
      showToast(context, 'Enter a valid numeric score.', isError: true);
      return;
    }
    final mark = SchoolMark(
      id: '',
      schoolId: widget.staff.schoolId ?? '',
      studentId: student['id'] as String,
      classLevel: classLevel,
      subject: _subject,
      teacherName: _teacherCtrl.text.trim(),
      sequence: _sequence,
      academicYear: _yearCtrl.text.trim().isEmpty ? DateTime.now().year.toString() : _yearCtrl.text.trim(),
      score: score,
      maxScore: _maxScore,
      gradedBy: widget.staff.id,
    );
    final result = await SchoolMarksRepository.instance.upsert(mark);
    if (!mounted) return;
    if (result is Failure<void>) {
      showToast(context, result.message, isError: true);
    } else {
      showToast(context, 'Saved ${mark.subject} for ${student['name']}.');
      _scoreCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    if (!widget.staff.canRecordAnyMarks) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: Center(child: Text(
            'You need a teaching assignment or class-master standing to enter marks.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: ac.muted))),
      );
    }

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        title: Text('Enter Marks', style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchCtrl,
            style: GoogleFonts.inter(fontSize: 13, color: ac.txt),
            decoration: InputDecoration(
              hintText: 'Search student by name',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true, fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
            onChanged: _search,
          ),
          if (_searching)
            const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          for (final r in _results)
            ListTile(
              title: Text(r['name'] ?? '', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
              subtitle: Text(r['class_level'] ?? '', style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
              onTap: () => setState(() {
                _selectedStudent = r;
                _results = [];
                _searchCtrl.text = r['name'] ?? '';
                final allowed = _allowedSubjectsFor((r['class_level'] as String?) ?? '');
                _subject = allowed.isNotEmpty ? allowed.first : '';
              }),
            ),
          if (_selectedStudent != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Row(children: [
                Icon(Icons.person_rounded, color: ac.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('${_selectedStudent!['name']} · ${_selectedStudent!['class_level'] ?? 'No class'}',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.primary))),
              ]),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<AcademicSequence>(
              initialValue: _sequence,
              decoration: const InputDecoration(labelText: 'Sequence'),
              items: [for (final s in AcademicSequence.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => setState(() => _sequence = v ?? _sequence),
            ),
            Builder(builder: (_) {
              final allowedSubjects = _allowedSubjectsFor((_selectedStudent!['class_level'] as String?) ?? '');
              if (allowedSubjects.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'You have no teaching assignment for ${_selectedStudent!['class_level'] ?? 'this class'}.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: ac.red),
                  ),
                );
              }
              if (!allowedSubjects.contains(_subject)) _subject = allowedSubjects.first;
              return DropdownButtonFormField<String>(
                initialValue: _subject,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [for (final s in allowedSubjects) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setState(() => _subject = v ?? _subject),
              );
            }),
            TextField(
              controller: _teacherCtrl,
              readOnly: !widget.staff.hasMinRole(UserRole.schoolAdmin),
              decoration: const InputDecoration(labelText: 'Teacher'),
            ),
            TextField(
              controller: _yearCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Academic Year'),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _scoreCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Score'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<double>(
                  initialValue: _maxScore,
                  decoration: const InputDecoration(labelText: 'Out of'),
                  items: const [
                    DropdownMenuItem(value: 20.0, child: Text('20')),
                    DropdownMenuItem(value: 100.0, child: Text('100')),
                  ],
                  onChanged: (v) => setState(() => _maxScore = v ?? 20),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            PrimaryBtn(label: 'Save Mark', onTap: _save),
          ],
        ],
      ),
    );
  }
}

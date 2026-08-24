// lib/features/school/marks_entry_page.dart
// Staff-only entry point for real marks -- without this, MarksPage would
// have no way to ever show real data. Gated to canUploadContent
// (lecturer+), matching the marks/{id} Firestore rule exactly. Search
// reuses MessagingRepository.searchUsers (the same name-prefix search
// already used to find people to message) rather than inventing a
// second user-search implementation.

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
  double _maxScore = 20;
  bool _searching = false;

  @override
  void dispose() {
    _teacherCtrl.dispose();
    _searchCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
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
    final score = double.tryParse(_scoreCtrl.text.trim());
    if (score == null) {
      showToast(context, 'Enter a valid numeric score.', isError: true);
      return;
    }
    final mark = SchoolMark(
      id: '',
      schoolId: widget.staff.schoolId ?? '',
      studentId: student['id'] as String,
      classLevel: (student['classLevel'] as String?) ?? '',
      subject: _subject,
      teacherName: _teacherCtrl.text.trim(),
      sequence: _sequence,
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

    if (!widget.staff.canUploadContent) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: Center(child: Text('Staff access required.', style: GoogleFonts.inter(color: ac.muted))),
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
              subtitle: Text(r['classLevel'] ?? '', style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
              onTap: () => setState(() {
                _selectedStudent = r;
                _results = [];
                _searchCtrl.text = r['name'] ?? '';
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
                Expanded(child: Text('${_selectedStudent!['name']} · ${_selectedStudent!['classLevel'] ?? 'No class'}',
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
            DropdownButtonFormField<String>(
              initialValue: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [for (final s in kAcademicSubjects) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (v) => setState(() => _subject = v ?? _subject),
            ),
            TextField(controller: _teacherCtrl, decoration: const InputDecoration(labelText: 'Teacher')),
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

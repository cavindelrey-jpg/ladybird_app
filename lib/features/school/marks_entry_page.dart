// lib/features/school/marks_entry_page.dart
// Staff marks entry, class-at-a-time. Pick class + subject + sequence and
// the whole class roster appears with any existing marks prefilled; type
// scores down the list (keyboard "next" moves to the following student)
// and save them all in one go.
//
// Replaces the old one-student-at-a-time flow (search a name, pick a
// subject, type one score, save, repeat) which made a 60-student class
// ~240 interactions, and searched students platform-wide rather than
// within the class.
//
// Permission scoping is unchanged: only the (class, subject) pairs
// AppUser.canRecordMarksFor() allows are offered, and the school_marks
// RLS policy + guard trigger enforce the same thing server-side.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/marks_csv.dart';
import '../../core/result.dart';
import '../../models/academic_content.dart' show kAcademicSubjects, kAcademicLevels;
import '../../models/app_user.dart';
import '../../models/school_mark.dart';
import '../../repositories/school_marks_repository.dart';
import '../../services/school_document_export_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'marks_csv_import_page.dart';
import 'student_roster_page.dart';
import 'widgets/management_scaffold.dart';

/// Real classes only -- 'Undergraduate'/'All Levels' are content scopes.
List<String> get _schoolClassLevels => kAcademicLevels.take(7).toList();

/// Classes this staff member can record ANY subject for.
List<String> recordableClassesFor(AppUser staff) {
  if (staff.isSuperAdmin || staff.isAdmin || staff.hasMinRole(UserRole.schoolAdmin)) return _schoolClassLevels;
  final assigned = {
    if ((staff.classMasterOfClass ?? '').isNotEmpty) staff.classMasterOfClass!,
    for (final a in staff.teachingAssignments) a.classLevel,
  }.where((c) => c.isNotEmpty).toList();
  if (assigned.isNotEmpty) {
    return assigned..sort((a, b) => _schoolClassLevels.indexOf(a).compareTo(_schoolClassLevels.indexOf(b)));
  }
  // Fallback: When explicit assignments are not yet configured, all classes are available
  return _schoolClassLevels;
}

/// Subjects this staff member can record in [classLevel].
List<String> recordableSubjectsFor(AppUser staff, String classLevel) {
  final filtered = kAcademicSubjects
      .where((s) => staff.canRecordMarksFor(subject: s, classLevel: classLevel))
      .toList();
  return filtered.isNotEmpty ? filtered : kAcademicSubjects;
}

class MarksEntryPage extends StatefulWidget {
  final AppUser staff;
  final String? initialClass;
  final String? initialSubject;
  final AcademicSequence? initialSequence;
  const MarksEntryPage({
    super.key,
    required this.staff,
    this.initialClass,
    this.initialSubject,
    this.initialSequence,
  });

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  late final List<String> _classes = recordableClassesFor(widget.staff);
  String? _class;
  String? _subject;
  AcademicSequence _sequence = AcademicSequence.t1s1;
  late final _yearCtrl = TextEditingController(text: DateTime.now().year.toString());
  double _maxScore = 20;
  final _filterCtrl = TextEditingController();

  bool _loading = false;
  String? _loadError;
  bool _saving = false;
  List<RosterStudent> _roster = [];
  Map<String, SchoolMark> _existing = {};
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _focus = {};
  final Map<String, String> _saveErrors = {};

  String get _schoolId => widget.staff.schoolId ?? '';
  String get _year => _yearCtrl.text.trim().isEmpty ? DateTime.now().year.toString() : _yearCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    if (widget.initialSequence != null) {
      _sequence = widget.initialSequence!;
    }
    if (_classes.isNotEmpty) {
      _class = _classes.contains(widget.initialClass) ? widget.initialClass : _classes.first;
      final subjects = recordableSubjectsFor(widget.staff, _class!);
      _subject = subjects.contains(widget.initialSubject)
          ? widget.initialSubject
          : (subjects.isNotEmpty ? subjects.first : null);
      _load();
    }
  }

  Future<void> _openCsvImport() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MarksCsvImportPage(staff: widget.staff)),
    );
    if (res != null && mounted) {
      if (res is MarksImportResult) {
        if (res.classLevel != null && _classes.contains(res.classLevel)) {
          _class = res.classLevel;
          final subjects = recordableSubjectsFor(widget.staff, _class!);
          _subject = (res.subject != null && subjects.contains(res.subject))
              ? res.subject
              : (subjects.isNotEmpty ? subjects.first : null);
        }
        if (res.sequence != null) {
          _sequence = res.sequence!;
        }
      }
      _load();
    }
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _filterCtrl.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  // ── state helpers ─────────────────────────────────────────────────────

  String _initialText(String studentId) {
    final m = _existing[studentId];
    if (m == null) return '';
    final v = m.scoreOutOf(_maxScore);
    return v == v.roundToDouble() ? v.toInt().toString() : double.parse(v.toStringAsFixed(2)).toString();
  }

  /// Compares VALUES, not text: "12,5" typed and "12.5" saved are the
  /// same mark (comparing text left a saved row stuck on "Not saved yet").
  bool _isDirty(String id) {
    final text = _ctrls[id]?.text ?? '';
    final existing = _existing[id];
    if (existing == null) return text.trim().isNotEmpty;
    final parsed = parseScoreInput(text, _maxScore);
    if (parsed.error != null || parsed.value == null) return true;
    return (parsed.value! - existing.scoreOutOf(_maxScore)).abs() > 0.001;
  }

  String? _fieldError(String id) {
    final text = _ctrls[id]?.text ?? '';
    final parsed = parseScoreInput(text, _maxScore);
    if (parsed.error != null) return parsed.error;
    if (parsed.value == null && _existing.containsKey(id) && _isDirty(id)) return 'Enter 0 to clear';
    return _saveErrors[id];
  }

  List<String> get _dirtyIds => _roster.map((s) => s.id).where(_isDirty).toList();
  int get _invalidDirtyCount => _dirtyIds.where((id) => parseScoreInput(_ctrls[id]!.text, _maxScore).error != null ||
      (parseScoreInput(_ctrls[id]!.text, _maxScore).value == null)).length;

  Future<bool> _confirmDiscard() async {
    if (_dirtyIds.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved marks?'),
        content: Text('${_dirtyIds.length} mark(s) haven\'t been saved yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _changeSelection(VoidCallback apply) async {
    if (!await _confirmDiscard()) return;
    setState(apply);
    _load();
  }

  Future<void> _load() async {
    final cls = _class, subject = _subject;
    if (cls == null || subject == null) return;
    setState(() {
      _loading = true;
      _loadError = null;
      _saveErrors.clear();
    });
    final repo = SchoolMarksRepository.instance;
    final results = await Future.wait([
      repo.classRoster(_schoolId, cls),
      repo.marksForClass(schoolId: _schoolId, classLevel: cls, subject: subject, sequence: _sequence, academicYear: _year),
    ]);
    if (!mounted || cls != _class || subject != _subject) return;
    final rosterRes = results[0] as Result<List<RosterStudent>>;
    final marksRes = results[1] as Result<Map<String, SchoolMark>>;
    if (rosterRes is Failure<List<RosterStudent>>) {
      setState(() { _loading = false; _loadError = rosterRes.message; });
      return;
    }
    if (marksRes is Failure<Map<String, SchoolMark>>) {
      setState(() { _loading = false; _loadError = marksRes.message; });
      return;
    }
    final roster = (rosterRes as Success<List<RosterStudent>>).value;
    final existing = (marksRes as Success<Map<String, SchoolMark>>).value;
    // Show existing marks on the scale they were entered on, when the
    // whole class agrees on one.
    final scales = existing.values.map((m) => m.maxScore).toSet();
    setState(() {
      _roster = roster;
      _existing = existing;
      if (scales.length == 1) _maxScore = scales.first;
      for (final s in roster) {
        (_ctrls[s.id] ??= TextEditingController()).text = _initialText(s.id);
        _focus[s.id] ??= FocusNode();
      }
      _loading = false;
    });
  }

  Future<void> _saveAll() async {
    FocusScope.of(context).unfocus();
    final dirty = _dirtyIds;
    if (dirty.isEmpty) {
      showToast(context, 'Nothing to save — no marks changed.');
      return;
    }
    if (_invalidDirtyCount > 0) {
      showToast(context, 'Fix the $_invalidDirtyCount highlighted mark(s) first.', isError: true);
      setState(() {});
      return;
    }
    setState(() { _saving = true; _saveErrors.clear(); });
    final now = DateTime.now();
    final marks = [
      for (final id in dirty)
        SchoolMark(
          id: '',
          schoolId: _schoolId,
          studentId: id,
          classLevel: _class!,
          subject: _subject!,
          teacherName: widget.staff.name,
          sequence: _sequence,
          academicYear: _year,
          score: parseScoreInput(_ctrls[id]!.text, _maxScore).value!,
          maxScore: _maxScore,
          gradedAt: now,
          gradedBy: widget.staff.id,
        ),
    ];
    final failures = await SchoolMarksRepository.instance.upsertMany(marks);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveErrors.addAll(failures);
      for (final m in marks) {
        if (!failures.containsKey(m.studentId)) _existing[m.studentId] = m;
      }
    });
    final saved = marks.length - failures.length;
    if (failures.isEmpty) {
      showToast(context, 'Saved $saved mark${saved == 1 ? '' : 's'} for $_subject · $_class.');
    } else {
      showToast(context, 'Saved $saved, ${failures.length} failed — see the highlighted rows.', isError: true);
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final csv = generateMarksCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/marks_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Marks CSV Template');
    } catch (e) {
      if (mounted) showToast(context, 'Could not generate template: $e', isError: true);
    }
  }

  Future<void> _export() async {
    if (_roster.isEmpty || _class == null || _subject == null) return;
    final csv = exportMarksCsv(
      roster: _roster, marksByStudentId: _existing, classLevel: _class!,
      subject: _subject!, sequence: _sequence, academicYear: _year,
    );
    try {
      final dir = await getTemporaryDirectory();
      final safe = '${_class}_${_subject}_${_sequence.name}_$_year'.replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
      final file = File('${dir.path}/marks_$safe.csv');
      // BOM so Excel opens accented names (Loïc, Nadège) correctly.
      await file.writeAsString('\uFEFF$csv');
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Marks · $_subject · $_class · ${_sequence.label}');
    } catch (e) {
      if (mounted) showToast(context, 'Couldn\'t create the export file.', isError: true);
    }
  }

  Future<void> _exportPdf() async {
    if (_roster.isEmpty || _class == null || _subject == null) {
      showToast(context, 'No marks available to export.');
      return;
    }
    try {
      showToast(context, 'Generating Marks PDF...');
      final marks = _roster.map((s) {
        final existing = _existing[s.id];
        if (existing != null) return existing;
        final draftScore = double.tryParse(_ctrls[s.id]?.text ?? '');
        return SchoolMark(
          id: 'temp_${s.id}',
          studentId: s.id,
          studentName: s.name,
          classLevel: _class!,
          subject: _subject!,
          sequence: _sequence,
          score: draftScore ?? 0.0,
          maxScore: 20.0,
          academicYear: _year,
          schoolId: widget.staff.schoolId ?? '',
        );
      }).toList();

      final file = await SchoolDocumentExportService.instance.exportMarksPdf(
        schoolName: widget.staff.schoolName.isNotEmpty ? widget.staff.schoolName : 'CFPMI',
        classLevel: _class!,
        subject: _subject!,
        sequenceName: _sequence.label,
        marks: marks,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'Marks · $_subject · $_class · ${_sequence.label} (PDF)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export PDF: $e', isError: true);
    }
  }

  Future<void> _exportDocx() async {
    if (_roster.isEmpty || _class == null || _subject == null) {
      showToast(context, 'No marks available to export.');
      return;
    }
    try {
      showToast(context, 'Generating Marks Word document...');
      final marks = _roster.map((s) {
        final existing = _existing[s.id];
        if (existing != null) return existing;
        final draftScore = double.tryParse(_ctrls[s.id]?.text ?? '');
        return SchoolMark(
          id: 'temp_${s.id}',
          studentId: s.id,
          studentName: s.name,
          classLevel: _class!,
          subject: _subject!,
          sequence: _sequence,
          score: draftScore ?? 0.0,
          maxScore: 20.0,
          academicYear: _year,
          schoolId: widget.staff.schoolId ?? '',
        );
      }).toList();

      final file = await SchoolDocumentExportService.instance.exportMarksDocx(
        schoolName: widget.staff.schoolName.isNotEmpty ? widget.staff.schoolName : 'CFPMI',
        classLevel: _class!,
        subject: _subject!,
        sequenceName: _sequence.label,
        marks: marks,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'Marks · $_subject · $_class · ${_sequence.label} (Word Document)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export Word document: $e', isError: true);
    }
  }

  Future<void> _promptAddStudent() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Student to ${_class ?? 'Class'}'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Student Full Name',
            hintText: 'e.g. Marie Claire',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Student'),
          ),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final newId = 'std_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
      final newStudent = RosterStudent(id: newId, name: name, classLevel: _class ?? '');
      setState(() {
        _roster = [..._roster, newStudent]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _ctrls[newId] = TextEditingController();
        _focus[newId] = FocusNode();
      });
      if (mounted) showToast(context, 'Added $name to ${_class ?? 'class'} roster.');
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    if (!widget.staff.canRecordAnyMarks || _classes.isEmpty) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0, title: const Text('Enter Marks')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'You need a teaching assignment or class-master role to enter marks. Ask your school admin to assign you a subject and class.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: ac.muted, height: 1.5)),
        )),
      );
    }

    final dirtyCount = _dirtyIds.length;
    return PopScope(
      canPop: dirtyCount == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: ManagementScaffold(
        title: 'Enter Marks',
        sidebarItems: const [ManagementNavItem(icon: Icons.assessment_outlined, label: 'Marks', selected: true)],
        actions: [
          IconButton(
            tooltip: 'Add Student',
            icon: const Icon(Icons.person_add_rounded),
            onPressed: _promptAddStudent,
          ),
          IconButton(
            tooltip: 'Class Roster',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StudentRosterPage(user: widget.staff))).then((_) => _load()),
          ),
          IconButton(
            tooltip: 'Import Marks CSV',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: _openCsvImport,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Import / Export & Templates',
            onSelected: (val) {
              switch (val) {
                case 'template':
                  _downloadTemplate();
                  break;
                case 'csv':
                  _export();
                  break;
                case 'pdf':
                  _exportPdf();
                  break;
                case 'docx':
                  _exportDocx();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'template',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Download CSV Template'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'csv',
                enabled: _roster.isNotEmpty && !_loading,
                child: const Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                enabled: _roster.isNotEmpty && !_loading,
                child: const Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Export as PDF Document'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'docx',
                enabled: _roster.isNotEmpty && !_loading,
                child: const Row(
                  children: [
                    Icon(Icons.description_outlined, size: 20, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('Export as Word (.docx)'),
                  ],
                ),
              ),
            ],
          ),
        ],
        body: Column(children: [
          _filters(ac),
          Expanded(child: _body(ac)),
          _saveBar(ac, dirtyCount),
        ]),
      ),
    );
  }

  Widget _filters(AppColors ac) {
    final subjects = _class == null ? const <String>[] : recordableSubjectsFor(widget.staff, _class!);
    InputDecoration deco(String label) => InputDecoration(
          labelText: label, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
        );
    return Container(
      color: ac.surf,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(children: [
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _class, isExpanded: true, decoration: deco('Class'),
            items: [for (final c in _classes) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) {
              if (v == null || v == _class) return;
              _changeSelection(() {
                _class = v;
                final s = recordableSubjectsFor(widget.staff, v);
                _subject = s.contains(_subject) ? _subject : (s.isNotEmpty ? s.first : null);
              });
            },
          )),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(
            key: ValueKey('subj-$_class'),
            initialValue: _subject, isExpanded: true, decoration: deco('Subject'),
            items: [for (final s in subjects) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              if (v == null || v == _subject) return;
              _changeSelection(() => _subject = v);
            },
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 5, child: DropdownButtonFormField<AcademicSequence>(
            initialValue: _sequence, isExpanded: true, decoration: deco('Sequence'),
            items: [for (final s in AcademicSequence.values) DropdownMenuItem(value: s, child: Text(_shortSeq(s), overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              if (v == null || v == _sequence) return;
              _changeSelection(() => _sequence = v);
            },
          )),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: TextField(
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/-]'))],
            decoration: deco('Year'),
            onSubmitted: (_) => _load(),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: DropdownButtonFormField<double>(
            initialValue: _maxScore, isExpanded: true, decoration: deco('Out of'),
            items: const [
              DropdownMenuItem(value: 20.0, child: Text('/20')),
              DropdownMenuItem(value: 100.0, child: Text('/100')),
            ],
            onChanged: (v) {
              if (v == null || v == _maxScore) return;
              setState(() {
                _maxScore = v;
                for (final s in _roster) {
                  if (!_isDirty(s.id)) _ctrls[s.id]!.text = _initialText(s.id);
                }
              });
            },
          )),
        ]),
        if (_roster.length > 12) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _filterCtrl,
            onChanged: (_) => setState(() {}),
            decoration: deco('Find a student').copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 18)),
          ),
        ],
      ]),
    );
  }

  static String _shortSeq(AcademicSequence s) => '${s.term.replaceAll('Term ', 'T')} · ${s.sequenceLabel.replaceAll('Sequence ', 'Seq ')}';

  Widget _body(AppColors ac) {
    if (_subject == null) {
      return _message(ac, Icons.block_rounded, 'You have no subject to record in $_class.');
    }
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_loadError != null) {
      return _message(ac, Icons.wifi_off_rounded, _loadError!, action: TextButton.icon(
        onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')));
    }
    if (_roster.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 54, color: ac.muted),
              const SizedBox(height: 14),
              Text(
                'No students in $_class yet',
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt),
              ),
              const SizedBox(height: 6),
              Text(
                'Add students directly to record marks, or import a complete marks CSV spreadsheet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _promptAddStudent,
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: Text('Add Student to $_class'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openCsvImport,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Import Marks CSV'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StudentRosterPage(user: widget.staff))).then((_) => _load()),
                    icon: const Icon(Icons.people_alt_outlined, size: 18),
                    label: const Text('Class Roster'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final q = _filterCtrl.text.trim().toLowerCase();
    final visible = q.isEmpty ? _roster : _roster.where((s) => s.name.toLowerCase().contains(q)).toList();
    final marked = _roster.where((s) => (_ctrls[s.id]?.text.trim() ?? '').isNotEmpty).length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          Text('${_roster.length} students', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
          const Spacer(),
          Text('$marked / ${_roster.length} marked', style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: visible.length,
          itemBuilder: (ctx, i) => _studentRow(ac, visible, i),
        ),
      ),
    ]);
  }

  Widget _studentRow(AppColors ac, List<RosterStudent> visible, int i) {
    final s = visible[i];
    final dirty = _isDirty(s.id);
    final error = _fieldError(s.id);
    final saved = !dirty && _existing.containsKey(s.id);
    return Container(
      key: ValueKey(s.id),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: error != null ? ac.redBg : ac.surf,
        borderRadius: BorderRadius.circular(Rad.sm),
        border: Border.all(color: error != null ? ac.red : dirty ? ac.primary : ac.bdr2),
      ),
      child: Row(children: [
        SizedBox(width: 28, child: Text('${_roster.indexOf(s) + 1}', style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
          if (error != null)
            Text(error, style: GoogleFonts.inter(fontSize: 11, color: ac.red))
          else if (saved)
            Text('Saved', style: GoogleFonts.inter(fontSize: 11, color: ac.grn))
          else if (dirty)
            Text('Not saved yet', style: GoogleFonts.inter(fontSize: 11, color: ac.primary)),
        ])),
        SizedBox(
          width: 84,
          child: TextField(
            controller: _ctrls[s.id],
            focusNode: _focus[s.id],
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: i < visible.length - 1 ? TextInputAction.next : TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() => _saveErrors.remove(s.id)),
            onSubmitted: (_) {
              if (i < visible.length - 1) _focus[visible[i + 1].id]?.requestFocus();
            },
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt),
            decoration: InputDecoration(
              isDense: true,
              hintText: '–',
              suffixText: '/${_maxScore.toInt()}',
              suffixStyle: GoogleFonts.inter(fontSize: 10.5, color: ac.muted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _saveBar(AppColors ac, int dirtyCount) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(color: ac.surf, border: Border(top: BorderSide(color: ac.bdr2))),
        child: Row(children: [
          Expanded(child: Text(
            dirtyCount == 0 ? 'All changes saved' : '$dirtyCount unsaved change${dirtyCount == 1 ? '' : 's'}',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: dirtyCount == 0 ? ac.muted : ac.txt),
          )),
          SizedBox(
            width: 150,
            child: PrimaryBtn(label: 'Save Marks', loading: _saving,
                onTap: _saving || dirtyCount == 0 ? () {} : _saveAll),
          ),
        ]),
      ),
    );
  }

  Widget _message(AppColors ac, IconData icon, String text, {Widget? action}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: ac.muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.5)),
            if (action != null) ...[const SizedBox(height: 8), action],
          ]),
        ),
      );
}

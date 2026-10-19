// lib/features/school/teacher_management_page.dart
// Admin Teacher-Control System (school-operations spec item 7): register
// which (subject, classLevel) pairs a teacher may act on, and who is a
// class's Class Master. This is the ONLY place that writes
// AppUser.teachingAssignments/classMasterOfClass -- nothing else in the
// app could set them before this page existed (grep confirmed
// teachingAssignments was write-only-by-hand-in-Postgres until now). Rides
// on the existing users_update_admin RLS policy (academia-cameroon's
// 20260828060100_rls_policies.sql) -- see TeacherManagementRepository's
// own header comment for why no new RPC/policy was needed.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/result.dart';
import '../../core/teacher_csv.dart';
import '../../models/academic_content.dart' show kAcademicSubjects, kAcademicLevels;
import '../../models/app_user.dart';
import '../../models/teaching_assignment.dart';
import '../../repositories/teacher_management_repository.dart';
import '../../repositories/school_repository.dart';
import '../../services/school_document_export_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'teacher_csv_import_page.dart';
import 'widgets/management_scaffold.dart';
import 'manage_subjects_dialog.dart';

// Undergraduate/All Levels (the last two of kAcademicLevels) describe
// CONTENT scope, not an actual class in this school's own roster -- a
// teacher is never "assigned to" either one.
List<String> get _schoolClassLevels => kAcademicLevels.take(7).toList();

class TeacherManagementPage extends StatefulWidget {
  final AppUser admin;
  const TeacherManagementPage({super.key, required this.admin});

  @override
  State<TeacherManagementPage> createState() => _TeacherManagementPageState();
}

class _TeacherManagementPageState extends State<TeacherManagementPage> {
  final _searchCtrl = TextEditingController();
  List<AppUser> _results = [];
  List<AppUser> _assigned = [];
  List<String> _subjects = kAcademicSubjects;
  bool _searching = false;
  bool _loadingAssigned = true;

  String get _schoolId => widget.admin.schoolId ?? '';

  @override
  void initState() {
    super.initState();
    _loadAssigned();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final res = await SchoolRepository.instance.getSubjects(_schoolId);
    if (!mounted) return;
    // A school that hasn't configured its own subject list yet gets the
    // standard catalogue -- the dropdown used to offer only "Mathematics".
    setState(() => _subjects = res is Success<List<String>> && res.value.isNotEmpty ? res.value : kAcademicSubjects);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssigned() async {
    // Every staff member, not only those already assigned -- a newly
    // hired teacher used to be invisible here unless you knew to search.
    final staff = await TeacherManagementRepository.instance.staffOnce(_schoolId);
    if (!mounted) return;
    setState(() {
      _assigned = staff;
      _loadingAssigned = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await TeacherManagementRepository.instance.searchStaff(_schoolId, query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _downloadTemplate() async {
    try {
      final csv = generateTeacherCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/teacher_assignments_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Teacher Assignments CSV Template');
    } catch (e) {
      if (mounted) showToast(context, 'Could not generate template: $e', isError: true);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final staff = await TeacherManagementRepository.instance.assignedStaffOnce(_schoolId);
      if (staff.isEmpty) {
        if (mounted) showToast(context, 'No teacher assignments to export yet.');
        return;
      }
      final csv = exportTeacherAssignmentsCsv(staff);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/teacher_assignments.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Teacher Assignments Export');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export teacher assignments: $e', isError: true);
    }
  }

  Future<void> _exportPdf() async {
    try {
      final staff = await TeacherManagementRepository.instance.assignedStaffOnce(_schoolId);
      if (staff.isEmpty) {
        if (mounted) showToast(context, 'No teacher assignments to export yet.');
        return;
      }
      showToast(context, 'Generating Staff Directory PDF...');
      final file = await SchoolDocumentExportService.instance.exportStaffDirectoryPdf(
        schoolName: widget.admin.schoolName.isNotEmpty ? widget.admin.schoolName : 'CFPMI',
        staff: staff,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'Faculty & Staff Directory (PDF)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export PDF: $e', isError: true);
    }
  }

  Future<void> _exportDocx() async {
    try {
      final staff = await TeacherManagementRepository.instance.assignedStaffOnce(_schoolId);
      if (staff.isEmpty) {
        if (mounted) showToast(context, 'No teacher assignments to export yet.');
        return;
      }
      showToast(context, 'Generating Staff Directory Word document...');
      final file = await SchoolDocumentExportService.instance.exportStaffDirectoryDocx(
        schoolName: widget.admin.schoolName.isNotEmpty ? widget.admin.schoolName : 'CFPMI',
        staff: staff,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'Faculty & Staff Directory (Word Document)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export Word document: $e', isError: true);
    }
  }

  Future<void> _openCsvImport() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeacherCsvImportPage(admin: widget.admin),
      ),
    );
    if (!mounted) return;
    _loadAssigned();
    _loadSubjects();
  }

  void _openEditor(AppUser teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignmentEditorSheet(
        teacher: teacher,
        subjects: _subjects,
        onChanged: () {
          _loadAssigned();
          setState(() => _results = []);
          _searchCtrl.clear();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    if (!widget.admin.hasMinRole(UserRole.schoolAdmin)) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: Center(child: Text('You need school-admin access to manage teachers.', style: GoogleFonts.inter(color: ac.muted))),
      );
    }

    return ManagementScaffold(
      title: 'Teacher Management',
      sidebarItems: const [ManagementNavItem(icon: Icons.badge_outlined, label: 'Teachers', selected: true)],
      actions: [
        IconButton(
          tooltip: 'Upload Assignments CSV',
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
                _exportCsv();
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
            const PopupMenuItem(
              value: 'csv',
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Export as CSV'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Export as PDF Document'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'docx',
              child: Row(
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.inter(fontSize: 13, color: ac.txt),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name to register or edit',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: ac.surf3,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                  ),
                  onChanged: _search,
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => ManageSubjectsDialog(schoolId: _schoolId),
                  );
                  _loadSubjects();
                },
                icon: const Icon(Icons.library_books),
                label: const Text('Subjects'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openCsvImport,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Upload CSV'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: ac.bdr),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: ac.bdr),
                  ),
                ),
              ),
            ],
          ),
          if (_searching) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          for (final r in _results)
            ListTile(
              title: Text(r.name, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
              subtitle: Text(r.roleLabel, style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
              trailing: Icon(Icons.chevron_right_rounded, color: ac.muted),
              onTap: () => _openEditor(r),
            ),
          const SizedBox(height: 8),
          Text('Staff', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 8),
          if (_loadingAssigned)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_assigned.isEmpty)
            Text('No staff accounts at this school yet. Issue Teacher codes from Access Codes.', style: GoogleFonts.inter(color: ac.muted))
          else
            for (final t in _assigned) _StaffTile(teacher: t, onTap: () => _openEditor(t)),
        ],
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final AppUser teacher;
  final VoidCallback onTap;
  const _StaffTile({required this.teacher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final summary = [
      if (teacher.classMasterOfClass != null) 'Class Master of ${teacher.classMasterOfClass}',
      for (final a in teacher.teachingAssignments) '${a.subject} · ${a.classLevel}',
    ].join('\n');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(teacher.name, style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: ac.txt)),
              const SizedBox(height: 4),
              Text(summary.isEmpty ? '${teacher.roleLabel} · No assignments yet — tap to assign' : summary, style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: ac.muted),
        ]),
      ),
    );
  }
}

class _AssignmentEditorSheet extends StatefulWidget {
  final AppUser teacher;
  final List<String> subjects;
  final VoidCallback onChanged;
  const _AssignmentEditorSheet({required this.teacher, required this.subjects, required this.onChanged});

  @override
  State<_AssignmentEditorSheet> createState() => _AssignmentEditorSheetState();
}

class _AssignmentEditorSheetState extends State<_AssignmentEditorSheet> {
  late List<TeachingAssignment> _assignments = List.of(widget.teacher.teachingAssignments);
  late String? _classMaster = widget.teacher.classMasterOfClass;
  String _addClass = _schoolClassLevels.first;
  late String _addSubject = widget.subjects.isNotEmpty ? widget.subjects.first : 'Mathematics';
  bool _saving = false;

  Future<void> _saveAssignments(List<TeachingAssignment> next) async {
    setState(() => _saving = true);
    final result = await TeacherManagementRepository.instance.setTeachingAssignments(widget.teacher.id, next);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result is Success<void>) _assignments = next;
    });
    if (result is Failure<void>) showToast(context, result.message, isError: true);
    widget.onChanged();
  }

  Future<void> _saveClassMaster(String? classLevel) async {
    setState(() => _saving = true);
    final result = await TeacherManagementRepository.instance.setClassMasterOfClass(widget.teacher.id, classLevel);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result is Success<void>) _classMaster = classLevel;
    });
    if (result is Failure<void>) showToast(context, result.message, isError: true);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(color: ac.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.teacher.name, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
            Text(widget.teacher.roleLabel, style: GoogleFonts.inter(fontSize: 12, color: ac.muted)),
            const SizedBox(height: 20),
            Text('Class Master Of', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.txt)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: _classMaster,
              decoration: const InputDecoration(hintText: 'Not a class master'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Not a class master')),
                for (final c in _schoolClassLevels) DropdownMenuItem<String?>(value: c, child: Text(c)),
              ],
              onChanged: _saving ? null : _saveClassMaster,
            ),
            const SizedBox(height: 20),
            Text('Teaching Assignments', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.txt)),
            const SizedBox(height: 8),
            if (_assignments.isEmpty)
              Text('No subjects assigned yet.', style: GoogleFonts.inter(fontSize: 12.5, color: ac.muted)),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in _assignments)
                Chip(
                  label: Text('${a.subject} · ${a.classLevel}'),
                  onDeleted: _saving ? null : () => _saveAssignments(List.of(_assignments)..remove(a)),
                ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _addClass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [for (final c in _schoolClassLevels) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setState(() => _addClass = v ?? _addClass),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true, // long subject names overflowed by 26px on phones
                  initialValue: _addSubject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    if (widget.subjects.isEmpty) const DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                    for (final s in widget.subjects) DropdownMenuItem(value: s, child: Text(s))
                  ],
                  onChanged: (v) => setState(() => _addSubject = v ?? _addSubject),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SecondaryBtn(
              label: 'Add Assignment',
              icon: Icons.add_rounded,
              onTap: _saving
                  ? () {}
                  : () {
                      final next = TeachingAssignment(subject: _addSubject, classLevel: _addClass);
                      if (_assignments.contains(next)) return;
                      _saveAssignments([..._assignments, next]);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

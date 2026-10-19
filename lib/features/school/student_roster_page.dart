// lib/features/school/student_roster_page.dart
// School Administration: Student Records and Class Lists management.
// Supports manual entry, CSV template download, CSV bulk import, and CSV export.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/result.dart';
import '../../core/student_roster_csv.dart';
import '../../models/academic_content.dart' show kAcademicLevels;
import '../../models/app_user.dart';
import '../../models/student_record.dart';
import '../../repositories/student_roster_repository.dart';
import '../../services/school_document_export_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'student_roster_csv_import_page.dart';
import 'widgets/management_scaffold.dart';

List<String> get _schoolClassLevels => kAcademicLevels.take(7).toList();

class StudentRosterPage extends StatefulWidget {
  final AppUser user;
  const StudentRosterPage({super.key, required this.user});

  @override
  State<StudentRosterPage> createState() => _StudentRosterPageState();
}

class _StudentRosterPageState extends State<StudentRosterPage> {
  String? _selectedClass; // null = all classes
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<StudentRecord> _students = [];
  bool _loading = true;

  String get _schoolId => widget.user.schoolId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await StudentRosterRepository.instance.getStudents(
      _schoolId,
      classLevel: _selectedClass,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _students = res is Success<List<StudentRecord>> ? res.value : [];
    });
  }

  Future<void> _openImport() async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentRosterCsvImportPage(
          staff: widget.user,
          targetClass: _selectedClass,
        ),
      ),
    );
    if (!mounted) return;
    if (updated is String && _schoolClassLevels.contains(updated)) {
      _selectedClass = updated;
    }
    _load();
  }

  Future<void> _downloadTemplate() async {
    try {
      final csv = generateStudentRosterCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/student_roster_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Student Roster CSV Template');
    } catch (e) {
      if (mounted) showToast(context, 'Could not generate template: $e', isError: true);
    }
  }

  Future<void> _exportCsv() async {
    if (_students.isEmpty) {
      showToast(context, 'No student records to export.');
      return;
    }
    try {
      final csv = exportStudentRosterCsv(_students);
      final dir = await getTemporaryDirectory();
      final className = _selectedClass?.replaceAll(' ', '_') ?? 'all_classes';
      final file = File('${dir.path}/student_roster_$className.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Student Roster Export - $className');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export roster: $e', isError: true);
    }
  }

  Future<void> _exportPdf() async {
    if (_students.isEmpty) {
      showToast(context, 'No student records to export.');
      return;
    }
    try {
      showToast(context, 'Generating Class Roster PDF...');
      final file = await SchoolDocumentExportService.instance.exportStudentRosterPdf(
        schoolName: widget.user.schoolName.isNotEmpty ? widget.user.schoolName : 'CFPMI',
        classLevel: _selectedClass ?? 'All Classes',
        students: _students,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'Student Roster · ${_selectedClass ?? 'All'} (PDF)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export PDF: $e', isError: true);
    }
  }

  Future<void> _exportDocx() async {
    if (_students.isEmpty) {
      showToast(context, 'No student records to export.');
      return;
    }
    try {
      showToast(context, 'Generating Class Roster Word document...');
      final file = await SchoolDocumentExportService.instance.exportStudentRosterDocx(
        schoolName: widget.user.schoolName.isNotEmpty ? widget.user.schoolName : 'CFPMI',
        classLevel: _selectedClass ?? 'All Classes',
        students: _students,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'Student Roster · ${_selectedClass ?? 'All'} (Word Document)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export Word document: $e', isError: true);
    }
  }

  Future<void> _promptAddStudent({StudentRecord? editing}) async {
    final isEdit = editing != null;
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final matriculeCtrl = TextEditingController(text: editing?.matricule ?? '');
    final contactCtrl = TextEditingController(text: editing?.parentContact ?? '');
    String classLevel = editing?.classLevel ?? (_selectedClass ?? _schoolClassLevels.first);
    String gender = editing?.gender ?? 'M';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Student' : 'Add Student to Class Roster',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Student Full Name *', hintText: 'e.g. Brice Ngono'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: classLevel,
                  decoration: const InputDecoration(labelText: 'Class Level *'),
                  items: [
                    for (final c in _schoolClassLevels) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setDialogState(() => classLevel = v ?? classLevel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: matriculeCtrl,
                  decoration: const InputDecoration(labelText: 'Matricule / Student ID', hintText: 'e.g. LBS-2026-0042'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Parent Phone / Email', hintText: 'e.g. +237 671234567'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Male (M)')),
                    DropdownMenuItem(value: 'F', child: Text('Female (F)')),
                  ],
                  onChanged: (v) => setDialogState(() => gender = v ?? gender),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().length < 2) {
                  showToast(ctx, 'Enter a valid student name', isError: true);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Student'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final matricule = matriculeCtrl.text.trim().isNotEmpty ? matriculeCtrl.text.trim() : null;
      final contact = contactCtrl.text.trim().isNotEmpty ? contactCtrl.text.trim() : null;

      final record = StudentRecord(
        id: editing?.id ?? 'std_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
        schoolId: _schoolId,
        name: name,
        classLevel: classLevel,
        matricule: matricule,
        parentContact: contact,
        gender: gender,
        createdAt: editing?.createdAt ?? DateTime.now(),
      );

      final res = await StudentRosterRepository.instance.addStudent(record);
      if (res is Success<void>) {
        if (mounted) showToast(context, isEdit ? 'Student updated' : 'Added $name to $classLevel');
        _load();
      } else {
        if (mounted) showToast(context, 'Could not save student: ${(res as Failure).message}', isError: true);
      }
    }
  }

  Future<void> _deleteStudent(StudentRecord s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student from Roster?'),
        content: Text('Remove "${s.name}" from ${s.classLevel}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StudentRosterRepository.instance.deleteStudent(s.id, _schoolId);
      if (mounted) {
        showToast(context, 'Student removed');
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    final filtered = _students.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nMatch = s.name.toLowerCase().contains(q);
      final mMatch = s.matricule?.toLowerCase().contains(q) ?? false;
      return nMatch || mMatch;
    }).toList();

    return ManagementScaffold(
      title: 'Class Lists & Students',
      sidebarItems: const [
        ManagementNavItem(icon: Icons.people_alt_outlined, label: 'Student Records', selected: true),
      ],
      actions: [
        IconButton(
          tooltip: 'Upload Student CSV',
          icon: const Icon(Icons.upload_file_rounded),
          onPressed: _openImport,
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ac.primary,
        foregroundColor: Colors.white,
        onPressed: () => _promptAddStudent(),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Student'),
      ),
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
                    hintText: 'Search by student name or matricule...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: ac.surf3,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                  ),
                  onChanged: (q) => setState(() => _searchQuery = q.trim()),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: ac.surf3,
                  borderRadius: BorderRadius.circular(Rad.sm),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedClass,
                    hint: Text('All Classes', style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt)),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Classes')),
                      for (final c in _schoolClassLevels) DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedClass = v);
                      _load();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openImport,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filtered.length} Student${filtered.length == 1 ? '' : 's'} '
                '${_selectedClass != null ? 'in $_selectedClass' : 'Enrolled'}',
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            _emptyState(ac)
          else
            for (final s in filtered) _studentTile(ac, s),
          const SizedBox(height: 80), // clearance for FAB
        ],
      ),
    );
  }

  Widget _emptyState(AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr2),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: ac.muted),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No students found matching "$_searchQuery".' : 'No students in this class list yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload a completed Student CSV spreadsheet or add students manually.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: ac.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _openImport,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Upload Roster CSV'),
                style: ElevatedButton.styleFrom(backgroundColor: ac.primary, foregroundColor: Colors.white),
              ),
              OutlinedButton.icon(
                onPressed: () => _promptAddStudent(),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Student Manually'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _studentTile(AppColors ac, StudentRecord s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: ac.primaryBg,
            child: Text(
              s.name.isNotEmpty ? s.name.substring(0, 1).toUpperCase() : 'S',
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(4)),
                      child: Text(s.classLevel, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.txt2)),
                    ),
                    if (s.matricule != null && s.matricule!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(4)),
                        child: Text(s.matricule!, style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
                      ),
                    if (s.parentContact != null && s.parentContact!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(4)),
                        child: Text(s.parentContact!, style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: ac.muted, size: 20),
            onSelected: (v) {
              if (v == 'edit') {
                _promptAddStudent(editing: s);
              } else if (v == 'delete') {
                _deleteStudent(s);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Remove', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}

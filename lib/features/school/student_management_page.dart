// lib/features/school/student_management_page.dart
// Admin Student-Class assignment: set which class a student belongs to.
// Every screen keyed off class_level (Marks, Timetable, Homework, the
// daily-program cron) was silently inert for a student until this
// existed -- see student_class_repository.dart's header comment for why.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/academic_content.dart' show kAcademicLevels;
import '../../models/app_user.dart';
import '../../repositories/student_class_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'widgets/management_scaffold.dart';

// Undergraduate/All Levels (the last two of kAcademicLevels) describe
// CONTENT scope, not an actual class in this school's own roster --
// mirrors teacher_management_page.dart's own _schoolClassLevels exactly.
List<String> get _schoolClassLevels => kAcademicLevels.take(7).toList();

class StudentManagementPage extends StatefulWidget {
  final AppUser admin;
  const StudentManagementPage({super.key, required this.admin});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  final _searchCtrl = TextEditingController();
  List<AppUser> _results = [];
  List<AppUser> _unclassified = [];
  List<AppUser> _classified = [];
  bool _searching = false;
  bool _loading = true;

  String get _schoolId => widget.admin.schoolId ?? '';

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
    final unclassified = await StudentClassRepository.instance.unclassifiedStudentsOnce(_schoolId);
    final classified = await StudentClassRepository.instance.classifiedStudentsOnce(_schoolId);
    if (!mounted) return;
    setState(() {
      _unclassified = unclassified;
      _classified = classified;
      _loading = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await StudentClassRepository.instance.searchStudents(_schoolId, query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _openEditor(AppUser student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClassPickerSheet(
        student: student,
        onChanged: () {
          _load();
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
        body: Center(child: Text('You need school-admin access to manage students.', style: GoogleFonts.inter(color: ac.muted))),
      );
    }

    return ManagementScaffold(
      title: 'Student Management',
      sidebarItems: const [ManagementNavItem(icon: Icons.groups_2_outlined, label: 'Students', selected: true)],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchCtrl,
            style: GoogleFonts.inter(fontSize: 13, color: ac.txt),
            decoration: InputDecoration(
              hintText: 'Search students by name to set their class',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
            onChanged: _search,
          ),
          if (_searching) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          for (final r in _results) _StudentTile(student: r, onTap: () => _openEditor(r)),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else ...[
            if (_unclassified.isNotEmpty) ...[
              Text('Needs a Class (${_unclassified.length})',
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.red)),
              const SizedBox(height: 8),
              for (final s in _unclassified) _StudentTile(student: s, onTap: () => _openEditor(s)),
              const SizedBox(height: 16),
            ],
            Text('Classified Students (${_classified.length})', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 8),
            if (_classified.isEmpty)
              Text('No student has a class set yet -- search above to get started.', style: GoogleFonts.inter(color: ac.muted))
            else
              for (final s in _classified) _StudentTile(student: s, onTap: () => _openEditor(s)),
          ],
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final AppUser student;
  final VoidCallback onTap;
  const _StudentTile({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.name, style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: ac.txt)),
              const SizedBox(height: 4),
              Text(student.classLevel.isEmpty ? 'No class set' : student.classLevel,
                  style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: ac.muted),
        ]),
      ),
    );
  }
}

class _ClassPickerSheet extends StatefulWidget {
  final AppUser student;
  final VoidCallback onChanged;
  const _ClassPickerSheet({required this.student, required this.onChanged});

  @override
  State<_ClassPickerSheet> createState() => _ClassPickerSheetState();
}

class _ClassPickerSheetState extends State<_ClassPickerSheet> {
  late String? _classLevel = widget.student.classLevel.isEmpty ? null : widget.student.classLevel;
  bool _saving = false;

  Future<void> _save(String? classLevel) async {
    setState(() => _saving = true);
    final result = await StudentClassRepository.instance.setClassLevel(widget.student.id, classLevel ?? '');
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result is Success<void>) _classLevel = classLevel;
    });
    if (result is Failure<void>) showToast(context, result.message, isError: true);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(color: ac.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.student.name, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
            Text('Student', style: GoogleFonts.inter(fontSize: 12, color: ac.muted)),
            const SizedBox(height: 20),
            Text('Class', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.txt)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: _classLevel,
              decoration: const InputDecoration(hintText: 'No class set'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('No class set')),
                for (final c in _schoolClassLevels) DropdownMenuItem<String?>(value: c, child: Text(c)),
              ],
              onChanged: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

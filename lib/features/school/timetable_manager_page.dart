// lib/features/school/timetable_manager_page.dart
// Staff-only CRUD for the School Timetable, gated to canManageAnyTimetable
// (the school_timetable_slots RLS policy enforces the same server-side).
//
// Every save runs core/timetable_conflicts.dart against the WHOLE
// school's timetable: a class double-booked, a teacher in two classes at
// once, or a room used twice blocks the save; no teacher / a teacher not
// on staff / a teacher not assigned that subject is a warning that needs
// "Save anyway". Existing periods carry the same badges, so a clash
// created earlier (or by a teacher later removed) stays visible.
//
// Class, subject and teacher are picked from real school data rather
// than typed: a typed "form 4" used to create periods Form 4 students
// never saw.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/result.dart';
import '../../core/timetable_conflicts.dart';
import '../../core/timetable_csv.dart' hide normalizeTime;
import '../../models/academic_content.dart' show kAcademicLevels, kAcademicSubjects;
import '../../models/app_user.dart';
import '../../models/school_timetable_slot.dart';
import '../../repositories/school_repository.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../repositories/teacher_management_repository.dart';
import '../../services/school_document_export_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'timetable_csv_import_page.dart';
import 'widgets/management_scaffold.dart';

List<String> get _classLevels => kAcademicLevels.take(7).toList();

class TimetableManagerPage extends StatefulWidget {
  final AppUser user;
  const TimetableManagerPage({super.key, required this.user});

  @override
  State<TimetableManagerPage> createState() => _TimetableManagerPageState();
}

class _TimetableManagerPageState extends State<TimetableManagerPage> {
  late String _classLevel;
  late final Stream<List<SchoolTimetableSlot>> _schoolStream;
  List<SchoolTimetableSlot> _latestSchoolSlots = const [];
  List<TimetableStaff>? _staff; // null = couldn't load -> staff checks skipped
  List<String> _staffNames = const [];
  List<String> _subjects = kAcademicSubjects;

  String get _schoolId => widget.user.schoolId ?? '';

  @override
  void initState() {
    super.initState();
    final own = widget.user.classMasterOfClass ?? widget.user.classLevel;
    _classLevel = _classLevels.contains(own) ? own : _classLevels[4];
    _schoolStream = SchoolTimetableRepository.instance.watchForSchool(_schoolId);
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    try {
      final staff = await TeacherManagementRepository.instance.staffOnce(_schoolId);
      final subjects = await SchoolRepository.instance.getSubjects(_schoolId);
      if (!mounted) return;
      setState(() {
        _staff = [
          for (final u in staff)
            TimetableStaff(name: u.name, assignments: u.teachingAssignments, classMasterOf: u.classMasterOfClass),
        ];
        _staffNames = staff.map((u) => u.name).toList();
        if (subjects is Success<List<String>> && subjects.value.isNotEmpty) {
          _subjects = {...subjects.value, ...kAcademicSubjects}.toList();
        }
      });
    } catch (_) {
      // Offline: editor still works, staff checks are skipped.
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final csv = generateTimetableCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/timetable_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'School Timetable CSV Template');
    } catch (e) {
      if (mounted) showToast(context, 'Could not generate template: $e', isError: true);
    }
  }

  Future<void> _exportCsv() async {
    final slots = _latestSchoolSlots.where((s) => s.classLevel == _classLevel).toList();
    if (slots.isEmpty) {
      showToast(context, 'No periods to export for $_classLevel.');
      return;
    }
    try {
      final csv = exportTimetableCsv(slots);
      final dir = await getTemporaryDirectory();
      final safeClass = _classLevel.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
      final file = File('${dir.path}/timetable_$safeClass.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Timetable · $_classLevel');
    } catch (_) {
      if (mounted) showToast(context, 'Could not export timetable.', isError: true);
    }
  }

  Future<void> _exportPdf() async {
    final slots = _latestSchoolSlots.where((s) => s.classLevel == _classLevel).toList();
    if (slots.isEmpty) {
      showToast(context, 'No periods to export for $_classLevel.');
      return;
    }
    try {
      showToast(context, 'Generating Timetable PDF...');
      final file = await SchoolDocumentExportService.instance.exportTimetablePdf(
        schoolName: widget.user.schoolName.isNotEmpty ? widget.user.schoolName : 'CFPMI',
        classLevel: _classLevel,
        slots: slots,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'Timetable · $_classLevel (PDF)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export PDF: $e', isError: true);
    }
  }

  Future<void> _exportDocx() async {
    final slots = _latestSchoolSlots.where((s) => s.classLevel == _classLevel).toList();
    if (slots.isEmpty) {
      showToast(context, 'No periods to export for $_classLevel.');
      return;
    }
    try {
      showToast(context, 'Generating Timetable Word document...');
      final file = await SchoolDocumentExportService.instance.exportTimetableDocx(
        schoolName: widget.user.schoolName.isNotEmpty ? widget.user.schoolName : 'CFPMI',
        classLevel: _classLevel,
        slots: slots,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'Timetable · $_classLevel (Word Document)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export Word document: $e', isError: true);
    }
  }

  Future<void> _openCsvImport() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TimetableCsvImportPage(user: widget.user)),
    );
    if (mounted) {
      setState(() {
        if (res is String && _classLevels.contains(res)) {
          _classLevel = res;
        }
        _schoolStream = SchoolTimetableRepository.instance.watchForSchool(_schoolId);
      });
      _loadReferenceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (!widget.user.canManageAnyTimetable) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0, title: const Text('Manage Timetable')),
        body: Center(child: Text('Only school admins can edit the timetable.', style: GoogleFonts.inter(color: ac.muted))),
      );
    }
    if (_schoolId.isEmpty) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0, title: const Text('Manage Timetable')),
        body: Center(child: Text('Your account isn\'t linked to a school.', style: GoogleFonts.inter(color: ac.muted))),
      );
    }

    return ManagementScaffold(
      title: 'Manage Timetable',
      sidebarItems: const [ManagementNavItem(icon: Icons.calendar_month_rounded, label: 'Timetable', selected: true)],
      actions: [
        IconButton(
          icon: const Icon(Icons.upload_file_rounded),
          tooltip: 'Upload Timetable CSV',
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ac.primary,
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add period', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<String>(
            initialValue: _classLevel,
            decoration: InputDecoration(
              labelText: 'Class',
              filled: true, fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
            items: [for (final c in _classLevels) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _classLevel = v ?? _classLevel),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<SchoolTimetableSlot>>(
            stream: _schoolStream,
            builder: (context, snap) {
              if (snap.hasData) _latestSchoolSlots = snap.data!;
              if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (!snap.hasData && snap.hasError) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Couldn\'t load the timetable. Check your connection.',
                      textAlign: TextAlign.center, style: GoogleFonts.inter(color: ac.muted)),
                ));
              }
              final all = _latestSchoolSlots;
              final slots = all.where((s) => s.classLevel == _classLevel).toList()
                ..sort((a, b) {
                  final d = a.dayOfWeek.compareTo(b.dayOfWeek);
                  return d != 0 ? d : (normalizeTime(a.startTime) ?? a.startTime).compareTo(normalizeTime(b.startTime) ?? b.startTime);
                });
              final audit = auditTimetable(all, staff: _staff);
              final classIssues = slots.where((s) => audit.containsKey(s.id)).length;
              if (slots.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 48, color: ac.muted),
                        const SizedBox(height: 12),
                        Text('No periods yet for $_classLevel',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: ac.txt)),
                        const SizedBox(height: 6),
                        Text('Add periods manually or import the complete timetable via CSV spreadsheet.',
                            textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: ac.muted)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openCsvImport,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Upload CSV'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ac.primary,
                                side: BorderSide(color: ac.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () => _openEditor(context, null),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Period'),
                              style: FilledButton.styleFrom(backgroundColor: ac.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  if (classIssues > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: ac.orgBg, borderRadius: BorderRadius.circular(Rad.sm)),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded, color: ac.org, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('$classIssues period${classIssues == 1 ? ' needs' : 's need'} attention in $_classLevel.',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.org))),
                      ]),
                    ),
                  for (final s in slots) _slotTile(ac, s, audit[s.id] ?? const []),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _slotTile(AppColors ac, SchoolTimetableSlot s, List<TimetableConflict> issues) {
    final hasError = issues.any((c) => c.isError);
    final color = hasError ? ac.red : (issues.isNotEmpty ? ac.org : null);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm),
        border: Border.all(color: color ?? ac.bdr2),
      ),
      child: ListTile(
        onTap: () => _openEditor(context, s),
        title: Text('${s.dayName}  ${s.startTime}–${s.endTime} · ${s.subject}',
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([
            s.teacherName.isEmpty ? 'No teacher' : s.teacherName,
            if ((s.room ?? '').isNotEmpty) 'Room ${s.room}',
          ].join(' · '), style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
          for (final c in issues)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('• ${c.message}', style: GoogleFonts.inter(fontSize: 11, color: c.isError ? ac.red : ac.org)),
            ),
        ]),
        trailing: IconButton(
          tooltip: 'Delete period',
          icon: Icon(Icons.delete_outline_rounded, color: ac.red, size: 20),
          onPressed: () => _confirmDelete(s),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(SchoolTimetableSlot s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this period?'),
        content: Text('${s.classLevel} · ${s.dayName} ${s.startTime}–${s.endTime} · ${s.subject}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await SchoolTimetableRepository.instance.delete(_schoolId, s.id);
    if (!mounted) return;
    if (res is Failure<void>) showToast(context, res.message, isError: true);
  }

  Future<void> _openEditor(BuildContext context, SchoolTimetableSlot? existing) async {
    final startCtrl = TextEditingController(text: existing?.startTime ?? '07:30');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '08:25');
    final roomCtrl = TextEditingController(text: existing?.room ?? '');
    var day = existing?.dayOfWeek ?? 1;
    var subject = existing?.subject ?? '';
    var teacher = existing?.teacherName ?? '';
    var saving = false;
    final ac = AppColors.of(context);

    SchoolTimetableSlot build() => SchoolTimetableSlot(
          id: existing?.id ?? '',
          schoolId: _schoolId,
          classLevel: existing?.classLevel ?? _classLevel,
          dayOfWeek: day,
          startTime: normalizeTime(startCtrl.text) ?? startCtrl.text.trim(),
          endTime: normalizeTime(endCtrl.text) ?? endCtrl.text.trim(),
          subject: subject,
          teacherName: teacher,
          room: roomCtrl.text.trim().isEmpty ? null : roomCtrl.text.trim(),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final candidate = build();
        final conflicts = findConflicts(candidate, _latestSchoolSlots, staff: _staff);
        final errors = conflicts.where((c) => c.isError).toList();
        final warnings = conflicts.where((c) => !c.isError).toList();
        final subjects = {..._subjects, if (subject.isNotEmpty) subject}.toList();
        final teachers = {..._staffNames, if (teacher.isNotEmpty) teacher}.toList();

        Future<void> save() async {
          setSheet(() => saving = true);
          final result = existing == null
              ? await SchoolTimetableRepository.instance.add(candidate)
              : await SchoolTimetableRepository.instance.update(candidate);
          if (!ctx.mounted) return;
          setSheet(() => saving = false);
          if (result is Failure<void>) {
            showToast(ctx, result.message, isError: true);
          } else {
            Navigator.of(ctx).pop();
          }
        }

        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${existing == null ? 'Add period' : 'Edit period'} · ${candidate.classLevel}',
                        style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
                  ),
                  ElevatedButton(
                    onPressed: errors.isNotEmpty || saving ? null : save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(existing == null ? 'Confirm' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [for (var d = 1; d <= 6; d++) DropdownMenuItem(value: d, child: Text(SchoolTimetableSlot.dayNames[d]))],
                onChanged: (v) => setSheet(() => day = v ?? day),
              ),
              Row(children: [
                Expanded(child: TextField(
                  controller: startCtrl, keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(labelText: 'Start', hintText: '07:30'),
                  onChanged: (_) => setSheet(() {}))),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: endCtrl, keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(labelText: 'End', hintText: '08:25'),
                  onChanged: (_) => setSheet(() {}))),
              ]),
              DropdownButtonFormField<String>(
                initialValue: subject.isEmpty ? null : subject,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [for (final s in subjects) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setSheet(() => subject = v ?? subject),
              ),
              DropdownButtonFormField<String>(
                initialValue: teacher,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Teacher'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('No teacher yet')),
                  for (final t in teachers) DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setSheet(() => teacher = v ?? ''),
              ),
              TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room (optional)'),
                  onChanged: (_) => setSheet(() {})),
              const SizedBox(height: 14),
              for (final c in conflicts)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.isError ? ac.redBg : ac.orgBg, borderRadius: BorderRadius.circular(Rad.sm)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(c.isError ? Icons.block_rounded : Icons.warning_amber_rounded,
                        size: 16, color: c.isError ? ac.red : ac.org),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.message, style: GoogleFonts.inter(fontSize: 12, color: c.isError ? ac.red : ac.org))),
                  ]),
                ),
              const SizedBox(height: 8),
              PrimaryBtn(
                label: errors.isNotEmpty
                    ? 'Fix the conflict to save'
                    : warnings.isNotEmpty ? 'Save anyway' : (existing == null ? 'Add period' : 'Save'),
                loading: saving,
                onTap: errors.isNotEmpty || saving ? () {} : save,
              ),
            ]),
          ),
        );
      }),
    );
    startCtrl.dispose();
    endCtrl.dispose();
    roomCtrl.dispose();
  }
}

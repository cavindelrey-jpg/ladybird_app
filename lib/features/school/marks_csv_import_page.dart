// lib/features/school/marks_csv_import_page.dart
// Architecture brief item 21: an admin/teacher shouldn't have to remember
// a CSV shape from scratch, and should be able to hand the template to
// someone else (a clerk, another staff member, an AI agent) to fill in.
// Download -> populate elsewhere -> upload -> validate -> import, exactly
// the flow item 21 describes. Every imported row goes through the SAME
// canRecordMarksFor() permission check as manual single-mark entry
// (marks_entry_page.dart) -- a bulk CSV must not be a way to bypass the
// per-assignment restriction items 22-24 establish; each row still
// becomes an individual write, so firestore.rules' marks/{id} rule
// enforces this server-side too, row by row.
//
// Parsing/validation/matching lives in core/marks_csv.dart (unit tested
// with a 60-student class in test/marks_csv_test.dart). Students are
// matched against each class's roster -- one query per class -- instead
// of a platform-wide name search per row.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_mark.dart';
import '../../core/marks_csv.dart';
import '../../repositories/school_marks_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

class MarksImportResult {
  final int count;
  final String? classLevel;
  final String? subject;
  final AcademicSequence? sequence;
  final String? academicYear;

  const MarksImportResult({
    required this.count,
    this.classLevel,
    this.subject,
    this.sequence,
    this.academicYear,
  });
}

class MarksCsvImportPage extends StatefulWidget {
  final AppUser staff;
  const MarksCsvImportPage({super.key, required this.staff});

  @override
  State<MarksCsvImportPage> createState() => _MarksCsvImportPageState();
}

class _MarksCsvImportPageState extends State<MarksCsvImportPage> {
  bool _busy = false;
  String? _fileName;
  List<MarksImportRow> _rows = [];
  int _importedCount = 0;
  int _failedCount = 0;
  bool get _imported => _importedCount > 0 || _failedCount > 0;
  String? _importError;

  MarksImportResult? get _importResult {
    if (_importedCount <= 0) return null;
    final valid = _rows.where((r) => r.isValid && r.resolved != null).toList();
    if (valid.isEmpty) return MarksImportResult(count: _importedCount);
    final m = valid.first.resolved!;
    return MarksImportResult(
      count: _importedCount,
      classLevel: m.classLevel,
      subject: m.subject,
      sequence: m.sequence,
      academicYear: m.academicYear,
    );
  }

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final csv = generateMarksCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/marks_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Marks CSV Import Template');
    } catch (e) {
      if (mounted) showToast(context, 'Could not generate the template file.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndValidate() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
    } catch (e) {
      // Permission denied / no picker available: used to escape as an
      // uncaught error, so the button just appeared to do nothing.
      if (mounted) showToast(context, 'Couldn\'t open the file picker. Check storage permission and try again.', isError: true);
      return;
    }
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _rows = [];
      _importedCount = 0;
      _failedCount = 0;
      _importError = null;
      _fileName = result!.files.single.name;
    });

    try {
      final String content;
      try {
        content = await File(path).readAsString();
      } on FileSystemException {
        setState(() => _importError = 'That file couldn\'t be opened. Save it as "CSV UTF-8" and try again.');
        return;
      } on FormatException {
        setState(() => _importError = 'That file isn\'t readable text — is it an .xlsx renamed to .csv? Export it as "CSV UTF-8".');
        return;
      }
      final table = decodeCsv(content);
      final rosters = <String, List<RosterStudent>>{};
      for (final cls in MarksImportPlan.classLevelsIn(table)) {
        final res = await SchoolMarksRepository.instance.classRoster(widget.staff.schoolId ?? '', cls);
        if (res is Failure<List<RosterStudent>>) {
          setState(() => _importError = res.message);
          return;
        }
        rosters[cls] = (res as Success<List<RosterStudent>>).value;
      }
      final plan = planMarksImport(
        table: table,
        rosters: rosters,
        canRecord: (subject, cls) => widget.staff.canRecordMarksFor(subject: subject, classLevel: cls),
        schoolId: widget.staff.schoolId ?? '',
        teacherName: widget.staff.name,
        gradedBy: widget.staff.id,
        defaultYear: DateTime.now().year.toString(),
      );
      setState(() {
        _importError = plan.fileError;
        _rows = plan.rows;
        if (plan.fileError == null && plan.rows.isEmpty) _importError = 'The file has a header but no marks.';
      });
    } catch (e) {
      setState(() => _importError = 'Could not read that file as CSV.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importValidRows() async {
    final valid = _rows.where((r) => r.isValid).toList();
    if (valid.isEmpty) return;
    setState(() => _busy = true);
    final failures = await SchoolMarksRepository.instance.upsertMany([for (final r in valid) r.resolved!]);
    if (!mounted) return;
    for (final r in valid) {
      final err = failures[r.resolved!.studentId];
      if (err != null) {
        r.error = err;
        r.resolved = null;
      }
    }
    setState(() {
      _importedCount = valid.length - failures.length;
      _failedCount = failures.length;
      _busy = false;
    });
    showToast(context,
        failures.isEmpty ? 'Imported all $_importedCount marks.' : 'Imported $_importedCount, ${failures.length} failed.',
        isError: failures.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final validCount = _rows.where((r) => r.isValid).length;
    final errorCount = _rows.length - validCount;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        title: Text('Upload Marks CSV', style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
        leading: BackButton(
          color: ac.txt,
          onPressed: () => Navigator.of(context).pop(_importResult ?? (_importedCount > 0)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Required columns', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
              const SizedBox(height: 6),
              Text(
                'studentName, classLevel, subject, sequence, academicYear, score, maxScore.\n'
                'sequence must be one of: ${AcademicSequence.values.map((s) => s.name).join(', ')} '
                '(t=term, s=sequence within the term).\n'
                'studentName must exactly match a student already in that class at your school. '
                'Download the template below for a ready-to-fill example row.',
                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2, height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _downloadTemplate,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Get template'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _pickAndValidate,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload CSV'),
              ),
            ),
          ]),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Text('File: $_fileName', style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
          ],
          if (_importError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Text(_importError!, style: GoogleFonts.inter(fontSize: 12.5, color: ac.red)),
            ),
          ],
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('$validCount valid, $errorCount need attention',
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 10),
            // Problems first -- in a 60-row file they used to be scattered
            // among the valid rows.
            ...[..._rows.where((r) => !r.isValid), ..._rows.where((r) => r.isValid)].map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: r.isValid ? ac.grnBg : ac.redBg,
                    borderRadius: BorderRadius.circular(Rad.sm),
                  ),
                  child: Row(children: [
                    Icon(r.isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                        size: 16, color: r.isValid ? ac.grn : ac.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Line ${r.lineNumber}: ${r.studentName} · ${r.raw['subject'] ?? ''} '
                        '${r.isValid ? (_imported ? '— saved' : '— ready') : '— ${r.error}'}',
                        style: GoogleFonts.inter(fontSize: 12, color: r.isValid ? ac.grn : ac.red),
                      ),
                    ),
                  ]),
                )),
            const SizedBox(height: 12),
            if (!_imported)
              PrimaryBtn(
                label: validCount == 0 ? 'Nothing to import' : 'Import $validCount Valid Row${validCount == 1 ? '' : 's'}',
                loading: _busy,
                onTap: validCount == 0 ? () {} : _importValidRows,
              ),
          ],
          if (_importedCount > 0 || _failedCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _failedCount == 0 ? ac.grnBg : ac.surf,
                borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: _failedCount == 0 ? ac.grn : ac.bdr2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: ac.grn, size: 20),
                      const SizedBox(width: 8),
                      Text('Import Completed',
                          style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Imported $_importedCount mark(s) successfully.'
                    '${_failedCount > 0 ? ' $_failedCount failed (marked in red above).' : ''}',
                    style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
                  ),
                  if (_importResult?.classLevel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${_importResult!.classLevel} · ${_importResult!.subject ?? 'All subjects'} · ${_importResult!.sequence?.name.toUpperCase() ?? ''}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ac.txt),
                    ),
                  ],
                  const SizedBox(height: 12),
                  PrimaryBtn(
                    label: _importResult?.classLevel != null
                        ? 'Done — View ${_importResult!.classLevel} Marks'
                        : 'Done — View Recorded Marks',
                    icon: Icons.assessment_rounded,
                    onTap: () => Navigator.of(context).pop(_importResult ?? true),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _imported
              ? PrimaryBtn(
                  label: _importResult?.classLevel != null
                      ? 'Done — View ${_importResult!.classLevel} Marks'
                      : 'Done — View Recorded Marks',
                  icon: Icons.assessment_rounded,
                  onTap: () => Navigator.of(context).pop(_importResult ?? true),
                )
              : (validCount > 0
                  ? PrimaryBtn(
                      label: validCount == 0 ? 'Nothing to import' : 'Import $validCount Valid Row${validCount == 1 ? '' : 's'}',
                      loading: _busy,
                      onTap: validCount == 0 ? () {} : _importValidRows,
                    )
                  : const SizedBox.shrink()),
        ),
      ),
    );
  }
}

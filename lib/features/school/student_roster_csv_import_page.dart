// lib/features/school/student_roster_csv_import_page.dart
// Bulk CSV import for School Student Records / Class Lists.
// Follows the canonical reference pattern of marks_csv_import_page.dart.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/result.dart';
import '../../core/student_roster_csv.dart';
import '../../models/app_user.dart';
import '../../models/student_record.dart';
import '../../repositories/student_roster_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class StudentRosterCsvImportPage extends StatefulWidget {
  final AppUser staff;
  final String? targetClass;
  const StudentRosterCsvImportPage({super.key, required this.staff, this.targetClass});

  @override
  State<StudentRosterCsvImportPage> createState() => _StudentRosterCsvImportPageState();
}

class _StudentRosterCsvImportPageState extends State<StudentRosterCsvImportPage> {
  bool _busy = false;
  String? _fileName;
  StudentRosterPlan _plan = const StudentRosterPlan();
  int _importedCount = 0;
  int _failedCount = 0;
  bool get _imported => _importedCount > 0 || _failedCount > 0;
  String? _importError;

  String get _schoolId => widget.staff.schoolId ?? '';

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final csv = generateStudentRosterCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/student_roster_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Student roster import template');
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
      if (mounted) {
        showToast(context, 'Couldn\'t open the file picker. Check storage permission and try again.', isError: true);
      }
      return;
    }
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _plan = const StudentRosterPlan();
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
      }

      final existingRes = await StudentRosterRepository.instance.getStudents(_schoolId);
      final existing = existingRes is Success<List<StudentRecord>> ? existingRes.value : null;

      final plan = parseStudentRosterCsv(
        content,
        _schoolId,
        existingStudents: existing,
      );

      if (!mounted) return;
      setState(() {
        _plan = plan;
        _importError = plan.fileError;
      });
    } catch (e) {
      if (mounted) setState(() => _importError = 'Failed to parse file: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importValid() async {
    final validRecords = _plan.valid.map((r) => r.resolved!).toList();
    if (validRecords.isEmpty) return;

    setState(() {
      _busy = true;
      _importedCount = 0;
      _failedCount = 0;
    });

    final res = await StudentRosterRepository.instance.batchUpsert(_schoolId, validRecords);
    if (!mounted) return;

    if (res is Success<void>) {
      setState(() {
        _busy = false;
        _importedCount = validRecords.length;
        _failedCount = 0;
      });
      showToast(context, 'Imported ${validRecords.length} student(s) successfully.');
    } else {
      setState(() {
        _busy = false;
        _importedCount = 0;
        _failedCount = validRecords.length;
        _importError = (res as Failure).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final rows = _plan.rows;
    final validRows = _plan.valid;
    final errorRows = _plan.errors;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        leading: BackButton(
          color: ac.txt,
          onPressed: () {
            final validClasses = _plan.valid.map((r) => r.resolved?.classLevel).whereType<String>().toSet().toList();
            final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
            Navigator.of(context).pop(_importedCount > 0 ? (primaryClass ?? true) : null);
          },
        ),
        title: Text('Import Student Roster CSV',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _instructionCard(ac),
          const SizedBox(height: 16),
          _actionRow(ac),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_importError != null) ...[
            const SizedBox(height: 16),
            _errorBanner(ac, _importError!),
          ],
          if (_imported) ...[
            const SizedBox(height: 16),
            _importSummaryCard(ac),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            _statsRow(ac, rows.length, validRows.length, errorRows.length),
            const SizedBox(height: 12),
            _reviewList(ac, rows),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _imported
              ? PrimaryBtn(
                  label: () {
                    final validClasses = _plan.valid.map((r) => r.resolved?.classLevel).whereType<String>().toSet().toList();
                    final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
                    return primaryClass != null ? 'Done — View $primaryClass Roster' : 'Done — View Class Roster';
                  }(),
                  icon: Icons.people_alt_rounded,
                  onTap: () {
                    final validClasses = _plan.valid.map((r) => r.resolved?.classLevel).whereType<String>().toSet().toList();
                    final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
                    Navigator.of(context).pop(primaryClass ?? true);
                  },
                )
              : (validRows.isNotEmpty
                  ? PrimaryBtn(
                      label: _busy ? 'Importing...' : 'Import ${validRows.length} Student(s)',
                      icon: Icons.check_circle_rounded,
                      onTap: _busy ? () {} : _importValid,
                    )
                  : const SizedBox.shrink()),
        ),
      ),
    );
  }

  Widget _instructionCard(AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_outlined, color: ac.primary, size: 20),
              const SizedBox(width: 8),
              Text('Bulk Class List Instructions',
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Download the template to see the required CSV columns.\n'
            '2. Fill in student names, class level (e.g. "Form 4", "Form 5"), matricule, and parent contact.\n'
            '3. Upload your completed CSV. The system validates student records and identifies any duplicate matricules.\n'
            '4. Tap "Import Students" to bulk create the roster for your school.',
            style: GoogleFonts.inter(fontSize: 12, color: ac.txt2, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(AppColors ac) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _downloadTemplate,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download Template'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: ac.bdr),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _pickAndValidate,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(_fileName == null ? 'Select CSV File' : 'Change CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statsRow(AppColors ac, int total, int valid, int errors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(ac, 'Total Rows: $total', ac.surf3, ac.txt),
        _chip(ac, 'Valid: $valid', ac.grnBg, ac.grn),
        if (errors > 0) _chip(ac, 'Errors: $errors', ac.redBg, ac.red),
      ],
    );
  }

  Widget _chip(AppColors ac, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _errorBanner(AppColors ac, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(Rad.md)),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: ac.red, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: ac.red))),
        ],
      ),
    );
  }

  Widget _importSummaryCard(AppColors ac) {
    final validClasses = _plan.valid.map((r) => r.resolved?.classLevel).whereType<String>().toSet().toList();
    final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
    return Container(
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
          Text('$_importedCount student record(s) added/updated successfully.'
              '${_failedCount > 0 ? ' $_failedCount record(s) failed.' : ''}',
              style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          const SizedBox(height: 12),
          PrimaryBtn(
            label: primaryClass != null ? 'Done — View $primaryClass Roster' : 'Done — View Class Roster',
            icon: Icons.people_alt_rounded,
            onTap: () => Navigator.of(context).pop(primaryClass ?? true),
          ),
        ],
      ),
    );
  }

  Widget _reviewList(AppColors ac, List<StudentRosterImportRow> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview & Validation',
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
        const SizedBox(height: 8),
        for (final r in rows) _rowTile(ac, r),
      ],
    );
  }

  Widget _rowTile(AppColors ac, StudentRosterImportRow r) {
    final isErr = r.error != null;
    final isWarn = r.warning != null;
    final s = r.resolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: isErr ? ac.red : (isWarn ? ac.org : ac.bdr2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Line ${r.lineNumber}: ',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ac.muted)),
              Expanded(
                child: Text(
                  s?.name ?? r.raw['studentName'] ?? 'Unknown Student',
                  style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt),
                ),
              ),
              if (r.isValid)
                Icon(Icons.check_circle_rounded, color: ac.grn, size: 18)
              else if (isErr)
                Icon(Icons.cancel_rounded, color: ac.red, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (s != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(4)),
                  child: Text(s.classLevel,
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary)),
                ),
              if (s?.matricule != null && s!.matricule!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(4)),
                  child: Text('Matricule: ${s.matricule}',
                      style: GoogleFonts.inter(fontSize: 10.5, color: ac.txt2)),
                ),
              if (s?.parentContact != null && s!.parentContact!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(4)),
                  child: Text('Contact: ${s.parentContact}',
                      style: GoogleFonts.inter(fontSize: 10.5, color: ac.txt2)),
                ),
            ],
          ),
          if (isErr) ...[
            const SizedBox(height: 6),
            Text(r.error!, style: GoogleFonts.inter(fontSize: 11, color: ac.red, fontWeight: FontWeight.w600)),
          ],
          if (isWarn && !isErr) ...[
            const SizedBox(height: 6),
            Text(r.warning!, style: GoogleFonts.inter(fontSize: 11, color: ac.org)),
          ],
        ],
      ),
    );
  }
}

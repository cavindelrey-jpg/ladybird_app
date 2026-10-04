// lib/features/school/teacher_csv_import_page.dart
// Bulk CSV import for Teacher Teaching Assignments and Class Master status.
// Follows the canonical reference pattern of marks_csv_import_page.dart.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/result.dart';
import '../../core/teacher_csv.dart';
import '../../models/app_user.dart';
import '../../repositories/school_repository.dart';
import '../../repositories/teacher_management_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class TeacherCsvImportPage extends StatefulWidget {
  final AppUser admin;
  const TeacherCsvImportPage({super.key, required this.admin});

  @override
  State<TeacherCsvImportPage> createState() => _TeacherCsvImportPageState();
}

class _TeacherCsvImportPageState extends State<TeacherCsvImportPage> {
  bool _busy = false;
  String? _fileName;
  TeacherAssignmentPlan _plan = const TeacherAssignmentPlan();
  int _importedCount = 0;
  int _failedCount = 0;
  bool get _imported => _importedCount > 0 || _failedCount > 0;
  String? _importError;

  String get _schoolId => widget.admin.schoolId ?? '';

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final csv = generateTeacherCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/teacher_assignments_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Teacher assignments import template');
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
      _plan = const TeacherAssignmentPlan();
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

      final staff = await TeacherManagementRepository.instance.staffOnce(_schoolId);
      final subRes = await SchoolRepository.instance.getSubjects(_schoolId);
      final subjects = subRes is Success<List<String>> ? subRes.value : null;

      final plan = parseTeacherAssignmentsCsv(
        content,
        existingStaff: staff,
        availableSubjects: subjects,
        allowNewTeachers: true,
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
    final updates = _plan.teacherUpdates;
    if (updates.isEmpty) return;

    setState(() {
      _busy = true;
      _importedCount = 0;
      _failedCount = 0;
    });

    int success = 0;
    int failed = 0;

    for (final entry in updates.entries) {
      final teacherId = entry.key;
      final info = entry.value;

      if (info.isNewTeacher) {
        await TeacherManagementRepository.instance.createOrRegisterStaff(
          schoolId: _schoolId,
          id: teacherId,
          name: info.teacherName,
          email: info.email,
          assignments: info.assignments,
          classMasterOfClass: info.classMasterOf,
        );
        success++;
      } else {
        final assignRes = await TeacherManagementRepository.instance.setTeachingAssignments(
          teacherId,
          info.assignments,
        );

        if (info.classMasterOf != null) {
          await TeacherManagementRepository.instance.setClassMasterOfClass(
            teacherId,
            info.classMasterOf,
          );
        }

        if (assignRes is Success<void>) {
          success++;
        } else {
          failed++;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _importedCount = success;
      _failedCount = failed;
    });

    if (success > 0) {
      showToast(context, 'Successfully updated $success teacher(s).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final rows = _plan.rows;
    final validRows = _plan.valid;
    final errorRows = _plan.errors;
    final teacherCount = _plan.teacherUpdates.length;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        leading: BackButton(
          color: ac.txt,
          onPressed: () => Navigator.of(context).pop(_importedCount > 0),
        ),
        title: Text('Import Teacher Assignments CSV',
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
            _statsRow(ac, rows.length, validRows.length, errorRows.length, teacherCount),
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
                  label: 'Done — View Staff Assignments',
                  icon: Icons.people_alt_rounded,
                  onTap: () => Navigator.of(context).pop(_importedCount > 0),
                )
              : (validRows.isNotEmpty
                  ? PrimaryBtn(
                      label: _busy ? 'Importing...' : 'Import Assignments for $teacherCount Teacher(s)',
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
              Icon(Icons.badge_outlined, color: ac.primary, size: 20),
              const SizedBox(width: 8),
              Text('Bulk Teacher Assignment Instructions',
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Download the template to see the required CSV columns.\n'
            '2. Fill in teacher name or email, subjects, classes, and Class Master status.\n'
            '3. Comma or semicolon separate multiple subjects (e.g. "Maths, Physics") or classes (e.g. "Form 4, Form 5").\n'
            '4. Upload your CSV here. Review matched teachers and validation before applying.',
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

  Widget _statsRow(AppColors ac, int total, int valid, int errors, int teachers) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(ac, 'Total Rows: $total', ac.surf3, ac.txt),
        _chip(ac, 'Valid: $valid', ac.grnBg, ac.grn),
        if (errors > 0) _chip(ac, 'Errors: $errors', ac.redBg, ac.red),
        _chip(ac, 'Unique Teachers: $teachers', ac.primaryBg, ac.primary),
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
          Text('$_importedCount teacher(s) updated successfully.'
              '${_failedCount > 0 ? ' $_failedCount update(s) failed.' : ''}',
              style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          const SizedBox(height: 12),
          PrimaryBtn(
            label: 'Done — View Staff Assignments',
            icon: Icons.people_alt_rounded,
            onTap: () => Navigator.of(context).pop(_importedCount > 0),
          ),
        ],
      ),
    );
  }

  Widget _reviewList(AppColors ac, List<TeacherImportRow> rows) {
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

  Widget _rowTile(AppColors ac, TeacherImportRow r) {
    final isErr = r.error != null;
    final isWarn = r.warning != null;

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
                  r.resolvedTeacherName ?? r.raw['teacherName'] ?? r.raw['teacherEmail'] ?? 'Unknown',
                  style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt),
                ),
              ),
              if (r.isValid)
                Icon(Icons.check_circle_rounded, color: ac.grn, size: 18)
              else if (isErr)
                Icon(Icons.cancel_rounded, color: ac.red, size: 18),
            ],
          ),
          if (r.resolvedTeacherEmail != null && r.resolvedTeacherEmail!.isNotEmpty)
            Text(r.resolvedTeacherEmail!, style: GoogleFonts.inter(fontSize: 11, color: ac.muted)),
          const SizedBox(height: 6),
          if (r.assignments.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in r.assignments)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(4)),
                    child: Text('${a.subject} · ${a.classLevel}',
                        style: GoogleFonts.inter(fontSize: 10.5, color: ac.txt2)),
                  ),
              ],
            ),
          if (r.classMasterOf != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(4)),
              child: Text('Class Master: ${r.classMasterOf}',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.gold)),
            ),
          ],
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

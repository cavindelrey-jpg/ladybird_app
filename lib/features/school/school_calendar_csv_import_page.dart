// lib/features/school/school_calendar_csv_import_page.dart
// Bulk CSV import for School Calendar / Program of Activities.
// Mirrors marks_csv_import_page.dart and timetable_csv_import_page.dart.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/school_calendar_csv.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_calendar_event.dart';
import '../../repositories/school_calendar_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class SchoolCalendarCsvImportPage extends StatefulWidget {
  final AppUser staff;
  SchoolCalendarCsvImportPage({super.key, AppUser? staff, AppUser? user})
      : staff = (staff ?? user)!;

  @override
  State<SchoolCalendarCsvImportPage> createState() => _SchoolCalendarCsvImportPageState();
}

class _SchoolCalendarCsvImportPageState extends State<SchoolCalendarCsvImportPage> {
  SchoolCalendarPlan _plan = const SchoolCalendarPlan();
  bool _busy = false;
  String? _fileName;
  String? _importError;
  int _importedCount = 0;
  int _failedCount = 0;
  bool _imported = false;

  String get _schoolId => widget.staff.schoolId ?? '';

  Future<void> _downloadTemplate() async {
    try {
      final csv = generateSchoolCalendarCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/program_of_activities_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Program of Activities CSV Template for Academia',
      );
    } catch (e) {
      if (mounted) {
        showToast(context, 'Could not generate template: $e', isError: true);
      }
    }
  }

  Future<void> _pickAndParseCsv() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
    } catch (e) {
      if (mounted) {
        showToast(context, 'Couldn\'t open the file picker: $e', isError: true);
      }
      return;
    }

    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _plan = const SchoolCalendarPlan();
      _importedCount = 0;
      _failedCount = 0;
      _importError = null;
      _imported = false;
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

      final plan = parseSchoolCalendarCsv(content, _schoolId);
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

    final res = await SchoolCalendarRepository.instance.batchCreate(_schoolId, validRecords);
    if (!mounted) return;

    if (res is Success<int>) {
      setState(() {
        _busy = false;
        _importedCount = res.value;
        _failedCount = 0;
        _imported = true;
      });
      showToast(context, 'Imported ${res.value} activity records successfully.');
    } else {
      setState(() {
        _busy = false;
        _importedCount = 0;
        _failedCount = validRecords.length;
        _imported = false;
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Will notify parent screen if records were imported
      },
      child: Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(
          backgroundColor: ac.bg,
          elevation: 0,
          leading: BackButton(
            color: ac.txt,
            onPressed: () => Navigator.of(context).pop(_importedCount > 0),
          ),
          title: Text(
            'Import Program of Activities CSV',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt),
          ),
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
              const SizedBox(height: 16),
              if (validRows.isNotEmpty && !_imported) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _importValid,
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text(
                      'Import ${validRows.length} Valid Activities',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Preview & Validation Details',
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
              const SizedBox(height: 10),
              ...rows.map((r) => _rowCard(ac, r)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _instructionCard(AppColors ac) {
    return ACard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, color: ac.primary, size: 20),
              const SizedBox(width: 8),
              Text('Bulk Activity Planning Workflow',
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Download the standardized CSV template below.\n'
            '2. Fill in your annual/termly activities externally (Excel, Sheets, etc.).\n'
            '3. Upload your completed CSV. Academia validates every row and imports all valid events.\n'
            '4. Export your completed program as PDF or Word at any time.',
            style: GoogleFonts.inter(fontSize: 12, color: ac.txt2, height: 1.4),
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
            key: const Key('download_calendar_template_btn'),
            onPressed: _downloadTemplate,
            icon: Icon(Icons.download_rounded, color: ac.primary, size: 18),
            label: Text('Download Template', style: TextStyle(color: ac.primary, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: ac.bdr),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('upload_calendar_csv_btn'),
            onPressed: _pickAndParseCsv,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: Text(_fileName != null ? 'Change File' : 'Upload Completed CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(AppColors ac, String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ac.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: ac.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: ac.red, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _importSummaryCard(AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import Complete',
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  '• $_importedCount records imported successfully\n'
                  '• $_failedCount records require correction',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(AppColors ac, int total, int valid, int errors) {
    return Row(
      children: [
        _statBadge(ac, 'Total Rows', '$total', ac.txt2),
        const SizedBox(width: 8),
        _statBadge(ac, 'Valid', '$valid', Colors.green),
        const SizedBox(width: 8),
        _statBadge(ac, 'Errors', '$errors', errors > 0 ? ac.red : ac.txt2),
      ],
    );
  }

  Widget _statBadge(AppColors ac, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ac.bdr2),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: ac.muted)),
          ],
        ),
      ),
    );
  }

  Widget _rowCard(AppColors ac, SchoolCalendarImportRow r) {
    final isValid = r.isValid;
    final hasWarning = r.warning != null;
    final borderColor = !isValid ? ac.red : (hasWarning ? Colors.orange : ac.bdr2);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isValid ? Colors.green.withValues(alpha: 0.15) : ac.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Row ${r.lineNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isValid ? Colors.green.shade800 : ac.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.raw['activity']?.isNotEmpty == true ? r.raw['activity']! : 'Untitled Activity',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ac.txt),
                ),
              ),
              Text(
                r.raw['date'] ?? '',
                style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2),
              ),
            ],
          ),
          if (r.error != null) ...[
            const SizedBox(height: 6),
            Text('❌ ${r.error}', style: TextStyle(color: ac.red, fontSize: 11.5)),
          ],
          if (r.warning != null) ...[
            const SizedBox(height: 6),
            Text('⚠️ ${r.warning}', style: TextStyle(color: Colors.orange.shade800, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

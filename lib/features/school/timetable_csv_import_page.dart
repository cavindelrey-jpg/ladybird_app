// lib/features/school/timetable_csv_import_page.dart
// Bulk CSV import for School Timetables.
// Follows the same pattern as Marks CSV import:
// Download template -> Fill externally -> Upload -> Validate & Conflict check -> Bulk import.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../core/timetable_csv.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

class TimetableCsvImportPage extends StatefulWidget {
  final AppUser user;
  const TimetableCsvImportPage({super.key, required this.user});

  @override
  State<TimetableCsvImportPage> createState() => _TimetableCsvImportPageState();
}

class _TimetableCsvImportPageState extends State<TimetableCsvImportPage> {
  bool _busy = false;
  String? _fileName;
  List<TimetableImportRow> _rows = [];
  int _importedCount = 0;
  int _failedCount = 0;
  bool get _imported => _importedCount > 0 || _failedCount > 0;
  String? _importError;

  String get _schoolId => widget.user.schoolId ?? '';

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final csv = generateTimetableCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/timetable_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'School Timetable CSV Template');
    } catch (e) {
      if (mounted) showToast(context, 'Could not generate timetable template file.', isError: true);
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
    } catch (_) {
      if (mounted) showToast(context, 'Couldn\'t open file picker. Check storage permissions and try again.', isError: true);
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
      }

      if (content.contains('\u0000')) {
        setState(() => _importError = 'That file isn\'t readable text — is it an .xlsx renamed to .csv? Export it as "CSV UTF-8".');
        return;
      }

      final existingSlots = await SchoolTimetableRepository.instance.getForSchoolOnce(_schoolId);
      final parsed = parseTimetableCsv(content, _schoolId, existingSchoolSlots: existingSlots);

      if (parsed.fileError != null) {
        setState(() => _importError = parsed.fileError);
        return;
      }

      setState(() => _rows = parsed.rows);
    } catch (_) {
      setState(() => _importError = 'Could not read that file as CSV.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importValidRows() async {
    final validSlots = _rows.where((r) => r.isValid).map((r) => r.resolved!).toList();
    if (validSlots.isEmpty) return;

    setState(() => _busy = true);
    int ok = 0;
    int fail = 0;

    final result = await SchoolTimetableRepository.instance.batchAdd(validSlots);
    if (result is Success<int>) {
      ok = result.value;
    } else {
      // Fall back to individual writes if batch fails
      for (final s in validSlots) {
        final res = await SchoolTimetableRepository.instance.add(s);
        if (res is Success) {
          ok++;
        } else {
          fail++;
        }
      }
    }

    if (mounted) {
      setState(() {
        _importedCount = ok;
        _failedCount = fail;
        _busy = false;
      });
      showToast(context, 'Imported $ok timetable periods.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final validCount = _rows.where((r) => r.isValid).length;
    final errorCount = _rows.where((r) => !r.isValid).length;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        leading: BackButton(
          color: ac.txt,
          onPressed: () {
            final validClasses = _rows.where((r) => r.isValid).map((r) => r.classLevel).toSet().toList();
            final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
            Navigator.of(context).pop(_importedCount > 0 ? (primaryClass ?? true) : null);
          },
        ),
        title: Text('Upload Timetable CSV', style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _guideCard(context, ac),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _downloadTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download Template'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ac.primary,
                    side: BorderSide(color: ac.primary),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryBtn(
                  label: _busy ? 'Reading…' : 'Upload CSV',
                  onTap: _busy ? () {} : () => _pickAndValidate(),
                ),
              ),
            ],
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Text('Selected: $_fileName', style: AppText.caption.copyWith(color: ac.txt2)),
          ],
          if (_importError != null) ...[
            const SizedBox(height: 16),
            _errorBanner(_importError!, ac),
          ],
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 18),
            _statsRow(validCount, errorCount, ac),
            const SizedBox(height: 12),
            _rowsList(ac),
            const SizedBox(height: 18),
            if (validCount > 0 && !_imported)
              PrimaryBtn(
                label: _busy ? 'Saving…' : 'Import $validCount Valid Periods',
                onTap: _busy ? () {} : () => _importValidRows(),
              ),
            if (_imported) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Rad.sm),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Successfully imported $_importedCount periods.' +
                            (_failedCount > 0 ? ' ($_failedCount failed)' : ''),
                        style: AppText.bodySm.copyWith(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryBtn(
                label: () {
                  final validClasses = _rows.where((r) => r.isValid).map((r) => r.classLevel).toSet().toList();
                  final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
                  return primaryClass != null ? 'Done — View $primaryClass Timetable' : 'Done — View Updated Timetable';
                }(),
                icon: Icons.calendar_month_rounded,
                onTap: () {
                  final validClasses = _rows.where((r) => r.isValid).map((r) => r.classLevel).toSet().toList();
                  final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
                  Navigator.pop(context, primaryClass ?? true);
                },
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _imported
              ? PrimaryBtn(
                  label: () {
                    final validClasses = _rows.where((r) => r.isValid).map((r) => r.classLevel).toSet().toList();
                    final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
                    return primaryClass != null ? 'Done — View $primaryClass Timetable' : 'Done — View Updated Timetable';
                  }(),
                  icon: Icons.calendar_month_rounded,
                  onTap: () {
                    final validClasses = _rows.where((r) => r.isValid).map((r) => r.classLevel).toSet().toList();
                    final primaryClass = validClasses.isNotEmpty ? validClasses.first : null;
                    Navigator.pop(context, primaryClass ?? true);
                  },
                )
              : (validCount > 0
                  ? PrimaryBtn(
                      label: _busy ? 'Saving…' : 'Import $validCount Valid Periods',
                      onTap: _busy ? () {} : () => _importValidRows(),
                    )
                  : const SizedBox.shrink()),
        ),
      ),
    );
  }

  Widget _guideCard(BuildContext context, AppColors ac) {
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
              Icon(Icons.calendar_month_outlined, size: 20, color: ac.primary),
              const SizedBox(width: 8),
              Text('Bulk Timetable Setup', style: AppText.subtitle.copyWith(fontSize: 14, color: ac.txt)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Download the CSV template with pre-set columns.\n'
            '2. Fill in periods (Class, Day, Time, Subject, Teacher, Room).\n'
            '3. Upload the completed CSV — the app validates times and checks for clashes.\n'
            '4. Import valid periods with a single tap.',
            style: AppText.bodySm.copyWith(color: ac.txt2, height: 1.5, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Rad.sm),
        border: Border.all(color: ac.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: ac.red, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.bodySm.copyWith(color: ac.red))),
        ],
      ),
    );
  }

  Widget _statsRow(int valid, int errors, AppColors ac) {
    return Row(
      children: [
        _statChip(label: 'Total Rows', count: _rows.length, color: ac.txt2, ac: ac),
        const SizedBox(width: 8),
        _statChip(label: 'Valid', count: valid, color: Colors.green, ac: ac),
        if (errors > 0) ...[
          const SizedBox(width: 8),
          _statChip(label: 'Errors', count: errors, color: ac.red, ac: ac),
        ],
      ],
    );
  }

  Widget _statChip({required String label, required int count, required Color color, required AppColors ac}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Rad.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text('$count $label', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _rowsList(AppColors ac) {
    return Column(
      children: _rows.map((r) {
        final isValid = r.isValid;
        final slot = r.resolved;
        final title = slot != null
            ? '${slot.classLevel} · ${slot.subject}'
            : (r.raw['subject']?.isNotEmpty == true ? r.raw['subject']! : 'Row #${r.lineNumber}');

        final subtitle = slot != null
            ? '${dayNameFromInt(slot.dayOfWeek)} ${slot.startTime}–${slot.endTime}' +
                (slot.teacherName.isNotEmpty ? ' · ${slot.teacherName}' : '') +
                (slot.room != null ? ' (${slot.room})' : '')
            : '${r.raw['classLevel'] ?? ''} ${r.raw['dayOfWeek'] ?? ''} ${r.raw['startTime'] ?? ''}–${r.raw['endTime'] ?? ''}';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(
              color: isValid ? ac.bdr2 : ac.red.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isValid ? Colors.green : ac.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, color: ac.txt)),
                  ),
                  Text('Line ${r.lineNumber}', style: AppText.caption.copyWith(color: ac.muted, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(subtitle, style: AppText.caption.copyWith(color: ac.txt2)),
              ),
              if (r.error != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(r.error!, style: TextStyle(color: ac.red, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              ],
              if (r.warning != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(r.warning!, style: TextStyle(color: Colors.amber[800], fontSize: 11)),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

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

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_mark.dart';
import '../../repositories/messaging_repository.dart';
import '../../repositories/school_marks_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

const List<String> _kTemplateColumns = [
  'studentName', 'classLevel', 'subject', 'sequence', 'academicYear', 'score', 'maxScore',
];

/// Minimal RFC4180-style CSV encoder. Written directly rather than via
/// package:csv -- a real `flutter analyze` run reported both of that
/// package's expected classes (CsvToListConverter/ListToCsvConverter) as
/// "isn't a class" against the version actually pinned in pubspec.lock
/// (8.0.0), which can't be verified further in this sandbox (no network
/// to check the real published API for that version). Only the shape
/// this page actually needs (a simple comma-delimited grid with basic
/// quoting) -- not a general-purpose CSV library replacement.
String _encodeCsv(List<List<String>> rows) {
  String encodeField(String f) {
    if (f.contains(',') || f.contains('"') || f.contains('\n')) {
      return '"${f.replaceAll('"', '""')}"';
    }
    return f;
  }
  return rows.map((row) => row.map(encodeField).join(',')).join('\n');
}

/// Matching decoder -- handles quoted fields, escaped "" quotes, and
/// \n/\r\n line endings (including newlines embedded inside a quoted
/// field), which is what a real spreadsheet export can produce.
List<List<String>> _decodeCsv(String content) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < content.length) {
    final ch = content[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          field.write('"');
          i += 2;
        } else {
          inQuotes = false;
          i++;
        }
      } else {
        field.write(ch);
        i++;
      }
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      i++;
    } else if (ch == ',') {
      row.add(field.toString());
      field.clear();
      i++;
    } else if (ch == '\n' || ch == '\r') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = [];
      if (ch == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
        i += 2;
      } else {
        i++;
      }
    } else {
      field.write(ch);
      i++;
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

class _ImportRow {
  final int lineNumber;
  final Map<String, String> raw;
  String? error;
  SchoolMark? resolved;
  String? studentDisplayName;
  _ImportRow({required this.lineNumber, required this.raw});
  bool get isValid => error == null && resolved != null;
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
  List<_ImportRow> _rows = [];
  int _importedCount = 0;
  String? _importError;

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final csv = _encodeCsv([
        _kTemplateColumns,
        ['Ada Lovelace', 'Form 5', 'Physics', 't1s1', DateTime.now().year.toString(), '15', '20'],
      ]);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/marks_template.csv');
      await file.writeAsString(csv);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Ladybird marks import template');
    } catch (e) {
      if (mounted) showToast(context, 'Could not generate the template file.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndValidate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _rows = [];
      _importedCount = 0;
      _importError = null;
      _fileName = result!.files.single.name;
    });

    try {
      final content = await File(path).readAsString();
      final table = _decodeCsv(content);
      if (table.isEmpty) {
        setState(() => _importError = 'The file is empty.');
        return;
      }
      final header = table.first.map((c) => c.toString().trim()).toList();
      final missing = _kTemplateColumns.where((c) => !header.contains(c)).toList();
      if (missing.isNotEmpty) {
        setState(() => _importError = 'Missing column(s): ${missing.join(', ')}. Download the template to see the exact format.');
        return;
      }

      final rows = <_ImportRow>[];
      for (var i = 1; i < table.length; i++) {
        final cells = table[i];
        if (cells.every((c) => c.toString().trim().isEmpty)) continue; // skip blank lines
        final raw = <String, String>{
          for (var c = 0; c < header.length && c < cells.length; c++)
            header[c]: cells[c].toString().trim(),
        };
        rows.add(await _validateRow(lineNumber: i + 1, raw: raw));
      }
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _importError = 'Could not read that file as CSV.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_ImportRow> _validateRow({required int lineNumber, required Map<String, String> raw}) async {
    final row = _ImportRow(lineNumber: lineNumber, raw: raw);
    final studentName = raw['studentName'] ?? '';
    final classLevel = raw['classLevel'] ?? '';
    final subject = raw['subject'] ?? '';
    final sequenceKey = raw['sequence'] ?? '';
    final academicYear = raw['academicYear'] ?? '';
    final scoreStr = raw['score'] ?? '';
    final maxScoreStr = raw['maxScore'] ?? '';

    if (studentName.isEmpty || classLevel.isEmpty || subject.isEmpty) {
      row.error = 'studentName, classLevel, and subject are required.';
      return row;
    }
    final sequence = AcademicSequence.fromKey(sequenceKey);
    if (sequence == null) {
      row.error = 'Unknown sequence "$sequenceKey" -- use one of: ${AcademicSequence.values.map((s) => s.name).join(', ')}.';
      return row;
    }
    final score = double.tryParse(scoreStr);
    final maxScore = double.tryParse(maxScoreStr);
    if (score == null || maxScore == null || maxScore <= 0) {
      row.error = 'score/maxScore must be numbers, and maxScore must be greater than 0.';
      return row;
    }
    if (score < 0 || score > maxScore) {
      row.error = 'score ($score) must be between 0 and maxScore ($maxScore).';
      return row;
    }
    if (!widget.staff.canRecordMarksFor(subject: subject, classLevel: classLevel)) {
      row.error = 'You\'re not assigned to teach $subject in $classLevel.';
      return row;
    }

    // Resolve studentName -> a real studentId, scoped to this school +
    // class to cut down on same-name collisions. Ambiguous or missing
    // matches fail closed rather than guessing.
    final candidates = await MessagingRepository.instance.searchUsers(studentName);
    final matches = candidates.where((c) =>
        (c['name'] as String? ?? '').trim().toLowerCase() == studentName.trim().toLowerCase() &&
        (c['institution_id'] as String? ?? '') == (widget.staff.schoolId ?? '') &&
        (c['class_level'] as String? ?? '') == classLevel).toList();
    if (matches.isEmpty) {
      row.error = 'No student named "$studentName" found in $classLevel at your school.';
      return row;
    }
    if (matches.length > 1) {
      row.error = 'Multiple students named "$studentName" in $classLevel -- resolve manually.';
      return row;
    }

    row.studentDisplayName = studentName;
    row.resolved = SchoolMark(
      id: '',
      schoolId: widget.staff.schoolId ?? '',
      studentId: matches.first['id'] as String,
      classLevel: classLevel,
      subject: subject,
      teacherName: widget.staff.name,
      sequence: sequence,
      academicYear: academicYear.isEmpty ? DateTime.now().year.toString() : academicYear,
      score: score,
      maxScore: maxScore,
      gradedBy: widget.staff.id,
    );
    return row;
  }

  Future<void> _importValidRows() async {
    final valid = _rows.where((r) => r.isValid).toList();
    if (valid.isEmpty) return;
    setState(() => _busy = true);
    var count = 0;
    for (final row in valid) {
      final result = await SchoolMarksRepository.instance.upsert(row.resolved!);
      if (result is Success<void>) {
        count++;
      } else if (result is Failure<void>) {
        row.error = result.message;
      }
    }
    if (!mounted) return;
    setState(() {
      _importedCount = count;
      _busy = false;
    });
    showToast(context, 'Imported $count of ${valid.length} rows.');
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
                label: const Text('Download CSV Template'),
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
            ..._rows.map((r) => Container(
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
                        'Line ${r.lineNumber}: ${r.raw['studentName'] ?? ''} · ${r.raw['subject'] ?? ''} '
                        '${r.isValid ? '— ready' : '— ${r.error}'}',
                        style: GoogleFonts.inter(fontSize: 12, color: r.isValid ? ac.grn : ac.red),
                      ),
                    ),
                  ]),
                )),
            const SizedBox(height: 12),
            PrimaryBtn(
              label: 'Import $validCount Valid Row${validCount == 1 ? '' : 's'}',
              loading: _busy,
              onTap: validCount == 0 ? () {} : _importValidRows,
            ),
          ],
          if (_importedCount > 0) ...[
            const SizedBox(height: 16),
            Text('Imported $_importedCount row(s).',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ac.grn)),
          ],
        ],
      ),
    );
  }
}

// lib/services/exam_pdf_export_service.dart
// Production-quality PDF document export for composed examinations.
// Generates a multi-page examination paper matching official school formats,
// complete with digital letterhead, logo, candidate info box, question typography,
// and right-aligned mark allocations.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/examination.dart';
import '../models/exam_question.dart';

class ExamPdfExportService {
  ExamPdfExportService._();
  static final ExamPdfExportService instance = ExamPdfExportService._();

  /// Generates and exports the examination as a PDF document.
  Future<File> exportExaminationPdf({
    required Examination examination,
    SchoolExamTemplate? template,
    bool includeLetterhead = true,
    bool includeSolutions = false,
    Uint8List? customLogoBytes,
  }) async {
    final pdf = pw.Document(
      title: '${examination.title} - ${examination.subject}',
      author: examination.examinerName,
      subject: examination.subject,
    );

    final tmpl = template ?? examination.selectedTemplate ?? const SchoolExamTemplate(
      id: 'default',
      schoolId: '',
      name: 'Default',
      schoolName: 'CFPMI',
    );

    // Try loading logo bytes from asset if custom bytes not supplied
    Uint8List? logoBytes = customLogoBytes;
    if (logoBytes == null) {
      try {
        final byteData = await rootBundle.load('assets/branding/ladybird_logo.jpg');
        logoBytes = byteData.buffer.asUint8List();
      } catch (_) {
        try {
          final byteData = await rootBundle.load('assets/branding/green_hills_logo.jpg');
          logoBytes = byteData.buffer.asUint8List();
        } catch (_) {}
      }
    }

    final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        header: (pw.Context ctx) {
          if (ctx.pageNumber == 1) {
            return pw.Container(); // First page renders full letterhead in body
          }
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${examination.title} — ${examination.subject} (${examination.classLevel})',
                  style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                ),
                pw.Text(
                  tmpl.schoolName,
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            margin: const pw.EdgeInsets.only(top: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Academic Year: ${examination.academicYear}',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
                pw.Text(
                  'Confidential Exam Material',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // ── Official Letterhead ──────────────────────────────────────────
            if (includeLetterhead) ...[
              _buildLetterhead(tmpl, logoImage),
              pw.SizedBox(height: 10),
            ],

            // ── Examination Metadata Header ──────────────────────────────────
            _buildExamHeader(examination),
            pw.SizedBox(height: 10),

            // ── Candidate Info Box ───────────────────────────────────────────
            if (tmpl.includeStudentFields) ...[
              _buildCandidateBox(),
              pw.SizedBox(height: 10),
            ],

            // ── Instructions Box ─────────────────────────────────────────────
            if (tmpl.includeInstructionsBox && examination.instructions.isNotEmpty) ...[
              _buildInstructionsBox(examination.instructions),
              pw.SizedBox(height: 14),
            ],

            // ── Questions Section ────────────────────────────────────────────
            pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                'SECTION A: ALL QUESTIONS MANDATORY',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8),
              ),
            ),
            pw.Divider(thickness: 1, color: PdfColors.black),
            pw.SizedBox(height: 10),

            for (int i = 0; i < examination.questions.length; i++) ...[
              _buildQuestion(i + 1, examination.questions[i], includeSolutions),
              pw.SizedBox(height: 16),
            ],

            // ── Solutions Section (if enabled) ──────────────────────────────
            if (includeSolutions) ...[
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1.5, color: PdfColors.grey800),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Text(
                  'MARKING SCHEME & MODEL SOLUTIONS (CONFIDENTIAL)',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                ),
              ),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600),
              pw.SizedBox(height: 10),
              for (int i = 0; i < examination.questions.length; i++) ...[
                _buildSolution(i + 1, examination.questions[i]),
                pw.SizedBox(height: 10),
              ],
            ],

            pw.SizedBox(height: 24),
            pw.Center(
              child: pw.Text(
                '*** END OF EXAMINATION PAPER ***',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
          ];
        },
      ),
    );

    // Save PDF to file in temporary directory
    final bytes = await pdf.save();
    final tempDir = await getTemporaryDirectory();
    final safeTitle = '${examination.title}_${examination.subject}_${examination.classLevel}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
    final file = File('${tempDir.path}/exam_$safeTitle.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Shares the generated PDF file via the OS share dialog.
  Future<void> sharePdf({
    required Examination examination,
    SchoolExamTemplate? template,
    bool includeLetterhead = true,
    bool includeSolutions = false,
    Uint8List? customLogoBytes,
  }) async {
    final file = await exportExaminationPdf(
      examination: examination,
      template: template,
      includeLetterhead: includeLetterhead,
      includeSolutions: includeSolutions,
      customLogoBytes: customLogoBytes,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: '${examination.title} - ${examination.subject} (${examination.classLevel})',
    );
  }

  // ─── Component Builders ───────────────────────────────────────────────────

  pw.Widget _buildLetterhead(SchoolExamTemplate tmpl, pw.MemoryImage? logoImage) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // National bilingual left header
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'REPUBLIC OF CAMEROON\nPeace - Work - Fatherland\nMINISTRY OF SECONDARY EDUCATION',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, lineSpacing: 1.5),
                ),
              ],
            ),
          ),

          // School Crest in Center
          if (logoImage != null)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10),
              child: pw.Image(logoImage, width: 48, height: 48),
            )
          else
            pw.Container(
              width: 48,
              height: 48,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: PdfColors.grey700, width: 1),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text('CREST', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ),

          // School right header / French bilingual
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'RÉPUBLIQUE DU CAMEROUN\nPaix - Travail - Patrie\nMINISTÈRE DES ENSEIGNEMENTS SECONDAIRES',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, lineSpacing: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildExamHeader(Examination exam) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          pw.Text(
            exam.title.toUpperCase(),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SUBJECT: ${exam.subject.toUpperCase()}',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('CLASS: ${exam.classLevel.toUpperCase()}',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('DURATION: ${exam.durationMinutes} MIN',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('ACADEMIC YEAR: ${exam.academicYear}', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('TOTAL MARKS: ${exam.effectiveTotalMarks} MARKS',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('DATE: ${exam.date.day.toString().padLeft(2, '0')}/${exam.date.month.toString().padLeft(2, '0')}/${exam.date.year}',
                  style: const pw.TextStyle(fontSize: 8.5)),
            ],
          ),
          if (exam.examinerName.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('EXAMINER: ${exam.examinerName}',
                  style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic)),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildCandidateBox() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              'CANDIDATE NAME: _________________________________________',
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'ROLL / MATRICULE: ________________',
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInstructionsBox(String instructions) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('INSTRUCTIONS TO CANDIDATES:',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(instructions, style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3)),
        ],
      ),
    );
  }

  pw.Widget _buildQuestion(int number, ExamQuestion q, bool showSolutions) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Question Number & Marks Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                'QUESTION $number. ${q.topic.isNotEmpty ? '(${q.topic})' : ''}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text(
              '[ ${q.marks} MARKS ]',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4),

        // Prompt
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Text(
            q.content,
            style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.4),
          ),
        ),

        // MCQ Choices
        if (q.type == QuestionType.mcq && q.options.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (int opt = 0; opt < q.options.length; opt++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Text(
                      '${String.fromCharCode(65 + opt)}.  ${q.options[opt]}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Source Attribution Note in footer of question
        if (q.source.isNotEmpty && q.source != 'School Question Bank') ...[
          pw.SizedBox(height: 3),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8),
            child: pw.Text(
              'Source: ${q.source}',
              style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildSolution(int number, ExamQuestion q) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Solution Q$number: [${q.marks} Marks]',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          if (q.type == QuestionType.mcq && q.correctOptionIndex != null)
            pw.Text(
              'Correct Answer: Option ${String.fromCharCode(65 + q.correctOptionIndex!)}',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
            ),
          if (q.rubric != null && q.rubric!.isNotEmpty)
            pw.Text('Grading Rubric: ${q.rubric}', style: const pw.TextStyle(fontSize: 8.5)),
          if (q.expectedPoints.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text('Key Points Required:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            for (final pt in q.expectedPoints)
              pw.Text('• ${pt.text}', style: const pw.TextStyle(fontSize: 8)),
          ],
        ],
      ),
    );
  }
}

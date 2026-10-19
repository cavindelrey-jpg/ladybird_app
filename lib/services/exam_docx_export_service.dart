// lib/services/exam_docx_export_service.dart
// Production-quality Word (.docx) document generator for composed examinations.
// Builds a valid ECMA-376 OpenXML WordprocessingML package with standard
// styles, digital school letterhead, candidate tables, questions, and mark allocations.

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/examination.dart';
import '../models/exam_question.dart';
import '../models/test.dart';

class ExamDocxExportService {
  ExamDocxExportService._();
  static final ExamDocxExportService instance = ExamDocxExportService._();

  /// Generates and exports the examination as a Word (.docx) document.
  Future<File> exportExaminationDocx({
    required Examination examination,
    SchoolExamTemplate? template,
    bool includeLetterhead = true,
    bool includeSolutions = false,
  }) async {
    final tmpl = template ?? examination.selectedTemplate ?? const SchoolExamTemplate(
      id: 'default',
      schoolId: '',
      name: 'Default',
      schoolName: 'CFPMI',
    );

    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    // 3. word/_rels/document.xml.rels
    final docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml)));

    // 4. word/styles.xml
    final stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
        <w:lang w:val="en-GB"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:line="240" w:lineRule="auto" w:after="120"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>''';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 5. word/document.xml
    final docBody = _buildDocumentBody(
      exam: examination,
      tmpl: tmpl,
      includeLetterhead: includeLetterhead,
      includeSolutions: includeSolutions,
    );

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
$docBody
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>
    </w:sectPr>
  </w:body>
</w:document>''';
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));

    // Encode package as ZIP
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    final tempDir = await getTemporaryDirectory();
    final safeTitle = '${examination.title}_${examination.subject}_${examination.classLevel}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
    final file = File('${tempDir.path}/exam_$safeTitle.docx');
    await file.writeAsBytes(zipBytes ?? const <int>[], flush: true);
    return file;
  }

  /// Shares the generated Word (.docx) file via the OS share dialog.
  Future<void> shareDocx({
    required Examination examination,
    SchoolExamTemplate? template,
    bool includeLetterhead = true,
    bool includeSolutions = false,
  }) async {
    final file = await exportExaminationDocx(
      examination: examination,
      template: template,
      includeLetterhead: includeLetterhead,
      includeSolutions: includeSolutions,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')],
      text: '${examination.title} - ${examination.subject} (${examination.classLevel})',
    );
  }

  // ─── Document XML Builder Helpers ─────────────────────────────────────────

  String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _p(String text, {bool bold = false, bool italic = false, int size = 22, String align = 'left', int after = 120}) {
    final bTag = bold ? '<w:b/>' : '';
    final iTag = italic ? '<w:i/>' : '';
    final jcTag = align != 'left' ? '<w:jc w:val="$align"/>' : '';

    return '''
    <w:p>
      <w:pPr>
        $jcTag
        <w:spacing w:after="$after"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          $bTag
          $iTag
          <w:sz w:val="$size"/>
          <w:szCs w:val="$size"/>
        </w:rPr>
        <w:t xml:space="preserve">${_xmlEscape(text)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _buildDocumentBody({
    required Examination exam,
    required SchoolExamTemplate tmpl,
    required bool includeLetterhead,
    required bool includeSolutions,
  }) {
    final sb = StringBuffer();

    // ── Letterhead ──────────────────────────────────────────────────────────
    if (includeLetterhead) {
      sb.writeln(_p('REPUBLIC OF CAMEROON', bold: true, size: 20, align: 'center', after: 20));
      sb.writeln(_p('Peace - Work - Fatherland', italic: true, size: 18, align: 'center', after: 20));
      sb.writeln(_p('MINISTRY OF SECONDARY EDUCATION', bold: true, size: 20, align: 'center', after: 80));

      sb.writeln(_p(tmpl.schoolName.toUpperCase(), bold: true, size: 26, align: 'center', after: 40));
      if (tmpl.subHeader.isNotEmpty) {
        sb.writeln(_p(tmpl.subHeader, size: 18, align: 'center', after: 30));
      }
      if (tmpl.motto != null && tmpl.motto!.isNotEmpty) {
        sb.writeln(_p('Motto: "${tmpl.motto}"', italic: true, size: 18, align: 'center', after: 80));
      }

      // Divider line
      sb.writeln('''
      <w:p>
        <w:pPr>
          <w:pBdr>
            <w:bottom w:val="single" w:sz="12" w:space="1" w:color="000000"/>
          </w:pBdr>
          <w:spacing w:after="160"/>
        </w:pPr>
      </w:p>''');
    }

    // ── Examination Title ───────────────────────────────────────────────────
    sb.writeln(_p(exam.title.toUpperCase(), bold: true, size: 26, align: 'center', after: 120));

    // ── Exam Metadata Table ─────────────────────────────────────────────────
    sb.writeln('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="6" w:color="888888"/>
          <w:bottom w:val="single" w:sz="6" w:color="888888"/>
          <w:left w:val="none"/>
          <w:right w:val="none"/>
          <w:insideH w:val="none"/>
          <w:insideV w:val="none"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tr>
        <w:tc>
          <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>SUBJECT: ${_xmlEscape(exam.subject.toUpperCase())}</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>CLASS: ${_xmlEscape(exam.classLevel.toUpperCase())}</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>DURATION: ${exam.durationMinutes} MINUTES</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
      <w:tr>
        <w:tc>
          <w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>ACADEMIC YEAR: ${_xmlEscape(exam.academicYear)}</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/></w:rPr><w:t>TOTAL MARKS: ${exam.effectiveTotalMarks} MARKS</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>DATE: ${exam.date.day.toString().padLeft(2, '0')}/${exam.date.month.toString().padLeft(2, '0')}/${exam.date.year}</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
    </w:tbl>''');

    if (exam.examinerName.isNotEmpty) {
      sb.writeln(_p('Examiner / Teacher: ${exam.examinerName}', italic: true, size: 18, after: 140));
    } else {
      sb.writeln(_p('', after: 120));
    }

    // ── Candidate Identification Box ────────────────────────────────────────
    if (tmpl.includeStudentFields) {
      sb.writeln('''
      <w:tbl>
        <w:tblPr>
          <w:tblW w:w="0" w:type="auto"/>
          <w:tblBorders>
            <w:top w:val="single" w:sz="6" w:color="000000"/>
            <w:bottom w:val="single" w:sz="6" w:color="000000"/>
            <w:left w:val="single" w:sz="6" w:color="000000"/>
            <w:right w:val="single" w:sz="6" w:color="000000"/>
          </w:tblBorders>
        </w:tblPr>
        <w:tr>
          <w:tc>
            <w:tcPr><w:tcMar><w:top w:w="120"/><w:bottom w:w="120"/><w:left w:w="160"/><w:right w:w="160"/></w:tcMar></w:tcPr>
            <w:p><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>CANDIDATE NAME: __________________________________________________</w:t></w:r></w:p>
          </w:tc>
          <w:tc>
            <w:tcPr><w:tcMar><w:top w:w="120"/><w:bottom w:w="120"/><w:left w:w="160"/><w:right w:w="160"/></w:tcMar></w:tcPr>
            <w:p><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>ROLL / MATRICULE: _________________</w:t></w:r></w:p>
          </w:tc>
        </w:tr>
      </w:tbl>''');
      sb.writeln(_p('', after: 100));
    }

    // ── Instructions to Candidates Box ──────────────────────────────────────
    if (tmpl.includeInstructionsBox && exam.instructions.isNotEmpty) {
      sb.writeln('''
      <w:tbl>
        <w:tblPr>
          <w:tblW w:w="0" w:type="auto"/>
          <w:tblBorders>
            <w:top w:val="single" w:sz="8" w:color="000000"/>
            <w:bottom w:val="single" w:sz="8" w:color="000000"/>
            <w:left w:val="single" w:sz="8" w:color="000000"/>
            <w:right w:val="single" w:sz="8" w:color="000000"/>
          </w:tblBorders>
        </w:tblPr>
        <w:tr>
          <w:tc>
            <w:tcPr><w:tcMar><w:top w:w="140"/><w:bottom w:w="140"/><w:left w:w="180"/><w:right w:w="180"/></w:tcMar></w:tcPr>
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="19"/></w:rPr><w:t>INSTRUCTIONS TO CANDIDATES:</w:t></w:r></w:p>
            <w:p><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>${_xmlEscape(exam.instructions)}</w:t></w:r></w:p>
          </w:tc>
        </w:tr>
      </w:tbl>''');
      sb.writeln(_p('', after: 140));
    }

    // ── Section Heading ─────────────────────────────────────────────────────
    sb.writeln(_p('SECTION A: ALL QUESTIONS COMPULSORY', bold: true, size: 22, align: 'center', after: 80));
    sb.writeln('''
    <w:p>
      <w:pPr>
        <w:pBdr>
          <w:bottom w:val="single" w:sz="6" w:color="000000"/>
        </w:pBdr>
        <w:spacing w:after="200"/>
      </w:pPr>
    </w:p>''');

    // ── Questions ───────────────────────────────────────────────────────────
    for (int i = 0; i < exam.questions.length; i++) {
      final q = exam.questions[i];
      final topicSuffix = q.topic.isNotEmpty ? ' (${q.topic})' : '';

      // Question Header with marks on right
      sb.writeln('''
      <w:p>
        <w:pPr>
          <w:tabs>
            <w:tab w:val="right" w:pos="9638"/>
          </w:tabs>
          <w:spacing w:after="80"/>
        </w:pPr>
        <w:r>
          <w:rPr><w:b/><w:sz w:val="22"/></w:rPr>
          <w:t>QUESTION ${i + 1}.$topicSuffix</w:t>
        </w:r>
        <w:r>
          <w:tab/>
        </w:r>
        <w:r>
          <w:rPr><w:b/><w:sz w:val="21"/></w:rPr>
          <w:t>[ ${q.marks} MARKS ]</w:t>
        </w:r>
      </w:p>''');

      // Question text
      for (final line in q.content.split('\n')) {
        sb.writeln('''
        <w:p>
          <w:pPr>
            <w:ind w:left="360"/>
            <w:spacing w:after="80"/>
          </w:pPr>
          <w:r>
            <w:rPr><w:sz w:val="21"/></w:rPr>
            <w:t xml:space="preserve">${_xmlEscape(line)}</w:t>
          </w:r>
        </w:p>''');
      }

      // Multiple choice options
      if (q.type == QuestionType.mcq && q.options.isNotEmpty) {
        for (int opt = 0; opt < q.options.length; opt++) {
          final letter = String.fromCharCode(65 + opt);
          sb.writeln('''
          <w:p>
            <w:pPr>
              <w:ind w:left="720"/>
              <w:spacing w:after="60"/>
            </w:pPr>
            <w:r>
              <w:rPr><w:b/><w:sz w:val="20"/></w:rPr>
              <w:t>$letter.  </w:t>
            </w:r>
            <w:r>
              <w:rPr><w:sz w:val="20"/></w:rPr>
              <w:t xml:space="preserve">${_xmlEscape(q.options[opt])}</w:t>
            </w:r>
          </w:p>''');
        }
      }

      // Source attribution
      if (q.source.isNotEmpty && q.source != 'School Question Bank') {
        sb.writeln('''
        <w:p>
          <w:pPr>
            <w:ind w:left="360"/>
            <w:spacing w:after="160"/>
          </w:pPr>
          <w:r>
            <w:rPr><w:i/><w:sz w:val="16"/><w:color w:val="666666"/></w:rPr>
            <w:t>Source: ${_xmlEscape(q.source)}</w:t>
          </w:r>
        </w:p>''');
      } else {
        sb.writeln(_p('', after: 120));
      }
    }

    // ── Solutions Section (if enabled) ──────────────────────────────────────
    if (includeSolutions) {
      sb.writeln('''
      <w:p>
        <w:pPr>
          <w:pageBreakBefore/>
          <w:spacing w:after="140"/>
        </w:pPr>
      </w:p>''');
      sb.writeln(_p('MARKING SCHEME & MODEL SOLUTIONS (CONFIDENTIAL)', bold: true, size: 24, align: 'center', after: 160));

      for (int i = 0; i < exam.questions.length; i++) {
        final q = exam.questions[i];
        sb.writeln(_p('Solution Question ${i + 1} [${q.marks} Marks]:', bold: true, size: 20, after: 60));

        if (q.type == QuestionType.mcq && q.correctOptionIndex != null) {
          final letter = String.fromCharCode(65 + q.correctOptionIndex!);
          sb.writeln(_p('  Correct Answer: Option $letter', bold: true, size: 19, after: 40));
        }

        if (q.rubric != null && q.rubric!.isNotEmpty) {
          sb.writeln(_p('  Grading Rubric: ${q.rubric}', size: 18, after: 40));
        }

        if (q.expectedPoints.isNotEmpty) {
          for (final pt in q.expectedPoints) {
            sb.writeln(_p('  • ${pt.text}', size: 18, after: 30));
          }
        }
        sb.writeln(_p('', after: 80));
      }
    }

    // ── Document Footer ─────────────────────────────────────────────────────
    sb.writeln(_p('*** END OF EXAMINATION PAPER ***', bold: true, size: 22, align: 'center', after: 200));

    return sb.toString();
  }
}

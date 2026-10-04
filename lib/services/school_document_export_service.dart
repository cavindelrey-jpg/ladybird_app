// lib/services/school_document_export_service.dart
// Production-quality PDF and Word (.docx) document generator for Academia:
// - Class Timetables
// - Programs of Activities / School Calendars
// - Student Class Rosters
// - Staff Directories & Teaching Assignments
// - Marks & Assessment Broadsheets

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/school_timetable_slot.dart';
import '../models/school_calendar_event.dart';
import '../models/student_record.dart';
import '../models/app_user.dart';
import '../models/school_mark.dart';

class SchoolDocumentExportService {
  SchoolDocumentExportService._();
  static final SchoolDocumentExportService instance = SchoolDocumentExportService._();

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPERS: ASSETS & COMMON DOCX OPENXML
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Uint8List?> _loadLogoBytes() async {
    try {
      final byteData = await rootBundle.load('assets/branding/ladybird_logo.jpg');
      return byteData.buffer.asUint8List();
    } catch (_) {
      try {
        final byteData = await rootBundle.load('assets/branding/green_hills_logo.jpg');
        return byteData.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }
  }

  String _clean(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]+'), '_');

  Future<Directory> _getTempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  Archive _createDocxBase({required String title, required String bodyXml}) {
    final archive = Archive();

    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsXml.length, utf8.encode(docRelsXml)));

    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:color w:val="2D3748"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>''';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $bodyXml
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000"/>
    </w:sectPr>
  </w:body>
</w:document>''';
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));

    return archive;
  }

  String _xmlEsc(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _docxParagraph(String text, {bool bold = false, int size = 22, String color = '2D3748', String align = 'left'}) {
    return '''<w:p>
      <w:pPr>
        <w:jc w:val="$align"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          ${bold ? '<w:b/>' : ''}
          <w:sz w:val="$size"/>
          <w:color w:val="$color"/>
        </w:rPr>
        <w:t xml:space="preserve">${_xmlEsc(text)}</w:t>
      </w:r>
    </w:p>''';
  }

  String _docxTableHeader(List<String> headers, List<int> colWidths) {
    final cells = <String>[];
    for (int i = 0; i < headers.length; i++) {
      final w = i < colWidths.length ? colWidths[i] : 2000;
      cells.add('''<w:tc>
        <w:tcPr>
          <w:tcW w:w="$w" w:type="dxa"/>
          <w:shd w:val="clear" w:color="auto" w:fill="2B6CB0"/>
        </w:tcPr>
        <w:p>
          <w:pPr><w:jc w:val="center"/></w:pPr>
          <w:r>
            <w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr>
            <w:t>${_xmlEsc(headers[i])}</w:t>
          </w:r>
        </w:p>
      </w:tc>''');
    }
    return '<w:tr>${cells.join()}</w:tr>';
  }

  String _docxTableRow(List<String> values, List<int> colWidths, {bool isEven = false}) {
    final cells = <String>[];
    final fill = isEven ? 'F7FAFC' : 'FFFFFF';
    for (int i = 0; i < values.length; i++) {
      final w = i < colWidths.length ? colWidths[i] : 2000;
      cells.add('''<w:tc>
        <w:tcPr>
          <w:tcW w:w="$w" w:type="dxa"/>
          <w:shd w:val="clear" w:color="auto" w:fill="$fill"/>
        </w:tcPr>
        <w:p>
          <w:pPr><w:jc w:val="left"/></w:pPr>
          <w:r>
            <w:rPr><w:sz w:val="18"/><w:color w:val="2D3748"/></w:rPr>
            <w:t>${_xmlEsc(values[i])}</w:t>
          </w:r>
        </w:p>
      </w:tc>''');
    }
    return '<w:tr>${cells.join()}</w:tr>';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. TIMETABLE EXPORT (PDF & WORD)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<File> exportTimetablePdf({
    required String schoolName,
    required String classLevel,
    required List<SchoolTimetableSlot> slots,
  }) async {
    final pdf = pw.Document(title: '$schoolName - Timetable ($classLevel)');
    final logoBytes = await _loadLogoBytes();
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sortedSlots = List<SchoolTimetableSlot>.from(slots)
      ..sort((a, b) {
        final d = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (d != 0) return d;
        return a.startTime.compareTo(b.startTime);
      });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, width: 44, height: 44),
                  pw.SizedBox(width: 14),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(schoolName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('OFFICIAL CLASS TIMETABLE - $classLevel',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.Text('Generated via Academia Management System',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 12),

            // Timetable Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(1.0),
                2: const pw.FlexColumnWidth(2.0),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(1.0),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    'Day',
                    'Time',
                    'Subject',
                    'Teacher',
                    'Room',
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  )).toList(),
                ),
                ...sortedSlots.map((s) {
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: s.dayOfWeek.isEven ? PdfColors.grey100 : PdfColors.white,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(SchoolTimetableSlot.dayNames[s.dayOfWeek],
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text('${s.startTime} - ${s.endTime}', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(s.subject, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(s.teacherName.isNotEmpty ? s.teacherName : '—', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(s.room?.isNotEmpty == true ? s.room! : '—', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Periods: ${sortedSlots.length}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                pw.Text('Principal / Academic Dean Signature: _______________________',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/timetable_${_clean(classLevel)}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportTimetableDocx({
    required String schoolName,
    required String classLevel,
    required List<SchoolTimetableSlot> slots,
  }) async {
    final sortedSlots = List<SchoolTimetableSlot>.from(slots)
      ..sort((a, b) {
        final d = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (d != 0) return d;
        return a.startTime.compareTo(b.startTime);
      });

    final buf = StringBuffer();
    buf.writeln(_docxParagraph(schoolName.toUpperCase(), bold: true, size: 28, color: '1A365D', align: 'center'));
    buf.writeln(_docxParagraph('OFFICIAL CLASS TIMETABLE - $classLevel', bold: true, size: 22, color: '2B6CB0', align: 'center'));
    buf.writeln(_docxParagraph('Generated via Academia Management System', size: 16, color: '718096', align: 'center'));
    buf.writeln('<w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>');

    buf.writeln('<w:tbl>');
    buf.writeln('''<w:tblPr>
      <w:tblW w:w="10000" w:type="dxa"/>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
      </w:tblBorders>
    </w:tblPr>''');

    final colWidths = [1800, 2000, 3000, 2200, 1000];
    buf.writeln(_docxTableHeader(['Day', 'Time', 'Subject', 'Teacher', 'Room'], colWidths));

    for (int i = 0; i < sortedSlots.length; i++) {
      final s = sortedSlots[i];
      buf.writeln(_docxTableRow([
        SchoolTimetableSlot.dayNames[s.dayOfWeek],
        '${s.startTime} - ${s.endTime}',
        s.subject,
        s.teacherName.isNotEmpty ? s.teacherName : '—',
        s.room?.isNotEmpty == true ? s.room! : '—',
      ], colWidths, isEven: i.isEven));
    }
    buf.writeln('</w:tbl>');

    final archive = _createDocxBase(
      title: 'Timetable - $classLevel',
      bodyXml: buf.toString(),
    );

    final encoded = ZipEncoder().encode(archive);
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/timetable_${_clean(classLevel)}.docx');
    if (encoded != null) {
      await file.writeAsBytes(encoded, flush: true);
    }
    return file;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. PROGRAM OF ACTIVITIES / SCHOOL CALENDAR EXPORT (PDF & WORD)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<File> exportActivitiesPdf({
    required String schoolName,
    required List<SchoolCalendarEvent> events,
    String? termOrYear,
  }) async {
    final pdf = pw.Document(title: '$schoolName - Program of Activities');
    final logoBytes = await _loadLogoBytes();
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sortedEvents = List<SchoolCalendarEvent>.from(events)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, width: 44, height: 44),
                  pw.SizedBox(width: 14),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(schoolName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('ANNUAL & TERMLY PROGRAM OF ACTIVITIES ${termOrYear != null ? '— $termOrYear' : ''}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.Text('Official School Master Calendar',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 12),

            // Activities Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2.0),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    'Date',
                    'Activity',
                    'Description',
                    'Category',
                    'Location',
                    'Target Group',
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  )).toList(),
                ),
                ...sortedEvents.map((e) {
                  final dateStr = '${e.startDate.year}-${e.startDate.month.toString().padLeft(2, '0')}-${e.startDate.day.toString().padLeft(2, '0')}';
                  final targetStr = e.affectedClasses.isEmpty ? 'All Students / School' : e.affectedClasses.join(', ');
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: sortedEvents.indexOf(e).isEven ? PdfColors.grey100 : PdfColors.white,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(dateStr, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(e.title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(e.description.isNotEmpty ? e.description : '—', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(e.category.label, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(e.location?.isNotEmpty == true ? e.location! : 'Campus', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(targetStr, style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Planned Activities: ${sortedEvents.length}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                pw.Text('Approved by Administration: _______________________', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/program_of_activities.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportActivitiesDocx({
    required String schoolName,
    required List<SchoolCalendarEvent> events,
    String? termOrYear,
  }) async {
    final sortedEvents = List<SchoolCalendarEvent>.from(events)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final buf = StringBuffer();
    buf.writeln(_docxParagraph(schoolName.toUpperCase(), bold: true, size: 28, color: '1A365D', align: 'center'));
    buf.writeln(_docxParagraph('PROGRAM OF ACTIVITIES ${termOrYear != null ? '— $termOrYear' : ''}', bold: true, size: 22, color: '2B6CB0', align: 'center'));
    buf.writeln(_docxParagraph('Official School Master Calendar', size: 16, color: '718096', align: 'center'));
    buf.writeln('<w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>');

    buf.writeln('<w:tbl>');
    buf.writeln('''<w:tblPr>
      <w:tblW w:w="10000" w:type="dxa"/>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
      </w:tblBorders>
    </w:tblPr>''');

    final colWidths = [1500, 2500, 3000, 1500, 1500];
    buf.writeln(_docxTableHeader(['Date', 'Activity', 'Description', 'Category', 'Target Group'], colWidths));

    for (int i = 0; i < sortedEvents.length; i++) {
      final e = sortedEvents[i];
      final dateStr = '${e.startDate.year}-${e.startDate.month.toString().padLeft(2, '0')}-${e.startDate.day.toString().padLeft(2, '0')}';
      final targetStr = e.affectedClasses.isEmpty ? 'All Students / School' : e.affectedClasses.join(', ');
      buf.writeln(_docxTableRow([
        dateStr,
        e.title,
        e.description.isNotEmpty ? e.description : '—',
        e.category.label,
        targetStr,
      ], colWidths, isEven: i.isEven));
    }
    buf.writeln('</w:tbl>');

    final archive = _createDocxBase(
      title: 'Program of Activities',
      bodyXml: buf.toString(),
    );

    final encoded = ZipEncoder().encode(archive);
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/program_of_activities.docx');
    if (encoded != null) {
      await file.writeAsBytes(encoded, flush: true);
    }
    return file;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. STUDENT ROSTER / CLASS LIST EXPORT (PDF & WORD)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<File> exportStudentRosterPdf({
    required String schoolName,
    required String classLevel,
    required List<StudentRecord> students,
  }) async {
    final pdf = pw.Document(title: '$schoolName - Class Roster ($classLevel)');
    final logoBytes = await _loadLogoBytes();
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sorted = List<StudentRecord>.from(students)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, width: 44, height: 44),
                  pw.SizedBox(width: 14),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(schoolName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('OFFICIAL CLASS ROSTER - $classLevel',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.Text('Total Students Enrolled: ${sorted.length}',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 12),

            // Students Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(3.0),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(1.0),
                4: const pw.FlexColumnWidth(2.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    '#',
                    'Student Full Name',
                    'Matricule / ID',
                    'Gender',
                    'Parent Contact',
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  )).toList(),
                ),
                ...sorted.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final s = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx.isEven ? PdfColors.grey100 : PdfColors.white,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                        child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(s.name, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(s.matricule?.isNotEmpty == true ? s.matricule! : '—', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(s.gender?.isNotEmpty == true ? s.gender! : '—', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(s.parentContact?.isNotEmpty == true ? s.parentContact! : '—', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/roster_${_clean(classLevel)}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportStudentRosterDocx({
    required String schoolName,
    required String classLevel,
    required List<StudentRecord> students,
  }) async {
    final sorted = List<StudentRecord>.from(students)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final buf = StringBuffer();
    buf.writeln(_docxParagraph(schoolName.toUpperCase(), bold: true, size: 28, color: '1A365D', align: 'center'));
    buf.writeln(_docxParagraph('OFFICIAL CLASS ROSTER - $classLevel', bold: true, size: 22, color: '2B6CB0', align: 'center'));
    buf.writeln(_docxParagraph('Total Students Enrolled: ${sorted.length}', size: 16, color: '718096', align: 'center'));
    buf.writeln('<w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>');

    buf.writeln('<w:tbl>');
    buf.writeln('''<w:tblPr>
      <w:tblW w:w="10000" w:type="dxa"/>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
      </w:tblBorders>
    </w:tblPr>''');

    final colWidths = [800, 3600, 2000, 1200, 2400];
    buf.writeln(_docxTableHeader(['#', 'Student Full Name', 'Matricule / ID', 'Gender', 'Parent Contact'], colWidths));

    for (int i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      buf.writeln(_docxTableRow([
        '${i + 1}',
        s.name,
        s.matricule?.isNotEmpty == true ? s.matricule! : '—',
        s.gender?.isNotEmpty == true ? s.gender! : '—',
        s.parentContact?.isNotEmpty == true ? s.parentContact! : '—',
      ], colWidths, isEven: i.isEven));
    }
    buf.writeln('</w:tbl>');

    final archive = _createDocxBase(
      title: 'Class Roster - $classLevel',
      bodyXml: buf.toString(),
    );

    final encoded = ZipEncoder().encode(archive);
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/roster_${_clean(classLevel)}.docx');
    if (encoded != null) {
      await file.writeAsBytes(encoded, flush: true);
    }
    return file;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. TEACHERS & STAFF DIRECTORY EXPORT (PDF & WORD)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<File> exportStaffDirectoryPdf({
    required String schoolName,
    required List<AppUser> staff,
  }) async {
    final pdf = pw.Document(title: '$schoolName - Faculty & Staff Directory');
    final logoBytes = await _loadLogoBytes();
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sorted = List<AppUser>.from(staff)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, width: 44, height: 44),
                  pw.SizedBox(width: 14),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(schoolName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('OFFICIAL FACULTY & TEACHING ASSIGNMENTS DIRECTORY',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.Text('Total Teaching Staff: ${sorted.length}',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 12),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(26),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(2.0),
                3: const pw.FlexColumnWidth(2.5),
                4: const pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    '#',
                    'Teacher Name',
                    'Email / Contact',
                    'Assigned Subjects & Classes',
                    'Class Master',
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  )).toList(),
                ),
                ...sorted.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final t = entry.value;
                  final assignmentsStr = t.teachingAssignments.isEmpty
                      ? 'General Staff'
                      : t.teachingAssignments.map((a) => '${a.subject} (${a.classLevel})').join(', ');
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx.isEven ? PdfColors.grey100 : PdfColors.white,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                        child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(t.name, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(t.email.isNotEmpty ? t.email : '—', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(assignmentsStr, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(t.classMasterOfClass?.isNotEmpty == true ? t.classMasterOfClass! : '—',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/staff_directory.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportStaffDirectoryDocx({
    required String schoolName,
    required List<AppUser> staff,
  }) async {
    final sorted = List<AppUser>.from(staff)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final buf = StringBuffer();
    buf.writeln(_docxParagraph(schoolName.toUpperCase(), bold: true, size: 28, color: '1A365D', align: 'center'));
    buf.writeln(_docxParagraph('FACULTY & TEACHING ASSIGNMENTS DIRECTORY', bold: true, size: 22, color: '2B6CB0', align: 'center'));
    buf.writeln(_docxParagraph('Total Teaching Staff: ${sorted.length}', size: 16, color: '718096', align: 'center'));
    buf.writeln('<w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>');

    buf.writeln('<w:tbl>');
    buf.writeln('''<w:tblPr>
      <w:tblW w:w="10000" w:type="dxa"/>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
      </w:tblBorders>
    </w:tblPr>''');

    final colWidths = [600, 2600, 2400, 3000, 1400];
    buf.writeln(_docxTableHeader(['#', 'Teacher Name', 'Email', 'Assigned Subjects/Classes', 'Class Master'], colWidths));

    for (int i = 0; i < sorted.length; i++) {
      final t = sorted[i];
      final assignmentsStr = t.teachingAssignments.isEmpty
          ? 'General Staff'
          : t.teachingAssignments.map((a) => '${a.subject} (${a.classLevel})').join(', ');
      buf.writeln(_docxTableRow([
        '${i + 1}',
        t.name,
        t.email.isNotEmpty ? t.email : '—',
        assignmentsStr,
        t.classMasterOfClass?.isNotEmpty == true ? t.classMasterOfClass! : '—',
      ], colWidths, isEven: i.isEven));
    }
    buf.writeln('</w:tbl>');

    final archive = _createDocxBase(
      title: 'Staff Directory',
      bodyXml: buf.toString(),
    );

    final encoded = ZipEncoder().encode(archive);
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/staff_directory.docx');
    if (encoded != null) {
      await file.writeAsBytes(encoded, flush: true);
    }
    return file;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. MARKS & BROADSHEET EXPORT (PDF & WORD)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<File> exportMarksPdf({
    required String schoolName,
    required String classLevel,
    required String subject,
    required String sequenceName,
    required List<SchoolMark> marks,
  }) async {
    final pdf = pw.Document(title: '$schoolName - Marks Broadsheet');
    final logoBytes = await _loadLogoBytes();
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sorted = List<SchoolMark>.from(marks)
      ..sort((a, b) => (b.score / (b.maxScore == 0 ? 1 : b.maxScore))
          .compareTo(a.score / (a.maxScore == 0 ? 1 : a.maxScore)));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, width: 44, height: 44),
                  pw.SizedBox(width: 14),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(schoolName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('OFFICIAL MARKS & ASSESSMENT BROADSHEET',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.Text('Class: $classLevel | Subject: $subject | Sequence: $sequenceName',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 12),

            // Marks Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(28),
                1: const pw.FlexColumnWidth(3.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    '#',
                    'Student Name',
                    'Raw Score',
                    'Score /20',
                    'Grade',
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  )).toList(),
                ),
                ...sorted.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final m = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx.isEven ? PdfColors.grey100 : PdfColors.white,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                        child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(m.studentName, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text('${m.score.toStringAsFixed(1)} / ${m.maxScore.toStringAsFixed(0)}',
                            style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(m.scoreOn20.toStringAsFixed(1),
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(m.gradeLetter,
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/marks_${_clean(classLevel)}_${_clean(subject)}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportMarksDocx({
    required String schoolName,
    required String classLevel,
    required String subject,
    required String sequenceName,
    required List<SchoolMark> marks,
  }) async {
    final sorted = List<SchoolMark>.from(marks)
      ..sort((a, b) => (b.score / (b.maxScore == 0 ? 1 : b.maxScore))
          .compareTo(a.score / (a.maxScore == 0 ? 1 : a.maxScore)));

    final buf = StringBuffer();
    buf.writeln(_docxParagraph(schoolName.toUpperCase(), bold: true, size: 28, color: '1A365D', align: 'center'));
    buf.writeln(_docxParagraph('MARKS & ASSESSMENT BROADSHEET', bold: true, size: 22, color: '2B6CB0', align: 'center'));
    buf.writeln(_docxParagraph('Class: $classLevel | Subject: $subject | Sequence: $sequenceName', size: 16, color: '718096', align: 'center'));
    buf.writeln('<w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>');

    buf.writeln('<w:tbl>');
    buf.writeln('''<w:tblPr>
      <w:tblW w:w="10000" w:type="dxa"/>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
      </w:tblBorders>
    </w:tblPr>''');

    final colWidths = [800, 4200, 1800, 1600, 1600];
    buf.writeln(_docxTableHeader(['#', 'Student Name', 'Raw Score', 'Score /20', 'Grade'], colWidths));

    for (int i = 0; i < sorted.length; i++) {
      final m = sorted[i];
      buf.writeln(_docxTableRow([
        '${i + 1}',
        m.studentName,
        '${m.score.toStringAsFixed(1)} / ${m.maxScore.toStringAsFixed(0)}',
        m.scoreOn20.toStringAsFixed(1),
        m.gradeLetter,
      ], colWidths, isEven: i.isEven));
    }
    buf.writeln('</w:tbl>');

    final archive = _createDocxBase(
      title: 'Marks - $classLevel - $subject',
      bodyXml: buf.toString(),
    );

    final encoded = ZipEncoder().encode(archive);
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/marks_${_clean(classLevel)}_${_clean(subject)}.docx');
    if (encoded != null) {
      await file.writeAsBytes(encoded, flush: true);
    }
    return file;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SHARED CONVENIENCE: OPEN OS SHARE SHEET
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> shareFile(File file, {String? text}) async {
    await Share.shareXFiles([XFile(file.path)], text: text ?? 'Exported Document');
  }
}

// lib/features/school/exam_composer/exam_preview_page.dart
// Production-quality examination preview and document export page.
// Allows teachers to preview, customize digital letterhead, logo, and layout,
// and export actual publication documents as Word (.docx) and PDF (.pdf).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/app_user.dart';
import '../../../models/exam_question.dart';
import '../../../models/examination.dart';
import '../../../repositories/exam_repository.dart';
import '../../../services/exam_docx_export_service.dart';
import '../../../services/exam_pdf_export_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';

class ExamPreviewPage extends StatefulWidget {
  final Examination examination;
  final AppUser user;

  const ExamPreviewPage({
    super.key,
    required this.examination,
    required this.user,
  });

  @override
  State<ExamPreviewPage> createState() => _ExamPreviewPageState();
}

class _ExamPreviewPageState extends State<ExamPreviewPage> {
  late Examination _exam;
  SchoolExamTemplate? _currentTemplate;
  bool _showMarkingScheme = false;
  bool _includeLetterhead = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _exam = widget.examination;
    _currentTemplate = _exam.selectedTemplate ??
        ExamRepository.instance.getDefaultTemplate(widget.user.schoolId ?? '');
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final schoolId = widget.user.schoolId ?? '';
    final templates = await ExamRepository.instance.watchSchoolTemplates(schoolId).first;
    if (templates.isNotEmpty && mounted) {
      setState(() {
        if (_exam.templateId != null) {
          _currentTemplate = templates.firstWhere(
            (t) => t.id == _exam.templateId,
            orElse: () => templates.first,
          );
        } else {
          _currentTemplate = templates.first;
        }
      });
    }
  }

  void _chooseTemplate() async {
    final schoolId = widget.user.schoolId ?? '';
    final templates = await ExamRepository.instance.watchSchoolTemplates(schoolId).first;
    if (!mounted) return;
    final ac = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select School Letterhead / Template',
                  style: AppText.title.copyWith(fontSize: 16)),
            ),
            const Divider(height: 1),
            ...templates.map((t) => ListTile(
                  leading: Icon(Icons.article_outlined, color: ac.primary),
                  title: Text(t.name),
                  subtitle: Text('${t.schoolName} · ${t.type.label}'),
                  trailing: t.id == _currentTemplate?.id ? Icon(Icons.check, color: ac.primary) : null,
                  onTap: () {
                    setState(() {
                      _currentTemplate = t;
                      _exam = _exam.copyWith(templateId: t.id, selectedTemplate: t);
                    });
                    ExamRepository.instance.saveExamination(_exam);
                    Navigator.pop(bCtx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  /// Opens the customization bottom sheet for teachers to customize school logo,
  /// letterhead text, headers, and exam layout.
  void _customizeLetterheadAndFormatting() {
    final ac = AppColors.of(context);
    final tmpl = _currentTemplate ?? ExamRepository.instance.getDefaultTemplate(widget.user.schoolId ?? '');

    final schoolNameCtrl = TextEditingController(text: tmpl.schoolName);
    final countryHeaderCtrl = TextEditingController(text: tmpl.countryHeader);
    final subHeaderCtrl = TextEditingController(text: tmpl.subHeader);
    final mottoCtrl = TextEditingController(text: tmpl.motto ?? '');
    final instructionsCtrl = TextEditingController(text: _exam.instructions);
    bool includeStudentFields = tmpl.includeStudentFields;
    bool includeInstructions = tmpl.includeInstructionsBox;
    String fontFamily = tmpl.fontFamily;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customize Paper & Letterhead',
                        style: AppText.title.copyWith(fontSize: 17, color: ac.txt)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Adjust the school letterhead, font style, and examination structure.',
                  style: AppText.caption.copyWith(color: ac.muted),
                ),
                const SizedBox(height: 16),

                // School Name
                TextField(
                  controller: schoolNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'School / Institution Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.school_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // National / Country Header
                TextField(
                  controller: countryHeaderCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'National / Ministry Header',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // Subheader / Delegation / Address
                TextField(
                  controller: subHeaderCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Regional Delegation & Address',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // Motto
                TextField(
                  controller: mottoCtrl,
                  decoration: InputDecoration(
                    labelText: 'School Motto',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.format_quote_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Instructions
                TextField(
                  controller: instructionsCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Instructions to Candidates',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Formatting Toggles
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Candidate Info Box (Name, Roll No)', style: TextStyle(fontSize: 13.5)),
                  value: includeStudentFields,
                  onChanged: (v) => setModalState(() => includeStudentFields = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Instructions Box', style: TextStyle(fontSize: 13.5)),
                  value: includeInstructions,
                  onChanged: (v) => setModalState(() => includeInstructions = v),
                ),
                const SizedBox(height: 10),

                // Font Family Selector
                Text('Typography / Font Style', style: AppText.caption.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _fontChoiceChip(
                      label: 'Serif (Classic)',
                      selected: fontFamily == 'Serif',
                      onTap: () => setModalState(() => fontFamily = 'Serif'),
                      ac: ac,
                    ),
                    const SizedBox(width: 8),
                    _fontChoiceChip(
                      label: 'Sans-Serif (Modern)',
                      selected: fontFamily == 'Sans',
                      onTap: () => setModalState(() => fontFamily = 'Sans'),
                      ac: ac,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final updatedTemplate = tmpl.copyWith(
                        schoolName: schoolNameCtrl.text.trim(),
                        countryHeader: countryHeaderCtrl.text.trim(),
                        subHeader: subHeaderCtrl.text.trim(),
                        motto: mottoCtrl.text.trim().isEmpty ? null : mottoCtrl.text.trim(),
                        includeStudentFields: includeStudentFields,
                        includeInstructionsBox: includeInstructions,
                        fontFamily: fontFamily,
                      );

                      setState(() {
                        _currentTemplate = updatedTemplate;
                        _exam = _exam.copyWith(
                          instructions: instructionsCtrl.text.trim(),
                          selectedTemplate: updatedTemplate,
                        );
                      });

                      ExamRepository.instance.saveExamination(_exam);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Examination formatting and letterhead updated.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apply Customizations', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fontChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required AppColors ac,
  }) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : ac.txt)),
      selected: selected,
      selectedColor: ac.primary,
      backgroundColor: ac.surf2,
      onSelected: (_) => onTap(),
    );
  }

  // ── Document Export Handlers ──────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      await ExamPdfExportService.instance.sharePdf(
        examination: _exam,
        template: _currentTemplate,
        includeLetterhead: _includeLetterhead,
        includeSolutions: _showMarkingScheme,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportDocx() async {
    setState(() => _exporting = true);
    try {
      await ExamDocxExportService.instance.shareDocx(
        examination: _exam,
        template: _currentTemplate,
        includeLetterhead: _includeLetterhead,
        includeSolutions: _showMarkingScheme,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export Word document: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showExportMenu() {
    final ac = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Export Official Examination Document',
                  style: AppText.title.copyWith(fontSize: 16)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.picture_as_pdf_rounded, color: ac.red, size: 24),
              ),
              title: const Text('Export as PDF (.pdf)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Preserves complete letterhead, typography, and page numbers for printing.'),
              onTap: () {
                Navigator.pop(bCtx);
                _exportPdf();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ac.bluBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.description_rounded, color: ac.blu, size: 24),
              ),
              title: const Text('Export as Word Document (.docx)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Fully editable in Microsoft Word, LibreOffice, or Google Docs.'),
              onTap: () {
                Navigator.pop(bCtx);
                _exportDocx();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.tune_rounded, color: ac.primary, size: 24),
              ),
              title: const Text('Customize Letterhead & Formatting', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Change school logo, headers, motto, or instructions before export.'),
              onTap: () {
                Navigator.pop(bCtx);
                _customizeLetterheadAndFormatting();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.copy_rounded, color: ac.txt2, size: 24),
              ),
              title: const Text('Copy Plain Text to Clipboard'),
              onTap: () {
                Navigator.pop(bCtx);
                _copyToClipboard();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _generatePlainTextPaper() {
    final buffer = StringBuffer();
    final tmpl = _currentTemplate;

    if (_includeLetterhead && tmpl != null) {
      buffer.writeln(tmpl.countryHeader);
      buffer.writeln('--------------------------------------------------');
      buffer.writeln(tmpl.schoolName.toUpperCase());
      buffer.writeln(tmpl.subHeader);
      if (tmpl.motto != null) buffer.writeln('Motto: "${tmpl.motto}"');
      buffer.writeln('==================================================');
    }

    buffer.writeln(_exam.title.toUpperCase());
    buffer.writeln('SUBJECT: ${_exam.subject.toUpperCase()}    CLASS: ${_exam.classLevel.toUpperCase()}');
    buffer.writeln('ACADEMIC YEAR: ${_exam.academicYear}    DURATION: ${_exam.durationMinutes} MINUTES');
    buffer.writeln('TOTAL MARKS: ${_exam.effectiveTotalMarks} MARKS    DATE: ${_exam.date.day}/${_exam.date.month}/${_exam.date.year}');
    buffer.writeln('EXAMINER: ${_exam.examinerName}');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('CANDIDATE NAME: ______________________ ROLL NO: ______');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('INSTRUCTIONS: ${_exam.instructions}');
    buffer.writeln('==================================================\n');

    for (int i = 0; i < _exam.questions.length; i++) {
      final q = _exam.questions[i];
      buffer.writeln('QUESTION ${i + 1} [${q.marks} MARKS] (${q.type.label})');
      buffer.writeln(q.content);

      if (q.type == QuestionType.mcq && q.options.isNotEmpty) {
        for (int opt = 0; opt < q.options.length; opt++) {
          buffer.writeln('  ${String.fromCharCode(65 + opt)}. ${q.options[opt]}');
        }
      }

      if (_showMarkingScheme) {
        buffer.writeln('\n[MARKING SCHEME / SOLUTION:');
        if (q.type == QuestionType.mcq && q.correctOptionIndex != null) {
          buffer.writeln('  Correct Answer: ${String.fromCharCode(65 + q.correctOptionIndex!)}');
        }
        if (q.rubric != null) {
          buffer.writeln('  Guidance: ${q.rubric}');
        }
        buffer.writeln(']');
      }

      buffer.writeln('\n');
    }

    return buffer.toString();
  }

  void _copyToClipboard() {
    final text = _generatePlainTextPaper();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Examination paper copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final tmpl = _currentTemplate;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Examination Preview', style: AppText.title),
        backgroundColor: ac.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Customize Letterhead & Styling',
            onPressed: _customizeLetterheadAndFormatting,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export as PDF (.pdf)',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.description_rounded),
            tooltip: 'Export as Word (.docx)',
            onPressed: _exportDocx,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'template') _chooseTemplate();
              if (v == 'pdf') _exportPdf();
              if (v == 'docx') _exportDocx();
              if (v == 'customize') _customizeLetterheadAndFormatting();
              if (v == 'copy') _copyToClipboard();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pdf', child: Text('Export PDF (.pdf)')),
              const PopupMenuItem(value: 'docx', child: Text('Export Word (.docx)')),
              const PopupMenuItem(value: 'customize', child: Text('Customize Letterhead')),
              const PopupMenuItem(value: 'template', child: Text('Select School Template')),
              const PopupMenuItem(value: 'copy', child: Text('Copy Plain Text')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ac.surf,
          border: Border(top: BorderSide(color: ac.bdr)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showMarkingScheme = !_showMarkingScheme),
                icon: Icon(_showMarkingScheme ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                label: Text(_showMarkingScheme ? 'Hide Solutions' : 'Show Solutions', style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _customizeLetterheadAndFormatting,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Format Paper', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _showExportMenu,
                icon: _exporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_exporting ? 'Exporting…' : 'Export Document',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: ac.primary, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
            ],
            border: Border.all(color: const Color(0xFFD0D7DE)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Digital Letterhead
              if (_includeLetterhead && tmpl != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Ministry & Country
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tmpl.countryHeader,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontFamily: tmpl.fontFamily.toLowerCase() == 'serif' ? 'serif' : null,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Center: School Logo or Seal
                    Container(
                      width: 54,
                      height: 54,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: ac.primaryBg,
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(color: ac.primary, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.school_rounded, color: ac.primary, size: 28),
                    ),
                    // Right: School Info
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            tmpl.schoolName.toUpperCase(),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: ac.primary,
                              fontFamily: tmpl.fontFamily.toLowerCase() == 'serif' ? 'serif' : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tmpl.subHeader,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 8, color: Colors.black54, height: 1.2),
                          ),
                          if (tmpl.motto != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Motto: "${tmpl.motto}"',
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 8, fontStyle: FontStyle.italic, color: Colors.black87),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.black87, thickness: 1.5),
                const SizedBox(height: 4),
              ],

              // 2. Examination Title Banner
              Center(
                child: Text(
                  _exam.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.black,
                    fontFamily: tmpl?.fontFamily.toLowerCase() == 'serif' ? 'serif' : null,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Metadata Table Box
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 1),
                  color: const Color(0xFFF9FAFB),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SUBJECT: ${_exam.subject.toUpperCase()}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('CLASS: ${_exam.classLevel.toUpperCase()}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('YEAR: ${_exam.academicYear}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DURATION: ${_exam.durationMinutes} MINUTES',
                            style: const TextStyle(fontSize: 9.5, color: Colors.black87)),
                        Text('TOTAL MARKS: ${_exam.effectiveTotalMarks} MARKS',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text('DATE: ${_exam.date.day.toString().padLeft(2, '0')}/${_exam.date.month.toString().padLeft(2, '0')}/${_exam.date.year}',
                            style: const TextStyle(fontSize: 9.5, color: Colors.black87)),
                      ],
                    ),
                    if (_exam.examinerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('EXAMINER: ${_exam.examinerName}',
                            style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.black54)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Candidate Info Box
              if (tmpl?.includeStudentFields == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black87, width: 0.8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text('CANDIDATE NAME: _________________________________',
                            style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('ROLL NO: ____________',
                            style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 4. Instructions Box
              if (tmpl?.includeInstructionsBox == true && _exam.instructions.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black87, width: 0.8),
                    color: const Color(0xFFF9FAFB),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INSTRUCTIONS TO CANDIDATES:',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _exam.instructions,
                        style: const TextStyle(fontSize: 9.5, color: Colors.black87, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Section Heading
              const Center(
                child: Text(
                  'SECTION A: ALL QUESTIONS COMPULSORY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.black),
                ),
              ),
              const Divider(color: Colors.black87, thickness: 1),
              const SizedBox(height: 12),

              // 5. Questions List
              if (_exam.questions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No questions added yet. Use the Exam Composer to add questions.',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
                  ),
                )
              else
                ...List.generate(_exam.questions.length, (idx) {
                  final q = _exam.questions[idx];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QUESTION ${idx + 1}. ',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            if (q.topic.isNotEmpty)
                              Text(
                                '(${q.topic}) ',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                              ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black54),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '[ ${q.marks} MARKS ]',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            q.content,
                            style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                          ),
                        ),
                        if (q.type == QuestionType.mcq && q.options.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int opt = 0; opt < q.options.length; opt++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${String.fromCharCode(65 + opt)}.  ${q.options[opt]}',
                                      style: const TextStyle(fontSize: 10.5, color: Colors.black87),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (_showMarkingScheme) ...[
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.only(left: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Model Solution & Marking Scheme:',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                if (q.type == QuestionType.mcq && q.correctOptionIndex != null)
                                  Text('Correct Answer: Option ${String.fromCharCode(65 + q.correctOptionIndex!)}',
                                      style: const TextStyle(fontSize: 9, color: Color(0xFF166534))),
                                if (q.rubric != null)
                                  Text('Rubric: ${q.rubric}', style: const TextStyle(fontSize: 9, color: Color(0xFF166534))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),
              const Center(
                child: Text(
                  '*** END OF EXAMINATION PAPER ***',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

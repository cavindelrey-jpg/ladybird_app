// lib/features/school/exam_composer/exam_preview_page.dart
// Complete Preview mode showing the final examination paper exactly as it
// will appear when generated or printed, with school digital letterhead.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/app_user.dart';
import '../../../models/exam_question.dart';
import '../../../models/examination.dart';
import '../../../models/test.dart';
import '../../../repositories/exam_repository.dart';
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
  bool _loading = false;

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
                    Navigator.pop(bCtx);
                  },
                )),
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

  void _sharePaper() {
    final text = _generatePlainTextPaper();
    Share.share(text, subject: '${_exam.title} - ${_exam.subject} (${_exam.classLevel})');
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
            icon: const Icon(Icons.style_outlined),
            tooltip: 'Select Letterhead Template',
            onPressed: _chooseTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Paper',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Paper',
            onPressed: _sharePaper,
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
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sharePaper,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Generate Paper', style: TextStyle(fontSize: 12)),
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
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontFamily: 'serif',
                              height: 1.2,
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
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(color: const Color(0xFF0A7A3B), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.school, color: Color(0xFF0A7A3B), size: 28),
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
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0A7A3B),
                              fontFamily: 'serif',
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.black,
                    fontFamily: 'serif',
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Metadata Table Box
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SUBJECT: ${_exam.subject.toUpperCase()}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('CLASS: ${_exam.classLevel.toUpperCase()}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('YEAR: ${_exam.academicYear}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DURATION: ${_exam.durationMinutes} MIN',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                        Text('TOTAL MARKS: ${_exam.effectiveTotalMarks}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                        Text('DATE: ${_exam.date.day}/${_exam.date.month}/${_exam.date.year}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Student Identification Line Box
              if (tmpl?.includeStudentFields ?? true) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(color: Colors.black54, width: 0.8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text('Candidate Name: _________________________________',
                            style: TextStyle(fontSize: 10, color: Colors.black87)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Candidate No: ______________',
                            style: TextStyle(fontSize: 10, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 4. Instructions Box
              if (tmpl?.includeInstructionsBox ?? true) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black45, width: 0.8),
                    color: const Color(0xFFF8F9FA),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INSTRUCTIONS TO CANDIDATES:',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _exam.instructions,
                        style: const TextStyle(fontSize: 10, color: Colors.black87, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Questions in Order
              for (int i = 0; i < _exam.questions.length; i++) ...[
                _buildQuestionView(i + 1, _exam.questions[i]),
                const SizedBox(height: 16),
              ],

              // Footer End of Paper
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  '*** END OF EXAMINATION PAPER ***',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionView(int number, ExamQuestion q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUESTION $number',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'serif'),
            ),
            Text(
              '(${q.marks} marks)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          q.content,
          style: const TextStyle(fontSize: 12, color: Colors.black, height: 1.4, fontFamily: 'serif'),
        ),

        // MCQ Options
        if (q.type == QuestionType.mcq && q.options.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (int i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                '${String.fromCharCode(65 + i)})  ${q.options[i]}',
                style: const TextStyle(fontSize: 11.5, color: Colors.black87, fontFamily: 'serif'),
              ),
            ),
        ],

        // Ruled lines placeholder for structured questions
        if (q.type == QuestionType.structured && !_showMarkingScheme) ...[
          const SizedBox(height: 10),
          for (int line = 0; line < 3; line++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFD1D5DB), width: 0.8)),
              ),
              height: 1,
            ),
        ],

        // Marking Scheme if toggled
        if (_showMarkingScheme) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF81C784)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Marking Scheme & Guide:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                if (q.type == QuestionType.mcq && q.correctOptionIndex != null)
                  Text('Correct Answer: ${String.fromCharCode(65 + q.correctOptionIndex!)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                if (q.rubric != null && q.rubric!.isNotEmpty)
                  Text('Model steps: ${q.rubric}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF1B5E20))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

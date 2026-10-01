// lib/features/school/exam_composer/exam_metadata_page.dart
// Form for entering examination metadata before opening the Exam Composer.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/app_user.dart';
import '../../../models/examination.dart';
import '../../../repositories/exam_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import 'exam_composer_page.dart';

class ExamMetadataPage extends StatefulWidget {
  final AppUser user;
  final Examination? initialExam;

  const ExamMetadataPage({super.key, required this.user, this.initialExam});

  @override
  State<ExamMetadataPage> createState() => _ExamMetadataPageState();
}

class _ExamMetadataPageState extends State<ExamMetadataPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _classLevelCtrl;
  late final TextEditingController _academicYearCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _examinerCtrl;
  late final TextEditingController _instructionsCtrl;

  late ExamTemplateType _type;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final exam = widget.initialExam;
    _type = exam?.examinationType ?? ExamTemplateType.examination;
    _date = exam?.date ?? DateTime.now();

    // Pre-populate sensible defaults from user / assignments
    final defaultSubject = widget.user.teachingAssignments.isNotEmpty
        ? widget.user.teachingAssignments.first.subject
        : 'Mathematics';
    final defaultClass = widget.user.teachingAssignments.isNotEmpty
        ? widget.user.teachingAssignments.first.classLevel
        : (widget.user.classMasterOfClass ?? 'Form 5');

    _titleCtrl = TextEditingController(text: exam?.title ?? 'First Sequence Examination');
    _subjectCtrl = TextEditingController(text: exam?.subject ?? defaultSubject);
    _classLevelCtrl = TextEditingController(text: exam?.classLevel ?? defaultClass);
    _academicYearCtrl = TextEditingController(text: exam?.academicYear ?? '2025/2026');
    _durationCtrl = TextEditingController(text: (exam?.durationMinutes ?? 90).toString());
    _examinerCtrl = TextEditingController(text: exam?.examinerName ?? widget.user.name);
    _instructionsCtrl = TextEditingController(
      text: exam?.instructions ??
          'Answer ALL questions in Section A and any TWO in Section B. '
          'Show all working clearly. Non-programmable calculators allowed.',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _classLevelCtrl.dispose();
    _academicYearCtrl.dispose();
    _durationCtrl.dispose();
    _examinerCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _proceedToComposer() async {
    if (!_formKey.currentState!.validate()) return;

    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 90;
    final schoolId = widget.user.schoolId ?? '';

    final exam = (widget.initialExam ??
            Examination(
              id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
              schoolId: schoolId,
              title: _titleCtrl.text.trim(),
              examinationType: _type,
              subject: _subjectCtrl.text.trim(),
              classLevel: _classLevelCtrl.text.trim(),
              academicYear: _academicYearCtrl.text.trim(),
              durationMinutes: duration,
              date: _date,
              examinerName: _examinerCtrl.text.trim(),
              examinerId: widget.user.id,
              instructions: _instructionsCtrl.text.trim(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ))
        .copyWith(
      title: _titleCtrl.text.trim(),
      examinationType: _type,
      subject: _subjectCtrl.text.trim(),
      classLevel: _classLevelCtrl.text.trim(),
      academicYear: _academicYearCtrl.text.trim(),
      durationMinutes: duration,
      date: _date,
      examinerName: _examinerCtrl.text.trim(),
      instructions: _instructionsCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );

    await ExamRepository.instance.saveExamination(exam);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ExamComposerPage(examination: exam, user: widget.user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Examination Details', style: AppText.title),
        backgroundColor: ac.bg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Examination Metadata', style: AppText.h2.copyWith(fontSize: 18, color: ac.txt)),
              const SizedBox(height: 4),
              Text('Set up the examination profile before composing questions.',
                  style: AppText.bodySm.copyWith(color: ac.muted)),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _titleCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Exam title is required' : null,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: const InputDecoration(
                  labelText: 'Examination Title *',
                  hintText: 'e.g. First Sequence Examination',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Exam Type
              DropdownButtonFormField<ExamTemplateType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Assessment / Exam Type',
                  prefixIcon: Icon(Icons.assignment_outlined),
                ),
                items: ExamTemplateType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? ExamTemplateType.examination),
              ),
              const SizedBox(height: 16),

              // Subject & Class Level Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subjectCtrl,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject required' : null,
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        hintText: 'e.g. Mathematics',
                        prefixIcon: Icon(Icons.menu_book_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _classLevelCtrl,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Class required' : null,
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: const InputDecoration(
                        labelText: 'Class / Level *',
                        hintText: 'e.g. Form 5',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Academic Year & Duration Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _academicYearCtrl,
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        hintText: 'e.g. 2025/2026',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: const InputDecoration(
                        labelText: 'Duration (Minutes)',
                        hintText: '90',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date Picker Field
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Examination Date',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
                  child: Text(DateFormat('EEEE, d MMMM yyyy').format(_date),
                      style: AppText.bodySm.copyWith(color: ac.txt)),
                ),
              ),
              const SizedBox(height: 16),

              // Examiner
              TextFormField(
                controller: _examinerCtrl,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: const InputDecoration(
                  labelText: 'Examiner / Teacher Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Instructions
              TextFormField(
                controller: _instructionsCtrl,
                maxLines: 3,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: const InputDecoration(
                  labelText: 'Candidate Instructions',
                  hintText: 'e.g. Answer all questions in Section A...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _proceedToComposer,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text('Open Exam Composer', style: AppText.button.copyWith(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

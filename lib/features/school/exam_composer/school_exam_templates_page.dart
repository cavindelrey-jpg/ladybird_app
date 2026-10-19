// lib/features/school/exam_composer/school_exam_templates_page.dart
// Administrator configuration page for school examination templates and digital letterheads.
// Enforces permissions: teachers pick from configured templates; administrators configure them.

import 'package:flutter/material.dart';
import '../../../models/app_user.dart';
import '../../../models/examination.dart';
import '../../../repositories/exam_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';

class SchoolExamTemplatesPage extends StatefulWidget {
  final AppUser user;

  const SchoolExamTemplatesPage({super.key, required this.user});

  @override
  State<SchoolExamTemplatesPage> createState() => _SchoolExamTemplatesPageState();
}

class _SchoolExamTemplatesPageState extends State<SchoolExamTemplatesPage> {
  void _editTemplate(BuildContext context, SchoolExamTemplate? initial) {
    final schoolId = widget.user.schoolId ?? '';
    final nameCtrl = TextEditingController(text: initial?.name ?? 'Standard Exam Letterhead');
    final schoolNameCtrl = TextEditingController(text: initial?.schoolName ?? 'CFPMI');
    final countryHeaderCtrl = TextEditingController(
      text: initial?.countryHeader ??
          'REPUBLIC OF CAMEROON\nPeace - Work - Fatherland\nMINISTRY OF SECONDARY EDUCATION',
    );
    final subHeaderCtrl = TextEditingController(
      text: initial?.subHeader ??
          'REGIONAL DELEGATION OF SECONDARY EDUCATION\nP.O. Box 1234, Douala | Tel: +237 670 000 000',
    );
    final mottoCtrl = TextEditingController(text: initial?.motto ?? 'Excellence - Discipline - Success');
    final instructionsCtrl = TextEditingController(
      text: initial?.defaultInstructions ??
          'Answer ALL questions. Show all working clearly. Non-programmable calculators allowed.',
    );

    ExamTemplateType type = initial?.type ?? ExamTemplateType.examination;
    bool includeStudentFields = initial?.includeStudentFields ?? true;
    bool includeInstructionsBox = initial?.includeInstructionsBox ?? true;
    bool includeMarksBox = initial?.includeMarksBox ?? true;
    final ac = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        initial == null ? 'New Exam Letterhead Template' : 'Edit Template',
                        style: AppText.title.copyWith(fontSize: 16, color: ac.txt),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sCtx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Template Name *', hintText: 'e.g. Official Sequence Exam'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ExamTemplateType>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Template Type'),
                    items: ExamTemplateType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                        .toList(),
                    onChanged: (v) => setModalState(() => type = v ?? ExamTemplateType.examination),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: schoolNameCtrl,
                    decoration: const InputDecoration(labelText: 'Official School Name Header'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryHeaderCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Country & Ministry Header'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subHeaderCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Regional Delegation & Contact Header'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mottoCtrl,
                    decoration: const InputDecoration(labelText: 'School Motto'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructionsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Default Instructions Block'),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Include Student Info Fields (Name, Class, ID)'),
                    value: includeStudentFields,
                    onChanged: (v) => setModalState(() => includeStudentFields = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Include Standard Instructions Box'),
                    value: includeInstructionsBox,
                    onChanged: (v) => setModalState(() => includeInstructionsBox = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Include Total Marks Summary Box'),
                    value: includeMarksBox,
                    onChanged: (v) => setModalState(() => includeMarksBox = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final tmpl = SchoolExamTemplate(
                          id: initial?.id ?? 'tmpl_${DateTime.now().millisecondsSinceEpoch}',
                          schoolId: schoolId,
                          name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Standard Template',
                          type: type,
                          schoolName: schoolNameCtrl.text.trim(),
                          countryHeader: countryHeaderCtrl.text.trim(),
                          subHeader: subHeaderCtrl.text.trim(),
                          motto: mottoCtrl.text.trim(),
                          defaultInstructions: instructionsCtrl.text.trim(),
                          includeStudentFields: includeStudentFields,
                          includeInstructionsBox: includeInstructionsBox,
                          includeMarksBox: includeMarksBox,
                        );

                        await ExamRepository.instance.saveSchoolTemplate(tmpl);
                        if (sCtx.mounted) Navigator.pop(sCtx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save School Template'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = widget.user.schoolId ?? '';

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('School Exam Templates', style: AppText.title),
        backgroundColor: ac.bg,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTemplate(context, null),
        backgroundColor: ac.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Template'),
      ),
      body: StreamBuilder<List<SchoolExamTemplate>>(
        stream: ExamRepository.instance.watchSchoolTemplates(schoolId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final templates = snap.data ?? [];

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final t = templates[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ac.surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ac.bdr2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: ac.bluBg, borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.description_outlined, color: ac.blu, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: AppText.title.copyWith(fontSize: 15, color: ac.txt)),
                              Text(t.type.label, style: AppText.caption.copyWith(color: ac.muted)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _editTemplate(context, t),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Header: ${t.schoolName} · ${t.motto ?? ''}',
                      style: AppText.bodySm.copyWith(color: ac.txt2, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.defaultInstructions ?? 'Standard instructions applied.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: ac.muted),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// lib/features/school/exam_composer/question_editor_dialog.dart
// Dialog/Form for typing a new question from scratch or editing an existing question.

import 'package:flutter/material.dart';
import '../../../models/exam_question.dart';
import '../../../models/test.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';

class QuestionEditorDialog extends StatefulWidget {
  final ExamQuestion? initialQuestion;
  final String defaultSubject;
  final String defaultClassLevel;
  final String schoolId;

  const QuestionEditorDialog({
    super.key,
    this.initialQuestion,
    required this.defaultSubject,
    required this.defaultClassLevel,
    required this.schoolId,
  });

  @override
  State<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<QuestionEditorDialog> {
  late QuestionType _type;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _marksCtrl;
  late final TextEditingController _topicCtrl;
  late final TextEditingController _subtopicCtrl;
  late final TextEditingController _rubricCtrl;
  String _difficulty = 'medium';

  // MCQ
  late List<TextEditingController> _optionCtrls;
  int _correctOptionIndex = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    _type = q?.type ?? QuestionType.structured;
    _contentCtrl = TextEditingController(text: q?.content ?? '');
    _marksCtrl = TextEditingController(text: (q?.marks ?? 5).toString());
    _topicCtrl = TextEditingController(text: q?.topic ?? '');
    _subtopicCtrl = TextEditingController(text: q?.subtopic ?? '');
    _rubricCtrl = TextEditingController(text: q?.rubric ?? '');
    _difficulty = q?.difficulty ?? 'medium';

    final opts = q?.options ?? ['Option A', 'Option B', 'Option C', 'Option D'];
    _optionCtrls = opts.map((o) => TextEditingController(text: o)).toList();
    if (_optionCtrls.isEmpty) {
      _optionCtrls = List.generate(4, (i) => TextEditingController(text: 'Option ${String.fromCharCode(65 + i)}'));
    }
    _correctOptionIndex = (q?.correctOptionIndex ?? 0).clamp(0, _optionCtrls.length - 1);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _marksCtrl.dispose();
    _topicCtrl.dispose();
    _subtopicCtrl.dispose();
    _rubricCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the question text.')),
      );
      return;
    }

    final marks = int.tryParse(_marksCtrl.text.trim()) ?? 5;
    final options = _type == QuestionType.mcq
        ? _optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];

    final q = (widget.initialQuestion ??
            ExamQuestion(
              id: 'q_${DateTime.now().millisecondsSinceEpoch}',
              content: text,
              marks: marks,
              type: _type,
              subject: widget.defaultSubject,
              classLevel: widget.defaultClassLevel,
              topic: _topicCtrl.text.trim(),
              subtopic: _subtopicCtrl.text.trim(),
              difficulty: _difficulty,
              source: 'Self-authored',
              schoolId: widget.schoolId,
              createdAt: DateTime.now(),
            ))
        .copyWith(
      content: text,
      marks: marks,
      type: _type,
      topic: _topicCtrl.text.trim(),
      subtopic: _subtopicCtrl.text.trim(),
      difficulty: _difficulty,
      options: options,
      correctOptionIndex: _type == QuestionType.mcq ? _correctOptionIndex : null,
      rubric: _rubricCtrl.text.trim().isNotEmpty ? _rubricCtrl.text.trim() : null,
    );

    Navigator.of(context).pop(q);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isEditing = widget.initialQuestion != null;

    return Dialog(
      backgroundColor: ac.surf,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                      color: ac.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Question' : 'Create New Question',
                      style: AppText.title.copyWith(fontSize: 17, color: ac.txt),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ac.muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Type Selector
                    Text('Question Format', style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2)),
                    const SizedBox(height: 8),
                    SegmentedButton<QuestionType>(
                      segments: const [
                        ButtonSegment(
                          value: QuestionType.structured,
                          label: Text('Structured', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: QuestionType.mcq,
                          label: Text('MCQ', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: QuestionType.longForm,
                          label: Text('Essay', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (set) => setState(() => _type = set.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Question Content
                    Text('Question Content / Prompt *',
                        style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _contentCtrl,
                      maxLines: 4,
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: InputDecoration(
                        hintText: 'Enter question text or statement here...',
                        hintStyle: AppText.bodySm.copyWith(color: ac.muted),
                        filled: true,
                        fillColor: ac.surf2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ac.bdr),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Marks & Difficulty Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Marks', style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _marksCtrl,
                                keyboardType: TextInputType.number,
                                style: AppText.bodySm.copyWith(color: ac.txt),
                                decoration: InputDecoration(
                                  suffixText: 'marks',
                                  filled: true,
                                  fillColor: ac.surf2,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: ac.bdr),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Difficulty', style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _difficulty,
                                dropdownColor: ac.surf,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: ac.surf2,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: ac.bdr),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                                ],
                                onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Topic & Subtopic Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Topic', style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _topicCtrl,
                                style: AppText.bodySm.copyWith(color: ac.txt),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Algebra',
                                  filled: true,
                                  fillColor: ac.surf2,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: ac.bdr),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Subtopic', style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _subtopicCtrl,
                                style: AppText.bodySm.copyWith(color: ac.txt),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Quadratic Eq.',
                                  filled: true,
                                  fillColor: ac.surf2,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: ac.bdr),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // MCQ Options Section
                    if (_type == QuestionType.mcq) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Options & Correct Answer',
                              style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2)),
                          if (_optionCtrls.length < 6)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _optionCtrls.add(TextEditingController(
                                    text: 'Option ${String.fromCharCode(65 + _optionCtrls.length)}',
                                  ));
                                });
                              },
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Add Option', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < _optionCtrls.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Radio<int>(
                                value: i,
                                groupValue: _correctOptionIndex,
                                activeColor: ac.primary,
                                onChanged: (v) => setState(() => _correctOptionIndex = v ?? 0),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _optionCtrls[i],
                                  style: AppText.bodySm.copyWith(color: ac.txt),
                                  decoration: InputDecoration(
                                    prefixText: '${String.fromCharCode(65 + i)}. ',
                                    filled: true,
                                    fillColor: ac.surf2,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              if (_optionCtrls.length > 2)
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: ac.red),
                                  onPressed: () {
                                    setState(() {
                                      _optionCtrls.removeAt(i);
                                      if (_correctOptionIndex >= _optionCtrls.length) {
                                        _correctOptionIndex = _optionCtrls.length - 1;
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    // Rubric / Marking Guidance
                    Text('Marking Guidance / Answer Key',
                        style: AppText.subtitle.copyWith(fontSize: 12, color: ac.txt2)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _rubricCtrl,
                      maxLines: 2,
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: InputDecoration(
                        hintText: 'Key steps, points, or model answers expected...',
                        hintStyle: AppText.bodySm.copyWith(color: ac.muted),
                        filled: true,
                        fillColor: ac.surf2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ac.bdr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(isEditing ? 'Update Question' : 'Save Question'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

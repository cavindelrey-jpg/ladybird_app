// lib/features/school/exam_composer/exam_composer_page.dart
// Production-ready Exam Composer: assemble, reorder (drag & drop playlist style),
// edit, and manage questions, with direct integration to the Question Bank,
// Academia Library, Teacher Collections, and Preview mode.

import 'package:flutter/material.dart';
import '../../../models/app_user.dart';
import '../../../models/exam_question.dart';
import '../../../models/examination.dart';
import '../../../models/test.dart';
import '../../../repositories/exam_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import 'exam_preview_page.dart';
import 'question_bank_picker_sheet.dart';
import 'question_editor_dialog.dart';

class ExamComposerPage extends StatefulWidget {
  final Examination examination;
  final AppUser user;

  const ExamComposerPage({
    super.key,
    required this.examination,
    required this.user,
  });

  @override
  State<ExamComposerPage> createState() => _ExamComposerPageState();
}

class _ExamComposerPageState extends State<ExamComposerPage> {
  late Examination _exam;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _exam = widget.examination;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _exam = _exam.copyWith(updatedAt: DateTime.now());
    await ExamRepository.instance.saveExamination(_exam);
    if (mounted) setState(() => _saving = false);
  }

  void _addFromQuestionBank() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuestionBankPickerSheet(
        schoolId: widget.user.schoolId ?? '',
        defaultSubject: _exam.subject,
        defaultClassLevel: _exam.classLevel,
        alreadyAddedIds: _exam.questions.map((q) => q.id).toSet(),
        onQuestionAdded: (q) {
          setState(() {
            _exam = _exam.copyWith(questions: [..._exam.questions, q]);
          });
          _save();
        },
      ),
    );
  }

  void _addFromCollections() async {
    final schoolId = widget.user.schoolId ?? '';
    final collections = await ExamRepository.instance
        .watchCollections(schoolId: schoolId, teacherId: widget.user.id)
        .first;

    if (!mounted) return;
    final ac = AppColors.of(context);

    if (collections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved collections found. Create a collection first in Question Collections.')),
      );
      return;
    }

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
              child: Text('Add Questions from Collection',
                  style: AppText.title.copyWith(fontSize: 16)),
            ),
            const Divider(height: 1),
            ...collections.map((col) => ListTile(
                  leading: Icon(Icons.collections_bookmark_outlined, color: ac.primary),
                  title: Text(col.name),
                  subtitle: Text('${col.questions.length} questions · ${col.subject}'),
                  onTap: () {
                    Navigator.pop(bCtx);
                    _importFromCollection(col);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _importFromCollection(QuestionCollection col) {
    final existingIds = _exam.questions.map((q) => q.id).toSet();
    final newQuestions = col.questions.where((q) => !existingIds.contains(q.id)).toList();

    if (newQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All questions in this collection are already added.')),
      );
      return;
    }

    setState(() {
      _exam = _exam.copyWith(questions: [..._exam.questions, ...newQuestions]);
    });
    _save();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${newQuestions.length} questions from "${col.name}".')),
    );
  }

  void _createQuestionFromScratch() async {
    final q = await showDialog<ExamQuestion>(
      context: context,
      builder: (_) => QuestionEditorDialog(
        defaultSubject: _exam.subject,
        defaultClassLevel: _exam.classLevel,
        schoolId: widget.user.schoolId ?? '',
      ),
    );
    if (q != null) {
      setState(() {
        _exam = _exam.copyWith(questions: [..._exam.questions, q]);
      });
      await ExamRepository.instance.saveQuestionToBank(q);
      _save();
    }
  }

  void _editQuestion(int index) async {
    final current = _exam.questions[index];
    final updated = await showDialog<ExamQuestion>(
      context: context,
      builder: (_) => QuestionEditorDialog(
        initialQuestion: current,
        defaultSubject: _exam.subject,
        defaultClassLevel: _exam.classLevel,
        schoolId: widget.user.schoolId ?? '',
      ),
    );
    if (updated != null) {
      setState(() {
        final list = List<ExamQuestion>.from(_exam.questions);
        list[index] = updated;
        _exam = _exam.copyWith(questions: list);
      });
      _save();
    }
  }

  void _removeQuestion(int index) {
    setState(() {
      final list = List<ExamQuestion>.from(_exam.questions);
      list.removeAt(index);
      _exam = _exam.copyWith(questions: list);
    });
    _save();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final list = List<ExamQuestion>.from(_exam.questions);
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _exam = _exam.copyWith(questions: list);
    });
    _save();
  }

  void _showAddQuestionOptions() {
    final ac = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.search_rounded, color: ac.primary),
              title: const Text('Search Question Bank / Library'),
              subtitle: const Text('Add past papers, textbooks, and school questions'),
              onTap: () {
                Navigator.pop(sCtx);
                _addFromQuestionBank();
              },
            ),
            ListTile(
              leading: Icon(Icons.collections_bookmark_outlined, color: ac.primary),
              title: const Text('Add from My Collections'),
              subtitle: const Text('Import saved revision question sets'),
              onTap: () {
                Navigator.pop(sCtx);
                _addFromCollections();
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_note_rounded, color: ac.primary),
              title: const Text('Write Question from Scratch'),
              subtitle: const Text('Create a new custom MCQ, Structured, or Essay question'),
              onTap: () {
                Navigator.pop(sCtx);
                _createQuestionFromScratch();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final totalMarks = _exam.computedTotalMarks;
    final topicCount = _exam.questions.map((q) => q.topic).where((t) => t.isNotEmpty).toSet().length;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_exam.title, style: AppText.title.copyWith(fontSize: 16)),
            Text('${_exam.subject} · ${_exam.classLevel}',
                style: AppText.caption.copyWith(color: ac.muted, fontSize: 11)),
          ],
        ),
        backgroundColor: ac.bg,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ExamPreviewPage(examination: _exam, user: widget.user),
              ));
            },
            icon: const Icon(Icons.preview_rounded, size: 18),
            label: const Text('Preview'),
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
                onPressed: _showAddQuestionOptions,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Question'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExamPreviewPage(examination: _exam, user: widget.user),
                  ));
                },
                icon: const Icon(Icons.assignment_turned_in_rounded),
                label: const Text('Finalize / Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Playlist Summary Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ac.surf2,
              border: Border(bottom: BorderSide(color: ac.bdr)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric(ac, '${_exam.questions.length}', 'Questions', Icons.help_outline_rounded),
                _metric(ac, '$totalMarks', 'Total Marks', Icons.stars_rounded),
                _metric(ac, '${_exam.durationMinutes}m', 'Duration', Icons.timer_outlined),
                _metric(ac, '$topicCount', 'Topics', Icons.category_outlined),
              ],
            ),
          ),

          // Reorderable Question List
          Expanded(
            child: _exam.questions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.playlist_add_rounded, size: 56, color: ac.muted),
                          const SizedBox(height: 16),
                          Text('No questions added yet',
                              style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
                          const SizedBox(height: 8),
                          Text(
                            'Assemble your exam by searching the school Question Bank, Academia Library past papers, or typing questions from scratch.',
                            textAlign: TextAlign.center,
                            style: AppText.bodySm.copyWith(color: ac.muted),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _showAddQuestionOptions,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add First Question'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ac.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _exam.questions.length,
                    onReorder: _onReorder,
                    itemBuilder: (ctx, i) {
                      final q = _exam.questions[i];
                      return _PlaylistQuestionCard(
                        key: ValueKey(q.id),
                        index: i,
                        question: q,
                        onEdit: () => _editQuestion(i),
                        onDelete: () => _removeQuestion(i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metric(AppColors ac, String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: ac.primary),
            const SizedBox(width: 4),
            Text(value, style: AppText.title.copyWith(fontSize: 14, color: ac.txt)),
          ],
        ),
        Text(label, style: AppText.caption.copyWith(color: ac.muted, fontSize: 10.5)),
      ],
    );
  }
}

class _PlaylistQuestionCard extends StatelessWidget {
  final int index;
  final ExamQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaylistQuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.drag_indicator_rounded, color: ac.muted, size: 20),
                ),
              ),

              // Question number badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(6)),
                child: Text('Q${index + 1}',
                    style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),

              // Format chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(6)),
                child: Text(question.type.label,
                    style: AppText.caption.copyWith(fontSize: 10, color: ac.pur, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),

              // Marks
              Text('[${question.marks} marks]',
                  style: AppText.caption.copyWith(fontWeight: FontWeight.bold, color: ac.blu)),

              const Spacer(),

              // Edit action
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit wording or marks',
                onPressed: onEdit,
              ),

              // Delete action
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: ac.red),
                tooltip: 'Remove from exam',
                onPressed: onDelete,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Question Content
          Text(
            question.content,
            style: AppText.bodySm.copyWith(color: ac.txt, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // MCQ options snippet
          if (question.type == QuestionType.mcq && question.options.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < question.options.length.clamp(0, 4); i++)
                  Text(
                    '${String.fromCharCode(65 + i)}. ${question.options[i]}',
                    style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Footer info tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (question.topic.isNotEmpty)
                Text('• ${question.topic}', style: AppText.caption.copyWith(color: ac.muted, fontSize: 10.5)),
              Text('• Source: ${question.source}',
                  style: AppText.caption.copyWith(color: ac.muted, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}

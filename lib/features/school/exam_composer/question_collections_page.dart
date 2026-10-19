// lib/features/school/exam_composer/question_collections_page.dart
// Persistent teacher collections (Question -> Collection -> Exam).
// Allows teachers to curate revision questions, save them across terms,
// and import them into examinations.

import 'package:flutter/material.dart';
import '../../../models/app_user.dart';
import '../../../models/exam_question.dart';
import '../../../repositories/exam_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/widgets.dart';
import 'question_bank_picker_sheet.dart';
import 'question_editor_dialog.dart';

class QuestionCollectionsPage extends StatefulWidget {
  final AppUser user;
  final String? initialSubject;

  const QuestionCollectionsPage({
    super.key,
    required this.user,
    this.initialSubject,
  });

  @override
  State<QuestionCollectionsPage> createState() => _QuestionCollectionsPageState();
}

class _QuestionCollectionsPageState extends State<QuestionCollectionsPage> {
  void _createCollectionDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final subjectCtrl = TextEditingController(text: widget.initialSubject ?? 'Mathematics');
    final ac = AppColors.of(context);

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: ac.surf,
        title: const Text('Create Question Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Collection Name *',
                hintText: 'e.g. My Revision Questions, Mid-Term Drills',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Mathematics',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Focus on Form 5 quadratic equations and calculus',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final collection = QuestionCollection(
                id: 'col_${DateTime.now().millisecondsSinceEpoch}',
                teacherId: widget.user.id,
                schoolId: widget.user.schoolId ?? '',
                name: name,
                description: descCtrl.text.trim(),
                subject: subjectCtrl.text.trim(),
                questions: [],
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              await ExamRepository.instance.saveCollection(collection);
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ac.primary, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = widget.user.schoolId ?? '';

    return StreamBuilder<List<QuestionCollection>>(
      stream: ExamRepository.instance.watchCollections(
        schoolId: schoolId,
        teacherId: widget.user.id,
      ),
      builder: (context, snap) {
        final collections = snap.data ?? [];

        return ApplicationShell(
          user: widget.user,
          currentTitle: 'My Question Collections',
          subtitle: '${collections.length} saved sets',
          currentDestination: AppNavDestination.testsAndQuizzes,
          showBackButton: true,
          onBack: () => Navigator.of(context).maybePop(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createCollectionDialog(context),
            backgroundColor: ac.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Collection'),
          ),
          contextualPanel: _buildCollectionsContextualPanel(context, ac, collections),
          child: snap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : collections.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.collections_bookmark_outlined, size: 56, color: ac.muted),
                            const SizedBox(height: 16),
                            Text(
                              'No saved collections yet',
                              style: AppText.title.copyWith(fontSize: 16, color: ac.txt),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create persistent collections like "My Revision Questions" to save and organize questions for upcoming exams.',
                              textAlign: TextAlign.center,
                              style: AppText.bodySm.copyWith(color: ac.muted),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _createCollectionDialog(context),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create First Collection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ac.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: collections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final col = collections[i];
                        return _CollectionCard(
                          collection: col,
                          user: widget.user,
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => _CollectionDetailPage(collection: col, user: widget.user),
                            ));
                          },
                        );
                      },
                    ),
        );
      },
    );
  }

  Widget _buildCollectionsContextualPanel(
    BuildContext context,
    AppColors ac,
    List<QuestionCollection> collections,
  ) {
    final totalQuestions = collections.fold<int>(0, (sum, c) => sum + c.questions.length);
    final subjects = collections.map((c) => c.subject).where((s) => s.isNotEmpty).toSet().toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Curated Collections', style: AppText.title.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _createCollectionDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create New Collection', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ac.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 20),

        // Collection Stats Card
        Text('Library Overview', style: AppText.title.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            children: [
              _metricRow(ac, 'Saved Collections', '${collections.length}', Icons.collections_bookmark_outlined),
              const Divider(height: 16),
              _metricRow(ac, 'Curated Questions', '$totalQuestions', Icons.help_outline_rounded),
              const Divider(height: 16),
              _metricRow(ac, 'Active Subjects', '${subjects.length}', Icons.subject_rounded),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (subjects.isNotEmpty) ...[
          Text('Subjects Covered', style: AppText.title.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: subjects.map((subj) {
              final count = collections.where((c) => c.subject == subj).length;
              return Chip(
                backgroundColor: ac.surf,
                side: BorderSide(color: ac.bdr),
                label: Text('$subj ($count)', style: TextStyle(fontSize: 11, color: ac.txt)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Best Practice Tip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: ac.primary),
                  const SizedBox(width: 8),
                  Text('Teacher Tip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ac.txt)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Organize questions by topic or exam term (e.g. "Term 1 Algebra Drills"). You can pull questions directly from these collections into new exams inside the Exam Composer.',
                style: TextStyle(fontSize: 12, color: ac.txt2, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricRow(AppColors ac, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ac.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: ac.txt2))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final QuestionCollection collection;
  final AppUser user;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.collection,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
                    decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.folder_special_rounded, color: ac.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(collection.name,
                            style: AppText.title.copyWith(fontSize: 15, color: ac.txt)),
                        if (collection.subject.isNotEmpty)
                          Text(collection.subject,
                              style: AppText.caption.copyWith(color: ac.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: ac.muted),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('Delete Collection?'),
                          content: Text('Are you sure you want to remove "${collection.name}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ExamRepository.instance.deleteCollection(collection.id);
                      }
                    },
                  ),
                ],
              ),
              if (collection.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(collection.description,
                    style: AppText.bodySm.copyWith(color: ac.txt2, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _statChip(ac, '${collection.questions.length} questions', Icons.help_outline_rounded),
                  const SizedBox(width: 8),
                  _statChip(ac, '${collection.totalMarks} total marks', Icons.stars_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(AppColors ac, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ac.muted),
          const SizedBox(width: 4),
          Text(label, style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2)),
        ],
      ),
    );
  }
}

class _CollectionDetailPage extends StatefulWidget {
  final QuestionCollection collection;
  final AppUser user;

  const _CollectionDetailPage({required this.collection, required this.user});

  @override
  State<_CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<_CollectionDetailPage> {
  late QuestionCollection _col;

  @override
  void initState() {
    super.initState();
    _col = widget.collection;
  }

  Future<void> _save() async {
    _col = _col.copyWith(updatedAt: DateTime.now());
    await ExamRepository.instance.saveCollection(_col);
    setState(() {});
  }

  void _addFromBank() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuestionBankPickerSheet(
        schoolId: widget.user.schoolId ?? '',
        defaultSubject: _col.subject,
        defaultClassLevel: '',
        alreadyAddedIds: _col.questions.map((q) => q.id).toSet(),
        onQuestionAdded: (q) {
          setState(() {
            _col = _col.copyWith(questions: [..._col.questions, q]);
          });
          _save();
        },
      ),
    );
  }

  void _createNewQuestion() async {
    final q = await showDialog<ExamQuestion>(
      context: context,
      builder: (_) => QuestionEditorDialog(
        defaultSubject: _col.subject,
        defaultClassLevel: '',
        schoolId: widget.user.schoolId ?? '',
      ),
    );
    if (q != null) {
      setState(() {
        _col = _col.copyWith(questions: [..._col.questions, q]);
      });
      await ExamRepository.instance.saveQuestionToBank(q);
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ApplicationShell(
      user: widget.user,
      currentTitle: _col.name,
      subtitle: '${_col.subject.isEmpty ? "Collection" : _col.subject} · ${_col.questions.length} questions',
      currentDestination: AppNavDestination.testsAndQuizzes,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      contextualPanel: _buildDetailContextualPanel(context, ac),
      child: _col.questions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline_rounded, size: 48, color: ac.muted),
                    const SizedBox(height: 16),
                    Text('Collection is empty',
                        style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
                    const SizedBox(height: 8),
                    Text(
                      'Add questions from the school Question Bank, Academia Library past papers, or write new questions.',
                      textAlign: TextAlign.center,
                      style: AppText.bodySm.copyWith(color: ac.muted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _addFromBank,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Search Question Bank'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _col.questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final q = _col.questions[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ac.surf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ac.bdr2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Q${i + 1} · ${q.type.label} · ${q.marks} marks',
                              style: AppText.subtitle.copyWith(fontSize: 12, color: ac.primary)),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: ac.muted),
                            onPressed: () {
                              setState(() {
                                final updated = List<ExamQuestion>.from(_col.questions)..removeAt(i);
                                _col = _col.copyWith(questions: updated);
                              });
                              _save();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(q.content, style: AppText.bodySm.copyWith(color: ac.txt)),
                      const SizedBox(height: 6),
                      Text('Source: ${q.source}',
                          style: AppText.caption.copyWith(color: ac.muted, fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailContextualPanel(BuildContext context, AppColors ac) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Add Questions', style: AppText.title.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _addFromBank,
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('Search Question Bank', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ac.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _createNewQuestion,
          icon: Icon(Icons.create_rounded, size: 18, color: ac.primary),
          label: const Text('Create New Question', style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: ac.primary,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 20),

        Text('Collection Details', style: AppText.title.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            children: [
              _detailRow(ac, 'Subject', _col.subject.isEmpty ? 'General' : _col.subject),
              const Divider(height: 16),
              _detailRow(ac, 'Questions', '${_col.questions.length} items'),
              const Divider(height: 16),
              _detailRow(ac, 'Total Marks', '${_col.totalMarks} marks'),
            ],
          ),
        ),
        if (_col.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ac.bdr),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notes / Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ac.txt)),
                const SizedBox(height: 6),
                Text(_col.description, style: TextStyle(fontSize: 12, color: ac.txt2, height: 1.4)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailRow(AppColors ac, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: ac.txt2)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// lib/features/school/exam_composer/exam_list_page.dart
// Entry point for the Question Bank + Exam Composer system.
// Displays school examinations, draft papers, and links to Collections and Templates.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/app_user.dart';
import '../../../models/examination.dart';
import '../../../repositories/exam_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import 'exam_composer_page.dart';
import 'exam_metadata_page.dart';
import 'exam_preview_page.dart';
import 'question_collections_page.dart';
import 'school_exam_templates_page.dart';
import '../../academic_content/bulk_past_paper_upload_page.dart';

class ExamListPage extends StatefulWidget {
  final AppUser user;

  const ExamListPage({super.key, required this.user});

  @override
  State<ExamListPage> createState() => _ExamListPageState();
}

class _ExamListPageState extends State<ExamListPage> {
  String _filterSubject = '';

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = widget.user.schoolId ?? '';
    final canManageTemplates = widget.user.isAdmin || widget.user.canManageSchool;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Exam Composer', style: AppText.title),
        backgroundColor: ac.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: 'My Collections',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QuestionCollectionsPage(user: widget.user),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.drive_folder_upload_rounded),
            tooltip: 'Mass Upload Past Papers',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BulkPastPaperUploadPage(user: widget.user),
              ));
            },
          ),
          if (canManageTemplates)
            IconButton(
              icon: const Icon(Icons.style_outlined),
              tooltip: 'School Letterheads & Templates',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SchoolExamTemplatesPage(user: widget.user),
                ));
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExamMetadataPage(user: widget.user),
          ));
        },
        backgroundColor: ac.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Examination'),
      ),
      body: StreamBuilder<List<Examination>>(
        stream: ExamRepository.instance.watchExaminations(
          schoolId: schoolId,
          teacherId: widget.user.isAdmin ? null : widget.user.id,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final exams = snap.data ?? [];

          if (exams.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_outlined, size: 56, color: ac.muted),
                    const SizedBox(height: 16),
                    Text('No examinations created yet',
                        style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
                    const SizedBox(height: 8),
                    Text(
                      'Create official sequence papers, class tests, and mock exams with digital letterheads and question bank integration.',
                      textAlign: TextAlign.center,
                      style: AppText.bodySm.copyWith(color: ac.muted),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ExamMetadataPage(user: widget.user),
                        ));
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New Examination'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: exams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final exam = exams[i];
              return _ExamItemCard(
                exam: exam,
                user: widget.user,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExamComposerPage(examination: exam, user: widget.user),
                  ));
                },
                onPreview: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExamPreviewPage(examination: exam, user: widget.user),
                  ));
                },
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete Examination?'),
                      content: Text('Are you sure you want to delete "${exam.title}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ExamRepository.instance.deleteExamination(exam.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ExamItemCard extends StatelessWidget {
  final Examination exam;
  final AppUser user;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  const _ExamItemCard({
    required this.exam,
    required this.user,
    required this.onTap,
    required this.onPreview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final dateStr = DateFormat('d MMM yyyy').format(exam.date);

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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      exam.examinationType.label,
                      style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      exam.classLevel,
                      style: AppText.caption.copyWith(color: ac.txt2, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.preview_outlined, size: 20, color: ac.primary),
                    tooltip: 'Preview / Print',
                    onPressed: onPreview,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: ac.muted),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Text(exam.title, style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
              const SizedBox(height: 4),
              Text('${exam.subject} · ${exam.academicYear} · $dateStr',
                  style: AppText.caption.copyWith(color: ac.muted)),

              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(ac, '${exam.questions.length} questions', Icons.playlist_add_check_rounded),
                  const SizedBox(width: 8),
                  _infoChip(ac, '${exam.effectiveTotalMarks} marks', Icons.stars_rounded),
                  const SizedBox(width: 8),
                  _infoChip(ac, '${exam.durationMinutes} mins', Icons.timer_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(AppColors ac, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ac.muted),
          const SizedBox(width: 4),
          Text(text, style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2)),
        ],
      ),
    );
  }
}

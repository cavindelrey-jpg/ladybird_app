// lib/features/school/daily_notices/compose_daily_notice_page.dart
// Form for teachers and Class Masters to submit daily academic notices,
// homework, reminders, and assignments for their class.

import 'package:flutter/material.dart';
import '../../../models/app_user.dart';
import '../../../models/daily_notice.dart';
import '../../../repositories/daily_notice_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';

class ComposeDailyNoticePage extends StatefulWidget {
  final AppUser user;
  final String? initialClass;
  final String? initialSubject;

  const ComposeDailyNoticePage({
    super.key,
    required this.user,
    this.initialClass,
    this.initialSubject,
  });

  @override
  State<ComposeDailyNoticePage> createState() => _ComposeDailyNoticePageState();
}

class _ComposeDailyNoticePageState extends State<ComposeDailyNoticePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _classCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _attachmentCtrl;

  NoticeType _type = NoticeType.notice;
  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final defaultClass = widget.initialClass ??
        (widget.user.teachingAssignments.isNotEmpty
            ? widget.user.teachingAssignments.first.classLevel
            : (widget.user.classMasterOfClass ?? 'Form 5'));
    final defaultSubject = widget.initialSubject ??
        (widget.user.teachingAssignments.isNotEmpty
            ? widget.user.teachingAssignments.first.subject
            : 'Mathematics');

    _classCtrl = TextEditingController(text: defaultClass);
    _subjectCtrl = TextEditingController(text: defaultSubject);
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
    _attachmentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _classCtrl.dispose();
    _subjectCtrl.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _attachmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final teacherRole = widget.user.classMasterOfClass != null
        ? 'Class Master (${widget.user.classMasterOfClass})'
        : 'Subject Teacher';

    final notice = DailyNotice(
      id: 'notice_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: widget.user.schoolId ?? '',
      classLevel: _classCtrl.text.trim(),
      subject: _subjectCtrl.text.trim(),
      teacherId: widget.user.id,
      teacherName: widget.user.name,
      teacherRole: teacherRole,
      noticeType: _type,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      attachmentUrl: _attachmentCtrl.text.trim().isNotEmpty ? _attachmentCtrl.text.trim() : null,
      date: _date,
      isSystemGenerated: false,
      createdAt: DateTime.now(),
    );

    await DailyNoticeRepository.instance.submitNotice(notice);

    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notice posted for ${_classCtrl.text.trim()}.')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Submit Daily Notice', style: AppText.title),
        backgroundColor: ac.bg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Academic Notice Form', style: AppText.h2.copyWith(fontSize: 18, color: ac.txt)),
              const SizedBox(height: 4),
              Text('Broadcast homework, reminders, and academic information to students and parents.',
                  style: AppText.bodySm.copyWith(color: ac.muted)),
              const SizedBox(height: 20),

              // Notice Type
              DropdownButtonFormField<NoticeType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Notice Type *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  NoticeType.notice,
                  NoticeType.homework,
                  NoticeType.reminder,
                  NoticeType.assignment,
                  NoticeType.announcement,
                ].map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                onChanged: (v) => setState(() => _type = v ?? NoticeType.notice),
              ),
              const SizedBox(height: 16),

              // Class & Subject Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _classCtrl,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Class required' : null,
                      style: AppText.bodySm.copyWith(color: ac.txt),
                      decoration: const InputDecoration(
                        labelText: 'Class Level *',
                        hintText: 'e.g. Form 5',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: const InputDecoration(
                  labelText: 'Notice Title *',
                  hintText: 'e.g. Form 5 Mathematics Exercise Due Friday',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Content / Details
              TextFormField(
                controller: _contentCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Content required' : null,
                maxLines: 5,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: const InputDecoration(
                  labelText: 'Notice Content / Description *',
                  hintText: 'Type instructions, assignment problems, or reminders for the class...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Optional Attachment URL
              TextFormField(
                controller: _attachmentCtrl,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: const InputDecoration(
                  labelText: 'Attachment / Resource Link (Optional)',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.attach_file_rounded),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Submitting...' : 'Post Notice',
                      style: AppText.button.copyWith(fontSize: 15)),
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

// lib/features/school_connect/school_request_form_page.dart
// One real form behind every tile in School Connect's "How can we help
// you today?" grid — Report an Issue, Leave Request, Fee Enquiries,
// School Requests and Give Feedback all submit through here to
// SchoolRequestRepository, and show up afterwards in "Your Requests"
// with a status. That round trip is what makes each tile a genuine
// destination instead of a dead button that writes into the void.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/school_request.dart';
import '../../repositories/school_request_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class SchoolRequestFormPage extends StatefulWidget {
  final AppUser user;
  final SchoolRequestType type;
  const SchoolRequestFormPage({super.key, required this.user, required this.type});

  @override
  State<SchoolRequestFormPage> createState() => _SchoolRequestFormPageState();
}

class _SchoolRequestFormPageState extends State<SchoolRequestFormPage> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _saving = false;
  bool _submitted = false;

  String get _sid => widget.user.schoolId ?? '';

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      showToast(context, 'Add a subject and a short message.');
      return;
    }
    setState(() => _saving = true);
    final request = SchoolRequest(
      id: '',
      schoolId: _sid,
      studentId: widget.user.id,
      studentName: widget.user.name,
      type: widget.type,
      subject: subject,
      message: message,
      createdAt: DateTime.now(),
    );
    final result = await SchoolRequestRepository.instance.submit(request);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success) {
      setState(() => _submitted = true);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(widget.type.label, style: AppText.title),
      ),
      body: AppBackground(child: _submitted ? _SubmittedState(type: widget.type) : _form(ac)),
    );
  }

  Widget _form(AppColors ac) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.primaryBg,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.primary.withValues(alpha: .2)),
          ),
          child: Row(children: [
            Icon(Icons.route_rounded, size: 18, color: ac.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(
                'This goes straight to your school\'s ${widget.type.routedTo}.',
                style: AppText.bodySm.copyWith(color: ac.primary))),
          ]),
        ),
        const SizedBox(height: 20),
        Text('Subject', style: AppText.label.copyWith(letterSpacing: .4)),
        const SizedBox(height: 8),
        TextField(
          controller: _subjectCtrl,
          decoration: const InputDecoration(hintText: 'A short summary'),
        ),
        const SizedBox(height: 16),
        Text('Message', style: AppText.label.copyWith(letterSpacing: .4)),
        const SizedBox(height: 8),
        TextField(
          controller: _messageCtrl,
          maxLines: 6,
          decoration: InputDecoration(hintText: widget.type.hint),
        ),
        const SizedBox(height: 24),
        PrimaryBtn(label: 'Submit', loading: _saving, onTap: _submit),
      ]),
    );
  }
}

class _SubmittedState extends StatelessWidget {
  final SchoolRequestType type;
  const _SubmittedState({required this.type});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconBadge(icon: Icons.check_rounded, color: ac.grn, size: 72, iconSize: 32),
          const SizedBox(height: 20),
          Text('Sent to ${type.routedTo}', style: AppText.h2.copyWith(fontSize: 17),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Track it any time from "Your Requests" on the School Connect '
            'home screen.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
          SecondaryBtn(label: 'Done', onTap: () => Navigator.of(context).pop()),
        ]),
      ),
    );
  }
}

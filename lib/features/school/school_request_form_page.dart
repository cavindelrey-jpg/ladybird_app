// lib/features/school/school_request_form_page.dart
// Submission form shared by all five School Connect request types --
// they're the same shape (student writes a message, picks a type, staff
// responds later), so one form with a type selector rather than five
// near-identical screens.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_request.dart';
import '../../repositories/school_request_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

class SchoolRequestFormPage extends StatefulWidget {
  final AppUser user;
  final SchoolRequestType initialType;
  const SchoolRequestFormPage({super.key, required this.user, required this.initialType});

  @override
  State<SchoolRequestFormPage> createState() => _SchoolRequestFormPageState();
}

class _SchoolRequestFormPageState extends State<SchoolRequestFormPage> {
  late SchoolRequestType _type = widget.initialType;
  final _messageCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      showToast(context, 'Write a message first.', isError: true);
      return;
    }
    setState(() => _saving = true);
    final u = widget.user;
    final request = SchoolRequest(
      id: '',
      schoolId: u.schoolId ?? '',
      studentId: u.id,
      studentName: u.name,
      classLevel: u.classLevel,
      type: _type,
      message: message,
    );
    final result = await SchoolRequestRepository.instance.submit(request);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Failure<void>) {
      showToast(context, result.message, isError: true);
    } else {
      showToast(context, 'Sent to the school.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        title: Text('New Request', style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<SchoolRequestType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final t in SchoolRequestType.values) DropdownMenuItem(value: t, child: Text(t.label))],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 6,
            style: GoogleFonts.inter(fontSize: 13, color: ac.txt),
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: _hintFor(_type),
              alignLabelWithHint: true,
              filled: true, fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryBtn(label: 'Send to School', loading: _saving, onTap: _submit),
        ],
      ),
    );
  }

  String _hintFor(SchoolRequestType type) {
    switch (type) {
      case SchoolRequestType.issue:      return 'Describe the issue you\'re reporting...';
      case SchoolRequestType.leave:      return 'Dates and reason for the leave request...';
      case SchoolRequestType.feeInquiry: return 'What would you like to know about fees...';
      case SchoolRequestType.general:    return 'What do you need from the school...';
      case SchoolRequestType.feedback:   return 'Share your feedback...';
    }
  }
}

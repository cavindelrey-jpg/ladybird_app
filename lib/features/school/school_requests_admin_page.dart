// lib/features/school/school_requests_admin_page.dart
// Staff inbox for School Connect requests -- without this, a student
// submission would go into the database and never be seen by anyone.
// Gated to canUploadContent (lecturer+) or canManageSchool, matching the
// school_requests/{id} rule's update gate exactly.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_request.dart';
import '../../repositories/school_request_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

class SchoolRequestsAdminPage extends StatefulWidget {
  final AppUser staff;
  const SchoolRequestsAdminPage({super.key, required this.staff});

  @override
  State<SchoolRequestsAdminPage> createState() => _SchoolRequestsAdminPageState();
}

class _SchoolRequestsAdminPageState extends State<SchoolRequestsAdminPage> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final staff = widget.staff;

    if (!staff.canUploadContent && !staff.canManageSchool) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: Center(child: Text('Staff access required.', style: GoogleFonts.inter(color: ac.muted))),
      );
    }

    final schoolId = staff.schoolId ?? '';
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        title: Text('Requests Inbox', style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
        actions: [
          TextButton(
            onPressed: () => setState(() => _openOnly = !_openOnly),
            child: Text(_openOnly ? 'Show all' : 'Show open only'),
          ),
        ],
      ),
      body: StreamBuilder<List<SchoolRequest>>(
        stream: SchoolRequestRepository.instance.watchForSchool(schoolId, openOnly: _openOnly),
        builder: (context, snap) {
          final requests = snap.data ?? const <SchoolRequest>[];
          if (requests.isEmpty) {
            return Center(child: Text(_openOnly ? 'No open requests.' : 'No requests yet.',
                style: GoogleFonts.inter(color: ac.muted)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _requestCard(context, ac, requests[i]),
          );
        },
      ),
    );
  }

  Widget _requestCard(BuildContext context, AppColors ac, SchoolRequest r) {
    final statusColor = switch (r.status) {
      SchoolRequestStatus.pending    => ac.org,
      SchoolRequestStatus.inProgress => ac.blu,
      SchoolRequestStatus.resolved   => ac.grn,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${r.type.label} · ${r.studentName}',
                style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
            child: Text(r.status.label, style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(r.classLevel, style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
        const SizedBox(height: 8),
        Text(r.message, style: GoogleFonts.inter(fontSize: 12, color: ac.txt2, height: 1.35)),
        if (r.staffResponse != null && r.staffResponse!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(Rad.sm)),
            child: Text('Response: ${r.staffResponse}',
                style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt, fontStyle: FontStyle.italic)),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _openResponseSheet(context, r),
            child: const Text('Respond'),
          ),
        ),
      ]),
    );
  }

  Future<void> _openResponseSheet(BuildContext context, SchoolRequest r) async {
    final ctrl = TextEditingController(text: r.staffResponse ?? '');
    var status = r.status == SchoolRequestStatus.pending ? SchoolRequestStatus.inProgress : r.status;
    final ac = AppColors.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Respond to ${r.studentName}', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Response')),
            const SizedBox(height: 10),
            DropdownButtonFormField<SchoolRequestStatus>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [for (final s in SchoolRequestStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => setSheetState(() => status = v ?? status),
            ),
            const SizedBox(height: 16),
            PrimaryBtn(
              label: 'Save',
              onTap: () async {
                final result = await SchoolRequestRepository.instance.respond(
                  r.id, response: ctrl.text.trim(), status: status,
                );
                if (!ctx.mounted) return;
                if (result is Failure<void>) {
                  showToast(ctx, result.message, isError: true);
                } else {
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ]),
        );
      }),
    );
  }
}

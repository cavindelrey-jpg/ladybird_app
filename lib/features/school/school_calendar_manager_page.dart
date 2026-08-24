// lib/features/school/school_calendar_manager_page.dart
// Staff CRUD for the School Connect calendar -- gated to canManageSchool,
// matching schools/{schoolId}/academic_calendar's write rule exactly.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_event.dart';
import '../../repositories/school_event_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

class SchoolCalendarManagerPage extends StatelessWidget {
  final AppUser user;
  const SchoolCalendarManagerPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = user.schoolId ?? '';

    if (!user.canManageSchool) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: Center(child: Text('Staff access required.', style: GoogleFonts.inter(color: ac.muted))),
      );
    }

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        title: Text('Manage Calendar', style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ac.primary,
        onPressed: schoolId.isEmpty ? null : () => _openEditor(context, schoolId),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: StreamBuilder<List<SchoolEvent>>(
        stream: SchoolEventRepository.instance.watchAll(schoolId),
        builder: (context, snap) {
          final events = snap.data ?? const <SchoolEvent>[];
          if (events.isEmpty) {
            return Center(child: Text('No events yet -- tap + to add one.', style: GoogleFonts.inter(color: ac.muted)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = events[i];
              return Material(
                color: ac.surf,
                borderRadius: BorderRadius.circular(Rad.sm),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                  title: Text(e.title, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
                  subtitle: Text('${e.startAt.day}/${e.startAt.month}/${e.startAt.year}${(e.location ?? '').isNotEmpty ? ' · ${e.location}' : ''}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: ac.red, size: 20),
                    onPressed: () => SchoolEventRepository.instance.delete(schoolId, e.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, String schoolId) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    var startAt = DateTime.now().add(const Duration(days: 1));
    final ac = AppColors.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Event', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
              const SizedBox(height: 16),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location (optional)')),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${startAt.day}/${startAt.month}/${startAt.year}',
                    style: GoogleFonts.inter(fontSize: 13, color: ac.txt)),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx, initialDate: startAt,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setSheetState(() => startAt = picked);
                },
              ),
              const SizedBox(height: 16),
              PrimaryBtn(
                label: 'Add Event',
                onTap: () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    showToast(ctx, 'Title is required.', isError: true);
                    return;
                  }
                  final event = SchoolEvent(
                    id: '', schoolId: schoolId,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    startAt: startAt,
                    location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                  );
                  final result = await SchoolEventRepository.instance.add(event);
                  if (!ctx.mounted) return;
                  if (result is Failure<void>) {
                    showToast(ctx, result.message, isError: true);
                  } else {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ]),
          ),
        );
      }),
    );
  }
}

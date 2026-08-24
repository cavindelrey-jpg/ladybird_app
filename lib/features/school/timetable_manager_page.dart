// lib/features/school/timetable_manager_page.dart
// Staff-only CRUD for the School Timetable -- gated to canManageSchool(),
// matching firestore.rules' own write gate on schools/{schoolId}/
// timetable exactly. Without this, the "real, operational" Timetable
// page would have no way to ever contain real data.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_timetable_slot.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

class TimetableManagerPage extends StatefulWidget {
  final AppUser user;
  const TimetableManagerPage({super.key, required this.user});

  @override
  State<TimetableManagerPage> createState() => _TimetableManagerPageState();
}

class _TimetableManagerPageState extends State<TimetableManagerPage> {
  String _classLevel = '';
  final _classCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _classLevel = widget.user.classLevel;
    _classCtrl.text = _classLevel;
  }

  @override
  void dispose() {
    _classCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = widget.user.schoolId ?? '';

    if (!widget.user.canManageSchool) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: Center(child: Text('Staff access required.',
            style: GoogleFonts.inter(color: ac.muted))),
      );
    }

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        title: Text('Manage Timetable', style: AppText.h2.copyWith(fontSize: 16, color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ac.primary,
        onPressed: schoolId.isEmpty || _classLevel.isEmpty
            ? null
            : () => _openEditor(context, schoolId, null),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _classCtrl,
            style: GoogleFonts.inter(fontSize: 13, color: ac.txt),
            decoration: InputDecoration(
              labelText: 'Class (e.g. Form 4)',
              filled: true, fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _classLevel = v.trim()),
          ),
        ),
        if (schoolId.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Your account has no schoolId set -- can\'t manage a timetable without one.',
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.red)),
          )
        else
          Expanded(
            child: StreamBuilder<List<SchoolTimetableSlot>>(
              stream: SchoolTimetableRepository.instance.watchForClass(schoolId, _classLevel),
              builder: (context, snap) {
                final slots = snap.data ?? const <SchoolTimetableSlot>[];
                if (_classLevel.isEmpty) {
                  return Center(child: Text('Enter a class to manage its timetable.',
                      style: GoogleFonts.inter(color: ac.muted)));
                }
                if (slots.isEmpty) {
                  return Center(child: Text('No slots yet for $_classLevel -- tap + to add one.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: ac.muted)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: slots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = slots[i];
                    return Material(
                      color: ac.surf,
                      borderRadius: BorderRadius.circular(Rad.sm),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                        title: Text('${s.dayName} ${s.startTime}-${s.endTime} · ${s.subject}',
                            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
                        subtitle: Text('${s.teacherName}${(s.room ?? '').isNotEmpty ? ' · ${s.room}' : ''}',
                            style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: ac.red, size: 20),
                          onPressed: () async {
                            await SchoolTimetableRepository.instance.delete(schoolId, s.id);
                          },
                        ),
                        onTap: () => _openEditor(context, schoolId, s),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ]),
    );
  }

  Future<void> _openEditor(BuildContext context, String schoolId, SchoolTimetableSlot? existing) async {
    final subjectCtrl = TextEditingController(text: existing?.subject ?? '');
    final teacherCtrl = TextEditingController(text: existing?.teacherName ?? '');
    final roomCtrl = TextEditingController(text: existing?.room ?? '');
    final startCtrl = TextEditingController(text: existing?.startTime ?? '08:00');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '09:00');
    var dayOfWeek = existing?.dayOfWeek ?? 1;

    final ac = AppColors.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Add Period' : 'Edit Period',
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: dayOfWeek,
                decoration: const InputDecoration(labelText: 'Day'),
                // Mon-Sat only (1-6) -- TimetablePage's weekly grid only
                // renders those 6 columns, matching mockups/mockup2.jpg.
                // A Sunday (7) slot would silently never appear to
                // students if this allowed picking it.
                items: [
                  for (var d = 1; d <= 6; d++)
                    DropdownMenuItem(value: d, child: Text(SchoolTimetableSlot.dayNames[d])),
                ],
                onChanged: (v) => setSheetState(() => dayOfWeek = v ?? 1),
              ),
              Row(children: [
                Expanded(child: TextField(controller: startCtrl,
                    decoration: const InputDecoration(labelText: 'Start (HH:mm)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: endCtrl,
                    decoration: const InputDecoration(labelText: 'End (HH:mm)'))),
              ]),
              TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
              TextField(controller: teacherCtrl, decoration: const InputDecoration(labelText: 'Teacher')),
              TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room (optional)')),
              const SizedBox(height: 20),
              PrimaryBtn(
                label: existing == null ? 'Add' : 'Save',
                onTap: () async {
                  if (subjectCtrl.text.trim().isEmpty) {
                    showToast(ctx, 'Subject is required.', isError: true);
                    return;
                  }
                  final slot = SchoolTimetableSlot(
                    id: existing?.id ?? '',
                    schoolId: schoolId,
                    classLevel: _classLevel,
                    dayOfWeek: dayOfWeek,
                    startTime: startCtrl.text.trim(),
                    endTime: endCtrl.text.trim(),
                    subject: subjectCtrl.text.trim(),
                    teacherName: teacherCtrl.text.trim(),
                    room: roomCtrl.text.trim().isEmpty ? null : roomCtrl.text.trim(),
                  );
                  final result = existing == null
                      ? await SchoolTimetableRepository.instance.add(slot)
                      : await SchoolTimetableRepository.instance.update(slot);
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

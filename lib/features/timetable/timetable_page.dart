// lib/features/timetable/timetable_page.dart
// Weekly grid. Students see their class group. Lecturers see their slots. Admins see all + can add.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/timetable_repository.dart';
import '../../core/result.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class TimetablePage extends StatefulWidget {
  final AppUser user;
  const TimetablePage({super.key, required this.user});
  @override State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  static const _days = ['Mon','Tue','Wed','Thu','Fri'];
  int _day = DateTime.now().weekday.clamp(1, 5);

  String get _sid => widget.user.schoolId ?? '';

  Stream<List<TimetableSlot>> get _stream {
    final u = widget.user;
    if (u.isLecturer) return TimetableRepository.instance.watchForLecturer(_sid, u.id);
    if (u.classLevel.isNotEmpty) return TimetableRepository.instance.watchForClass(_sid, u.classLevel);
    return TimetableRepository.instance.watchAll(_sid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Timetable', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: widget.user.canManageSchool
            ? [IconButton(icon: const Icon(Icons.add_rounded),
                onPressed: () => _showAdd(context))]
            : null,
      ),
      body: AppBackground(child: Column(children: [
        // Day selector
        Container(
          color: C.surf,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: List.generate(5, (i) {
            final d = i + 1;
            final sel = d == _day;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _day = d),
              child: Container(
                margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: sel ? C.primary : C.bg,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(_days[i], textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : C.txt2)),
              ),
            ));
          })),
        ),
        Expanded(
          child: StreamBuilder<List<TimetableSlot>>(
            stream: _stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                CrashService.instance.recordError(snap.error, snap.stackTrace,
                    context: 'TimetablePage._stream($_sid)');
                return ErrorView(message: "Couldn't load the timetable — ${snap.error}");
              }
              final slots = (snap.data ?? [])
                  .where((s) => s.dayOfWeek == _day).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
              if (slots.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.event_available_outlined, size: 48, color: C.muted),
                  const SizedBox(height: 12),
                  Text('No classes on ${_days[_day - 1]}',
                      style: GoogleFonts.inter(color: C.muted)),
                ]));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: slots.length,
                itemBuilder: (_, i) => _SlotCard(
                    slot: slots[i],
                    canDelete: widget.user.canManageSchool,
                    sid: _sid),
              );
            },
          ),
        ),
      ])),
    );
  }

  void _showAdd(BuildContext ctx) {
    final courseC = TextEditingController();
    final venueC  = TextEditingController();
    final groupC  = TextEditingController(text: widget.user.classLevel);
    final startC  = TextEditingController(text: '08:00');
    final endC    = TextEditingController(text: '10:00');
    int day = _day;
    bool saving = false;

    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (dCtx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(dCtx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add Slot', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: courseC, decoration: const InputDecoration(labelText: 'Course Name *')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: venueC,
                decoration: const InputDecoration(labelText: 'Venue *'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: groupC,
                decoration: const InputDecoration(labelText: 'Class Group'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: startC,
                decoration: const InputDecoration(labelText: 'Start'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: endC,
                decoration: const InputDecoration(labelText: 'End'))),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: day,
            decoration: const InputDecoration(labelText: 'Day'),
            items: List.generate(5, (i) => DropdownMenuItem(
                value: i + 1, child: Text(_days[i]))),
            onChanged: (v) => setM(() => day = v ?? day),
          ),
          const SizedBox(height: 16),
          PrimaryBtn(label: 'Add Slot', loading: saving, onTap: () async {
            if (courseC.text.trim().isEmpty || venueC.text.trim().isEmpty) return;
            setM(() => saving = true);
            final slot = TimetableSlot(
              id: '', schoolId: _sid,
              courseId: courseC.text.trim(), courseName: courseC.text.trim(),
              lecturerId: widget.user.id, lecturerName: widget.user.name,
              venue: venueC.text.trim(), dayOfWeek: day,
              startTime: startC.text.trim(), endTime: endC.text.trim(),
              classGroup: groupC.text.trim(),
            );
            final r = await TimetableRepository.instance.add(slot);
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
            if (r is Success && ctx.mounted) showToast(ctx, '✅ Slot added');
          }),
        ]),
      )),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final TimetableSlot slot;
  final bool canDelete;
  final String sid;
  const _SlotCard({required this.slot, required this.canDelete, required this.sid});

  static const _palette = [
    Color(0xFF1A56DB), Color(0xFF16A34A), Color(0xFF9333EA),
    Color(0xFFEA8C00), Color(0xFF0EA5E9), Color(0xFFEF4444),
  ];
  Color get _color => _palette[slot.courseName.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: C.surf, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.bdr)),
      child: Row(children: [
        Container(
            width: 6, height: 84,
            decoration: BoxDecoration(
                color: _color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)))),
        const SizedBox(width: 14),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(slot.courseName,
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 13, color: C.muted),
              const SizedBox(width: 4),
              Text('${slot.startTime}–${slot.endTime}',
                  style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
              const SizedBox(width: 12),
              const Icon(Icons.location_on_outlined, size: 13, color: C.muted),
              const SizedBox(width: 4),
              Text(slot.venue, style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
            ]),
            Text(slot.lecturerName,
                style: GoogleFonts.inter(fontSize: 11, color: C.txt2)),
          ]),
        )),
        if (canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: C.muted),
            onPressed: () async {
              await TimetableRepository.instance.delete(sid, slot.id);
              if (context.mounted) showToast(context, 'Slot removed');
            },
          ),
      ]),
    );
  }
}

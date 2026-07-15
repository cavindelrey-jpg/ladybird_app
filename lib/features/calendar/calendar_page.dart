// lib/features/calendar/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/calendar_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class CalendarPage extends StatelessWidget {
  final AppUser user;
  const CalendarPage({super.key, required this.user});

  String get _sid => user.schoolId ?? '';

  static const _typeLabels = {
    CalendarEventType.classStart: 'Term Start',
    CalendarEventType.classEnd:   'Term End',
    CalendarEventType.exam:       'Exam',
    CalendarEventType.holiday:    'Holiday',
    CalendarEventType.deadline:   'Deadline',
    CalendarEventType.ceremony:   'Ceremony',
    CalendarEventType.other:      'Event',
  };

  static const _months = ['','January','February','March','April','May','June',
    'July','August','September','October','November','December'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Academic Calendar',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: user.canManageSchool
            ? [IconButton(icon: const Icon(Icons.add_rounded),
                onPressed: () => _showAdd(context))]
            : null,
      ),
      body: StreamBuilder<List<CalendarEvent>>(
        stream: CalendarRepository.instance.watchAll(_sid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.event_outlined, size: 48, color: C.muted),
              const SizedBox(height: 12),
              Text('No events scheduled', style: GoogleFonts.inter(color: C.muted)),
            ]));
          }
          final Map<String, List<CalendarEvent>> grouped = {};
          for (final e in events) {
            final k = '${e.startDate.year}-${e.startDate.month.toString().padLeft(2,'0')}';
            (grouped[k] ??= []).add(e);
          }
          final keys = grouped.keys.toList()..sort();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            itemBuilder: (_, i) {
              final k = keys[i]; final evts = grouped[k]!;
              final parts = k.split('-');
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text('${_months[int.parse(parts[1])]} ${parts[0]}',
                      style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700,
                          color: C.primary))),
                ...evts.map((e) => _EventCard(event: e, canDelete: user.canManageSchool, sid: _sid)),
              ]);
            },
          );
        },
      ),
    );
  }

  void _showAdd(BuildContext ctx) {
    final titleC = TextEditingController();
    final descC  = TextEditingController();
    DateTime date = DateTime.now();
    CalendarEventType type = CalendarEventType.other;
    bool saving = false;

    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (dCtx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(dCtx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add Event', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Event Title *')),
          const SizedBox(height: 10),
          TextField(controller: descC, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 10),
          DropdownButtonFormField<CalendarEventType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: CalendarEventType.values.map((t) =>
                DropdownMenuItem(value: t, child: Text(_typeLabels[t] ?? t.name))).toList(),
            onChanged: (v) => setM(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final p = await showDatePicker(context: dCtx, initialDate: date,
                  firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (p != null) setM(() => date = p);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.bdr)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: C.primary),
                const SizedBox(width: 8),
                Text('${date.day}/${date.month}/${date.year}',
                    style: GoogleFonts.inter(fontSize: 14, color: C.txt)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryBtn(label: '📅 Add Event', loading: saving, onTap: () async {
            if (titleC.text.trim().isEmpty) return;
            setM(() => saving = true);
            final e = CalendarEvent(
              id: '', schoolId: _sid, title: titleC.text.trim(),
              description: descC.text.trim().isEmpty ? null : descC.text.trim(),
              startDate: date, type: type,
            );
            final r = await CalendarRepository.instance.create(e);
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
            if (r is Success && ctx.mounted) showToast(ctx, '✅ Event added');
          }),
        ]),
      )),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final bool canDelete;
  final String sid;
  const _EventCard({required this.event, required this.canDelete, required this.sid});

  Color get _typeColor {
    switch (event.type) {
      case CalendarEventType.exam:       return C.red;
      case CalendarEventType.holiday:    return C.grn;
      case CalendarEventType.classStart: return C.primary;
      case CalendarEventType.classEnd:   return C.navy;
      case CalendarEventType.deadline:   return C.org;
      case CalendarEventType.ceremony:   return C.gold;
      case CalendarEventType.other:      return C.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: _typeColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text('${event.startDate.day}',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: _typeColor)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.title,
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt)),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _typeColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(event.typeLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _typeColor))),
          if (event.description != null) ...[
            const SizedBox(height: 2),
            Text(event.description!, style: GoogleFonts.inter(fontSize: 11, color: C.txt2)),
          ],
        ])),
        if (canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: C.muted),
            onPressed: () async {
              await CalendarRepository.instance.delete(sid, event.id);
              if (context.mounted) showToast(context, 'Event removed');
            },
          ),
      ]),
    );
  }
}

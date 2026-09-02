// lib/features/timetable/personal_study_page.dart
// production_plan.md §5's Personal Study Timetable — student-authored
// study sessions, separate from the school-authored TimetablePage.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/personal_study_slot.dart';
import '../../models/academic_content.dart' show kAcademicSubjects;
import '../../repositories/personal_study_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class PersonalStudyPage extends StatelessWidget {
  final AppUser user;
  const PersonalStudyPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('My Study Timetable', style: AppText.title),
      ),
      body: AppBackground(child: StreamBuilder<List<PersonalStudySlot>>(
        stream: PersonalStudyRepository.instance.watchAll(user.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 400));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final slots = snap.data ?? const <PersonalStudySlot>[];
          if (slots.isEmpty) {
            return const EmptyState(
              icon: Icons.event_note_outlined, title: 'No study sessions planned',
              subtitle: 'Add times to revise a subject or take a quiz — Home will '
                  "show today's plan.",
            );
          }
          final byDay = <int, List<PersonalStudySlot>>{};
          for (final s in slots) {
            byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
          }
          for (final list in byDay.values) {
            list.sort((a, b) => a.startTime.compareTo(b.startTime));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              for (var day = 1; day <= 7; day++)
                if (byDay.containsKey(day)) ...[
                  Text(PersonalStudySlot.dayNames[day], style: AppText.h2.copyWith(fontSize: 15)),
                  const SizedBox(height: 8),
                  ...byDay[day]!.map((s) => _SlotCard(user: user, slot: s)),
                  const SizedBox(height: 16),
                ],
            ],
          );
        },
      )),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ac.navy,
        icon: Icon(Icons.add_rounded, color: ac.gold),
        label: Text('Add Session', style: AppText.button.copyWith(fontSize: 13)),
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _SlotFormSheet(user: user),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final AppUser user;
  final PersonalStudySlot slot;
  const _SlotCard({required this.user, required this.slot});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ACard(
        onTap: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _SlotFormSheet(user: user, existing: slot),
        ),
        child: Row(children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(color: ac.gold, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot.activity, style: AppText.title.copyWith(fontSize: 14)),
              Text('${slot.startTime} – ${slot.endTime}${slot.subject != null ? ' · ${slot.subject}' : ''}',
                  style: AppText.bodySm.copyWith(fontSize: 11.5)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: ac.muted),
        ]),
      ),
    );
  }
}

class _SlotFormSheet extends StatefulWidget {
  final AppUser user;
  final PersonalStudySlot? existing;
  const _SlotFormSheet({required this.user, this.existing});

  @override
  State<_SlotFormSheet> createState() => _SlotFormSheetState();
}

class _SlotFormSheetState extends State<_SlotFormSheet> {
  late final _activityCtrl = TextEditingController(text: widget.existing?.activity ?? '');
  late int _day = widget.existing?.dayOfWeek ?? DateTime.now().weekday;
  late TimeOfDay _start = _parseTime(widget.existing?.startTime) ?? const TimeOfDay(hour: 18, minute: 0);
  late TimeOfDay _end = _parseTime(widget.existing?.endTime) ?? const TimeOfDay(hour: 19, minute: 0);
  String? _subject;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subject = widget.existing?.subject;
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _activityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final activity = _activityCtrl.text.trim();
    if (activity.isEmpty) {
      showToast(context, 'Add what you\'ll be studying.');
      return;
    }
    setState(() => _saving = true);
    final slot = PersonalStudySlot(
      id: widget.existing?.id ?? '', userId: widget.user.id,
      dayOfWeek: _day, startTime: _fmt(_start), endTime: _fmt(_end),
      activity: activity, subject: _subject,
    );
    final result = widget.existing == null
        ? await PersonalStudyRepository.instance.add(slot)
        : await PersonalStudyRepository.instance.update(slot);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success) {
      Navigator.pop(context);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    HapticFeedback.mediumImpact();
    await PersonalStudyRepository.instance.delete(widget.user.id, widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SafeArea(
        // The Save/Delete row previously fell outside the visible area
        // whenever the keyboard was open and pushed this un-scrollable
        // Column taller than what was left of the screen -- no way to
        // reach it, which read as "there's no save button" even though
        // one was always there.
        child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.existing == null ? 'New Study Session' : 'Edit Study Session',
              style: AppText.title.copyWith(fontSize: 16)),
          const SizedBox(height: 14),
          TextField(controller: _activityCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Mathematics revision', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(7, (i) {
              final d = i + 1;
              final sel = d == _day;
              return ChoiceChip(
                label: Text(PersonalStudySlot.dayNames[d]),
                selected: sel,
                onSelected: (_) => setState(() => _day = d),
                selectedColor: ac.primary,
                labelStyle: TextStyle(color: sel ? Colors.white : ac.txt),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _start);
                  if (picked != null) setState(() => _start = picked);
                },
                child: Text('Start: ${_fmt(_start)}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _end);
                  if (picked != null) setState(() => _end = picked);
                },
                child: Text('End: ${_fmt(_end)}'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _subject,
            decoration: const InputDecoration(labelText: 'Subject (optional)', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ...kAcademicSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => _subject = v),
          ),
          const SizedBox(height: 16),
          Row(children: [
            if (widget.existing != null)
              TextButton(onPressed: _delete, child: Text('Delete', style: TextStyle(color: ac.red))),
            const Spacer(),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ]),
        ]),
        ),
      ),
    );
  }
}

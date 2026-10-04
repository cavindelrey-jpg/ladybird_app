// lib/features/timetable/personal_study_page.dart
// production_plan.md §5's Personal Study Timetable — student-authored
// study sessions, separate from the school-authored TimetablePage.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/personal_study_slot.dart';
import '../../repositories/personal_study_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class PersonalStudyPage extends StatefulWidget {
  final AppUser user;
  const PersonalStudyPage({super.key, required this.user});

  @override
  State<PersonalStudyPage> createState() => _PersonalStudyPageState();
}

class _PersonalStudyPageState extends State<PersonalStudyPage> {
  Future<void> _openCreateSheet(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SlotFormSheet(user: widget.user),
    );
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Personal Timetable', style: AppText.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                key: const Key('add_session_appbar_btn'),
                onPressed: () => _openCreateSheet(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: StreamBuilder<List<PersonalStudySlot>>(
          stream: PersonalStudyRepository.instance.watchAll(widget.user.id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 400));
            }
            if (snap.hasError && (!snap.hasData || snap.data!.isEmpty)) {
              return ErrorView(message: snap.error.toString());
            }
            final slots = snap.data ?? const <PersonalStudySlot>[];
            if (slots.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: ac.primaryBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_note_outlined, size: 36, color: ac.primary),
                      ),
                      const SizedBox(height: 16),
                      Text('No study sessions planned yet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
                      const SizedBox(height: 8),
                      Text(
                        'Plan your study times, revision sessions, and practice quizzes.\n'
                        "Today's active sessions will appear directly on your Home screen.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      PrimaryBtn(
                        label: 'Create Personal Timetable',
                        icon: Icons.add_rounded,
                        onTap: () => _openCreateSheet(context),
                      ),
                    ],
                  ),
                ),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        _fullDayName(day),
                        style: AppText.h2.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...byDay[day]!.map((s) => _SlotCard(
                          user: widget.user,
                          slot: s,
                          onUpdated: () {
                            if (mounted) setState(() {});
                          },
                        )),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ac.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add to Personal Timetable',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: () => _openCreateSheet(context),
      ),
    );
  }

  String _fullDayName(int day) {
    const names = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    if (day >= 1 && day <= 7) return names[day];
    return '';
  }
}

class _SlotCard extends StatelessWidget {
  final AppUser user;
  final PersonalStudySlot slot;
  final VoidCallback? onUpdated;
  const _SlotCard({required this.user, required this.slot, this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hasSubject = slot.subject != null && slot.subject!.trim().isNotEmpty;
    final title = hasSubject ? slot.subject!.trim() : slot.activity.trim();
    final hasRemark = hasSubject && slot.activity.trim().isNotEmpty && slot.activity.trim() != slot.subject!.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ACard(
        onTap: () async {
          final res = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => _SlotFormSheet(user: user, existing: slot),
          );
          if (res == true) onUpdated?.call();
        },
        child: Row(children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(color: ac.primary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.title.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 13, color: ac.muted),
                  const SizedBox(width: 4),
                  Text(
                    '${slot.startTime} – ${slot.endTime}',
                    style: AppText.bodySm.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: ac.txt),
                  ),
                  if (hasRemark) ...[
                    Text(' · ', style: TextStyle(color: ac.muted, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        slot.activity.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySm.copyWith(fontSize: 12, color: ac.txt2),
                      ),
                    ),
                  ],
                ],
              ),
            ]),
          ),
          Icon(Icons.edit_note_rounded, color: ac.muted, size: 20),
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
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _remarkCtrl;
  late int _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;

  static const List<String> _suggestedSubjects = [
    'Chemistry',
    'Physics',
    'Biology',
    'Mathematics',
    'English',
    'Literature',
    'Economics',
    'Geography',
    'History',
    'Computer Science',
  ];

  @override
  void initState() {
    super.initState();
    _subjectCtrl = TextEditingController(text: widget.existing?.subject ?? '');
    _remarkCtrl = TextEditingController(
      text: widget.existing != null
          ? (widget.existing!.activity == '${widget.existing!.subject} Revision' ? '' : widget.existing!.activity)
          : '',
    );
    _day = widget.existing?.dayOfWeek ?? DateTime.now().weekday;
    _start = _parseTime(widget.existing?.startTime) ?? const TimeOfDay(hour: 10, minute: 0);
    _end = _parseTime(widget.existing?.endTime) ?? const TimeOfDay(hour: 16, minute: 0);
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
    _subjectCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final remark = _remarkCtrl.text.trim();

    if (subject.isEmpty && remark.isEmpty) {
      showToast(context, 'Please enter a subject or personal remark for this session.', isError: true);
      return;
    }

    final startMin = _start.hour * 60 + _start.minute;
    final endMin = _end.hour * 60 + _end.minute;
    if (startMin >= endMin) {
      showToast(context, 'End time must be after start time.', isError: true);
      return;
    }

    setState(() => _saving = true);

    final activity = remark.isNotEmpty ? remark : '$subject Revision';

    final slot = PersonalStudySlot(
      id: widget.existing?.id ?? '',
      userId: widget.user.id,
      dayOfWeek: _day,
      startTime: _fmt(_start),
      endTime: _fmt(_end),
      activity: activity,
      subject: subject.isNotEmpty ? subject : null,
    );

    final result = widget.existing == null
        ? await PersonalStudyRepository.instance.add(slot)
        : await PersonalStudyRepository.instance.update(slot);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result is Success) {
      Navigator.of(context).pop(true);
      showToast(
        context,
        widget.existing == null ? 'Timetable entry saved successfully!' : 'Timetable entry updated!',
      );
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    await PersonalStudyRepository.instance.delete(widget.user.id, widget.existing!.id);
    if (mounted) {
      Navigator.of(context).pop(true);
      showToast(context, 'Study session removed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final availableHeight = (screenHeight - keyboardHeight).clamp(300.0, screenHeight);
    final maxSheetHeight = (availableHeight * 0.92).clamp(320.0, screenHeight * 0.90);

    return Container(
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ac.muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header bar with Cancel and Save action
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: ac.txt2),
                      tooltip: 'Cancel',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.existing == null ? 'New Timetable Entry' : 'Edit Timetable Entry',
                        style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      key: const Key('header_save_btn'),
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        widget.existing == null ? 'Save' : 'Update',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 36),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: ac.bdr2),

              // Scrollable Form Fields
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day of week
                      Text('Day of Week', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ac.txt2)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (i) {
                          final d = i + 1;
                          final sel = d == _day;
                          return ChoiceChip(
                            label: Text(PersonalStudySlot.dayNames[d]),
                            selected: sel,
                            onSelected: (_) => setState(() => _day = d),
                            selectedColor: ac.primary,
                            backgroundColor: ac.bg,
                            labelStyle: TextStyle(
                              color: sel ? Colors.white : ac.txt,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Time picker row
                      Text('Session Time', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ac.txt2)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('start_time_btn'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: ac.bdr),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: ac.bg,
                            ),
                            icon: Icon(Icons.access_time_rounded, size: 18, color: ac.primary),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _start);
                              if (picked != null) setState(() => _start = picked);
                            },
                            label: Text('Start: ${_fmt(_start)}', style: TextStyle(color: ac.txt, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('end_time_btn'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: ac.bdr),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: ac.bg,
                            ),
                            icon: Icon(Icons.access_time_filled_rounded, size: 18, color: ac.gold),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _end);
                              if (picked != null) setState(() => _end = picked);
                            },
                            label: Text('End: ${_fmt(_end)}', style: TextStyle(color: ac.txt, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Subject input
                      Text('Subject', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ac.txt2)),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('subject_field'),
                        controller: _subjectCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Chemistry, Mathematics, Physics',
                          filled: true,
                          fillColor: ac.bg,
                          prefixIcon: Icon(Icons.school_outlined, size: 20, color: ac.muted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ac.bdr)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ac.bdr)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Quick Subject Suggestions
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _suggestedSubjects.map((sub) {
                          final isSelected = _subjectCtrl.text.trim().toLowerCase() == sub.toLowerCase();
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _subjectCtrl.text = sub;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? ac.primary.withValues(alpha: 0.15) : ac.bg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? ac.primary : ac.bdr2,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                sub,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? ac.primary : ac.txt2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Personal Remark input
                      Text('Personal Remark', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ac.txt2)),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('remark_field'),
                        controller: _remarkCtrl,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'e.g. Revision / laboratory work, Practice exam questions',
                          filled: true,
                          fillColor: ac.bg,
                          prefixIcon: Icon(Icons.edit_note_rounded, size: 20, color: ac.muted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ac.bdr)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ac.bdr)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Inline Primary Action at the bottom of the form
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          key: const Key('inline_save_timetable_entry_btn'),
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            _saving
                                ? 'Saving Timetable Entry...'
                                : (widget.existing == null ? 'Save Timetable Entry' : 'Save Changes'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ac.primary,
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky Bottom Footer Bar — always visible above keyboard and navigation
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: ac.surf,
                  border: Border(top: BorderSide(color: ac.bdr2)),
                ),
                child: Row(
                  children: [
                    if (widget.existing != null) ...[
                      OutlinedButton.icon(
                        key: const Key('delete_timetable_entry_btn'),
                        onPressed: _saving ? null : _delete,
                        icon: Icon(Icons.delete_outline_rounded, color: ac.red, size: 18),
                        label: Text('Delete', style: TextStyle(color: ac.red)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: ac.red.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          key: const Key('sticky_save_timetable_entry_btn'),
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            _saving
                                ? 'Saving Timetable Entry...'
                                : (widget.existing == null ? 'Save Timetable Entry' : 'Save Changes'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ac.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

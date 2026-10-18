// lib/features/school/timetable_page.dart
// Official School Timetable -- matches mockups/mockup2.jpg: a full
// weekly grid (time rows x Mon-Sat columns), a "Today's Highlights"
// strip, and a footer note. Distinct from Profile's "My Study Plan"
// (personal, self-authored). Real data throughout: schools/{schoolId}/
// timetable/{id} via SchoolTimetableRepository, filtered to the signed-
// in student's own classLevel. No hardcoded periods -- an honest empty
// state when the school hasn't entered this class's timetable yet.

import 'package:flutter/material.dart';
import '../../models/academic_content.dart' show kAcademicLevels;
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/school_timetable_slot.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../timetable/personal_study_page.dart';
import 'timetable_manager_page.dart';
import 'widgets/school_shared_widgets.dart';
import '../../widgets/application_shell.dart';

class TimetablePage extends StatelessWidget {
  final AppUser user;
  const TimetablePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = user.schoolId ?? '';
    final classLevel = user.classLevel;

    return ApplicationShell(
      user: user,
      currentTitle: 'Timetable',
      currentDestination: AppNavDestination.timetable,
      child: (schoolId.isNotEmpty && !user.isStudent && !user.isParent)
          ? _StaffTimetableView(page: this)
          : (schoolId.isEmpty || classLevel.isEmpty)
          ? _missingClassState(context, ac)
          : StreamBuilder<List<SchoolTimetableSlot>>(
              stream: SchoolTimetableRepository.instance.watchForClass(schoolId, classLevel),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                final all = snap.data ?? const <SchoolTimetableSlot>[];
                if (all.isEmpty) return _emptyState(context, ac, classLevel);
                return ListView(
                  children: [
                    StudentInfoCard(user: user),
                    const SizedBox(height: 16),
                    _todaysHighlights(ac, all),
                    const SizedBox(height: 16),
                    _weekGrid(ac, all),
                    const SizedBox(height: 16),
                    _noteFooter(context, ac),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
    );
  }

  Widget _todaysHighlights(AppColors ac, List<SchoolTimetableSlot> all) {
    final today = DateTime.now().weekday;
    final todays = all.where((s) => s.dayOfWeek == today).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (todays.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(Rad.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome_rounded, color: ac.pur, size: 16),
          const SizedBox(width: 6),
          Text("Today's Highlights", style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.pur)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 8, children: [
          for (final s in todays.take(4))
            SizedBox(
              width: 140,
              child: Row(children: [
                Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: ac.pur, shape: BoxShape.circle)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.startTime, style: GoogleFonts.inter(fontSize: 10, color: ac.txt2)),
                    Text(s.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt)),
                  ]),
                ),
              ]),
            ),
        ]),
      ]),
    );
  }

  Widget _weekGrid(AppColors ac, List<SchoolTimetableSlot> all) {
    const dayCols = [1, 2, 3, 4, 5, 6]; // Mon-Sat -- no Sunday classes
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final times = (all.map((s) => s.startTime).toSet().toList()..sort());
    final byDayAndTime = <String, SchoolTimetableSlot>{
      for (final s in all) '${s.dayOfWeek}:${s.startTime}': s,
    };
    const timeColWidth = 62.0;
    const dayColWidth = 108.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(children: [
            // Header row
            Row(children: [
              SizedBox(width: timeColWidth, height: 40, child: Center(
                  child: Text('Time', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ac.muted)))),
              for (final label in dayLabels)
                SizedBox(width: dayColWidth, height: 40, child: Center(
                    child: Text(label, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w800, color: ac.txt)))),
            ]),
            Divider(height: 1, color: ac.bdr),
            for (final time in times) ...[
              Row(children: [
                SizedBox(
                  width: timeColWidth, height: 56,
                  child: Center(child: Text(time, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.txt2))),
                ),
                for (final day in dayCols)
                  SizedBox(
                    width: dayColWidth, height: 56,
                    child: _gridCell(ac, byDayAndTime['$day:$time']),
                  ),
              ]),
              Divider(height: 1, color: ac.bdr2),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _gridCell(AppColors ac, SchoolTimetableSlot? slot) {
    if (slot == null) {
      return Center(child: Text('—', style: GoogleFonts.inter(fontSize: 12, color: ac.muted)));
    }
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(slot.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary)),
        if ((slot.room ?? '').isNotEmpty)
          Text(slot.room!, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 9, color: ac.primary.withValues(alpha: .75))),
      ]),
    );
  }

  Widget _noteFooter(BuildContext context, AppColors ac) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.md)),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: ac.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Please Note', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w800, color: ac.primary)),
            Text('Timetable is subject to change. Check regularly for updates.',
                style: GoogleFonts.inter(fontSize: 11, color: ac.txt2)),
          ]),
        ),
      ]),
    );
  }

  Widget _missingClassState(BuildContext context, AppColors ac) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ac.surf, shape: BoxShape.circle),
              child: Icon(Icons.school_outlined, size: 44, color: ac.muted),
            ),
            const SizedBox(height: 16),
            Text('Your class isn\'t set yet',
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 8),
            Text('Set your class in Profile to see your school timetable, or create your own personal study timetable now.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2, height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PersonalStudyPage(user: user)),
              ),
              icon: const Icon(Icons.event_note_rounded, size: 18),
              label: const Text('Open Personal Timetable'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ),
      );

  Widget _emptyState(BuildContext context, AppColors ac, String classLevel) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ac.primaryBg, shape: BoxShape.circle),
              child: Icon(Icons.event_busy_rounded, size: 44, color: ac.primary),
            ),
            const SizedBox(height: 16),
            Text('No official timetable yet for $classLevel',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 8),
            Text('Your school hasn\'t published this class\'s timetable yet. You can create your own personal study schedule in the meantime.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2, height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PersonalStudyPage(user: user)),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create Personal Timetable'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ),
      );
}


/// Teachers / class masters / admins have no class of their own, so the
/// student view used to dead-end on "no class". Staff see their own
/// periods across every class (matched by teacher name, the same way the
/// 7 PM programme does), or any class's timetable.
class _StaffTimetableView extends StatefulWidget {
  final TimetablePage page;
  const _StaffTimetableView({required this.page});
  @override
  State<_StaffTimetableView> createState() => _StaffTimetableViewState();
}

class _StaffTimetableViewState extends State<_StaffTimetableView> {
  static const _mine = '__mine__';
  late String _view = _mine;
  late final Stream<List<SchoolTimetableSlot>> _stream =
      SchoolTimetableRepository.instance.watchForSchool(widget.page.user.schoolId ?? '');

  String _n(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final user = widget.page.user;
    final classes = kAcademicLevels.take(7).toList();
    return StreamBuilder<List<SchoolTimetableSlot>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (!snap.hasData && snap.hasError) {
          return Center(child: Text('Couldn\'t load the timetable. Check your connection.',
              style: GoogleFonts.inter(color: ac.muted)));
        }
        final all = snap.data ?? const <SchoolTimetableSlot>[];
        final slots = _view == _mine
            ? [
                for (final s in all.where((s) => _n(s.teacherName) == _n(user.name)))
                  SchoolTimetableSlot(
                    id: s.id, schoolId: s.schoolId, classLevel: s.classLevel, dayOfWeek: s.dayOfWeek,
                    startTime: s.startTime, endTime: s.endTime,
                    subject: '${s.subject} · ${s.classLevel}', teacherName: s.teacherName, room: s.room),
              ]
            : all.where((s) => s.classLevel == _view).toList();
        return ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _view,
              decoration: const InputDecoration(labelText: 'Show', isDense: true),
              items: [
                const DropdownMenuItem(value: _mine, child: Text('My teaching timetable')),
                for (final c in classes) DropdownMenuItem(value: c, child: Text('$c timetable')),
              ],
              onChanged: (v) => setState(() => _view = v ?? _view),
            ),
          ),
          const SizedBox(height: 16),
          if (slots.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _view != _mine
                    ? 'No periods for $_view yet.'
                    : user.canManageAnyTimetable
                        ? 'You aren\'t teaching any periods. Choose a class above to see its timetable, '
                          'or tap the edit icon to manage it.'
                        : 'No periods list you (${user.name}) as the teacher yet. '
                          'Ask your school admin to add you to the timetable.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(color: ac.muted, height: 1.5)),
            )
          else ...[
            widget.page._todaysHighlights(ac, slots),
            const SizedBox(height: 16),
            widget.page._weekGrid(ac, slots),
            const SizedBox(height: 16),
          ],
        ]);
      },
    );
  }
}

// lib/features/school/timetable_page.dart
// Official School Timetable -- School Navigation's "Timetable" module.
// Distinct from Profile's "My Study Plan" (personal, self-authored). Real
// data: schools/{schoolId}/timetable/{id} via SchoolTimetableRepository,
// filtered to the signed-in student's own classLevel. No hardcoded
// periods -- an honest empty state when the school hasn't entered this
// class's timetable yet, same "never fake data" standard as the rest of
// this app.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/branding.dart';
import '../../models/app_user.dart';
import '../../models/school_timetable_slot.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'timetable_manager_page.dart';

class TimetablePage extends StatefulWidget {
  final AppUser user;
  const TimetablePage({super.key, required this.user});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late int _selectedDay = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final u = widget.user;
    final schoolId = u.schoolId ?? '';
    final classLevel = u.classLevel;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        title: Text('Timetable', style: AppText.h2.copyWith(color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
        actions: [
          if (u.canManageSchool)
            IconButton(
              icon: Icon(Icons.edit_calendar_outlined, color: ac.txt2),
              tooltip: 'Manage timetable',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TimetableManagerPage(user: u))),
            ),
        ],
      ),
      body: (schoolId.isEmpty || classLevel.isEmpty)
          ? _missingClassState(ac)
          : Column(children: [
              _header(ac, classLevel),
              _daySelector(ac),
              Expanded(
                child: StreamBuilder<List<SchoolTimetableSlot>>(
                  stream: SchoolTimetableRepository.instance.watchForClass(schoolId, classLevel),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    final all = snap.data ?? const <SchoolTimetableSlot>[];
                    final dayPeriods = all.where((s) => s.dayOfWeek == _selectedDay).toList();
                    if (all.isEmpty) return _emptyState(ac, classLevel);
                    if (dayPeriods.isEmpty) return _emptyDayState(ac);
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: dayPeriods.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _periodCard(ac, dayPeriods[i]),
                    );
                  },
                ),
              ),
            ]),
    );
  }

  Widget _header(AppColors ac, String classLevel) {
    final u = widget.user;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ac.navy, ac.navy2],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Rad.lg),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22, backgroundColor: Colors.white.withValues(alpha: .15),
          backgroundImage: (u.photoUrl ?? '').isNotEmpty ? NetworkImage(u.photoUrl!) : null,
          child: (u.photoUrl ?? '').isEmpty
              ? Text(u.initials, style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text('$classLevel · ${Branding.current.appName}',
                style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withValues(alpha: .8))),
          ]),
        ),
      ]),
    );
  }

  Widget _daySelector(AppColors ac) {
    const labels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final day = i + 1;
          final selected = day == _selectedDay;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              width: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? ac.primary : ac.surf,
                borderRadius: BorderRadius.circular(Rad.sm),
                border: Border.all(color: selected ? ac.primary : ac.bdr),
              ),
              child: Text(labels[day], style: GoogleFonts.sora(
                  fontSize: 12.5, fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : ac.txt2)),
            ),
          );
        },
      ),
    );
  }

  Widget _periodCard(AppColors ac, SchoolTimetableSlot s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surf, borderRadius: BorderRadius.circular(Rad.md),
        border: Border(left: BorderSide(color: ac.primary, width: 3)),
      ),
      child: Row(children: [
        SizedBox(
          width: 64,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.startTime, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: ac.txt)),
            Text(s.endTime, style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
          ]),
        ),
        Container(width: 1, height: 34, color: ac.bdr2, margin: const EdgeInsets.symmetric(horizontal: 10)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.subject, style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 13, color: ac.muted),
              const SizedBox(width: 3),
              Text(s.teacherName.isEmpty ? 'Unassigned' : s.teacherName,
                  style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
              if ((s.room ?? '').isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(Icons.room_outlined, size: 13, color: ac.muted),
                const SizedBox(width: 3),
                Text(s.room!, style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _missingClassState(AppColors ac) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.school_outlined, size: 48, color: ac.muted),
            const SizedBox(height: 16),
            Text('Your class isn\'t set yet',
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 8),
            Text('Set your class in Profile to see your timetable.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          ]),
        ),
      );

  Widget _emptyState(AppColors ac, String classLevel) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_rounded, size: 48, color: ac.muted),
            const SizedBox(height: 16),
            Text('No timetable yet for $classLevel',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 8),
            Text('Check back once the school has entered it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          ]),
        ),
      );

  Widget _emptyDayState(AppColors ac) => Center(
        child: Text('No periods scheduled for this day.',
            style: GoogleFonts.inter(fontSize: 12.5, color: ac.muted)),
      );
}

// lib/features/dashboard/timetable_page.dart
// Hardcoded Form5A schedule REMOVED.
// Renders empty-state until school pushes timetable via Firestore.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = (DateTime.now().weekday - 1).clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Day picker
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _selectedDay = i),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: i == _selectedDay ? C.navy : C.surf2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: i == _selectedDay ? C.navy : C.bdr),
                ),
                child: Text(_days[i], style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: i == _selectedDay ? Colors.white : C.txt2)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('${_days[_selectedDay]} — Schedule',
          style: GoogleFonts.sora(
            fontSize: 14, fontWeight: FontWeight.w700, color: C.primary)),
        const SizedBox(height: 20),
        // Empty state — timetable not yet connected
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: C.surf, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.bdr),
          ),
          child: Column(children: [
            Icon(Icons.calendar_today_outlined, size: 48, color: C.muted),
            const SizedBox(height: 12),
            Text('Timetable not yet available',
              style: GoogleFonts.inter(color: C.muted, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Your school administrator will upload the schedule',
              style: GoogleFonts.inter(color: C.muted, fontSize: 12),
              textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

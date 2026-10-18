// lib/features/school/attendance_page.dart
// Attendance register and presence tracking for students and classes.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/application_shell.dart';

class AttendancePage extends StatelessWidget {
  final AppUser user;
  const AttendancePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ApplicationShell(
      user: user,
      currentDestination: AppNavDestination.attendance,
      currentTitle: 'Attendance',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _summaryCard(context, ac),
          const SizedBox(height: 24),
          _recentRecordsCard(context, ac),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Term Attendance Overview',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ac.grn.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('96.4% Present',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600, color: ac.grn)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metricTile('Present Days', '82', ac.grn, ac),
              const SizedBox(width: 12),
              _metricTile('Authorized Absences', '3', ac.primary, ac),
              const SizedBox(width: 12),
              _metricTile('Unexcused', '0', ac.red, ac),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color, AppColors ac) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ac.surf2,
          borderRadius: BorderRadius.circular(Rad.sm),
          border: Border.all(color: ac.bdr2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w500, color: ac.txt2)),
          ],
        ),
      ),
    );
  }

  Widget _recentRecordsCard(BuildContext context, AppColors ac) {
    final records = [
      ('Today', 'Present', 'All 4 classes attended', true),
      ('Yesterday', 'Present', 'All 4 classes attended', true),
      ('16 Oct 2025', 'Present', 'All classes attended', true),
      ('15 Oct 2025', 'Late (10 mins)', 'Morning registration', false),
      ('14 Oct 2025', 'Present', 'All classes attended', true),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Attendance Log',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 12),
          for (final (date, status, detail, isPresent) in records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isPresent
                        ? Icons.check_circle_rounded
                        : Icons.access_time_rounded,
                    size: 18,
                    color: isPresent ? ac.grn : ac.org,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(date,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ac.txt)),
                        Text(detail,
                            style: GoogleFonts.inter(
                                fontSize: 11.5, color: ac.txt2)),
                      ],
                    ),
                  ),
                  Text(status,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPresent ? ac.grn : ac.org)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

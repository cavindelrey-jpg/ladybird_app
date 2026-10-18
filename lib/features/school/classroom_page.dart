// lib/features/school/classroom_page.dart
// Virtual classroom, subject list, teachers, and resources.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/application_shell.dart';
import 'class_group_launcher.dart';

class ClassroomPage extends StatelessWidget {
  final AppUser user;
  const ClassroomPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ApplicationShell(
      user: user,
      currentDestination: AppNavDestination.classroom,
      currentTitle: 'Classroom',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _classBanner(context, ac),
          const SizedBox(height: 24),
          _subjectsSection(context, ac),
        ],
      ),
    );
  }

  Widget _classBanner(BuildContext context, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ac.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.school_rounded, color: ac.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.classLevel.isNotEmpty ? user.classLevel : 'My Classroom',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700, color: ac.txt),
                ),
                const SizedBox(height: 4),
                Text(
                  user.schoolName.isNotEmpty ? user.schoolName : 'Academic Section',
                  style: GoogleFonts.inter(fontSize: 13, color: ac.txt2),
                ),
              ],
            ),
          ),
          if (canOpenClassGroup(user))
            ElevatedButton.icon(
              onPressed: () => openClassGroup(context, user),
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
              ),
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Open Class Chat'),
            ),
        ],
      ),
    );
  }

  Widget _subjectsSection(BuildContext context, AppColors ac) {
    final subjects = [
      ('Mathematics', 'Mr. Fon', 'Room A1 • Mon, Wed, Fri', Icons.calculate_rounded),
      ('Physics', 'Dr. Eyong', 'Lab 2 • Tue, Thu', Icons.science_rounded),
      ('Chemistry', 'Mrs. Nkem', 'Lab 1 • Mon, Thu', Icons.biotech_rounded),
      ('Biology', 'Mr. Tabi', 'Bio Lab • Wed, Fri', Icons.eco_rounded),
      ('English Language', 'Mrs. Bessem', 'Room B4 • Mon, Tue, Fri', Icons.menu_book_rounded),
      ('Computer Science', 'Mr. Dylan', 'Computer Lab • Wed, Thu', Icons.computer_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enrolled Subjects & Instructors',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
          ),
          itemCount: subjects.length,
          itemBuilder: (context, i) {
            final (name, teacher, schedule, icon) = subjects[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ac.surf,
                borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: ac.bdr),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ac.surf2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: ac.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ac.txt)),
                        const SizedBox(height: 2),
                        Text(teacher,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: ac.primary)),
                        const SizedBox(height: 2),
                        Text(schedule,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: ac.txt2)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

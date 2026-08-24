// lib/features/school/widgets/school_shared_widgets.dart
// Shared header + student-info-card widgets for School Connect, Marks,
// and Timetable -- mockups/mockup1-3.jpg all use the exact same top bar
// (back arrow, school crest, title + subtitle) and student card (photo,
// name+role badge, Class/Student ID, Class Master/School) shape, just
// with different page titles/subtitles and trailing actions.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/branding.dart';
import '../../../models/app_user.dart';
import '../../../repositories/school_class_info_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/widgets.dart';

/// The school crest + title + subtitle combination every School Connect/
/// Marks/Timetable AppBar uses. [trailing] is whatever page-specific
/// icon buttons sit on the right (mockups vary: bell, calendar, download).
PreferredSizeWidget schoolAppBar({
  required BuildContext context,
  required String title,
  required String subtitle,
  List<Widget> trailing = const [],
}) {
  final ac = AppColors.of(context);
  return AppBar(
    backgroundColor: ac.bg,
    elevation: 0,
    iconTheme: IconThemeData(color: ac.txt),
    titleSpacing: 0,
    title: Row(children: [
      const BrandLogo(size: 34),
      const SizedBox(width: 10),
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 10.5, color: ac.txt2)),
        ]),
      ),
    ]),
    actions: trailing,
  );
}

/// The student identity card at the top of all three pages -- real data
/// throughout: Class/School Connect Student ID both read off AppUser
/// (classLevel, serialNumber), Class Master is the one field nothing in
/// this app tracked before this pass (SchoolClassInfoRepository).
class StudentInfoCard extends StatelessWidget {
  final AppUser user;
  const StudentInfoCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf, borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: ac.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 28, backgroundColor: ac.primaryBg,
            backgroundImage: (user.photoUrl ?? '').isNotEmpty ? NetworkImage(user.photoUrl!) : null,
            child: (user.photoUrl ?? '').isEmpty
                ? Text(user.initials, style: GoogleFonts.sora(fontSize: 18, color: ac.primary, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(children: [
              Flexible(child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(20)),
                child: Text(user.roleLabel, style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _field(ac, 'Class', user.classLevel.isEmpty ? '—' : user.classLevel)),
          Expanded(child: _field(ac, 'Student ID', (user.serialNumber ?? '').isEmpty ? '—' : user.serialNumber!)),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: StreamBuilder<String?>(
              stream: SchoolClassInfoRepository.instance.watchClassMasterName(user.schoolId ?? '', user.classLevel),
              builder: (context, snap) {
                final name = snap.data ?? '';
                return _field(ac, 'Class Master', name.isEmpty ? 'Not set' : name);
              },
            ),
          ),
          Expanded(child: _field(ac, 'School', Branding.current.appName)),
        ]),
      ]),
    );
  }

  Widget _field(AppColors ac, String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
      const SizedBox(height: 2),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt)),
    ]);
  }
}

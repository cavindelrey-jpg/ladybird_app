// lib/widgets/app_drawer.dart
// Unified global navigation drawer matching the GlobalSidebar design system.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../pages/settings_page.dart';
import '../pages/help_support_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/academic_content/library_home_page.dart';
import '../features/academic_content/library_folder_page.dart';
import '../repositories/library_folder_repository.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/testing/quiz_categories_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/timetable_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/attendance_page.dart';
import '../features/school/fees_page.dart';
import '../features/school/classroom_page.dart';

class AppDrawer extends StatelessWidget {
  final AppUser? user;
  final VoidCallback? onHomeTap;
  const AppDrawer({super.key, this.user, this.onHomeTap});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF081630),
      child: SafeArea(
        child: Column(
          children: [
            _header(context),
            const Divider(height: 1, color: Color(0xFF162544)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                children: [
                  _navItem(context, Icons.home_rounded, 'Home', () {
                    Navigator.of(context).pop();
                    if (onHomeTap != null) {
                      onHomeTap!();
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => UniversalHomePage(user: user ?? AppUser.guest()),
                        ),
                      );
                    }
                  }),
                  _navItem(context, Icons.menu_book_rounded, 'Academic Courses', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CoursesHomePage(user: user),
                    ));
                  }),
                  _navItem(context, Icons.folder_copy_rounded, 'Academic Library', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LibraryHomePage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.description_rounded, 'Past Questions', () {
                    Navigator.of(context).pop();
                    _openLibraryFolderByName(context, user ?? AppUser.guest(), 'Past Papers');
                  }),
                  _navItem(context, Icons.fact_check_rounded, 'Tests & Quizzes', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => QuizCategoriesPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.forum_rounded, 'School Connect', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SchoolConnectPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.bar_chart_rounded, 'Marks', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MarksPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.edit_note_rounded, 'Homework', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => HomeworkPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.calendar_today_rounded, 'Timetable', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TimetablePage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.check_circle_outline_rounded, 'Attendance', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AttendancePage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.account_balance_wallet_rounded, 'Fees', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FeesPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.desktop_windows_rounded, 'Classroom', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ClassroomPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.campaign_rounded, 'Announcements', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DailyNoticesPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                ],
              ),
            ),
            const Divider(color: Color(0xFF162544), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                children: [
                  _navItem(context, Icons.settings_outlined, 'Settings', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SettingsPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.help_outline_rounded, 'Help', () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => HelpSupportPage(user: user ?? AppUser.guest()),
                    ));
                  }),
                  _navItem(context, Icons.logout_rounded, 'Sign Out', () {
                    Navigator.of(context).pop();
                    AuthService.instance.performSignOut(context);
                  }, iconColor: const Color(0xFFEF4444), textColor: const Color(0xFFEF4444)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE5A93C),
            backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                ? NetworkImage(user!.photoUrl!)
                : null,
            child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                ? Text(
                    user?.initials ?? 'ND',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF081630),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name.isNotEmpty == true ? user!.name : 'Academic Student',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  user?.roleLabel.isNotEmpty == true ? user!.roleLabel : 'Student',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF8CA3CF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? iconColor,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? const Color(0xFFC0D2F0)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? const Color(0xFFC0D2F0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLibraryFolderByName(BuildContext context, AppUser user, String name) async {
    final folder = await LibraryFolderRepository.instance.rootFolderByName(name);
    if (!context.mounted) return;
    if (folder == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryHomePage(user: user)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LibraryFolderPage(folderId: folder.id, folderName: folder.name, user: user),
    ));
  }
}

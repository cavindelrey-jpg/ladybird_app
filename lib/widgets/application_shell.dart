// lib/widgets/application_shell.dart
// Pure mobile scaffold wrapper for secondary school workspaces (Attendance, Fees, Exams, etc.).
// Provides standard mobile AppBar with back button, page title, subtitle,
// and safe area body. Zero desktop sidebars or web layouts.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';

enum AppNavDestination {
  home,
  academicCourses,
  academicLibrary,
  pastQuestions,
  testsAndQuizzes,
  magazine,
  clubs,
  messages,
  dictionary,
  bookmarks,
  studyPlan,
  schoolConnect,
  marks,
  homework,
  timetable,
  attendance,
  fees,
  classroom,
  announcements,
  examComposer,
  settings,
  help,
  none,
}

class ShellBreadcrumb {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const ShellBreadcrumb({
    required this.label,
    this.onTap,
    this.icon,
  });
}

class ApplicationShell extends StatelessWidget {
  final AppUser user;
  final String? currentTitle;
  final String? title;
  final String? subtitle;
  final AppNavDestination? currentDestination;
  final List<ShellBreadcrumb>? breadcrumbs;
  final List<Widget>? headerActions;
  final bool showBackButton;
  final Widget child;

  const ApplicationShell({
    super.key,
    required this.user,
    this.currentTitle,
    this.title,
    this.subtitle,
    this.currentDestination,
    this.breadcrumbs,
    this.headerActions,
    this.showBackButton = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final displayTitle = title ?? currentTitle ?? (breadcrumbs?.isNotEmpty == true ? breadcrumbs!.last.label : '');
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        leading: showBackButton && Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: ac.txt),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTitle,
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ac.txt,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: ac.muted,
                ),
              ),
          ],
        ),
        actions: headerActions,
      ),
      body: SafeArea(child: child),
    );
  }
}

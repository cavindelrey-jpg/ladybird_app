// lib/features/school/widgets/management_scaffold.dart
// Shared scaffold for admin/teacher management pages (Homework
// Management, Teacher Management, School Calendar, and -- lightly
// wrapping pages that already existed -- Marks/Timetable management).
//
// Below kWideBreakpoint this renders exactly like every other school page
// (a schoolAppBar-style title bar). At/above it, a persistent left
// sidebar replaces the app's usual Drawer and the AppBar becomes a plain
// top bar -- this is the "Ladybird Web Portal" chrome from the mockups,
// built once here and reused by every management page, rather than a
// separate app or deployment (same Flutter codebase, `flutter build web`
// serves it).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/app_user.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/widgets.dart';

const double kWideBreakpoint = 900;

class ManagementNavItem {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const ManagementNavItem({required this.icon, required this.label, this.selected = false, this.onTap});
}

class ManagementScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<ManagementNavItem> sidebarItems;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final PreferredSizeWidget? bottom;

  final AppUser? user;
  final AppNavDestination destination;
  final Widget? contextualPanel;

  const ManagementScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.sidebarItems = const [],
    this.actions = const [],
    required this.body,
    this.floatingActionButton,
    this.drawer,
    this.bottom,
    this.user,
    this.destination = AppNavDestination.schoolConnect,
    this.contextualPanel,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ApplicationShell(
      user: user,
      currentTitle: title,
      subtitle: subtitle,
      currentDestination: destination,
      contextualPanel: contextualPanel,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      floatingActionButton: floatingActionButton,
      child: Column(
        children: [
          if (actions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: ac.surf,
              child: Row(
                children: [
                  const Spacer(),
                  ...actions,
                ],
              ),
            ),
          if (bottom != null) bottom!,
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final ManagementNavItem item;
  final AppColors ac;
  const _SidebarTile({required this.item, required this.ac});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.selected ? ac.primaryBg : Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Icon(item.icon, size: 20, color: item.selected ? ac.primary : ac.muted),
            const SizedBox(width: 14),
            Text(item.label,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: item.selected ? FontWeight.w700 : FontWeight.w500,
                    color: item.selected ? ac.primary : ac.txt)),
          ]),
        ),
      ),
    );
  }
}

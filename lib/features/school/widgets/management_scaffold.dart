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
import '../../../theme/app_colors.dart';

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
  final List<ManagementNavItem> sidebarItems;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final PreferredSizeWidget? bottom;

  const ManagementScaffold({
    super.key,
    required this.title,
    this.sidebarItems = const [],
    this.actions = const [],
    required this.body,
    this.floatingActionButton,
    this.drawer,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isWide = MediaQuery.of(context).size.width >= kWideBreakpoint && sidebarItems.isNotEmpty;

    if (!isWide) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(
          backgroundColor: ac.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: ac.txt),
          title: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
          actions: actions,
          bottom: bottom,
        ),
        drawer: drawer,
        floatingActionButton: floatingActionButton,
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: ac.bg,
      floatingActionButton: floatingActionButton,
      body: Row(children: [
        Container(
          width: 232,
          color: ac.surf,
          child: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              for (final item in sidebarItems) _SidebarTile(item: item, ac: ac),
            ]),
          ),
        ),
        VerticalDivider(width: 1, color: ac.bdr),
        Expanded(
          child: Column(children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text(title, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: ac.txt)),
                const Spacer(),
                ...actions,
              ]),
            ),
            Divider(height: 1, color: ac.bdr),
            if (bottom != null) bottom!,
            Expanded(child: body),
          ]),
        ),
      ]),
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

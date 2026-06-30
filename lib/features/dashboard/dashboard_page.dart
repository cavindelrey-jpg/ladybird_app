// lib/features/dashboard/dashboard_page.dart
// Redesigned dashboard: animated welcome, role hero, live stats, events, announcements.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/calendar_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class DashboardPage extends StatefulWidget {
  final AppUser user;
  const DashboardPage({super.key, required this.user});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _DashHeader(user: widget.user)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _HeroBanner(user: widget.user),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Upcoming Events'),
                  const SizedBox(height: 10),
                  _LiveEvents(schoolId: widget.user.schoolId),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Latest Announcements'),
                  const SizedBox(height: 10),
                  _LiveAnnouncements(schoolId: widget.user.schoolId),
                ])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  final AppUser user;
  const _DashHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final rc = RoleColors.fg(user.role.name);
    return Container(
      color: C.surf,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(children: [
        UserAvatar(initials: user.initials, radius: 24,
            bg: RoleColors.bg(user.role.name), fg: rc),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome back', style: GoogleFonts.inter(fontSize: 12, color: C.txt2)),
          Text(user.name, style: GoogleFonts.sora(
              fontSize: 17, fontWeight: FontWeight.w700, color: C.txt),
              overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: RoleColors.bg(user.role.name),
              borderRadius: BorderRadius.circular(Rad.xs)),
          child: Text(user.roleLabel, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: rc)),
        ),
      ]),
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final AppUser user;
  const _HeroBanner({required this.user});

  Map<String, dynamic> get _cfg {
    switch (user.role) {
      case UserRole.superAdmin:
        return {
          'title': 'Platform Overview',
          'sub': 'All institutions under your control.',
          'colors': [const Color(0xFF5B21B6), const Color(0xFF7C3AED)],
          'icon': Icons.hub_rounded,
        };
      case UserRole.schoolAdmin:
        return {
          'title': 'School Dashboard',
          'sub': 'Manage users, courses and settings.',
          'colors': [const Color(0xFF1A56DB), const Color(0xFF2563EB)],
          'icon': Icons.domain_rounded,
        };
      case UserRole.departmentAdmin:
        return {
          'title': 'Department Hub',
          'sub': 'Oversee courses and student progress.',
          'colors': [const Color(0xFF0369A1), const Color(0xFF0284C7)],
          'icon': Icons.corporate_fare_rounded,
        };
      case UserRole.lecturer:
        return {
          'title': 'Teaching Hub',
          'sub': 'Courses, assignments, marks & attendance.',
          'colors': [const Color(0xFF92400E), const Color(0xFFC9A227)],
          'icon': Icons.cast_for_education_rounded,
        };
      case UserRole.student:
        return {
          'title': 'Your Campus',
          'sub': 'Library, assignments, timetable & results.',
          'colors': [const Color(0xFF166534), const Color(0xFF16A34A)],
          'icon': Icons.school_rounded,
        };
      case UserRole.guest:
        return {
          'title': 'Welcome',
          'sub': 'Explore Academia.',
          'colors': [const Color(0xFF334155), const Color(0xFF475569)],
          'icon': Icons.explore_rounded,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    final String title = cfg['title'];
    final String sub = cfg['sub'];
    final List<Color> colors = cfg['colors'];
    final IconData icon = cfg['icon'];

    return GradientCard(
      colors: colors, height: 120,
      child: Stack(children: [
        Positioned(right: -8, top: -8,
            child: Icon(icon, size: 100, color: Colors.white.withValues(alpha: .1))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, style: GoogleFonts.sora(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text(sub, style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withValues(alpha: .8), height: 1.4)),
              ]),
        ),
      ]),
    );
  }
}

// ── Live Events ───────────────────────────────────────────

class _LiveEvents extends StatelessWidget {
  final String? schoolId;
  const _LiveEvents({this.schoolId});

  static Color _typeColor(CalendarEventType t) {
    switch (t) {
      case CalendarEventType.exam:       return C.red;
      case CalendarEventType.holiday:    return C.grn;
      case CalendarEventType.classStart: return C.primary;
      case CalendarEventType.deadline:   return C.org;
      case CalendarEventType.ceremony:   return C.gold;
      default:                           return C.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (schoolId == null || schoolId!.isEmpty) {
      return const EmptyState(icon: Icons.event_outlined, title: 'No events scheduled',
          subtitle: 'Upcoming events will appear here');
    }
    return StreamBuilder<List<CalendarEvent>>(
      stream: CalendarRepository.instance.watchUpcoming(schoolId!)
          .map((l) => l.take(3).toList()),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(children: [
            ShimmerCard(height: 64), ShimmerCard(height: 64)]);
        }
        if (snap.hasError) return ErrorView(message: snap.error.toString());
        final events = snap.data ?? [];
        if (events.isEmpty) {
          return const EmptyState(icon: Icons.event_outlined, title: 'No upcoming events');
        }
        return Column(children: events.map((e) {
          final col = _typeColor(e.type);
          return ACard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 46, height: 46,
                  decoration: BoxDecoration(color: col.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(Rad.sm)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${e.startDate.day}', style: GoogleFonts.sora(
                        fontSize: 16, fontWeight: FontWeight.w800, color: col)),
                    Text(_monthAbbr(e.startDate.month),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: col)),
                  ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: GoogleFonts.sora(
                    fontSize: 13, fontWeight: FontWeight.w700, color: C.txt),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                StatusBadge(label: e.typeLabel, color: col),
              ])),
            ]),
          );
        }).expand((w) => [w, const SizedBox(height: 8)]).toList()..removeLast());
      },
    );
  }

  static String _monthAbbr(int m) {
    const a = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return m >= 1 && m <= 12 ? a[m] : '';
  }
}

// ── Live Announcements ────────────────────────────────────

class _LiveAnnouncements extends StatelessWidget {
  final String? schoolId;
  const _LiveAnnouncements({this.schoolId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementRepository.instance
          .watchAnnouncements(schoolId: schoolId).map((l) => l.take(3).toList()),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(children: [
            ShimmerCard(height: 90), ShimmerCard(height: 90)]);
        }
        if (snap.hasError) return ErrorView(message: snap.error.toString());
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.campaign_outlined, title: 'No announcements yet',
              subtitle: 'School notices will appear here');
        }
        return Column(children: list.map((a) {
          final diff = DateTime.now().difference(a.date);
          final dateStr = diff.inDays == 0 ? 'Today'
              : diff.inDays == 1 ? 'Yesterday' : '${diff.inDays}d ago';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnnCard(
              tag: a.tag.isNotEmpty ? a.tag : 'Notice',
              title: a.title, body: a.body, date: dateStr,
              accent: a.urgent ? C.red : C.navy3, urgent: a.urgent,
            ),
          );
        }).toList());
      },
    );
  }
}
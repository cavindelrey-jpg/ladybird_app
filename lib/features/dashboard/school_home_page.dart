// lib/features/dashboard/school_home_page.dart
// The school-mode Home screen (Green Hill / any future white-label
// school client — gated on AppConfig.isSchoolMode, see app_router.dart).
// Deliberately NOT UniversalHomePage: that screen is built around
// Academia's general-education Quick Access set (Library/Courses/Past
// Questions/Clubs). This one puts the school's own operational
// features — Attendance, Timetable, Marks, Announcements — front and
// center, per the school's own product brief: the platform for THIS
// school, not a re-skinned copy of the public Academia app.
//
// Reuses existing, already-working repositories/pages rather than
// inventing new plumbing: AttendancePage/TimetablePage/MarksPage/
// AnnouncementsPage/ClubsPage/MessagesHomePage all already exist and
// are fully functional — this screen is a front door to them, not a
// reimplementation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/branding.dart';
import '../../models/app_user.dart';
import '../../models/announcement.dart';
import '../../models/timetable_slot.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/timetable_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/xp_widgets.dart';
import '../../pages/notifications_page.dart';
import '../../pages/profile_page.dart';
import '../attendance/attendance_page.dart';
import '../timetable/timetable_page.dart';
import '../../pages/marks_page.dart';
import '../announcements/announcements_page.dart';
import '../clubs/clubs_page.dart';
import '../messages/messages_home_page.dart';
import '../academic_content/academic_content_page.dart';
import '../courses_marketplace/courses_marketplace_page.dart';

class SchoolHomePage extends StatelessWidget {
  final AppUser user;
  const SchoolHomePage({super.key, required this.user});

  String get _sid => user.schoolId ?? '';

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final brand = Branding.current;
    return Scaffold(
      backgroundColor: ac.bg,
      body: AppBackground(child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _Header(user: user, brand: brand),
              const SizedBox(height: 16),
              _HeroBanner(brand: brand),
              const SizedBox(height: 24),
              _SectionLabel('Today\'s Schedule'),
              const SizedBox(height: 10),
              _TodaySchedule(schoolId: _sid, classGroup: user.classLevel, brand: brand),
              const SizedBox(height: 24),
              _SectionLabel('Quick Access'),
              const SizedBox(height: 10),
              _QuickAccessGrid(user: user, brand: brand),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _SectionLabel('Recent Announcements')),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AnnouncementsPage(user: user, canPost: user.canPostAnnouncement))),
                    child: Text('View all', style: TextStyle(color: brand.primaryColor, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              _RecentAnnouncements(schoolId: _sid, brand: brand),
            ],
          ),
        ),
      )),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
    );
  }
}

class _Header extends StatelessWidget {
  final AppUser user;
  final Branding brand;
  const _Header({required this.user, required this.brand});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(children: [
        BrandLogo(size: 36),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_greeting,', style: TextStyle(fontSize: 12, color: ac.txt2)),
          Text(user.name.isEmpty ? 'Welcome' : user.name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        XpBalanceBadge(userId: user.id),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: ac.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: user.id))),
        ),
        UserAvatar(
          initials: user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
          radius: 18, photoUrl: user.photoUrl,
          bg: brand.primaryColor.withValues(alpha: .14), fg: brand.primaryColor,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfilePage(user: user))),
        ),
      ]),
    );
  }
}

/// Brand-colored (not the app's fixed navy/gold) welcome banner — this is
/// the single biggest "this is a different product" visual cue on the
/// screen a presenter opens first when switching from Academia.
class _HeroBanner extends StatelessWidget {
  final Branding brand;
  const _HeroBanner({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [brand.secondaryColor, brand.primaryColor],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: brand.primaryColor.withValues(alpha: .28),
              blurRadius: 20, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(right: -20, top: -20,
            child: Opacity(opacity: .14, child: BrandLogo(size: 130))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome to', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .75))),
            const SizedBox(height: 2),
            Text(brand.appName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
            const SizedBox(height: 8),
            Text(brand.tagline,
                style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .85), fontStyle: FontStyle.italic)),
          ]),
        ]),
      ),
    );
  }
}

class _TodaySchedule extends StatelessWidget {
  final String schoolId;
  final String classGroup;
  final Branding brand;
  const _TodaySchedule({required this.schoolId, required this.classGroup, required this.brand});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (schoolId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('No school linked yet.', style: TextStyle(color: ac.muted, fontSize: 13)),
      );
    }
    final today = DateTime.now().weekday; // 1=Mon..7=Sun, matches TimetableSlot.dayOfWeek for 1-5
    final stream = classGroup.isNotEmpty
        ? TimetableRepository.instance.watchForClass(schoolId, classGroup)
        : TimetableRepository.instance.watchAll(schoolId);
    return StreamBuilder<List<TimetableSlot>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [ShimmerCard(height: 56), ShimmerCard(height: 56)]),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Could not load the timetable.', style: TextStyle(color: ac.red, fontSize: 12)),
          );
        }
        final todaySlots = (snap.data ?? [])
            .where((s) => s.dayOfWeek == today)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        if (todaySlots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No classes scheduled for today.', style: TextStyle(color: ac.muted, fontSize: 13)),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: todaySlots.take(4).map((s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: ac.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: ac.bdr)),
            child: Row(children: [
              Container(
                width: 4, height: 36,
                decoration: BoxDecoration(color: brand.primaryColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.courseName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: ac.txt)),
                const SizedBox(height: 2),
                Text(s.venue.isEmpty ? s.lecturerName : '${s.venue} · ${s.lecturerName}',
                    style: TextStyle(fontSize: 11.5, color: ac.txt2)),
              ])),
              Text('${s.startTime} - ${s.endTime}',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: brand.primaryColor)),
            ]),
          )).toList()),
        );
      },
    );
  }
}

class _QuickAccessItem {
  final IconData icon;
  final String label;
  final WidgetBuilder pageBuilder;
  const _QuickAccessItem(this.icon, this.label, this.pageBuilder);
}

class _QuickAccessGrid extends StatelessWidget {
  final AppUser user;
  final Branding brand;
  const _QuickAccessGrid({required this.user, required this.brand});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    // School-operational features FIRST (this is the whole point of this
    // screen vs. UniversalHomePage's Library/Courses/PastQuestions/Clubs
    // ordering), general Academia features after.
    final items = <_QuickAccessItem>[
      _QuickAccessItem(Icons.fact_check_rounded, 'Attendance', (_) => AttendancePage(user: user)),
      _QuickAccessItem(Icons.calendar_view_week_rounded, 'Timetable', (_) => TimetablePage(user: user)),
      _QuickAccessItem(Icons.grade_rounded, 'Marks', (_) => MarksPage(user: user)),
      _QuickAccessItem(Icons.campaign_rounded, 'Announcements', (_) => AnnouncementsPage(user: user, canPost: user.canPostAnnouncement)),
      _QuickAccessItem(Icons.groups_rounded, 'Clubs', (_) => ClubsPage(user: user)),
      _QuickAccessItem(Icons.chat_bubble_rounded, 'Messages', (_) => MessagesHomePage(user: user)),
      _QuickAccessItem(Icons.menu_book_rounded, 'Library', (_) => AcademicContentPage(user: user)),
      _QuickAccessItem(Icons.school_rounded, 'Courses', (_) => CoursesMarketplacePage(user: user)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 14, childAspectRatio: 0.78,
        ),
        itemBuilder: (context, i) {
          final item = items[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(MaterialPageRoute(builder: item.pageBuilder));
              },
              child: Column(children: [
                Container(
                  width: 52, height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [brand.primaryColor.withValues(alpha: .20), brand.accentColor.withValues(alpha: .14)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: brand.primaryColor.withValues(alpha: .18)),
                  ),
                  child: Icon(item.icon, color: brand.primaryColor, size: 24),
                ),
                const SizedBox(height: 6),
                Text(item.label, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.txt2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _RecentAnnouncements extends StatelessWidget {
  final String schoolId;
  final Branding brand;
  const _RecentAnnouncements({required this.schoolId, required this.brand});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementRepository.instance
          .watchAnnouncements(schoolId: schoolId.isEmpty ? null : schoolId)
          .map((l) => l.take(3).toList()),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [ShimmerCard(height: 90), ShimmerCard(height: 90)]),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Could not load announcements.', style: TextStyle(color: ac.red, fontSize: 12)),
          );
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No announcements yet.', style: TextStyle(color: ac.muted, fontSize: 13)),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: list.map((a) {
            final diff = DateTime.now().difference(a.date);
            final dateStr = diff.inDays == 0 ? 'Today' : diff.inDays == 1 ? 'Yesterday' : '${diff.inDays}d ago';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnnCard(
                tag: a.tag.isNotEmpty ? a.tag : 'Notice',
                title: a.title, body: a.body, date: dateStr,
                accent: a.urgent ? ac.red : brand.primaryColor, urgent: a.urgent,
              ),
            );
          }).toList()),
        );
      },
    );
  }
}

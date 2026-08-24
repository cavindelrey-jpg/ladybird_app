// lib/features/school/school_connect_page.dart
// The student's central interface for communicating with and receiving
// information from the school. Real data throughout:
//   - Header: student identity + class.
//   - Quick action: jump straight to submitting a request.
//   - School services: 5 request types -> SchoolRequestFormPage, all
//     backed by the real school_requests/{id} collection.
//   - Calendar & activities: real schools/{schoolId}/academic_calendar
//     data (SchoolEventRepository) -- the page that already had a
//     correct, unused Firestore rule.
//   - Teacher Announcements: reuses the existing, already-real
//     AnnouncementRepository scoped to this school -- no new backend.
//   - Footer: School Info.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/branding.dart';
import '../../models/announcement.dart';
import '../../models/app_user.dart';
import '../../models/school_event.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/school_event_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../announcements/announcements_page.dart';
import 'school_calendar_manager_page.dart';
import 'school_request_form_page.dart';
import 'school_requests_admin_page.dart';
import '../../models/school_request.dart';

class SchoolConnectPage extends StatelessWidget {
  final AppUser user;
  const SchoolConnectPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = user.schoolId ?? '';

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        title: Text('School Connect', style: AppText.h2.copyWith(color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
        actions: [
          if (user.canManageSchool || user.canUploadContent)
            IconButton(
              icon: Icon(Icons.inbox_outlined, color: ac.txt2),
              tooltip: 'Requests inbox',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SchoolRequestsAdminPage(staff: user))),
            ),
        ],
      ),
      body: schoolId.isEmpty
          ? _missingSchoolState(ac)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _header(ac),
                const SizedBox(height: 16),
                _quickActionBox(context, ac, schoolId),
                const SizedBox(height: 20),
                _sectionLabel(ac, 'School Services'),
                const SizedBox(height: 10),
                _servicesGrid(context, ac, schoolId),
                const SizedBox(height: 24),
                _calendarSection(context, ac, schoolId),
                const SizedBox(height: 24),
                _announcementsSection(context, ac, schoolId),
                const SizedBox(height: 24),
                _schoolInfoFooter(ac),
              ],
            ),
    );
  }

  Widget _header(AppColors ac) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ac.navy, ac.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Rad.lg),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24, backgroundColor: Colors.white.withValues(alpha: .15),
          backgroundImage: (user.photoUrl ?? '').isNotEmpty ? NetworkImage(user.photoUrl!) : null,
          child: (user.photoUrl ?? '').isEmpty
              ? Text(user.initials, style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text(user.classLevel.isEmpty ? Branding.current.appName : '${user.classLevel} · ${Branding.current.appName}',
                style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withValues(alpha: .8))),
          ]),
        ),
      ]),
    );
  }

  Widget _quickActionBox(BuildContext context, AppColors ac, String schoolId) {
    return Material(
      color: ac.primaryBg,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SchoolRequestFormPage(user: user, initialType: SchoolRequestType.general))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.chat_bubble_outline_rounded, color: ac.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Need something from the school? Send a request.',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.primary)),
            ),
            Icon(Icons.arrow_forward_rounded, size: 16, color: ac.primary),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(AppColors ac, String text) =>
      Text(text, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: ac.txt));

  Widget _servicesGrid(BuildContext context, AppColors ac, String schoolId) {
    final items = <(SchoolRequestType, IconData, Color)>[
      (SchoolRequestType.issue, Icons.report_problem_outlined, ac.red),
      (SchoolRequestType.leave, Icons.event_busy_outlined, ac.org),
      (SchoolRequestType.feeInquiry, Icons.payments_outlined, ac.gold),
      (SchoolRequestType.general, Icons.assignment_outlined, ac.primary),
      (SchoolRequestType.feedback, Icons.feedback_outlined, ac.pur),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        for (final (type, icon, color) in items)
          Material(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.md),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SchoolRequestFormPage(user: user, initialType: type))),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(type.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.txt)),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _calendarSection(BuildContext context, AppColors ac, String schoolId) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionLabel(ac, 'Calendar & Activities'),
        if (user.canManageSchool)
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SchoolCalendarManagerPage(user: user))),
            icon: const Icon(Icons.edit_calendar_outlined, size: 16),
            label: const Text('Manage'),
          ),
      ]),
      const SizedBox(height: 10),
      StreamBuilder<List<SchoolEvent>>(
        stream: SchoolEventRepository.instance.watchAll(schoolId),
        builder: (context, snap) {
          final all = snap.data ?? const <SchoolEvent>[];
          final upcoming = all.where((e) => e.isUpcoming).toList();
          if (all.isEmpty) {
            return _emptyCard(ac, 'No activities on the calendar yet.');
          }
          return Column(children: [
            Text('Upcoming Events', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ac.muted)),
            const SizedBox(height: 6),
            if (upcoming.isEmpty)
              _emptyCard(ac, 'No upcoming events right now.')
            else
              for (final e in upcoming.take(5)) _eventCard(ac, e),
          ]);
        },
      ),
    ]);
  }

  Widget _eventCard(AppColors ac, SchoolEvent e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${e.startAt.day}', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: ac.gold)),
            Text(_monthAbbr(e.startAt.month), style: GoogleFonts.inter(fontSize: 8.5, color: ac.gold)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt)),
            if ((e.location ?? '').isNotEmpty)
              Text(e.location!, style: GoogleFonts.inter(fontSize: 10.5, color: ac.txt2)),
          ]),
        ),
      ]),
    );
  }

  String _monthAbbr(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  Widget _announcementsSection(BuildContext context, AppColors ac, String schoolId) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionLabel(ac, 'Teacher Announcements'),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AnnouncementsPage(user: user, canPost: user.canPostAnnouncement))),
          child: const Text('View all'),
        ),
      ]),
      StreamBuilder<List<Announcement>>(
        stream: AnnouncementRepository.instance.watchAnnouncements(schoolId: schoolId),
        builder: (context, snap) {
          final items = snap.data ?? const <Announcement>[];
          if (items.isEmpty) return _emptyCard(ac, 'No announcements from the school yet.');
          return Column(children: [
            for (final a in items.take(3))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.campaign_rounded, size: 16, color: ac.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt)),
                      Text(a.authorName, style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
                    ]),
                  ),
                ]),
              ),
          ]);
        },
      ),
    ]);
  }

  Widget _schoolInfoFooter(AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(Rad.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('School Info', style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.txt)),
        const SizedBox(height: 6),
        Text(Branding.current.appName,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ac.txt2)),
        Text(Branding.current.tagline, style: GoogleFonts.inter(fontSize: 11, color: ac.muted)),
      ]),
    );
  }

  Widget _emptyCard(AppColors ac, String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
        child: Text(message, style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted)),
      );

  Widget _missingSchoolState(AppColors ac) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.school_outlined, size: 48, color: ac.muted),
            const SizedBox(height: 16),
            Text('Your school isn\'t linked to your account yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
          ]),
        ),
      );
}

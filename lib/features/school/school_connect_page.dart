// lib/features/school/school_connect_page.dart
// The student's central interface for communicating with and receiving
// information from the school. Matches mockups/mockup1.jpg: shared
// crest header + student info card, a quick-action box, 5 big colored
// service cards, side-by-side Announcements/Upcoming Events, and a
// footer. Real data throughout:
//   - School services: 5 request types -> SchoolRequestFormPage, all
//     backed by the real school_requests/{id} collection.
//   - Calendar & activities: real schools/{schoolId}/academic_calendar
//     data (SchoolEventRepository) -- the page that already had a
//     correct, unused Firestore rule.
//   - Teacher Announcements: reuses the existing, already-real
//     AnnouncementRepository scoped to this school -- no new backend.
//   - Footer: real School Info (Branding) + a real "Contact School
//     Office" action -- routes into the same request system rather than
//     showing fabricated phone numbers no data source backs.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/branding.dart';
import '../../models/announcement.dart';
import '../../models/app_user.dart';
import '../../models/school_event.dart';
import '../../models/school_request.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/school_event_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../pages/notifications_page.dart';
import '../announcements/announcements_page.dart';
import 'daily_notices/daily_notices_page.dart';
import 'exam_composer/exam_list_page.dart';
import 'homework_page.dart';
import 'marks_page.dart';
import 'timetable_page.dart';
import 'school_calendar_manager_page.dart';
import 'school_request_form_page.dart';
import 'school_requests_admin_page.dart';
import 'widgets/school_shared_widgets.dart';
import '../../widgets/application_shell.dart';

class SchoolConnectPage extends StatelessWidget {
  final AppUser user;
  const SchoolConnectPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = user.schoolId ?? '';

    return ApplicationShell(
      user: user,
      currentTitle: 'School Connect',
      currentDestination: AppNavDestination.schoolConnect,
      child: schoolId.isEmpty
          ? _missingSchoolState(ac)
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                StudentInfoCard(user: user),
                const SizedBox(height: 16),
                _coreAcademicsRow(context, ac),
                const SizedBox(height: 12),
                _academicToolsRow(context, ac),
                const SizedBox(height: 16),
                _quickActionBox(context, ac),
                const SizedBox(height: 20),
                _sectionLabel(ac, 'How can we help you today?'),
                const SizedBox(height: 10),
                _servicesRow(context, ac),
                const SizedBox(height: 24),
                _announcementsAndEventsRow(context, ac, schoolId),
                const SizedBox(height: 20),
                _contactFooter(context, ac),
              ],
            ),
    );
  }

  Widget _coreAcademicsRow(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _schoolQuickCard(
              context,
              ac: ac,
              icon: Icons.assessment_outlined,
              iconColor: ac.primary,
              iconBg: ac.primaryBg,
              title: 'Marks',
              subtitle: 'Grades & Reports',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MarksPage(user: user),
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _schoolQuickCard(
              context,
              ac: ac,
              icon: Icons.menu_book_outlined,
              iconColor: ac.org,
              iconBg: ac.orgBg,
              title: 'Homework',
              subtitle: 'Tasks & Quizzes',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HomeworkPage(user: user),
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _schoolQuickCard(
              context,
              ac: ac,
              icon: Icons.calendar_month_outlined,
              iconColor: ac.grn,
              iconBg: ac.grnBg,
              title: 'Timetable',
              subtitle: 'Class Schedule',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TimetablePage(user: user),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _schoolQuickCard(
    BuildContext context, {
    required AppColors ac,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(title, style: AppText.title.copyWith(fontSize: 13, color: ac.txt)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: ac.muted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _academicToolsRow(BuildContext context, AppColors ac) {
    final canComposeExam = user.isAdmin || user.isTeacher || user.isSchoolClassMaster || user.canManageSchool;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.md),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DailyNoticesPage(user: user),
                )),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Rad.md),
                    border: Border.all(color: ac.bdr2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: ac.orgBg, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.campaign_outlined, color: ac.org, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Daily Notices', style: AppText.title.copyWith(fontSize: 13, color: ac.txt)),
                            Text("Tomorrow's Programme", style: AppText.caption.copyWith(color: ac.muted, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (canComposeExam) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: ac.surf,
                borderRadius: BorderRadius.circular(Rad.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.md),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExamListPage(user: user),
                  )),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Rad.md),
                      border: Border.all(color: ac.bdr2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.assignment_outlined, color: ac.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exam Composer', style: AppText.title.copyWith(fontSize: 13, color: ac.txt)),
                              Text('Question Bank', style: AppText.caption.copyWith(color: ac.muted, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickActionBox(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
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
      ),
    );
  }

  Widget _sectionLabel(AppColors ac, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(text, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: ac.txt)),
      );

  Widget _servicesRow(BuildContext context, AppColors ac) {
    final items = <(SchoolRequestType, IconData, Color)>[
      (SchoolRequestType.issue, Icons.report_problem_outlined, ac.org),
      (SchoolRequestType.leave, Icons.event_available_outlined, ac.grn),
      (SchoolRequestType.feeInquiry, Icons.payments_outlined, ac.blu),
      (SchoolRequestType.general, Icons.description_outlined, ac.pur),
      (SchoolRequestType.feedback, Icons.chat_bubble_outline_rounded, ac.red),
    ];
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (type, icon, color) = items[i];
          return Material(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(Rad.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.md),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SchoolRequestFormPage(user: user, initialType: type))),
              child: Container(
                width: 96,
                padding: const EdgeInsets.all(10),
                alignment: Alignment.center,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 10),
                  Text(type.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _announcementsAndEventsRow(BuildContext context, AppColors ac, String schoolId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _panel(
            ac,
            icon: Icons.campaign_rounded, iconColor: ac.primary,
            title: 'Announcements',
            onViewAll: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AnnouncementsPage(user: user, canPost: user.canPostAnnouncement))),
            child: StreamBuilder<List<Announcement>>(
              stream: AnnouncementRepository.instance.watchAnnouncements(schoolId: schoolId),
              builder: (context, snap) {
                final items = snap.data ?? const <Announcement>[];
                if (items.isEmpty) return _emptyPanelText(ac, 'No announcements yet.');
                return Column(children: [
                  for (final a in items.take(3)) _announcementRow(ac, a),
                ]);
              },
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: _panel(
            ac,
            icon: Icons.event_rounded, iconColor: ac.gold,
            title: 'Upcoming Events',
            onViewAll: user.canManageSchool
                ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SchoolCalendarManagerPage(user: user)))
                : null,
            child: StreamBuilder<List<SchoolEvent>>(
              stream: SchoolEventRepository.instance.watchAll(schoolId),
              builder: (context, snap) {
                final upcoming = (snap.data ?? const <SchoolEvent>[]).where((e) => e.isUpcoming).toList();
                if (upcoming.isEmpty) return _emptyPanelText(ac, 'No upcoming events.');
                return Column(children: [
                  for (final e in upcoming.take(3)) _eventRow(ac, e),
                ]);
              },
            ),
          )),
        ]),
      ),
    );
  }

  Widget _panel(AppColors ac, {required IconData icon, required Color iconColor, required String title,
      required Widget child, VoidCallback? onViewAll}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Expanded(child: Text(title, style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w800, color: ac.txt))),
        ]),
        if (onViewAll != null) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: onViewAll,
            child: Text('View all', style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: ac.primary)),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Widget _announcementRow(AppColors ac, Announcement a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.txt, height: 1.3)),
        Text(a.authorName, style: GoogleFonts.inter(fontSize: 9, color: ac.muted)),
      ]),
    );
  }

  Widget _eventRow(AppColors ac, SchoolEvent e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.center,
          child: Text('${e.startAt.day}', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w800, color: ac.gold)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.txt, height: 1.3)),
        ),
      ]),
    );
  }

  Widget _emptyPanelText(AppColors ac, String message) =>
      Text(message, style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted));

  Widget _contactFooter(BuildContext context, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ac.surf3, borderRadius: BorderRadius.circular(Rad.md)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Need to talk to someone?', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: ac.txt)),
          const SizedBox(height: 4),
          Text('Reach out to the school directly through School Connect.',
              style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SchoolRequestFormPage(user: user, initialType: SchoolRequestType.general))),
              icon: const Icon(Icons.call_outlined, size: 16),
              label: const Text('Contact School Office'),
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: ac.bdr, height: 1),
          const SizedBox(height: 10),
          Text('School Info', style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w800, color: ac.txt)),
          const SizedBox(height: 4),
          Text(Branding.current.appName, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: ac.txt2)),
          Text(Branding.current.tagline, style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted)),
        ]),
      ),
    );
  }

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

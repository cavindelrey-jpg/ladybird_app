// lib/features/school_connect/school_connect_page.dart
// The student-facing "front door" into their school's official channels —
// requests/enquiries, announcements and the academic calendar — distinct
// from school_management_page.dart, which is the STAFF console for the
// same underlying data (role-gated on canManageSchool, not entitlement).
// This page is the Premium Silver-gated student surface described in
// core/feature_access.dart#AppFeature.schoolConnect.
//
// Every tile here has a real destination: the help grid submits through
// SchoolRequestRepository and shows up in "Your Requests" below; the
// Announcements/Upcoming Events sections stream from the same
// repositories school_home_page.dart already uses; Contact opens the
// institution's own contact email. Nothing here is a placeholder.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../models/announcement.dart';
import '../../models/calendar_event.dart';
import '../../models/institution.dart';
import '../../models/school_request.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/calendar_repository.dart';
import '../../repositories/institution_repository.dart';
import '../../repositories/school_request_repository.dart';
import '../../core/feature_access.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/silver_gate.dart';
import '../../widgets/student_header_card.dart';
import '../../pages/notifications_page.dart';
import '../announcements/announcements_page.dart';
import '../calendar/calendar_page.dart';
import 'school_request_form_page.dart';

class SchoolConnectPage extends StatelessWidget {
  final AppUser user;
  const SchoolConnectPage({super.key, required this.user});

  String get _sid => user.schoolId ?? '';

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    if (!FeatureAccess.canAccess(user, AppFeature.schoolConnect)) {
      return SilverLockedPage(
        user: user,
        feature: AppFeature.schoolConnect,
        title: 'School Connect',
        icon: Icons.hub_rounded,
        description: 'Reach your school directly — report issues, request '
            'leave, ask about fees, and keep up with notices and the '
            'academic calendar, all in one place.',
      );
    }

    if (_sid.isEmpty) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(
          backgroundColor: ac.bg, elevation: 0,
          iconTheme: IconThemeData(color: ac.txt),
          title: Text('School Connect', style: AppText.title),
        ),
        body: AppBackground(child: EmptyState(
          icon: Icons.link_off_rounded,
          title: 'No school linked',
          subtitle: 'School Connect needs an account linked to an '
              'institution. Link a school code from Settings to use it.',
        )),
      );
    }

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('School Connect', style: AppText.title),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: ac.txt2),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationsPage(userId: user.id))),
          ),
        ],
      ),
      body: AppBackground(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SchoolStudentHeaderCard(user: user),
          const SizedBox(height: 22),

          SectionHeader(title: 'How can we help you today?'),
          const SizedBox(height: 12),
          _HelpGrid(user: user),
          const SizedBox(height: 26),

          SectionHeader(
            title: 'Announcements',
            action: 'View all',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AnnouncementsPage(
                    user: user, canPost: user.canPostAnnouncement))),
          ),
          const SizedBox(height: 10),
          _AnnouncementsPreview(schoolId: _sid),
          const SizedBox(height: 26),

          SectionHeader(
            title: 'Upcoming Events',
            action: 'View calendar',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CalendarPage(user: user))),
          ),
          const SizedBox(height: 10),
          _UpcomingEventsPreview(schoolId: _sid),
          const SizedBox(height: 26),

          SectionHeader(title: 'Your Requests'),
          const SizedBox(height: 10),
          _MyRequestsPreview(user: user),
          const SizedBox(height: 26),

          _ContactCard(schoolId: _sid),
        ],
      )),
    );
  }
}

// ── Help grid ──────────────────────────────────────────────

class _HelpGrid extends StatelessWidget {
  final AppUser user;
  const _HelpGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final tiles = <(IconData, Color, SchoolRequestType)>[
      (Icons.report_problem_rounded, ac.red, SchoolRequestType.issue),
      (Icons.event_available_rounded, ac.grn, SchoolRequestType.leaveRequest),
      (Icons.account_balance_wallet_rounded, ac.blu, SchoolRequestType.feeEnquiry),
      (Icons.description_rounded, ac.pur, SchoolRequestType.generalRequest),
      (Icons.forum_rounded, ac.gold, SchoolRequestType.feedback),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.95,
      ),
      itemBuilder: (context, i) {
        final (icon, color, type) = tiles[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.md),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SchoolRequestFormPage(user: user, type: type))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              decoration: BoxDecoration(
                color: ac.surf,
                borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: ac.bdr),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconBadge(icon: icon, color: color, size: 40, iconSize: 19),
                const SizedBox(height: 8),
                Text(type.label, textAlign: TextAlign.center,
                    style: AppText.subtitle.copyWith(fontSize: 11, height: 1.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ── Announcements preview ─────────────────────────────────

class _AnnouncementsPreview extends StatelessWidget {
  final String schoolId;
  const _AnnouncementsPreview({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementRepository.instance
          .watchAnnouncements(schoolId: schoolId)
          .map((l) => l.take(3).toList()),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(children: [ShimmerCard(height: 88), ShimmerCard(height: 88)]);
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Text('No announcements yet.', style: AppText.bodySm.copyWith(color: ac.muted));
        }
        return Column(children: list.map((a) {
          final diff = DateTime.now().difference(a.date);
          final dateStr = diff.inDays == 0
              ? 'Today'
              : diff.inDays == 1
                  ? 'Yesterday'
                  : '${diff.inDays}d ago';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnnCard(
              tag: a.tag.isNotEmpty ? a.tag : 'Notice',
              title: a.title, body: a.body, date: dateStr,
              accent: a.urgent ? ac.red : ac.primary, urgent: a.urgent,
            ),
          );
        }).toList());
      },
    );
  }
}

// ── Upcoming events preview ───────────────────────────────

class _UpcomingEventsPreview extends StatelessWidget {
  final String schoolId;
  const _UpcomingEventsPreview({required this.schoolId});

  static const _months = ['','Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<CalendarEvent>>(
      stream: CalendarRepository.instance.watchUpcoming(schoolId)
          .map((l) => l.take(3).toList()),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(children: [ShimmerCard(height: 64), ShimmerCard(height: 64)]);
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Text('No upcoming events.', style: AppText.bodySm.copyWith(color: ac.muted));
        }
        return Column(children: list.map((e) {
          final accent = e.type == CalendarEventType.exam ? ac.red : ac.primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ACard(
              child: Row(children: [
                Container(
                  width: 46, height: 46, alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(Rad.sm)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${e.startDate.day}', style: AppText.title.copyWith(fontSize: 15, color: accent)),
                    Text(_months[e.startDate.month], style: AppText.caption.copyWith(color: accent, fontSize: 9)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: AppText.title.copyWith(fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(e.typeLabel, style: AppText.caption),
                ])),
              ]),
            ),
          );
        }).toList());
      },
    );
  }
}

// ── My requests preview ───────────────────────────────────

class _MyRequestsPreview extends StatelessWidget {
  final AppUser user;
  const _MyRequestsPreview({required this.user});

  Color _statusColor(AppColors ac, SchoolRequestStatus s) {
    switch (s) {
      case SchoolRequestStatus.open:     return ac.gold;
      case SchoolRequestStatus.inReview: return ac.blu;
      case SchoolRequestStatus.resolved: return ac.grn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<SchoolRequest>>(
      stream: SchoolRequestRepository.instance
          .watchMine(schoolId: user.schoolId ?? '', studentId: user.id)
          .map((l) => l.take(5).toList()),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerCard(height: 64);
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Text(
            "Nothing submitted yet — tap a tile above and it'll show up here.",
            style: AppText.bodySm.copyWith(color: ac.muted),
          );
        }
        return Column(children: list.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ACard(
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.subject, style: AppText.title.copyWith(fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(r.type.label, style: AppText.caption),
              ])),
              StatusBadge(label: r.status.label, color: _statusColor(ac, r.status)),
            ]),
          ),
        )).toList());
      },
    );
  }
}

// ── Contact ────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final String schoolId;
  const _ContactCard({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<Institution?>(
      stream: InstitutionRepository.instance.watch(schoolId),
      builder: (context, snap) {
        final email = snap.data?.contactEmail;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf, borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Need to talk to someone?', style: AppText.title.copyWith(fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              'Picking a topic above routes your message straight to the '
              'right office — School Office, Bursar\'s Office, your Class '
              'Master, or School Administration.',
              style: AppText.bodySm.copyWith(height: 1.5),
            ),
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: 14),
              SecondaryBtn(
                label: 'Email $email',
                icon: Icons.email_outlined,
                onTap: () => launchUrl(Uri.parse(
                    'mailto:$email?subject=School%20Connect%20enquiry')),
              ),
            ],
          ]),
        );
      },
    );
  }
}

// lib/features/school/daily_notices/daily_notices_page.dart
// Daily Academic Notices feed for teachers, class masters, students, and parents.
// Clearly distinguishes manually submitted teacher notices from automated
// timetable notifications ("Tomorrow's Programme").

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/app_user.dart';
import '../../../models/daily_notice.dart';
import '../../../repositories/daily_notice_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import 'compose_daily_notice_page.dart';
import '../../../widgets/application_shell.dart';

class DailyNoticesPage extends StatefulWidget {
  final AppUser user;

  const DailyNoticesPage({super.key, required this.user});

  @override
  State<DailyNoticesPage> createState() => _DailyNoticesPageState();
}

class _DailyNoticesPageState extends State<DailyNoticesPage> {
  int _tabIndex = 0; // 0=All, 1=Teacher Notices, 2=Tomorrow's Programme

  bool get _canPost =>
      widget.user.isAdmin ||
      widget.user.isTeacher ||
      widget.user.isSchoolClassMaster ||
      widget.user.canManageSchool;

  Future<void> _triggerProgrammeNow() async {
    final schoolId = widget.user.schoolId ?? '';
    final classLevel = widget.user.classLevel ??
        (widget.user.classMasterOfClass ??
            (widget.user.teachingAssignments.isNotEmpty
                ? widget.user.teachingAssignments.first.classLevel
                : 'Form 5'));

    final notice = await DailyNoticeRepository.instance.generateTomorrowsProgramme(
      schoolId: schoolId,
      classLevel: classLevel,
    );

    if (mounted) {
      if (notice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated Tomorrow\'s Programme for $classLevel.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate timetable programme for tomorrow.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = widget.user.schoolId ?? '';
    final userClass = widget.user.classLevel ?? '';

    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Announcements',
      currentDestination: AppNavDestination.announcements,
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ComposeDailyNoticePage(user: widget.user),
                ));
              },
              backgroundColor: ac.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Post Notice'),
            )
          : null,
      child: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ac.surf2,
              border: Border(bottom: BorderSide(color: ac.bdr)),
            ),
            child: Row(
              children: [
                _tabChip(ac, 0, 'All Notices'),
                const SizedBox(width: 8),
                _tabChip(ac, 1, 'Teacher Notices'),
                const SizedBox(width: 8),
                _tabChip(ac, 2, "Tomorrow's Programme"),
              ],
            ),
          ),

          // Notices List
          Expanded(
            child: StreamBuilder<List<DailyNotice>>(
              stream: DailyNoticeRepository.instance.watchForClass(schoolId, userClass),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var items = snap.data ?? [];

                if (_tabIndex == 1) {
                  items = items.where((n) => !n.isSystemGenerated).toList();
                } else if (_tabIndex == 2) {
                  items = items.where((n) => n.isSystemGenerated).toList();
                }

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_outlined, size: 56, color: ac.muted),
                          const SizedBox(height: 16),
                          Text(
                            _tabIndex == 2
                                ? "No timetable programme generated yet"
                                : "No daily notices posted yet",
                            style: AppText.title.copyWith(fontSize: 16, color: ac.txt),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tabIndex == 2
                                ? "Tomorrow's Programme generates automatically every day at 7:00 PM using the school timetable."
                                : "Class Masters and Subject Teachers can post daily homework, reminders, and notices here.",
                            textAlign: TextAlign.center,
                            style: AppText.bodySm.copyWith(color: ac.muted),
                          ),
                          if (_canPost && _tabIndex == 2) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _triggerProgrammeNow,
                              icon: const Icon(Icons.flash_on_rounded),
                              label: const Text("Generate Tomorrow's Programme"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ac.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final notice = items[i];
                    return _NoticeCard(
                      notice: notice,
                      user: widget.user,
                      onDelete: _canPost
                          ? () async {
                              await DailyNoticeRepository.instance.deleteNotice(notice.id);
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(AppColors ac, int index, String label) {
    final selected = _tabIndex == index;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: selected ? Colors.white : ac.txt)),
      selected: selected,
      onSelected: (_) => setState(() => _tabIndex = index),
      selectedColor: ac.primary,
      backgroundColor: ac.surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final DailyNotice notice;
  final AppUser user;
  final VoidCallback? onDelete;

  const _NoticeCard({
    required this.notice,
    required this.user,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isSystem = notice.isSystemGenerated;
    final dateStr = DateFormat('EEE, d MMM').format(notice.date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSystem ? ac.primary.withValues(alpha: .3) : ac.bdr2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSystem ? ac.primaryBg : ac.bluBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSystem ? Icons.auto_awesome_rounded : Icons.person_rounded,
                      size: 12,
                      color: isSystem ? ac.primary : ac.blu,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSystem ? 'Automated Timetable Programme' : 'Teacher Notice',
                      style: AppText.caption.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isSystem ? ac.primary : ac.blu,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  notice.classLevel,
                  style: AppText.caption.copyWith(fontSize: 10.5, color: ac.txt2, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (onDelete != null && (user.isAdmin || notice.teacherId == user.id))
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: ac.muted),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            notice.title,
            style: AppText.title.copyWith(fontSize: 15, color: ac.txt),
          ),
          const SizedBox(height: 2),

          // Subtitle Author
          Text(
            'By ${notice.teacherName} (${notice.teacherRole}) · $dateStr',
            style: AppText.caption.copyWith(color: ac.muted, fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Content
          Text(
            notice.content,
            style: AppText.bodySm.copyWith(color: ac.txt, height: 1.45),
          ),

          // Optional Attachment Link
          if (notice.attachmentUrl != null && notice.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                // open attachment
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attachment_rounded, size: 14, color: ac.primary),
                    const SizedBox(width: 6),
                    Text('View Attachment', style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

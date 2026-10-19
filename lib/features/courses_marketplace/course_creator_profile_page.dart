// lib/features/courses_marketplace/course_creator_profile_page.dart
// A course creator's published (and, on your own profile, draft) courses.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/follow_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'course_lessons_page.dart';
import 'course_composer_page.dart';
import '../../core/realtime_tolerant.dart';

/// One-time-ish lookup of the full user profile (for bio) — the header's
/// name/photo already come from PublicCourse, so this only backs the
/// extra bio field.
Stream<AppUser?> _watchCreatorUser(String creatorId) => Supabase.instance.client
    .from('users')
    .stream(primaryKey: ['id'])
    .eq('id', creatorId)
    .realtimeTolerant()
    .map((rows) => rows.isNotEmpty ? AppUser.fromSupabase(rows.first) : null);

class CourseCreatorProfilePage extends StatelessWidget {
  final String creatorId;
  final AppUser? currentUser;
  const CourseCreatorProfilePage({super.key, required this.creatorId, this.currentUser});

  bool get _isOwnProfile => (currentUser?.id ?? AuthService.instance.lastKnownUser?.id) == creatorId;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final effectiveUser = currentUser ?? AuthService.instance.lastKnownUser;

    return StreamBuilder<List<PublicCourse>>(
      stream: PublicCourseRepository.instance.watchByCreator(creatorId),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = snap.hasError ? snap.error : null;
        if (snap.hasError) {
          CrashService.instance.recordError(snap.error, snap.stackTrace,
              context: 'CourseCreatorProfilePage.watchByCreator($creatorId)');
        }

        var courses = snap.data ?? const <PublicCourse>[];
        if (!_isOwnProfile) courses = courses.where((c) => c.published).toList();

        final headerName = courses.isNotEmpty ? courses.first.creatorName : (_isOwnProfile ? (effectiveUser?.name ?? 'Creator') : 'Instructor');
        final photoUrl = courses.isNotEmpty ? courses.first.creatorPhotoUrl : effectiveUser?.photoUrl;

        return ApplicationShell(
          user: effectiveUser,
          currentTitle: _isOwnProfile ? 'Your Courses' : headerName,
          subtitle: _isOwnProfile
              ? 'Manage and monitor your published courses and drafts'
              : 'Instructor Catalog & Profile',
          currentDestination: AppNavDestination.academicCourses,
          showBackButton: true,
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            if (_isOwnProfile && effectiveUser != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Create New Course',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CourseComposerPage(user: effectiveUser),
                    ));
                  },
                ),
              ),
          ],
          contextualPanel: _CreatorProfileRightPanel(
            creatorId: creatorId,
            isOwnProfile: _isOwnProfile,
            courseCount: courses.length,
            publishedCount: courses.where((c) => c.published).length,
            draftCount: courses.where((c) => !c.published).length,
            currentUser: effectiveUser,
          ),
          child: Builder(
            builder: (context) {
              if (loading) return const LoadingView();
              if (error != null) {
                return ErrorView(message: "Couldn't load this profile — $error");
              }
              if (courses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: EmptyState(
                      icon: Icons.school_outlined,
                      title: _isOwnProfile
                          ? "You haven't published a course yet"
                          : 'No published courses yet',
                      subtitle: _isOwnProfile
                          ? 'Tap Create Course in the top bar to create your first course.'
                          : null,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ac.surf,
                      borderRadius: BorderRadius.circular(Rad.md),
                      border: Border.all(color: ac.bdr2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              initials: headerName.isEmpty ? '?' : headerName[0].toUpperCase(),
                              radius: 28,
                              photoUrl: photoUrl,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(headerName, style: AppText.h2),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      Text(
                                        '${courses.length} course${courses.length == 1 ? '' : 's'}',
                                        style: AppText.bodySm.copyWith(color: ac.txt2),
                                      ),
                                      Text('•', style: AppText.bodySm.copyWith(color: ac.muted)),
                                      StreamBuilder<int>(
                                        stream: FollowRepository.instance.watchFollowerCount(creatorId),
                                        builder: (context, s) => Text(
                                          '${s.data ?? 0} follower${(s.data ?? 0) == 1 ? '' : 's'}',
                                          style: AppText.bodySm.copyWith(color: ac.txt2),
                                        ),
                                      ),
                                      Text('•', style: AppText.bodySm.copyWith(color: ac.muted)),
                                      StreamBuilder<int>(
                                        stream: FollowRepository.instance.watchFollowingCount(creatorId),
                                        builder: (context, s) => Text(
                                          '${s.data ?? 0} following',
                                          style: AppText.bodySm.copyWith(color: ac.txt2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        StreamBuilder<AppUser?>(
                          stream: _watchCreatorUser(creatorId),
                          builder: (context, s) {
                            final u = s.data;
                            if (u == null || u.bio.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                u.bio,
                                style: AppText.bodySm.copyWith(height: 1.4, color: ac.txt),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isOwnProfile ? 'Your Curriculum Courses' : 'Published Courses',
                    style: AppText.title.copyWith(fontSize: 14, color: ac.txt),
                  ),
                  const SizedBox(height: 10),
                  ...courses.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ACard(
                          onTap: () {
                            if (c.published || _isOwnProfile) {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CourseLessonsPage(
                                  course: c,
                                  currentUser: effectiveUser,
                                ),
                              ));
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.title,
                                            style: AppText.title.copyWith(fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!c.published)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: StatusBadge(
                                              label: 'DRAFT',
                                              color: ac.org,
                                              bg: ac.orgBg,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.star_rounded, size: 13, color: ac.gold),
                                        const SizedBox(width: 2),
                                        Text(
                                          c.avgRating > 0 ? c.avgRating.toStringAsFixed(1) : '—',
                                          style: AppText.caption,
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(Icons.people_alt_outlined, size: 13, color: ac.muted),
                                        const SizedBox(width: 3),
                                        Text('${c.enrolledCount}', style: AppText.caption),
                                        if (c.category.isNotEmpty) ...[
                                          const SizedBox(width: 10),
                                          Text('•  ${c.category}', style: AppText.caption.copyWith(color: ac.txt2)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (_isOwnProfile && effectiveUser != null)
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, size: 18, color: ac.txt2),
                                  tooltip: 'Edit Course',
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => CourseComposerPage(
                                      user: effectiveUser,
                                      existing: c,
                                    ),
                                  )),
                                ),
                            ],
                          ),
                        ),
                      )),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _CreatorProfileRightPanel extends StatelessWidget {
  final String creatorId;
  final bool isOwnProfile;
  final int courseCount;
  final int publishedCount;
  final int draftCount;
  final AppUser? currentUser;

  const _CreatorProfileRightPanel({
    required this.creatorId,
    required this.isOwnProfile,
    required this.courseCount,
    required this.publishedCount,
    required this.draftCount,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 18, color: ac.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Curriculum Statistics',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatRow(label: 'Total Courses', value: '$courseCount'),
              const SizedBox(height: 8),
              _StatRow(label: 'Published', value: '$publishedCount'),
              if (isOwnProfile) ...[
                const SizedBox(height: 8),
                _StatRow(label: 'Drafts', value: '$draftCount'),
              ],
            ],
          ),
        ),
        if (isOwnProfile && currentUser != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_task_rounded, size: 18, color: ac.gold),
                    const SizedBox(width: 8),
                    Text(
                      'Creator Actions',
                      style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Create full video and rich text courses structured with levels, topics, and embedded quizzes.',
                  style: AppText.caption.copyWith(color: ac.txt2, height: 1.4),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryBtn(
                    label: 'Create Course',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CourseComposerPage(user: currentUser!),
                      ));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: ac.muted),
                  const SizedBox(width: 8),
                  Text(
                    'CFPMI Standards',
                    style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'All published courses are aligned with the national and school educational curriculum framework.',
                style: AppText.caption.copyWith(color: ac.txt2, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.bodySm.copyWith(color: ac.txt2)),
        Text(value, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, color: ac.txt)),
      ],
    );
  }
}

// lib/features/courses_marketplace/course_creator_profile_page.dart
// A course creator's published (and, on your own profile, draft) courses.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/follow_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
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

  bool get _isOwnProfile => currentUser?.id == creatorId;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(_isOwnProfile ? 'Your Courses' : 'Creator Profile', style: AppText.title),
      ),
      body: AppBackground(child: StreamBuilder<List<PublicCourse>>(
        stream: PublicCourseRepository.instance.watchByCreator(creatorId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            CrashService.instance.recordError(snap.error, snap.stackTrace,
                context: 'CourseCreatorProfilePage.watchByCreator($creatorId)');
            return ErrorView(message: "Couldn't load this profile — ${snap.error}");
          }
          var courses = snap.data ?? const <PublicCourse>[];
          if (!_isOwnProfile) courses = courses.where((c) => c.published).toList();
          if (courses.isEmpty) {
            return EmptyState(
              icon: Icons.school_outlined,
              title: _isOwnProfile ? "You haven't published a course yet" : 'No published courses yet',
              subtitle: _isOwnProfile ? 'Tap Create Course on the Courses tab to start.' : null,
            );
          }
          final headerName = courses.first.creatorName;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                UserAvatar(initials: headerName.isEmpty ? '?' : headerName[0].toUpperCase(),
                    radius: 26, photoUrl: courses.first.creatorPhotoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(headerName, style: AppText.h2),
                    Row(children: [
                      Text('${courses.length} course${courses.length == 1 ? '' : 's'}', style: AppText.bodySm),
                      Text('  ·  ', style: AppText.bodySm),
                      StreamBuilder<int>(
                        stream: FollowRepository.instance.watchFollowerCount(creatorId),
                        builder: (context, s) => Text(
                            '${s.data ?? 0} follower${(s.data ?? 0) == 1 ? '' : 's'}',
                            style: AppText.bodySm),
                      ),
                      Text('  ·  ', style: AppText.bodySm),
                      StreamBuilder<int>(
                        stream: FollowRepository.instance.watchFollowingCount(creatorId),
                        builder: (context, s) => Text(
                            '${s.data ?? 0} following', style: AppText.bodySm),
                      ),
                    ]),
                  ]),
                ),
              ]),
              StreamBuilder<AppUser?>(
                stream: _watchCreatorUser(creatorId),
                builder: (context, s) {
                  final u = s.data;
                  if (u == null || u.bio.isEmpty) {
                    return const SizedBox(height: 20);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    child: Text(u.bio, style: AppText.bodySm.copyWith(height: 1.4)),
                  );
                },
              ),
              ...courses.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ACard(
                  onTap: () {
                    if (c.published || _isOwnProfile) {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              CourseLessonsPage(course: c, currentUser: currentUser)));
                    }
                  },
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(c.title, style: AppText.title.copyWith(fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (!c.published)
                            Padding(padding: const EdgeInsets.only(left: 8),
                                child: StatusBadge(label: 'DRAFT', color: ac.org, bg: ac.orgBg)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.star_rounded, size: 13, color: ac.gold),
                          const SizedBox(width: 2),
                          Text(c.avgRating > 0 ? c.avgRating.toStringAsFixed(1) : '—', style: AppText.caption),
                          const SizedBox(width: 10),
                          Icon(Icons.people_alt_outlined, size: 13, color: ac.muted),
                          const SizedBox(width: 3),
                          Text('${c.enrolledCount}', style: AppText.caption),
                        ]),
                      ]),
                    ),
                    if (_isOwnProfile)
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 18, color: ac.txt2),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CourseComposerPage(user: currentUser!, existing: c))),
                      ),
                  ]),
                ),
              )),
            ],
          );
        },
      )),
    );
  }
}

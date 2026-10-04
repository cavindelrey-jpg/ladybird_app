// lib/features/courses_marketplace/lesson_reader_page.dart
// Where the user actually consumes content: video (or quill text) for one
// lesson, plus Overview/Resources/Notes/Comments tabs. Course-level actions
// (rating, like, bookmark, share, prerequisites, comments) live here rather
// than on a separate course page — a course itself has no content of its
// own anymore, only its lessons do.
//
// Video lessons stay gated Premium Gold-only for READERS, same rule the
// old course-level video had (core/feature_access.dart#AppFeature.
// coursesVideoLessons, the single place this gate is decided) — see
// _LockedVideoCard below, ported from course_reader_page.dart's
// _VideoLessonSection.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../../core/feature_access.dart';
import '../../models/app_user.dart';
import '../../models/course_lesson.dart';
import '../../models/entitlement.dart';
import '../../models/public_course.dart';
import '../../repositories/course_lesson_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/course_offline_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/formula_embed_builder.dart';
import '../../widgets/media_players.dart';
import '../../widgets/premium_unlock_sheet.dart';
import 'course_creator_profile_page.dart';

class LessonReaderPage extends StatefulWidget {
  final PublicCourse course;
  final CourseLesson lesson;
  final AppUser? currentUser;
  const LessonReaderPage({super.key, required this.course, required this.lesson, this.currentUser});

  @override
  State<LessonReaderPage> createState() => _LessonReaderPageState();
}

class _LessonReaderPageState extends State<LessonReaderPage> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 4, vsync: this);
  final _commentCtrl = TextEditingController();
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    CourseLessonRepository.instance.incrementView(widget.lesson.id);
    final user = widget.currentUser;
    if (user != null) {
      PublicCourseRepository.instance.markEnrolled(widget.course.id, user.id);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final user = widget.currentUser;
    final body = _commentCtrl.text.trim();
    if (user == null || body.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _postingComment = true);
    await PublicCourseRepository.instance.postComment(CourseComment(
      id: '', courseId: widget.course.id,
      authorId: user.id, authorName: user.name, authorPhotoUrl: user.photoUrl,
      body: body,
    ));
    _commentCtrl.clear();
    if (mounted) setState(() => _postingComment = false);
  }

  Future<void> _continue(BuildContext context) async {
    final adjacent = await CourseLessonRepository.instance.adjacentTo(widget.course.id, widget.lesson.id);
    if (!context.mounted) return;
    if (adjacent.next != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => LessonReaderPage(course: widget.course, lesson: adjacent.next!, currentUser: widget.currentUser)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final lesson = widget.lesson;
    final hasVideo = (lesson.videoUrl ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(lesson.title, style: AppText.title.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: AppBackground(child: Column(children: [
        if (hasVideo)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _LockedVideoCard(lesson: lesson, currentUser: widget.currentUser),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: ac.primary, unselectedLabelColor: ac.muted,
            indicatorColor: ac.primary,
            labelStyle: AppText.subtitle.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: AppText.subtitle.copyWith(fontSize: 13),
            tabs: const [
              Tab(text: 'Overview'), Tab(text: 'Resources'), Tab(text: 'Notes'), Tab(text: 'Comments'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
            _OverviewTab(course: widget.course, lesson: lesson, hasVideo: hasVideo, currentUser: widget.currentUser,
                onContinue: () => _continue(context)),
            const _EmptyTab(message: 'No resources have been added to this lesson yet.'),
            const _EmptyTab(message: 'Your personal notes for this lesson will appear here.'),
            _CommentsTab(
              course: widget.course, currentUser: widget.currentUser,
              commentCtrl: _commentCtrl, posting: _postingComment, onPost: _postComment,
            ),
          ]),
        ),
      ])),
    );
  }
}

/// Video lessons stay gated Premium Gold-only for readers — Silver and
/// Free/Guest both see the same locked card; only the CTA copy differs
/// (upgrade vs. sign in first). Ported from course_reader_page.dart's
/// _VideoLessonSection, now scoped per-lesson instead of per-course.
class _LockedVideoCard extends StatelessWidget {
  final CourseLesson lesson;
  final AppUser? currentUser;
  const _LockedVideoCard({required this.lesson, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final url = lesson.videoUrl!;
    if (FeatureAccess.canAccess(currentUser, AppFeature.coursesVideoLessons)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Rad.md),
        child: ArticleVideoPlayer(url: url),
      );
    }
    final signedIn = currentUser != null && !currentUser!.isGuest;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.goldBg,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.gold.withValues(alpha: .25)),
      ),
      child: Row(children: [
        Icon(Icons.lock_rounded, color: ac.gold, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Video Lesson — Premium Gold', style: AppText.title.copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Text(FeatureAccess.reasonBlocked(currentUser, AppFeature.coursesVideoLessons),
              style: AppText.caption.copyWith(fontSize: 11.5)),
        ])),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            if (!signedIn) {
              Navigator.of(context).pop();
              return;
            }
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: ac.surf,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
              builder: (_) => PremiumUnlockSheet(
                userId: currentUser!.id,
                initialTier: EntitlementTier.gold,
                onUnlockSuccess: () {},
              ),
            );
          },
          child: Text(signedIn ? 'Upgrade' : 'Sign in'),
        ),
      ]),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String message;
  const _EmptyTab({required this.message});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center, style: AppText.bodySm.copyWith(color: ac.txt2)),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final PublicCourse course;
  final CourseLesson lesson;
  final bool hasVideo;
  final AppUser? currentUser;
  final VoidCallback onContinue;
  const _OverviewTab({
    required this.course, required this.lesson, required this.hasVideo,
    required this.currentUser, required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (!hasVideo) ...[
          _LessonBody(lesson: lesson),
          const SizedBox(height: 20),
          Divider(color: AppColors.of(context).bdr2),
          const SizedBox(height: 16),
        ],
        Text('About this lesson', style: AppText.h2.copyWith(fontSize: 15)),
        const SizedBox(height: 6),
        Text(course.description.isNotEmpty ? course.description : 'No description provided.',
            style: AppText.bodySm.copyWith(fontSize: 13.5)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (lesson.durationSeconds != null && lesson.durationSeconds! > 0)
            _MetaPill(icon: Icons.schedule_rounded, label: 'Duration', value: _durationLabel(lesson.durationSeconds!)),
          if (course.level.isNotEmpty)
            _MetaPill(icon: Icons.school_outlined, label: 'Level', value: course.level),
          _MetaPill(icon: Icons.visibility_outlined, label: 'Viewers', value: '${lesson.viewCount}'),
          _MetaPill(icon: Icons.update_rounded, label: 'Last updated', value: _dateLabel(lesson.updatedAt)),
        ]),
        const SizedBox(height: 20),
        Divider(color: AppColors.of(context).bdr2),
        const SizedBox(height: 16),
        _CourseInfoRow(course: course, currentUser: currentUser),
        if (course.prerequisiteIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PrerequisitesLinks(course: course, currentUser: currentUser),
        ],
        const SizedBox(height: 20),
        _ActionRow(course: course, currentUser: currentUser),
        const SizedBox(height: 24),
        StreamBuilder<Set<String>>(
          stream: CourseOfflineService.instance.watchCompletedLessonIds(currentUser?.id ?? 'guest', course.id),
          builder: (context, cSnap) {
            final completed = cSnap.data?.contains(lesson.id) ?? false;
            final ac = AppColors.of(context);
            return OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: completed ? Colors.green : ac.primary,
                side: BorderSide(color: completed ? Colors.green : ac.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
              ),
              icon: Icon(completed ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                  color: completed ? Colors.green : ac.primary),
              label: Text(completed ? 'Lesson Completed' : 'Mark as Complete',
                  style: AppText.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: completed ? Colors.green : ac.primary)),
              onPressed: () async {
                HapticFeedback.lightImpact();
                final nowDone = await CourseOfflineService.instance.toggleLessonCompleted(
                  currentUser?.id ?? 'guest', course.id, lesson.id,
                );
                if (context.mounted) {
                  showToast(context, nowDone ? 'Lesson marked as completed!' : 'Lesson marked as incomplete.');
                }
              },
            );
          },
        ),
        const SizedBox(height: 12),
        PrimaryBtn(label: 'Continue Lesson', onTap: onContinue),
      ],
    );
  }

  static String _durationLabel(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _dateLabel(DateTime d) => '${_month(d.month)} ${d.day}, ${d.year}';
  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

class _LessonBody extends StatelessWidget {
  final CourseLesson lesson;
  const _LessonBody({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final deltaJson = lesson.bodyDelta;
    if (deltaJson == null || deltaJson.isEmpty) {
      return Text(lesson.body, style: AppText.body);
    }
    quill.QuillController controller;
    try {
      final doc = quill.Document.fromJson(jsonDecode(deltaJson));
      controller = quill.QuillController(
        document: doc, selection: const TextSelection.collapsed(offset: 0), readOnly: true,
      );
    } catch (_) {
      return Text(lesson.body, style: AppText.body);
    }
    return quill.QuillEditor.basic(
      controller: controller,
      config: quill.QuillEditorConfig(
        showCursor: false, autoFocus: false, placeholder: 'Lesson content…',
        embedBuilders: [...FlutterQuillEmbeds.editorBuilders(), const FormulaEmbedBuilder()],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: ac.muted),
          const SizedBox(width: 4),
          Text(label, style: AppText.caption.copyWith(fontSize: 10)),
        ]),
        const SizedBox(height: 2),
        Text(value, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5)),
      ]),
    );
  }
}

class _CourseInfoRow extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _CourseInfoRow({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<PublicCourse?>(
      stream: PublicCourseRepository.instance.watchOne(course.id),
      initialData: course,
      builder: (context, snap) {
        final c = snap.data ?? course;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.sm),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourseCreatorProfilePage(creatorId: c.creatorId, currentUser: currentUser))),
              child: Row(children: [
                UserAvatar(initials: c.creatorName.isEmpty ? '?' : c.creatorName[0].toUpperCase(),
                    radius: 16, photoUrl: c.creatorPhotoUrl),
                const SizedBox(width: 10),
                Text(c.creatorName, style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 13)),
                const Spacer(),
                Icon(Icons.people_alt_outlined, size: 14, color: ac.muted),
                const SizedBox(width: 4),
                Text('${c.enrolledCount} learners', style: AppText.caption),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Row(children: List.generate(5, (i) => Icon(
              i < c.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18, color: ac.gold,
            ))),
            const SizedBox(width: 8),
            Text(c.avgRating > 0 ? c.avgRating.toStringAsFixed(1) : 'No ratings yet',
                style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 13)),
            if (c.ratingCount > 0) Text(' (${c.ratingCount})', style: AppText.caption),
            const Spacer(),
            if (currentUser != null && currentUser!.id != c.creatorId)
              TextButton(
                onPressed: () => _showRateSheet(context, c),
                child: Text('Rate this course', style: AppText.caption.copyWith(
                    fontSize: 12, fontWeight: FontWeight.w700, color: ac.primary)),
              ),
          ]),
        ]);
      },
    );
  }

  void _showRateSheet(BuildContext context, PublicCourse course) {
    final ac = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (dCtx, setM) {
        int selected = 5;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Rate this course', style: AppText.title.copyWith(fontSize: 16)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
                IconButton(
                  icon: Icon(i < selected ? Icons.star_rounded : Icons.star_outline_rounded, size: 32, color: ac.gold),
                  onPressed: () => setM(() => selected = i + 1),
                ),
            )),
            const SizedBox(height: 12),
            PrimaryBtn(label: 'Submit Rating', onTap: () {
              HapticFeedback.mediumImpact();
              PublicCourseRepository.instance.rate(course.id, currentUser!.id, selected);
              Navigator.pop(dCtx);
            }),
          ]),
        );
      }),
    );
  }
}

class _PrerequisitesLinks extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _PrerequisitesLinks({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return FutureBuilder<List<PublicCourse>>(
      future: Future.wait(course.prerequisiteIds.map(
          (id) => PublicCourseRepository.instance.watchOne(id).first)).then(
              (list) => list.whereType<PublicCourse>().toList()),
      builder: (context, snap) {
        final prereqs = snap.data ?? const <PublicCourse>[];
        if (prereqs.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.sm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Read first', style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: ac.primary)),
            const SizedBox(height: 4),
            ...prereqs.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${p.title}', style: AppText.caption.copyWith(fontSize: 12, color: ac.primary)),
            )),
          ]),
        );
      },
    );
  }
}

class _ActionRow extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _ActionRow({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final u = currentUser;
    final repo = PublicCourseRepository.instance;
    return Row(children: [
      if (u == null)
        Text('Sign in to like or save this course.', style: AppText.bodySm.copyWith(color: ac.txt2))
      else ...[
        StreamBuilder<bool>(
          stream: repo.watchIsLiked(course.id, u.id),
          builder: (context, snap) {
            final liked = snap.data ?? false;
            return _ActionChip(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? ac.red : ac.txt2,
              label: '${course.likeCount}',
              onTap: () { HapticFeedback.selectionClick(); repo.toggleLike(course.id, u.id); },
            );
          },
        ),
        const SizedBox(width: 18),
        StreamBuilder<bool>(
          stream: repo.watchIsBookmarked(course.id, u.id),
          builder: (context, snap) {
            final saved = snap.data ?? false;
            return _ActionChip(
              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved ? ac.gold : ac.txt2,
              label: saved ? 'Saved' : 'Save',
              onTap: () { HapticFeedback.selectionClick(); repo.toggleBookmark(course.id, u.id); },
            );
          },
        ),
      ],
      const Spacer(),
      _ActionChip(
        icon: Icons.share_outlined, color: ac.txt2, label: 'Share',
        onTap: () {
          HapticFeedback.selectionClick();
          Share.share('${course.title}\n\nRead it on Academia.');
        },
      ),
    ]);
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppText.bodySm.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _CommentsTab extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  final TextEditingController commentCtrl;
  final bool posting;
  final VoidCallback onPost;
  const _CommentsTab({
    required this.course, required this.currentUser,
    required this.commentCtrl, required this.posting, required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (currentUser != null)
          Row(children: [
            Expanded(
              child: TextField(
                controller: commentCtrl,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  filled: true, fillColor: ac.surf3,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            posting
                ? const SizedBox(width: 40, height: 40,
                    child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
                : IconButton(icon: Icon(Icons.send_rounded, color: ac.primary), onPressed: onPost),
          ])
        else
          Text('Sign in to join the discussion.', style: AppText.bodySm.copyWith(color: ac.txt2)),
        const SizedBox(height: 16),
        StreamBuilder<List<CourseComment>>(
          stream: PublicCourseRepository.instance.watchComments(course.id),
          builder: (context, cSnap) {
            final comments = cSnap.data ?? const <CourseComment>[];
            if (comments.isEmpty) {
              return Text('No comments yet — start the discussion.', style: AppText.bodySm.copyWith(color: ac.txt2));
            }
            return Column(children: comments.map((cm) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                UserAvatar(initials: cm.authorName.isEmpty ? '?' : cm.authorName[0].toUpperCase(),
                    radius: 14, photoUrl: cm.authorPhotoUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cm.authorName, style: AppText.subtitle.copyWith(color: ac.txt)),
                    const SizedBox(height: 3),
                    Text(cm.body, style: AppText.bodySm.copyWith(height: 1.4)),
                  ]),
                ),
              ]),
            )).toList());
          },
        ),
      ],
    );
  }
}

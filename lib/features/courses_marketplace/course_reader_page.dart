// lib/features/courses_marketplace/course_reader_page.dart
// Read a course: cover, category, creator, interactive star rating,
// enrollment tracked once per view, body content, comments.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/branding.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'dart:convert';
import '../../core/feature_access.dart';
import '../../models/app_user.dart';
import '../../models/entitlement.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/formula_embed_builder.dart';
import '../../widgets/media_players.dart';
import '../../widgets/premium_unlock_sheet.dart';
import 'course_creator_profile_page.dart';
import 'course_composer_page.dart';
import 'course_browse_page.dart';

class CourseReaderPage extends StatefulWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const CourseReaderPage({super.key, required this.course, this.currentUser});

  @override
  State<CourseReaderPage> createState() => _CourseReaderPageState();
}

class _CourseReaderPageState extends State<CourseReaderPage> {
  final _commentCtrl = TextEditingController();
  bool _postingComment = false;
  bool _enrollTracked = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentUser != null && !_enrollTracked) {
      _enrollTracked = true;
      PublicCourseRepository.instance.markEnrolled(widget.course.id, widget.currentUser!.id);
    }
  }

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  bool get _isOwn => widget.currentUser?.id == widget.course.creatorId;

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

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final c = widget.course;
    return Scaffold(
      backgroundColor: ac.bg,
      body: AppBackground(child: StreamBuilder<PublicCourse?>(
        stream: PublicCourseRepository.instance.watchOne(c.id),
        initialData: c,
        builder: (context, snap) {
          final course = snap.data ?? c;
          return CustomScrollView(slivers: [
            SliverAppBar(
              backgroundColor: ac.bg, elevation: 0, pinned: true,
              iconTheme: IconThemeData(color: ac.txt),
              actions: [
                if (_isOwn)
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: ac.txt),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CourseComposerPage(user: widget.currentUser!, existing: course))),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if ((course.coverImageUrl ?? '').isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Rad.md),
                      child: Image.network(course.coverImageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 16),
                  if (course.hasCurriculumPlacement) ...[
                    _Breadcrumb(course: course, currentUser: widget.currentUser),
                    const SizedBox(height: 10),
                  ],
                  Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StatusBadge(label: course.category, color: ac.primary),
                    if (course.difficulty.isNotEmpty)
                      StatusBadge(label: course.difficulty, color: ac.txt2, bg: ac.surf2),
                    StatusBadge(label: _readingTimeLabel(course), color: ac.txt2, bg: ac.surf2),
                  ]),
                  if (course.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: course.tags
                        .map((t) => StatusBadge(label: t, color: ac.gold, bg: ac.goldBg))
                        .toList()),
                  ],
                  const SizedBox(height: 12),
                  Text(course.title, style: AppText.h1),
                  const SizedBox(height: 8),
                  Text(course.description, style: AppText.bodySm.copyWith(fontSize: 13.5)),
                  if (course.prerequisiteIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PrerequisitesLinks(course: course, currentUser: widget.currentUser),
                  ],
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Rad.sm),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CourseCreatorProfilePage(
                                creatorId: course.creatorId, currentUser: widget.currentUser)));
                      },
                      child: Row(children: [
                        UserAvatar(initials: course.creatorName.isEmpty ? '?' : course.creatorName[0].toUpperCase(),
                            radius: 16, photoUrl: course.creatorPhotoUrl),
                        const SizedBox(width: 10),
                        Text(course.creatorName, style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 13)),
                        const Spacer(),
                        Icon(Icons.people_alt_outlined, size: 14, color: ac.muted),
                        const SizedBox(width: 4),
                        Text('${course.enrolledCount} learners', style: AppText.caption),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RatingRow(course: course, currentUser: widget.currentUser),
                  const SizedBox(height: 20),
                  Divider(color: ac.bdr2),
                  const SizedBox(height: 20),
                  if ((course.videoUrl ?? '').isNotEmpty) ...[
                    _VideoLessonSection(course: course, currentUser: widget.currentUser),
                    const SizedBox(height: 20),
                  ],
                  _CourseBody(course: course),
                  const SizedBox(height: 24),
                  _CourseActionRow(course: course, currentUser: widget.currentUser),
                  if (course.hasCurriculumPlacement) ...[
                    const SizedBox(height: 24),
                    _ContinueReadingSection(course: course, currentUser: widget.currentUser),
                  ],
                  const SizedBox(height: 24),
                  Divider(color: ac.bdr2),
                  const SizedBox(height: 16),
                  Text('Comments (${course.commentCount})', style: AppText.h2.copyWith(fontSize: 15)),
                  const SizedBox(height: 14),
                  if (widget.currentUser != null)
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          style: AppText.bodySm.copyWith(color: ac.txt),
                          decoration: InputDecoration(
                            hintText: 'Add a comment…',
                            filled: true, fillColor: ac.surf3,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _postingComment
                          ? const SizedBox(width: 40, height: 40,
                          child: Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))))
                          : IconButton(icon: Icon(Icons.send_rounded, color: ac.primary), onPressed: _postComment),
                    ])
                  else
                    Text('Sign in to join the discussion.', style: AppText.bodySm),
                  const SizedBox(height: 16),
                  StreamBuilder<List<CourseComment>>(
                    stream: PublicCourseRepository.instance.watchComments(course.id),
                    builder: (context, cSnap) {
                      final comments = cSnap.data ?? const <CourseComment>[];
                      if (comments.isEmpty) {
                        return Text('No comments yet — start the discussion.', style: AppText.bodySm);
                      }
                      return Column(children: comments.map((cm) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CourseCreatorProfilePage(
                                    creatorId: cm.authorId, currentUser: widget.currentUser))),
                            child: UserAvatar(initials: cm.authorName.isEmpty ? '?' : cm.authorName[0].toUpperCase(),
                                radius: 14, photoUrl: cm.authorPhotoUrl),
                          ),
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
                ]),
              ),
            ),
          ]);
        },
      ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _RatingRow({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(children: [
      Row(children: List.generate(5, (i) => Icon(
        i < course.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 20, color: ac.gold,
      ))),
      const SizedBox(width: 8),
      Text(course.avgRating > 0 ? course.avgRating.toStringAsFixed(1) : 'No ratings yet',
          style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 13)),
      if (course.ratingCount > 0)
        Text(' (${course.ratingCount})', style: AppText.caption),
      const Spacer(),
      if (currentUser != null && currentUser!.id != course.creatorId)
        TextButton(
          onPressed: () => _showRateSheet(context),
          child: Text('Rate this', style: AppText.caption.copyWith(
              fontSize: 12, fontWeight: FontWeight.w700, color: ac.primary)),
        ),
    ]);
  }

  void _showRateSheet(BuildContext context) {
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
                  icon: Icon(i < selected ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 32, color: ac.gold),
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

/// The Video Course itself — locked behind Premium Gold (see
/// core/feature_access.dart#AppFeature.coursesVideoLessons, the single
/// place this gate is decided). Silver and Free/Guest both see the same
/// locked card; only the CTA copy differs (upgrade vs. sign in first).
class _VideoLessonSection extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _VideoLessonSection({required this.course, this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final url = course.videoUrl!;
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
          child: Text(signedIn ? 'Upgrade' : 'Sign in',
              style: AppText.subtitle.copyWith(fontSize: 12, color: ac.navy, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _CourseBody extends StatelessWidget {
  final PublicCourse course;
  const _CourseBody({required this.course});

  @override
  Widget build(BuildContext context) {
    final deltaJson = course.bodyDelta;
    if (deltaJson == null || deltaJson.isEmpty) {
      return Text(course.body, style: AppText.body);
    }
    quill.QuillController controller;
    try {
      final doc = quill.Document.fromJson(jsonDecode(deltaJson));
      controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      return Text(course.body, style: AppText.body);
    }

    return quill.QuillEditor.basic(
      controller: controller,
      config: quill.QuillEditorConfig(
        showCursor: false,
        autoFocus: false,
        placeholder: 'Course content…',
        // Formula builder added on top of the stock image/video embeds so
        // course LaTeX (Academia_Course_Generation_Rules.md Rule 1) renders
        // as real math instead of the Quill default "unknown embed" box.
        embedBuilders: [...FlutterQuillEmbeds.editorBuilders(), const FormulaEmbedBuilder()],
      ),
    );
  }
}
// ── Like / Bookmark / Share ─────────────────────────────────
// Same story as Magazine: toggleLike/toggleBookmark already existed in
// PublicCourseRepository but nothing in this reader ever called them.
class _CourseActionRow extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _CourseActionRow({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final u = currentUser;
    final repo = PublicCourseRepository.instance;
    return Row(children: [
      if (u == null)
        Text('Sign in to like or save this course.', style: AppText.bodySm)
      else ...[
        StreamBuilder<bool>(
          stream: repo.watchIsLiked(course.id, u.id),
          builder: (context, snap) {
            final liked = snap.data ?? false;
            return _CourseActionChip(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? ac.red : ac.txt2,
              label: '${course.likeCount}',
              onTap: () {
                HapticFeedback.selectionClick();
                repo.toggleLike(course.id, u.id);
              },
            );
          },
        ),
        const SizedBox(width: 18),
        StreamBuilder<bool>(
          stream: repo.watchIsBookmarked(course.id, u.id),
          builder: (context, snap) {
            final saved = snap.data ?? false;
            return _CourseActionChip(
              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved ? ac.gold : ac.txt2,
              label: saved ? 'Saved' : 'Save',
              onTap: () {
                HapticFeedback.selectionClick();
                repo.toggleBookmark(course.id, u.id);
              },
            );
          },
        ),
      ],
      const Spacer(),
      _CourseActionChip(
        icon: Icons.share_outlined, color: ac.txt2, label: 'Share',
        onTap: () {
          HapticFeedback.selectionClick();
          Share.share('${course.title}\n\nRead it on ${Branding.current.appName}.');
        },
      ),
    ]);
  }
}

class _CourseActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _CourseActionChip({required this.icon, required this.color, required this.label, required this.onTap});

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

// ── Breadcrumb — Category → Subject → Level → Topic ─────────────
// Only shown once a course has curriculum placement; the last segment
// (the topic) opens the browse page focused on this lesson's siblings,
// giving discovery-by-navigation as an alternative to search.
String _readingTimeLabel(PublicCourse course) {
  final words = course.body.trim().isEmpty ? 0 : course.body.trim().split(RegExp(r'\s+')).length;
  final minutes = (words / 200).ceil().clamp(1, 999);
  return '$minutes min read';
}

class _Breadcrumb extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _Breadcrumb({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    // Academic Section > Subject > Topic — matches CourseBrowsePage's own
    // tree order (see that file for why `category`, the Mathematics/
    // Science/... domain tag, is no longer a hierarchy tier here).
    final segments = [course.level, course.subject, course.topic];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.sm),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CourseBrowsePage(
                section: course.level,
                currentUser: currentUser,
                initialSubject: course.subject,
                initialTopic: course.topic))),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 14, color: ac.muted),
              ),
              Text(segments[i], style: AppText.caption.copyWith(
                  fontSize: 11.5, fontWeight: FontWeight.w600,
                  color: i == segments.length - 1 ? ac.primary : ac.txt2)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Read these first" — advisory links to lessons this one depends on.
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
            ...prereqs.map((p) => Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CourseReaderPage(course: p, currentUser: currentUser))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• ${p.title}', style: AppText.caption.copyWith(fontSize: 12, color: ac.primary)),
                ),
              ),
            )),
          ]),
        );
      },
    );
  }
}

/// Previous/next lesson in the same topic, plus a "more in this topic"
/// rail — computed from the topic's ordered sequence, not hardcoded.
class _ContinueReadingSection extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _ContinueReadingSection({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return FutureBuilder<CourseSequenceContext>(
      future: PublicCourseRepository.instance.continueReadingFor(course),
      builder: (context, snap) {
        final ctx = snap.data;
        if (ctx == null) return const SizedBox.shrink();
        final others = ctx.topicLessons.where((c) => c.id != course.id).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ctx.previous != null || ctx.next != null)
            Row(children: [
              if (ctx.previous != null)
                Expanded(child: _SequenceNavCard(
                    label: 'Previous', course: ctx.previous!, currentUser: currentUser, alignEnd: false)),
              if (ctx.previous != null && ctx.next != null) const SizedBox(width: 10),
              if (ctx.next != null)
                Expanded(child: _SequenceNavCard(
                    label: 'Next', course: ctx.next!, currentUser: currentUser, alignEnd: true)),
            ]),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('More in "${course.topic}"', style: AppText.h2.copyWith(fontSize: 14)),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: others.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final o = others[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CourseReaderPage(course: o, currentUser: currentUser))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: ac.surf2, borderRadius: BorderRadius.circular(20), border: Border.all(color: ac.bdr)),
                        child: Text(o.title, style: AppText.caption.copyWith(fontSize: 12, color: ac.txt2)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ]);
      },
    );
  }
}

class _SequenceNavCard extends StatelessWidget {
  final String label;
  final PublicCourse course;
  final AppUser? currentUser;
  final bool alignEnd;
  const _SequenceNavCard({required this.label, required this.course, required this.currentUser, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.sm),
        onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => CourseReaderPage(course: course, currentUser: currentUser))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr2)),
          child: Column(
            crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (!alignEnd) Icon(Icons.chevron_left_rounded, size: 14, color: ac.muted),
                Text(label, style: AppText.caption.copyWith(fontSize: 10.5, color: ac.muted)),
                if (alignEnd) Icon(Icons.chevron_right_rounded, size: 14, color: ac.muted),
              ]),
              const SizedBox(height: 2),
              Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                  style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

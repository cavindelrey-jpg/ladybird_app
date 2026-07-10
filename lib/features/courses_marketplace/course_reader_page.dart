// lib/features/courses_marketplace/course_reader_page.dart
// Read a course: cover, category, creator, interactive star rating,
// enrollment tracked once per view, body content, comments.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'dart:convert';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'course_creator_profile_page.dart';
import 'course_composer_page.dart';

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
    final c = widget.course;
    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<PublicCourse?>(
        stream: PublicCourseRepository.instance.watchOne(c.id),
        initialData: c,
        builder: (context, snap) {
          final course = snap.data ?? c;
          return CustomScrollView(slivers: [
            SliverAppBar(
              backgroundColor: C.bg, elevation: 0, pinned: true,
              iconTheme: const IconThemeData(color: C.txt),
              actions: [
                if (_isOwn)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: C.txt),
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
                  StatusBadge(label: course.category, color: C.primary),
                  const SizedBox(height: 12),
                  Text(course.title, style: AppText.h1),
                  const SizedBox(height: 8),
                  Text(course.description, style: AppText.bodySm.copyWith(fontSize: 13.5)),
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
                        Text(course.creatorName, style: AppText.subtitle.copyWith(color: C.txt, fontSize: 13)),
                        const Spacer(),
                        const Icon(Icons.people_alt_outlined, size: 14, color: C.muted),
                        const SizedBox(width: 4),
                        Text('${course.enrolledCount} learners', style: AppText.caption),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RatingRow(course: course, currentUser: widget.currentUser),
                  const SizedBox(height: 20),
                  const Divider(color: C.bdr2),
                  const SizedBox(height: 20),
                  _CourseBody(course: course),
                  const SizedBox(height: 32),
                  const Divider(color: C.bdr2),
                  const SizedBox(height: 16),
                  Text('Comments (${course.commentCount})', style: AppText.h2.copyWith(fontSize: 15)),
                  const SizedBox(height: 14),
                  if (widget.currentUser != null)
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          style: AppText.bodySm.copyWith(color: C.txt),
                          decoration: InputDecoration(
                            hintText: 'Add a comment…',
                            filled: true, fillColor: C.surf3,
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
                          : IconButton(icon: const Icon(Icons.send_rounded, color: C.primary), onPressed: _postComment),
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
                          UserAvatar(initials: cm.authorName.isEmpty ? '?' : cm.authorName[0].toUpperCase(),
                              radius: 14, photoUrl: cm.authorPhotoUrl),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(cm.authorName, style: AppText.subtitle.copyWith(color: C.txt)),
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
    );
  }
}

class _RatingRow extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _RatingRow({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Row(children: List.generate(5, (i) => Icon(
        i < course.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 20, color: C.gold,
      ))),
      const SizedBox(width: 8),
      Text(course.avgRating > 0 ? course.avgRating.toStringAsFixed(1) : 'No ratings yet',
          style: AppText.subtitle.copyWith(color: C.txt, fontSize: 13)),
      if (course.ratingCount > 0)
        Text(' (${course.ratingCount})', style: AppText.caption),
      const Spacer(),
      if (currentUser != null && currentUser!.id != course.creatorId)
        TextButton(
          onPressed: () => _showRateSheet(context),
          child: Text('Rate this', style: AppText.caption.copyWith(
              fontSize: 12, fontWeight: FontWeight.w700, color: C.primary)),
        ),
    ]);
  }

  void _showRateSheet(BuildContext context) {
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
                      size: 32, color: C.gold),
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
      controller = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
    } catch (_) {
      return Text(course.body, style: AppText.body);
    }

    return quill.QuillEditor.basic(
      controller: controller,
      config: quill.QuillEditorConfig(
        readOnly: true,
        showCursor: false,
        autoFocus: false,
        placeholder: 'Course content…',
        embedBuilders: FlutterQuillEmbeds.editorBuilders(),
      ),
    );
  }
}
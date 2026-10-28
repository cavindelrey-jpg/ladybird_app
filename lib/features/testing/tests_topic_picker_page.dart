// lib/features/testing/tests_topic_picker_page.dart
// Third tier of the Testing & Quiz browse tree (Category > Subject >
// Topic > Test) — e.g. High School > History > "The French Revolution".
// Each tile shows the real number of published tests for that topic and,
// once set, a real photo instead of the generated letter-avatar (see
// HierarchyAvatar). Tapping a tile opens TestsListPage, which lists the
// actual quizzes inside it.

import 'package:flutter/material.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart' show CurriculumIcon;
import '../../repositories/test_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'quiz_icon_editor.dart';
import 'tests_list_page.dart';

class TestsTopicPickerPage extends StatefulWidget {
  final AppUser user;
  final String category;
  final String subject;
  const TestsTopicPickerPage({
    super.key, required this.user, required this.category, required this.subject,
  });

  @override
  State<TestsTopicPickerPage> createState() => _TestsTopicPickerPageState();
}

class _TestsTopicPickerPageState extends State<TestsTopicPickerPage> {
  AppColors get ac => AppColors.of(context);

  bool get _canManage => widget.user.canUploadContent;

  Map<String, int> _counts = {};
  Map<String, CurriculumIcon> _icons = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      TestRepository.instance.topicTestCountsOnce(category: widget.category, subject: widget.subject),
      TestRepository.instance.quizNodeIconsOnce(),
    ]);
    if (!mounted) return;
    setState(() {
      _counts = results[0] as Map<String, int>;
      _icons = results[1] as Map<String, CurriculumIcon>;
      _loading = false;
    });
  }

  CurriculumIcon _iconFor(String topic) =>
      _icons[TestRepository.quizTopicIconKey(widget.category, widget.subject, topic)] ?? CurriculumIcon.none;

  Future<void> _editTopicLook(String topic) async {
    final current = _iconFor(topic);
    final key = TestRepository.quizTopicIconKey(widget.category, widget.subject, topic);
    await showQuizIconEditor(
      context,
      label: topic,
      currentEmoji: current.emoji,
      currentImageUrl: current.imageUrl,
      onSave: (emoji, image) async {
        // Was unconditionally blank -- a failed upload silently wiped
        // whatever image was already set instead of leaving it alone.
        String imageUrl = current.imageUrl;
        if (image != null) {
          final upload = await TestRepository.instance.uploadQuizNodeImage(key: key, imageFile: image);
          switch (upload) {
            case Success(:final value): imageUrl = value;
            case Failure(:final message): throw Exception(message);
          }
        } else {
          imageUrl = '';
        }
        final result = await TestRepository.instance.setQuizNodeIcon(key, emoji: emoji, imageUrl: imageUrl);
        if (result case Failure(:final message)) throw Exception(message);
      },
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(title: Text(widget.subject, style: AppText.h2)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _counts.isEmpty
              ? EmptyState(
                  icon: Icons.topic_outlined,
                  title: 'No topics here yet',
                  subtitle: 'Check back once a quiz is published for this subject.',
                  actionLabel: 'Refresh',
                  onAction: () => _load(),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _counts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.92,
                    ),
                    itemBuilder: (context, i) {
                      final topic = (_counts.keys.toList()..sort())[i];
                      final count = _counts[topic] ?? 0;
                      final icon = _iconFor(topic);
                      return Material(
                        color: ac.surf,
                        borderRadius: BorderRadius.circular(Rad.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Rad.md),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => TestsListPage(
                                  user: widget.user, category: widget.category, subject: widget.subject, topic: topic))),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
                            child: Stack(children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                HierarchyAvatar(label: topic, icon: icon.emoji, imageUrl: icon.imageUrl, size: 48),
                                const Spacer(),
                                Text(topic, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('$count quiz${count == 1 ? '' : 'zes'}', style: AppText.caption.copyWith(color: ac.txt2)),
                              ]),
                              if (_canManage)
                                Positioned(
                                  top: 0, right: 0,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _editTopicLook(topic),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: ac.surf2, shape: BoxShape.circle, border: Border.all(color: ac.bdr2)),
                                      child: Icon(Icons.edit_rounded, size: 14, color: ac.txt2),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

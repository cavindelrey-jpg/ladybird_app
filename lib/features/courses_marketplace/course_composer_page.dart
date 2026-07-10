// lib/features/courses_marketplace/course_composer_page.dart
// Create/edit a marketplace course: cover, category, title, description,
// body content. Any signed-in user can publish — matches the "anyone can
// contribute" vision, separate entirely from school-scoped Course
// creation (which stays admin-only in features/courses/).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class CourseComposerPage extends StatefulWidget {
  final AppUser user;
  final PublicCourse? existing;
  const CourseComposerPage({super.key, required this.user, this.existing});

  @override
  State<CourseComposerPage> createState() => _CourseComposerPageState();
}

class _CourseComposerPageState extends State<CourseComposerPage> {
  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
  late String _category = widget.existing?.category ?? kCourseCategories.first;
  File? _pickedCover;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    HapticFeedback.selectionClick();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedCover = File(picked.path));
  }

  Future<void> _save({required bool publish}) async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title and body are required.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _saving = true; _error = null; });

    final repo = PublicCourseRepository.instance;
    var course = widget.existing ?? PublicCourse(
      id: '', creatorId: widget.user.id, creatorName: widget.user.name,
      creatorPhotoUrl: widget.user.photoUrl, title: '',
    );
    course.title = _titleCtrl.text.trim();
    course.description = _descCtrl.text.trim();
    course.body = _bodyCtrl.text.trim();
    course.category = _category;
    course.published = publish;

    if (_isNew) {
      final result = await repo.create(course);
      if (result is Failure<String>) {
        setState(() { _error = result.message; _saving = false; });
        return;
      }
      course = PublicCourse(
        id: (result as Success<String>).value,
        creatorId: course.creatorId, creatorName: course.creatorName,
        creatorPhotoUrl: course.creatorPhotoUrl,
        title: course.title, description: course.description, body: course.body,
        category: course.category, published: course.published,
      );
    }

    if (_pickedCover != null) {
      final upload = await repo.uploadCover(courseId: course.id, imageFile: _pickedCover!);
      if (upload is Success<String>) course.coverImageUrl = upload.value;
    }

    final saveResult = await repo.update(course);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saveResult is Failure) {
      setState(() => _error = (saveResult).message);
      return;
    }
    showToast(context, publish ? 'Course published.' : 'Draft saved.');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete course?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: C.red))),
        ],
      ),
    );
    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      await PublicCourseRepository.instance.delete(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text(_isNew ? 'Create Course' : 'Edit Course', style: AppText.title),
        actions: [
          if (!_isNew)
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: C.red), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Rad.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.md),
              onTap: _pickCover,
              child: Container(
                height: 140, width: double.infinity,
                decoration: BoxDecoration(
                  color: C.navy, borderRadius: BorderRadius.circular(Rad.md),
                  image: _pickedCover != null
                      ? DecorationImage(image: FileImage(_pickedCover!), fit: BoxFit.cover)
                      : (widget.existing?.coverImageUrl != null
                          ? DecorationImage(image: NetworkImage(widget.existing!.coverImageUrl!), fit: BoxFit.cover)
                          : null),
                ),
                child: (_pickedCover == null && widget.existing?.coverImageUrl == null)
                    ? const Center(child: Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 32))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kCourseCategories.map((cat) {
              final active = cat == _category;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _category = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? C.primary : C.surf2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? C.primary : C.bdr),
                    ),
                    child: Text(cat, style: AppText.caption.copyWith(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: active ? Colors.white : C.txt2)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl, style: AppText.h1,
            decoration: const InputDecoration(hintText: 'Course title', border: InputBorder.none),
          ),
          const Divider(color: C.bdr2),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl, style: AppText.bodySm.copyWith(color: C.txt),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Short description (shown on cards)…', border: InputBorder.none),
          ),
          const SizedBox(height: 12),
          const Divider(color: C.bdr2),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl, style: AppText.body,
            maxLines: null, minLines: 12,
            decoration: const InputDecoration(hintText: 'Course content…', border: InputBorder.none),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Text(_error!, style: AppText.bodySm.copyWith(color: C.red)),
            ),
          ],
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: SecondaryBtn(label: 'Save Draft',
                onTap: _saving ? () {} : () => _save(publish: false))),
            const SizedBox(width: 12),
            Expanded(child: PrimaryBtn(label: 'Publish', loading: _saving,
                onTap: () => _save(publish: true))),
          ]),
        ],
      ),
    );
  }
}

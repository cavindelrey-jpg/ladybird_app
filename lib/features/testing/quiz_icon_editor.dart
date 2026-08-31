// lib/features/testing/quiz_icon_editor.dart
// Shared "change this tile's look" bottom sheet — used by every tier of
// the Quiz browse tree (QuizCategoriesPage, TestsSubjectPickerPage,
// TestsTopicPickerPage) so a Category/Subject/Topic tile's image/emoji
// can be set or changed AFTER creation, not just chosen once while
// authoring a test. Mirrors HierarchyPicker's emoji palette (widgets.dart)
// but as an edit affordance on an EXISTING node rather than a picker for
// a brand-new one.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Opens the editor sheet. [currentEmoji]/[currentImageUrl] pre-select
/// what's already set (if anything); [onSave] receives the final choice
/// — both empty means "cleared back to the letter-avatar fallback".
Future<void> showQuizIconEditor(
  BuildContext context, {
  required String label,
  required String currentEmoji,
  required String currentImageUrl,
  required Future<void> Function(String emoji, File? image) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _QuizIconEditorSheet(
      label: label,
      currentEmoji: currentEmoji,
      currentImageUrl: currentImageUrl,
      onSave: onSave,
    ),
  );
}

class _QuizIconEditorSheet extends StatefulWidget {
  final String label;
  final String currentEmoji;
  final String currentImageUrl;
  final Future<void> Function(String emoji, File? image) onSave;
  const _QuizIconEditorSheet({
    required this.label,
    required this.currentEmoji,
    required this.currentImageUrl,
    required this.onSave,
  });

  @override
  State<_QuizIconEditorSheet> createState() => _QuizIconEditorSheetState();
}

class _QuizIconEditorSheetState extends State<_QuizIconEditorSheet> {
  late String _emoji = widget.currentEmoji;
  File? _image;
  bool _saving = false;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _emoji = ''; // photo and emoji are mutually exclusive, same as HierarchyPicker
    });
  }

  Future<void> _clear() async {
    setState(() { _emoji = ''; _image = null; _saving = true; });
    try {
      await widget.onSave('', null);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, 'Could not clear: $e', isError: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Every onSave callback now throws on a failed upload/write (rather
    // than silently doing nothing, which is the real bug this used to
    // have) -- this is the one place that catches it and tells the user
    // instead of leaving the Save button spinning forever with no
    // explanation, which is indistinguishable from "the button just
    // doesn't work".
    try {
      await widget.onSave(_emoji, _image);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, 'Could not save: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hasImage = _image != null || (_emoji.isEmpty && widget.currentImageUrl.isNotEmpty);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Change look for "${widget.label}"', style: AppText.title),
          const SizedBox(height: 16),
          Center(
            child: HierarchyAvatar(
              label: widget.label,
              icon: _emoji,
              imageUrl: hasImage ? widget.currentImageUrl : '',
              localImage: _image,
              size: 72,
            ),
          ),
          const SizedBox(height: 16),
          SecondaryBtn(
            label: 'Choose a photo',
            onTap: _pickPhoto,
          ),
          const SizedBox(height: 12),
          Text('...or pick an emoji', style: AppText.caption.copyWith(color: ac.txt2)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: kCurriculumIconChoices.map((e) {
            final active = e == _emoji && _image == null;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() {
                _emoji = active ? '' : e;
                _image = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36, height: 36, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? ac.primaryBg : ac.surf2,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? ac.primary : ac.bdr),
                ),
                child: Text(e, style: const TextStyle(fontSize: 18)),
              ),
            );
          }).toList()),
          const SizedBox(height: 20),
          Row(children: [
            if (_emoji.isNotEmpty || _image != null || widget.currentImageUrl.isNotEmpty)
              Expanded(
                child: SecondaryBtn(
                  label: 'Clear',
                  onTap: _saving ? () {} : _clear,
                ),
              ),
            if (_emoji.isNotEmpty || _image != null || widget.currentImageUrl.isNotEmpty)
              const SizedBox(width: 12),
            Expanded(
              child: PrimaryBtn(label: 'Save', loading: _saving, onTap: _save),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// "+ New section" dialog for QuizCategoriesPage — just the name; the
/// look is set afterward via [showQuizIconEditor] on the new tile (same
/// two-step flow as changing an existing one, rather than a second,
/// slightly-different creation-time picker).
Future<String?> showAddQuizCategoryDialog(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('New section'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. Nursery, Master\'s'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final name = ctrl.text.trim();
            Navigator.pop(context, name.isEmpty ? null : name);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

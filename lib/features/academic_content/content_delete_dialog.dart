// lib/features/academic_content/content_delete_dialog.dart
// Confirmation dialog for deleting content (also removes Storage files).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_theme.dart';
import '../../core/result.dart';
import '../../theme/app_colors.dart';

class ContentDeleteDialog extends StatefulWidget {
  final AcademicContent content;
  final VoidCallback onDeleted;

  const ContentDeleteDialog({
    super.key,
    required this.content,
    required this.onDeleted,
  });

  @override
  State<ContentDeleteDialog> createState() => _ContentDeleteDialogState();
}

class _ContentDeleteDialogState extends State<ContentDeleteDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _deleting = true;
      _error = null;
    });
    final result = await AcademicContentRepository.instance.delete(widget.content.id);
    if (!mounted) return;
    if (result is Success) {
      Navigator.pop(context);
      widget.onDeleted();
    } else {
      setState(() {
        _error = (result as Failure).message;
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.delete_outline, color: ac.red, size: 22),
        const SizedBox(width: 8),
        Text('Delete Content', style: AppText.title.copyWith(fontSize: 17)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete "${widget.content.title}"?',
              style: AppText.bodySm.copyWith(fontSize: 14)),
          const SizedBox(height: 8),
          Text('This will permanently remove the file from storage. This action cannot be undone.',
              style: AppText.caption.copyWith(fontSize: 12)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: AppText.bodySm.copyWith(color: ac.red, fontSize: 12)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.bodySm.copyWith(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: _deleting ? null : _delete,
          style: ElevatedButton.styleFrom(
            backgroundColor: ac.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _deleting
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Delete', style: AppText.button.copyWith(fontSize: 14)),
        ),
      ],
    );
  }
}

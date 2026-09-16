import 'package:flutter/material.dart';
import '../../core/result.dart';
import '../../repositories/school_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageSubjectsDialog extends StatefulWidget {
  final String schoolId;
  const ManageSubjectsDialog({super.key, required this.schoolId});

  @override
  State<ManageSubjectsDialog> createState() => _ManageSubjectsDialogState();
}

class _ManageSubjectsDialogState extends State<ManageSubjectsDialog> {
  final _ctrl = TextEditingController();
  List<String> _subjects = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await SchoolRepository.instance.getSubjects(widget.schoolId);
    if (mounted) {
      setState(() {
        _loading = false;
        if (res is Success<List<String>>) _subjects = res.value;
      });
    }
  }

  Future<void> _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    final res = await SchoolRepository.instance.addSubject(widget.schoolId, text);
    if (mounted) {
      setState(() => _saving = false);
      if (res is Success) {
        _ctrl.clear();
        _load();
      } else {
        showToast(context, 'Failed to add subject', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return AlertDialog(
      backgroundColor: ac.surf,
      title: Text('Manage Subjects', style: GoogleFonts.inter(color: ac.txt)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: TextStyle(color: ac.txt),
                    decoration: InputDecoration(
                      hintText: 'New subject (e.g. Chemistry)',
                      filled: true,
                      fillColor: ac.bg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                  onPressed: _saving ? null : _add,
                  color: ac.blu,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(_subjects[index], style: TextStyle(color: ac.txt2)),
                    dense: true,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

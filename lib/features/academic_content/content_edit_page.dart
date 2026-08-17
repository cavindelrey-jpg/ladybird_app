// lib/features/academic_content/content_edit_page.dart
// Edit existing academic content. Supports replacing file/thumbnail.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_colors.dart';

import '../../widgets/app_background.dart';
class ContentEditPage extends StatefulWidget {
  final AcademicContent content;
  final AppUser user;

  const ContentEditPage({
    super.key,
    required this.content,
    required this.user,
  });

  @override
  State<ContentEditPage> createState() => _ContentEditPageState();
}

class _ContentEditPageState extends State<ContentEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _yearCtrl;

  late ContentType _type;
  late String _subject;   // locked to kAcademicSubjects — never free text
  late String _level;     // locked to kAcademicLevels
  late String _examBoard; // locked to kExamBoards
  File? _newContentFile;
  String? _newContentFileName;
  File? _newThumbnailFile;
  bool _saving = false;
  double _uploadProgress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.content;
    _titleCtrl = TextEditingController(text: c.title);
    _descCtrl = TextEditingController(text: c.description);
    _tagsCtrl = TextEditingController(text: c.tags.join(', '));
    _yearCtrl = TextEditingController(text: c.year?.toString() ?? '');
    _type = c.contentType;
    // Older docs may carry a subject/level/examBoard value from before
    // these were locked lists (or before level/examBoard existed at all)
    // — fall back to the first/last valid option rather than crashing on
    // a value not in the controlled list.
    _subject = kAcademicSubjects.contains(c.subject) ? c.subject : kAcademicSubjects.first;
    _level = kAcademicLevels.contains(c.level) ? c.level : kAcademicLevels.last;
    _examBoard = kExamBoards.contains(c.examBoard) ? c.examBoard : kExamBoards.last;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickNewFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: [
        'pdf','doc','docx','ppt','pptx','xls','xlsx',
        'mp4','mov','avi','png','jpg','jpeg','zip',
      ],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _newContentFile = File(result.files.single.path!);
        _newContentFileName = result.files.single.name;
      });
    }
  }

  Future<void> _pickNewThumbnail() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _newThumbnailFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _uploadProgress = 0;
    });

    final repo = AcademicContentRepository.instance;
    final institutionId =
        widget.user.schoolId ?? widget.content.institutionId;

    String fileUrl = widget.content.fileUrl ?? '';
    String? thumbnailUrl = widget.content.thumbnailUrl;

    // Replace content file if a new one was chosen
    if (_newContentFile != null) {
      final result = await repo.uploadFile(
        file: _newContentFile!,
        folder: 'content_files',
        institutionId: institutionId,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p * 0.6);
        },
      );
      if (result is Failure) {
        setState(() {
          _error = (result as Failure).message;
          _saving = false;
        });
        return;
      }
      fileUrl = (result as Success<String>).value;
    }

    // Replace thumbnail if a new one was chosen. A failed replace keeps
    // the existing thumbnail (not a hard stop -- the rest of the edit is
    // still worth saving) but must not be swallowed silently: the caller
    // needs to know "Content updated" doesn't mean every field actually
    // changed.
    String? thumbnailWarning;
    if (_newThumbnailFile != null) {
      final result = await repo.uploadFile(
        file: _newThumbnailFile!,
        folder: 'thumbnails',
        institutionId: institutionId,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = 0.6 + p * 0.4);
        },
      );
      if (result is Success<String>) {
        thumbnailUrl = result.value;
      } else {
        thumbnailWarning = (result as Failure).message;
      }
    }

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final updated = widget.content.copyWith(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      subject: _subject,
      level: _level,
      examBoard: _examBoard,
      year: int.tryParse(_yearCtrl.text.trim()),
      clearYear: _yearCtrl.text.trim().isEmpty,
      contentType: _type,
      tags: tags,
      fileUrl: fileUrl.isEmpty ? null : fileUrl,
      thumbnailUrl: thumbnailUrl,
    );

    final result = await repo.update(updated);
    if (!mounted) return;

    if (result is Success) {
      final ac = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(thumbnailWarning != null
              ? 'Content updated — thumbnail wasn\'t: $thumbnailWarning'
              : 'Content updated.'),
          backgroundColor: thumbnailWarning != null ? ac.gold : ac.grn,
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() {
        _error = (result as Failure).message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Edit Content',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save',
                style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700, color: ac.primary)),
          ),
        ],
      ),
      body: AppBackground(child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content type
              const _Label('Content Type'),
              const SizedBox(height: 10),
              _TypeRow(
                selected: _type,
                onSelected: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 20),

              const _Label('Title *'),
              const SizedBox(height: 8),
              _TextField(
                controller: _titleCtrl,
                hint: 'Title',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              const _Label('Subject *'),
              const SizedBox(height: 8),
              _ChoicePicker(
                options: kAcademicSubjects,
                selected: _subject,
                onSelected: (v) => setState(() => _subject = v),
              ),
              const SizedBox(height: 16),

              const _Label('Level / Class *'),
              const SizedBox(height: 8),
              _ChoicePicker(
                options: kAcademicLevels,
                selected: _level,
                onSelected: (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 16),

              const _Label('Examination *'),
              const SizedBox(height: 8),
              _ChoicePicker(
                options: kExamBoards,
                selected: _examBoard,
                onSelected: (v) => setState(() => _examBoard = v),
              ),
              const SizedBox(height: 16),

              const _Label('Year (optional)'),
              const SizedBox(height: 8),
              _TextField(
                controller: _yearCtrl,
                hint: 'e.g. 2024',
              ),
              const SizedBox(height: 16),

              const _Label('Description'),
              const SizedBox(height: 8),
              _TextField(
                  controller: _descCtrl,
                  hint: 'Description',
                  maxLines: 3),
              const SizedBox(height: 16),

              const _Label('Tags (comma separated)'),
              const SizedBox(height: 8),
              _TextField(
                  controller: _tagsCtrl, hint: 'e.g. form4, exam'),
              const SizedBox(height: 20),

              // Replace file
              const _Label('Replace Content File (optional)'),
              const SizedBox(height: 8),
              _FileRow(
                label: _newContentFileName ??
                    (widget.content.fileUrl != null
                        ? 'Current file (tap to replace)'
                        : 'No file'),
                selected: _newContentFile != null,
                onTap: _saving ? null : _pickNewFile,
              ),
              const SizedBox(height: 16),

              // Replace thumbnail
              const _Label('Replace Thumbnail (optional)'),
              const SizedBox(height: 8),
              _ThumbnailRow(
                existingUrl: widget.content.thumbnailUrl,
                newFile: _newThumbnailFile,
                onTap: _saving ? null : _pickNewThumbnail,
              ),
              const SizedBox(height: 28),

              if (_saving) ...[
                LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  backgroundColor: ac.bdr,
                  color: ac.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
              ],

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: ac.redBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!,
                      style: GoogleFonts.inter(
                          color: ac.red, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save Changes',
                      style: GoogleFonts.sora(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.of(context).txt2));
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: ac.muted, fontSize: 14),
        filled: true,
        fillColor: ac.surf,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.bdr)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.bdr)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: ac.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _ChoicePicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const _ChoicePicker({required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: options.map((o) {
        final active = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: active,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onSelected(o);
          },
          selectedColor: ac.primary,
          labelStyle: TextStyle(
              color: active ? Colors.white : ac.txt,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400),
          backgroundColor: ac.surf,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: active ? ac.primary : ac.bdr)),
        );
      }).toList(),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final ContentType selected;
  final ValueChanged<ContentType> onSelected;
  const _TypeRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ContentType.values.map((t) {
          final active = t == selected;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(t);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? ac.primaryBg : ac.surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? ac.primary : ac.bdr,
                      width: active ? 1.5 : 1),
                ),
                child: Text('${t.emoji} ${t.label}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? ac.primary : ac.txt2)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _FileRow(
      {required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null ? null : () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? ac.primaryBg : ac.surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? ac.primary : ac.bdr),
          ),
          child: Row(children: [
            Icon(Icons.attach_file_rounded,
                size: 18,
                color: selected ? ac.primary : ac.muted),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: selected ? ac.txt : ac.muted))),
            Icon(Icons.edit_outlined, size: 16, color: ac.muted),
          ]),
        ),
      ),
    );
  }
}

class _ThumbnailRow extends StatelessWidget {
  final String? existingUrl;
  final File? newFile;
  final VoidCallback? onTap;
  const _ThumbnailRow(
      {this.existingUrl, this.newFile, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null ? null : () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: newFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(newFile!, fit: BoxFit.cover,
                      width: double.infinity))
              : existingUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(fit: StackFit.expand, children: [
                        Image.network(existingUrl!, fit: BoxFit.cover),
                        Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(Icons.edit,
                                color: Colors.white, size: 28),
                          ),
                        ),
                      ]),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 28, color: ac.muted),
                        const SizedBox(height: 4),
                        Text('Add thumbnail',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: ac.muted)),
                      ],
                    ),
        ),
      ),
    );
  }
}

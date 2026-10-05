// lib/features/academic_content/content_upload_page.dart
// Upload new academic content with file + thumbnail. Uses Firebase Storage.

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
import 'bulk_past_paper_upload_page.dart';

import '../../widgets/app_background.dart';
class ContentUploadPage extends StatefulWidget {
  final AppUser user;

  /// The File Explorer folder to file this upload into. Null means
  /// "Unfiled" until an admin moves it.
  final String? initialFolderId;

  const ContentUploadPage({super.key, required this.user, this.initialFolderId});

  @override
  State<ContentUploadPage> createState() => _ContentUploadPageState();
}

class _ContentUploadPageState extends State<ContentUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  ContentType _type = ContentType.note;
  String _subject = kAcademicSubjects.first; // locked to predefined list — never free text
  String _level = kAcademicLevels.last;      // 'All Levels' default
  String _examBoard = kExamBoards.last;      // 'N/A' default
  File? _contentFile;
  String? _contentFileName;
  File? _thumbnailFile;
  double _uploadProgress = 0;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickContentFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf','doc','docx','ppt','pptx','xls','xlsx',
        'mp4','mov','avi','png','jpg','jpeg','zip',
      ],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _contentFile = File(result.files.single.path!);
        _contentFileName = result.files.single.name;
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _thumbnailFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contentFile == null) {
      setState(() => _error = 'Please select a content file.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
      _uploadProgress = 0;
    });

    final repo = AcademicContentRepository.instance;
    final institutionId = widget.user.schoolId ?? 'independent';

    // Upload content file
    final fileResult = await repo.uploadFile(
      file: _contentFile!,
      folder: 'content_files',
      institutionId: institutionId,
      onProgress: (p) {
        if (mounted) setState(() => _uploadProgress = p * 0.7);
      },
    );
    if (fileResult is Failure) {
      setState(() {
        _error = (fileResult as Failure).message;
        _uploading = false;
      });
      return;
    }
    final fileUrl = (fileResult as Success<String>).value;

    // Upload thumbnail (optional). A failed thumbnail shouldn't block
    // publishing the actual content the user already uploaded -- proceed
    // without one, but say so rather than pretending it worked.
    String? thumbnailUrl;
    String? thumbnailWarning;
    if (_thumbnailFile != null) {
      final thumbResult = await repo.uploadFile(
        file: _thumbnailFile!,
        folder: 'thumbnails',
        institutionId: institutionId,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = 0.7 + p * 0.3);
        },
      );
      if (thumbResult is Success<String>) {
        thumbnailUrl = thumbResult.value;
      } else {
        thumbnailWarning = (thumbResult as Failure).message;
      }
    }

    setState(() => _uploadProgress = 1.0);

    // Parse tags
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final content = AcademicContent(
      id: '',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      thumbnailUrl: thumbnailUrl,
      fileUrl: fileUrl,
      contentType: _type,
      subject: _subject,
      level: _level,
      examBoard: _examBoard,
      year: int.tryParse(_yearCtrl.text.trim()),
      institutionId: institutionId,
      uploadedBy: widget.user.id,
      uploaderName: widget.user.name,
      fileSizeBytes: _contentFile != null ? await _contentFile!.length() : null,
      uploadDate: DateTime.now(),
      tags: tags,
      folderId: widget.initialFolderId,
    );

    final addResult = await repo.add(content);
    if (!mounted) return;

    if (addResult is Success) {
      final ac = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(thumbnailWarning != null
              ? '${_type.label} uploaded — thumbnail failed: $thumbnailWarning'
              : '${_type.label} uploaded successfully!'),
          backgroundColor: thumbnailWarning != null ? ac.gold : ac.grn,
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() {
        _error = (addResult as Failure).message;
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Upload Content',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.drive_folder_upload_rounded, color: ac.primary, size: 18),
            label: Text('Bulk Upload', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ac.primary, fontSize: 13)),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => BulkPastPaperUploadPage(user: widget.user),
              ));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackground(child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content type selector
              const _SectionLabel('Content Type'),
              const SizedBox(height: 10),
              _ContentTypeGrid(
                selected: _type,
                onSelected: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 20),

              // Title
              const _SectionLabel('Title *'),
              const SizedBox(height: 8),
              _Field(
                controller: _titleCtrl,
                hint: 'e.g. Physics Form 4 Notes',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Subject — locked to predefined categories, never free text
              const _SectionLabel('Subject *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: kAcademicSubjects.map((s) {
                  final selected = s == _subject;
                  return ChoiceChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (_) => setState(() => _subject = s),
                    selectedColor: ac.primary,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : ac.txt,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                    backgroundColor: ac.surf2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: selected ? ac.primary : ac.bdr)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Level — locked to predefined categories, never free text
              const _SectionLabel('Level / Class *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: kAcademicLevels.map((l) {
                  final selected = l == _level;
                  return ChoiceChip(
                    label: Text(l),
                    selected: selected,
                    onSelected: (_) => setState(() => _level = l),
                    selectedColor: ac.primary,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : ac.txt,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                    backgroundColor: ac.surf2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: selected ? ac.primary : ac.bdr)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Exam board / series — locked to predefined categories
              const _SectionLabel('Examination *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: kExamBoards.map((e) {
                  final selected = e == _examBoard;
                  return ChoiceChip(
                    label: Text(e),
                    selected: selected,
                    onSelected: (_) => setState(() => _examBoard = e),
                    selectedColor: ac.primary,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : ac.txt,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                    backgroundColor: ac.surf2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: selected ? ac.primary : ac.bdr)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Year — optional, mainly relevant to Past Papers/Mock exams
              const _SectionLabel('Year (optional)'),
              const SizedBox(height: 8),
              _Field(
                controller: _yearCtrl,
                hint: 'e.g. 2024',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1990 || n > DateTime.now().year + 1) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              const _SectionLabel('Description'),
              const SizedBox(height: 8),
              _Field(
                controller: _descCtrl,
                hint: 'Briefly describe the content…',
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Tags
              const _SectionLabel('Tags (comma separated)'),
              const SizedBox(height: 8),
              _Field(
                controller: _tagsCtrl,
                hint: 'e.g. form4, revision, waves',
              ),
              const SizedBox(height: 20),

              // Content file picker
              const _SectionLabel('Content File *'),
              const SizedBox(height: 8),
              _FilePicker(
                label: _contentFileName ?? 'Choose file…',
                icon: Icons.attach_file_rounded,
                selected: _contentFile != null,
                onTap: _uploading ? null : _pickContentFile,
              ),
              const SizedBox(height: 16),

              // Thumbnail picker
              const _SectionLabel('Thumbnail (optional)'),
              const SizedBox(height: 8),
              _ThumbnailPicker(
                file: _thumbnailFile,
                onTap: _uploading ? null : _pickThumbnail,
              ),
              const SizedBox(height: 28),

              // Progress
              if (_uploading) ...[
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: ac.bdr,
                  color: ac.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploading… ${(_uploadProgress * 100).toInt()}%',
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                ),
                const SizedBox(height: 16),
              ],

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ac.redBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      style:
                          GoogleFonts.inter(color: ac.red, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _uploading ? 'Uploading…' : 'Upload ${_type.label}',
                    style: GoogleFonts.sora(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.of(context).txt2));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: ac.muted, fontSize: 14),
        filled: true,
        fillColor: ac.surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.bdr),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.bdr),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _ContentTypeGrid extends StatelessWidget {
  final ContentType selected;
  final ValueChanged<ContentType> onSelected;

  const _ContentTypeGrid(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ContentType.values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (_, i) {
        final t = ContentType.values[i];
        final active = t == selected;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(t);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: active ? ac.primaryBg : ac.surf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: active ? ac.primary : ac.bdr,
                    width: active ? 1.5 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(t.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: active ? ac.primary : ac.txt2)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _FilePicker({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

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
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? ac.primaryBg : ac.surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? ac.primary : ac.bdr,
                style: BorderStyle.solid),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: selected ? ac.primary : ac.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: selected ? ac.txt : ac.muted)),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: ac.grn),
          ]),
        ),
      ),
    );
  }
}

class _ThumbnailPicker extends StatelessWidget {
  final File? file;
  final VoidCallback? onTap;
  const _ThumbnailPicker({this.file, this.onTap});

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
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: file != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(file!, fit: BoxFit.cover),
                )
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 32, color: ac.muted),
                  const SizedBox(height: 6),
                  Text('Add thumbnail image',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: ac.muted)),
                ]),
        ),
      ),
    );
  }
}


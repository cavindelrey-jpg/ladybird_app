// lib/features/academic_content/bulk_content_upload_page.dart
// Bulk-ingest content of EVERY category (past papers, notes, books, presentations,
// assignments, research papers, videos) into the Library with batch thumbnail assignment.

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/result.dart';
import '../../core/past_paper_filename_parser.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/widgets.dart' show showToast;

enum _BatchItemStatus { ready, needsInfo, uploading, done, failed }

class _BatchItem {
  final File? file;
  final Uint8List? bytes;
  final int? sizeBytes;
  final String originalName;
  ContentType contentType;
  String discipline;
  String examBoard;
  int? year;
  int? paperNumber;
  String title;
  _BatchItemStatus status;
  String? error;

  _BatchItem({
    this.file,
    this.bytes,
    this.sizeBytes,
    required this.originalName,
    required this.contentType,
    required this.discipline,
    required this.examBoard,
    required this.year,
    required this.paperNumber,
    required this.title,
    this.status = _BatchItemStatus.ready,
  });

  bool get isComplete => title.trim().isNotEmpty && discipline.trim().isNotEmpty;
}

class BulkContentUploadPage extends StatefulWidget {
  final AppUser user;
  final String? folderId;
  final ContentType initialCategory;

  const BulkContentUploadPage({
    super.key,
    required this.user,
    this.folderId,
    this.initialCategory = ContentType.pastPaper,
  });

  @override
  State<BulkContentUploadPage> createState() => _BulkContentUploadPageState();
}

class _BulkContentUploadPageState extends State<BulkContentUploadPage> {
  late ContentType _defaultCategory = widget.initialCategory;
  final List<_BatchItem> _items = [];

  final Map<String, File> _pickedThumbnails = {};
  final Map<String, Uint8List> _pickedThumbnailBytes = {};
  final Map<String, String> _resolvedThumbnailUrls = {};
  bool _resolvingThumbnails = false;
  bool _uploading = false;
  int _doneCount = 0;

  String get _institutionId => widget.user.schoolId ?? 'independent';

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'epub', 'txt', 'ppt', 'pptx', 'mp4', 'png', 'jpg', 'jpeg'
      ],
      allowMultiple: true,
    );
    if (result == null) return;
    final newItems = <_BatchItem>[];
    for (final f in result.files) {
      if (kIsWeb) {
        if (f.bytes == null) continue;
      } else {
        if (f.path == null && f.bytes == null) continue;
      }
      final parsed = parsePastPaperFilename(f.name);
      final cleanTitle = f.name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
      final fallbackDiscipline = cleanTitle.split(RegExp(r'\s+')).firstWhere(
            (w) => w.isNotEmpty,
            orElse: () => 'General',
          );
      final discipline = (parsed?.discipline ?? '').trim().isNotEmpty
          ? parsed!.discipline
          : fallbackDiscipline;
      final year = parsed?.year ?? DateTime.now().year;
      final paperNumber = parsed?.paperNumber ?? 1;
      final isComplete = discipline.trim().isNotEmpty;

      newItems.add(_BatchItem(
        file: (!kIsWeb && f.path != null) ? File(f.path!) : null,
        bytes: f.bytes,
        sizeBytes: f.size,
        originalName: f.name,
        contentType: _defaultCategory,
        discipline: discipline,
        examBoard: parsed?.examBoard ?? 'N/A',
        year: year,
        paperNumber: paperNumber,
        title: parsed?.title ?? cleanTitle,
        status: isComplete ? _BatchItemStatus.ready : _BatchItemStatus.needsInfo,
      ));
    }
    setState(() => _items.addAll(newItems));
    await _resolveThumbnails();
  }

  Future<void> _resolveThumbnails() async {
    setState(() => _resolvingThumbnails = true);
    final disciplines = _items
        .where((i) => i.discipline.trim().isNotEmpty)
        .map((i) => i.discipline.trim())
        .toSet();
    for (final d in disciplines) {
      final key = d.toLowerCase();
      if (_resolvedThumbnailUrls.containsKey(key) ||
          _pickedThumbnails.containsKey(key) ||
          _pickedThumbnailBytes.containsKey(key)) {
        continue;
      }
      final existing = await AcademicContentRepository.instance
          .findThumbnailForTag(d, institutionId: _institutionId);
      if (existing != null && mounted) {
        setState(() => _resolvedThumbnailUrls[key] = existing);
      }
    }
    if (mounted) setState(() => _resolvingThumbnails = false);
  }

  Future<void> _pickThumbnailForDiscipline(String discipline) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final key = discipline.trim().toLowerCase();
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() => _pickedThumbnailBytes[key] = bytes);
    } else {
      setState(() => _pickedThumbnails[key] = File(picked.path));
    }
  }

  Future<void> _assignBatchThumbnailToAll() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final disciplines = _items.map((i) => i.discipline.trim().toLowerCase()).toSet();
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        for (final d in disciplines) {
          _pickedThumbnailBytes[d] = bytes;
        }
      });
    } else {
      final f = File(picked.path);
      setState(() {
        for (final d in disciplines) {
          _pickedThumbnails[d] = f;
        }
      });
    }
    if (mounted) showToast(context, 'Assigned thumbnail to all items in batch');
  }

  Future<void> _startUpload() async {
    if (_uploading || _items.isEmpty) return;
    final incomplete = _items.where((i) => !i.isComplete).length;
    if (incomplete > 0) {
      showToast(context, 'Please fix $incomplete incomplete item(s) before uploading', isError: true);
      return;
    }

    setState(() {
      _uploading = true;
      _doneCount = 0;
    });

    final repo = AcademicContentRepository.instance;

    // 1. Upload any newly-picked thumbnails
    final allKeys = {..._pickedThumbnails.keys, ..._pickedThumbnailBytes.keys};
    for (final key in allKeys) {
      final file = _pickedThumbnails[key];
      final bytes = _pickedThumbnailBytes[key];
      final result = await repo.uploadThumbnail(
        file: file,
        bytes: bytes,
        fileName: '$key.jpg',
        institutionId: _institutionId,
      );
      if (result is Success<String>) {
        _resolvedThumbnailUrls[key] = result.value;
      }
    }

    for (final item in _items) {
      if (!mounted) return;
      setState(() => item.status = _BatchItemStatus.uploading);

      final fileResult = await repo.uploadFile(
        file: item.file,
        bytes: item.bytes,
        fileName: item.originalName,
        folder: 'content_files',
        institutionId: _institutionId,
      );
      if (fileResult is Failure) {
        setState(() {
          item.status = _BatchItemStatus.failed;
          item.error = (fileResult as Failure).message;
        });
        continue;
      }
      final fileUrl = (fileResult as Success<String>).value;
      final thumbnailUrl = _resolvedThumbnailUrls[item.discipline.trim().toLowerCase()];

      int? fileSize = item.sizeBytes ?? item.bytes?.length;
      if (fileSize == null && item.file != null) {
        try {
          fileSize = await item.file!.length();
        } catch (_) {}
      }

      final content = AcademicContent(
        id: '',
        title: item.title,
        description: '',
        thumbnailUrl: thumbnailUrl,
        fileUrl: fileUrl,
        contentType: item.contentType,
        subject: mapDisciplineToSubjectCategory(item.discipline),
        level: 'All Levels',
        examBoard: item.examBoard,
        year: item.year,
        institutionId: _institutionId,
        uploadedBy: widget.user.id,
        uploaderName: widget.user.name,
        fileSizeBytes: fileSize,
        uploadDate: DateTime.now(),
        tags: [
          item.discipline.trim(),
          if (item.paperNumber != null) 'Paper ${item.paperNumber}',
          item.contentType.label,
        ],
        folderId: widget.folderId,
      );

      final addResult = await repo.add(content);
      if (!mounted) return;
      setState(() {
        if (addResult is Success) {
          item.status = _BatchItemStatus.done;
          _doneCount++;
        } else {
          item.status = _BatchItemStatus.failed;
          item.error = (addResult as Failure).message;
        }
      });
    }

    setState(() => _uploading = false);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    showToast(context, 'Uploaded $_doneCount of ${_items.length} items to Library');
  }

  void _editItem(int index) {
    final item = _items[index];
    final titleCtrl = TextEditingController(text: item.title);
    final disciplineCtrl = TextEditingController(text: item.discipline);
    final examCtrl = TextEditingController(text: item.examBoard);
    final yearCtrl = TextEditingController(text: item.year?.toString() ?? '');
    ContentType itemType = item.contentType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Edit "${item.originalName}"',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<ContentType>(
                value: itemType,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ContentType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text('${t.emoji} ${t.label}')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDlgState(() => itemType = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: disciplineCtrl,
                decoration: const InputDecoration(labelText: 'Discipline / Subject'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: examCtrl,
                decoration: const InputDecoration(labelText: 'Exam Board'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year'),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _items.removeAt(index));
                Navigator.pop(ctx);
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  item.contentType = itemType;
                  item.title = titleCtrl.text.trim();
                  item.discipline = disciplineCtrl.text.trim();
                  item.examBoard = examCtrl.text.trim();
                  item.year = int.tryParse(yearCtrl.text.trim());
                  item.status = item.isComplete ? _BatchItemStatus.ready : _BatchItemStatus.needsInfo;
                });
                Navigator.pop(ctx);
                _resolveThumbnails();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final disciplines = _items
        .where((i) => i.discipline.trim().isNotEmpty)
        .map((i) => i.discipline.trim())
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Bulk Content Upload',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: ac.txt)),
        backgroundColor: ac.surf,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _startUpload,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(_uploading ? 'Uploading $_doneCount/${_items.length}...' : 'Upload All (${_items.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Category & Batch Setup Row
            Card(
              color: ac.surf,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: ac.bdr),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.category_outlined, color: ac.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Content Category',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: ac.txt)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ContentType.values.map((type) {
                      final isSel = _defaultCategory == type;
                      return ChoiceChip(
                        label: Text('${type.emoji} ${type.label}'),
                        selected: isSel,
                        selectedColor: ac.primary.withValues(alpha: 0.15),
                        labelStyle: GoogleFonts.inter(
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? ac.primary : ac.txt,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _defaultCategory = type;
                              for (final it in _items) {
                                it.contentType = type;
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickFiles,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('Select Files for Batch'),
                      style: ElevatedButton.styleFrom(backgroundColor: ac.primary, foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    if (_items.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _assignBatchThumbnailToAll,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Assign One Thumbnail to All'),
                      ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Thumbnail Assignment Section
            if (disciplines.isNotEmpty) ...[
              Text('Thumbnails Assignment by Subject / Discipline',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: ac.txt)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: disciplines.map((disc) {
                  final key = disc.toLowerCase();
                  final hasPicked = _pickedThumbnails.containsKey(key) || _pickedThumbnailBytes.containsKey(key);
                  final hasResolved = _resolvedThumbnailUrls.containsKey(key);
                  final resolvedUrl = _resolvedThumbnailUrls[key];

                  return InkWell(
                    onTap: () => _pickThumbnailForDiscipline(disc),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 210,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ac.surf,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: (hasPicked || hasResolved) ? ac.primary : ac.bdr),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: ac.surf2,
                            borderRadius: BorderRadius.circular(8),
                            image: hasPicked && !kIsWeb && _pickedThumbnails[key] != null
                                ? DecorationImage(image: FileImage(_pickedThumbnails[key]!), fit: BoxFit.cover)
                                : (hasResolved && resolvedUrl != null)
                                    ? DecorationImage(image: NetworkImage(resolvedUrl), fit: BoxFit.cover)
                                    : null,
                          ),
                          child: (!hasPicked && !hasResolved)
                              ? Icon(Icons.image_search_rounded, color: ac.muted, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(disc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ac.txt)),
                            Text((hasPicked || hasResolved) ? 'Thumbnail set' : 'Tap to assign',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: (hasPicked || hasResolved) ? ac.grn : ac.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Batch Items List
            if (_items.isNotEmpty) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Items in Batch (${_items.length})',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: ac.txt)),
                TextButton(
                  onPressed: _uploading ? null : () => setState(() => _items.clear()),
                  child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
              ]),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final it = _items[i];
                  final statusIcon = switch (it.status) {
                    _BatchItemStatus.ready => Icon(Icons.check_circle_outline, color: ac.grn, size: 18),
                    _BatchItemStatus.needsInfo => Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    _BatchItemStatus.uploading => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    _BatchItemStatus.done => Icon(Icons.check_circle_rounded, color: ac.grn, size: 18),
                    _BatchItemStatus.failed => Icon(Icons.error_outline, color: ac.red, size: 18),
                  };

                  return ListTile(
                    tileColor: ac.surf,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: ac.bdr),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: ac.surf2,
                      child: Text(it.contentType.emoji, style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(it.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: ac.txt)),
                    subtitle: Text(
                      '${it.contentType.label} • ${it.discipline} • ${it.examBoard} ${it.year ?? ''}',
                      style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      statusIcon,
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: _uploading ? null : () => _editItem(i),
                      ),
                    ]),
                  );
                },
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    Icon(Icons.folder_zip_outlined, size: 64, color: ac.muted),
                    const SizedBox(height: 12),
                    Text('No files selected yet',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: ac.txt)),
                    const SizedBox(height: 6),
                    Text('Choose multiple files to upload with automatic thumbnail assignment',
                        style: GoogleFonts.inter(fontSize: 13, color: ac.txt2)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

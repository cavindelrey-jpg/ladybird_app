// lib/features/academic_content/bulk_past_paper_upload_page.dart
// Bulk-ingest past papers into the Library without a per-file form.
// Select many PDFs at once; each filename is parsed (see
// core/past_paper_filename_parser.dart) for subject/exam/year/paper
// number, e.g. "Physics GCE O Level 2024 Paper 1.pdf". Every paper under
// the same discipline (e.g. every Physics paper) shares ONE thumbnail —
// reused automatically from an existing upload if one already exists for
// that discipline, otherwise picked once and reused for the rest of the
// batch (and future batches, since it's looked up the same way).
//
// Files that don't match the expected filename shape are flagged rather
// than silently skipped or guessed at — the uploader corrects them
// inline (subject/year/paper number) before the batch proceeds.

import 'dart:io';
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
  final File file;
  final String originalName;
  String discipline;
  String examBoard;
  int? year;
  int? paperNumber;
  String title;
  _BatchItemStatus status;
  String? error;

  _BatchItem({
    required this.file,
    required this.originalName,
    required this.discipline,
    required this.examBoard,
    required this.year,
    required this.paperNumber,
    required this.title,
    this.status = _BatchItemStatus.ready,
  });

  bool get isComplete => discipline.trim().isNotEmpty && year != null && paperNumber != null;
}

class BulkPastPaperUploadPage extends StatefulWidget {
  final AppUser user;
  final String? folderId;
  const BulkPastPaperUploadPage({super.key, required this.user, this.folderId});

  @override
  State<BulkPastPaperUploadPage> createState() => _BulkPastPaperUploadPageState();
}

class _BulkPastPaperUploadPageState extends State<BulkPastPaperUploadPage> {
  final List<_BatchItem> _items = [];

  /// One shared thumbnail File/URL per discipline for this batch —
  /// keyed by discipline.toLowerCase() so "Physics"/"physics" share one.
  final Map<String, File> _pickedThumbnails = {};
  final Map<String, String> _resolvedThumbnailUrls = {};
  bool _resolvingThumbnails = false;
  bool _uploading = false;
  int _doneCount = 0;

  String get _institutionId => widget.user.schoolId ?? 'independent';

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    final newItems = <_BatchItem>[];
    for (final f in result.files) {
      if (f.path == null) continue;
      final parsed = parsePastPaperFilename(f.name);
      final discipline = parsed?.discipline ?? '';
      final year = parsed?.year;
      final paperNumber = parsed?.paperNumber;
      // A partial parse (e.g. year found but no paper number) still needs
      // fixing -- checking isComplete's own condition here, not just
      // whether parsing found *something*.
      final isComplete = discipline.trim().isNotEmpty && year != null && paperNumber != null;
      newItems.add(_BatchItem(
        file: File(f.path!),
        originalName: f.name,
        discipline: discipline,
        examBoard: parsed?.examBoard ?? 'N/A',
        year: year,
        paperNumber: paperNumber,
        title: parsed?.title ?? f.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
        status: isComplete ? _BatchItemStatus.ready : _BatchItemStatus.needsInfo,
      ));
    }
    setState(() => _items.addAll(newItems));
    await _resolveThumbnails();
  }

  /// For every discipline in the batch, check the Library for an
  /// already-used thumbnail (findThumbnailForTag) so returning uploaders
  /// never have to re-pick the same image. Whatever's left needing one
  /// gets prompted for below.
  Future<void> _resolveThumbnails() async {
    setState(() => _resolvingThumbnails = true);
    final disciplines = _items
        .where((i) => i.discipline.trim().isNotEmpty)
        .map((i) => i.discipline.trim())
        .toSet();
    for (final d in disciplines) {
      final key = d.toLowerCase();
      if (_resolvedThumbnailUrls.containsKey(key) || _pickedThumbnails.containsKey(key)) continue;
      final existing = await AcademicContentRepository.instance
          .findThumbnailForTag(d, institutionId: _institutionId);
      if (existing != null && mounted) {
        setState(() => _resolvedThumbnailUrls[key] = existing);
      }
    }
    if (mounted) setState(() => _resolvingThumbnails = false);
  }

  Future<void> _pickThumbnailFor(String discipline) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _pickedThumbnails[discipline.toLowerCase()] = File(picked.path));
    }
  }

  List<String> get _disciplinesNeedingThumbnail => _items
      .where((i) => i.discipline.trim().isNotEmpty)
      .map((i) => i.discipline.trim())
      .toSet()
      .where((d) =>
          !_resolvedThumbnailUrls.containsKey(d.toLowerCase()) &&
          !_pickedThumbnails.containsKey(d.toLowerCase()))
      .toList();

  bool get _canUpload =>
      _items.isNotEmpty &&
      _items.every((i) => i.isComplete) &&
      _disciplinesNeedingThumbnail.isEmpty &&
      !_uploading;

  Future<void> _uploadAll() async {
    setState(() { _uploading = true; _doneCount = 0; });
    final repo = AcademicContentRepository.instance;

    // Upload each newly-picked thumbnail ONCE per discipline, reuse the
    // resulting URL for every paper in that discipline below.
    for (final entry in _pickedThumbnails.entries) {
      if (_resolvedThumbnailUrls.containsKey(entry.key)) continue;
      final result = await repo.uploadFile(
        file: entry.value, folder: 'thumbnails', institutionId: _institutionId,
      );
      if (result is Success<String>) {
        _resolvedThumbnailUrls[entry.key] = result.value;
      }
    }

    for (final item in _items) {
      if (!mounted) return;
      setState(() => item.status = _BatchItemStatus.uploading);

      final fileResult = await repo.uploadFile(
        file: item.file, folder: 'content_files', institutionId: _institutionId,
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

      final content = AcademicContent(
        id: '',
        title: item.title,
        description: '',
        thumbnailUrl: thumbnailUrl,
        fileUrl: fileUrl,
        contentType: ContentType.pastPaper,
        subject: mapDisciplineToSubjectCategory(item.discipline),
        level: 'All Levels',
        examBoard: item.examBoard,
        year: item.year,
        institutionId: _institutionId,
        uploadedBy: widget.user.id,
        uploaderName: widget.user.name,
        fileSizeBytes: await item.file.length(),
        uploadDate: DateTime.now(),
        tags: [item.discipline.trim(), if (item.paperNumber != null) 'Paper ${item.paperNumber}'],
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

    if (!mounted) return;
    setState(() => _uploading = false);
    final failed = _items.where((i) => i.status == _BatchItemStatus.failed).length;
    showToast(
      context,
      failed == 0
          ? '$_doneCount past paper(s) uploaded'
          : '$_doneCount uploaded, $failed failed — see the list below',
      isError: failed > 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: Text('Bulk Upload Past Papers', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: AppBackground(child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Select every PDF at once. Each filename is read as '
                '"Subject Exam Year Paper N", e.g. "Physics GCE O Level 2024 Paper 1". '
                'Papers with the same subject share one thumbnail.',
                style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickFiles,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_items.isEmpty ? 'Select PDFs' : 'Add more PDFs'),
                ),
              ),
            ]),
          ),

          if (_resolvingThumbnails)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),

          if (_disciplinesNeedingThumbnail.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Pick one thumbnail per new subject',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt2)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _disciplinesNeedingThumbnail.map((d) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _ThumbnailChoice(
                    discipline: d,
                    file: _pickedThumbnails[d.toLowerCase()],
                    onTap: () => _pickThumbnailFor(d),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text('No files selected yet', style: GoogleFonts.inter(color: ac.muted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _BatchItemTile(
                      item: _items[i],
                      onEdited: () => setState(() {}),
                    ),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canUpload ? _uploadAll : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _uploading
                      ? 'Uploading… $_doneCount/${_items.length}'
                      : 'Upload ${_items.length} Paper${_items.length == 1 ? '' : 's'}',
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ]),
      )),
    );
  }
}

class _ThumbnailChoice extends StatelessWidget {
  final String discipline;
  final File? file;
  final VoidCallback onTap;
  const _ThumbnailChoice({required this.discipline, this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return InkWell(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 84,
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: file != null ? ac.primary : ac.bdr),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          file != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file!, width: 40, height: 40, fit: BoxFit.cover),
                )
              : Icon(Icons.add_photo_alternate_outlined, color: ac.muted, size: 28),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(discipline, maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 10, color: ac.txt2)),
          ),
        ]),
      ),
    );
  }
}

class _BatchItemTile extends StatelessWidget {
  final _BatchItem item;
  final VoidCallback onEdited;
  const _BatchItemTile({required this.item, required this.onEdited});

  Color _statusColor(AppColors ac) {
    switch (item.status) {
      case _BatchItemStatus.done:      return ac.grn;
      case _BatchItemStatus.failed:    return ac.red;
      case _BatchItemStatus.needsInfo: return ac.gold;
      case _BatchItemStatus.uploading: return ac.primary;
      case _BatchItemStatus.ready:     return ac.muted;
    }
  }

  IconData _statusIcon() {
    switch (item.status) {
      case _BatchItemStatus.done:      return Icons.check_circle_rounded;
      case _BatchItemStatus.failed:    return Icons.error_rounded;
      case _BatchItemStatus.needsInfo: return Icons.warning_rounded;
      case _BatchItemStatus.uploading: return Icons.cloud_upload_rounded;
      case _BatchItemStatus.ready:     return Icons.description_rounded;
    }
  }

  Future<void> _editInline(BuildContext context) async {
    final disciplineCtrl = TextEditingController(text: item.discipline);
    final yearCtrl = TextEditingController(text: item.year?.toString() ?? '');
    final paperCtrl = TextEditingController(text: item.paperNumber?.toString() ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(item.originalName, style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: disciplineCtrl, decoration: const InputDecoration(labelText: 'Subject (e.g. Physics)')),
          const SizedBox(height: 12),
          TextField(controller: yearCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year')),
          const SizedBox(height: 12),
          TextField(controller: paperCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Paper number')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          )),
        ]),
      ),
    );
    if (saved == true) {
      item.discipline = disciplineCtrl.text.trim();
      item.year = int.tryParse(yearCtrl.text.trim());
      item.paperNumber = int.tryParse(paperCtrl.text.trim());
      item.title = '${item.discipline} ${item.examBoard == 'N/A' ? '' : '${item.examBoard} '}${item.year ?? ''} Paper ${item.paperNumber ?? ''}'.trim();
      if (item.isComplete) item.status = _BatchItemStatus.ready;
      onEdited();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.status == _BatchItemStatus.uploading || item.status == _BatchItemStatus.done
            ? null
            : () => _editInline(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(_statusIcon(), color: _statusColor(ac), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.isComplete ? item.title : item.originalName,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ac.txt),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.status == _BatchItemStatus.needsInfo)
                  Text('Tap to fix — couldn\'t read subject/year/paper number',
                      style: GoogleFonts.inter(fontSize: 11, color: ac.gold)),
                if (item.status == _BatchItemStatus.failed && item.error != null)
                  Text(item.error!, style: GoogleFonts.inter(fontSize: 11, color: ac.red)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

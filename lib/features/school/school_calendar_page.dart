// lib/features/school/school_calendar_page.dart
// School Calendar / Activities (school-operations spec item 7 / the
// "School Calendar / Activities" mockup). Backed by
// public.school_calendar_events -- see supabase/migrations/
// 20260903160000_homework_and_calendar_events.sql. Every school member
// can read the calendar; only school_admin+ can create/edit/delete events
// (RLS-enforced, mirrored client-side here).
//
// Custom month grid rather than a new package -- table_calendar isn't a
// dependency in this project and a 7-column grid is simple enough not to
// need one.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/result.dart';
import '../../core/school_calendar_csv.dart';
import '../../models/app_user.dart';
import '../../models/school_calendar_event.dart';
import '../../repositories/school_calendar_repository.dart';
import '../../services/school_document_export_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'school_calendar_csv_import_page.dart';
import 'widgets/management_scaffold.dart';

Color _categoryColor(AppColors ac, SchoolEventCategory c) {
  switch (c) {
    case SchoolEventCategory.academic: return ac.primary;
    case SchoolEventCategory.exam:     return Colors.orange;
    case SchoolEventCategory.meeting:  return Colors.blue;
    case SchoolEventCategory.sports:   return Colors.green;
    case SchoolEventCategory.holiday:  return Colors.pink;
  }
}

class SchoolCalendarPage extends StatefulWidget {
  final AppUser user;
  const SchoolCalendarPage({super.key, required this.user});

  @override
  State<SchoolCalendarPage> createState() => _SchoolCalendarPageState();
}

class _SchoolCalendarPageState extends State<SchoolCalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<SchoolCalendarEvent> _currentEvents = const [];

  bool get _canManage => widget.user.hasMinRole(UserRole.schoolAdmin);
  String get _schoolId => widget.user.schoolId ?? '';

  void _openComposer({SchoolCalendarEvent? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventComposerSheet(schoolId: _schoolId, existing: existing),
    );
  }

  Future<void> _downloadTemplate() async {
    try {
      final csv = generateSchoolCalendarCsvTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/school_activities_template.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'School Activities CSV Template');
    } catch (e) {
      if (mounted) showToast(context, 'Could not generate template: $e', isError: true);
    }
  }

  Future<void> _openCsvImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SchoolCalendarCsvImportPage(user: widget.user)),
    );
  }

  Future<void> _exportCsv() async {
    if (_currentEvents.isEmpty) {
      showToast(context, 'No calendar events to export.');
      return;
    }
    try {
      final csv = exportSchoolCalendarCsv(_currentEvents);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/school_activities_${DateTime.now().year}.csv');
      await file.writeAsString('\uFEFF$csv');
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'School Activities Export');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export CSV: $e', isError: true);
    }
  }

  Future<void> _exportPdf() async {
    if (_currentEvents.isEmpty) {
      showToast(context, 'No calendar events to export.');
      return;
    }
    try {
      showToast(context, 'Generating Program of Activities PDF...');
      final file = await SchoolDocumentExportService.instance.exportActivitiesPdf(
        schoolName: widget.user.schoolName.isNotEmpty ? widget.user.schoolName : 'CFPMI',
        events: _currentEvents,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'School Program of Activities (PDF)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export PDF: $e', isError: true);
    }
  }

  Future<void> _exportDocx() async {
    if (_currentEvents.isEmpty) {
      showToast(context, 'No calendar events to export.');
      return;
    }
    try {
      showToast(context, 'Generating Program of Activities Word document...');
      final file = await SchoolDocumentExportService.instance.exportActivitiesDocx(
        schoolName: widget.user.schoolName.isNotEmpty ? widget.user.schoolName : 'CFPMI',
        events: _currentEvents,
      );
      if (!mounted) return;
      await SchoolDocumentExportService.instance.shareFile(file, text: 'School Program of Activities (Word Document)');
    } catch (e) {
      if (mounted) showToast(context, 'Could not export Word document: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ManagementScaffold(
      title: 'School Calendar / Activities',
      sidebarItems: const [ManagementNavItem(icon: Icons.calendar_month_rounded, label: 'Calendar', selected: true)],
      actions: [
        if (_canManage)
          IconButton(
            tooltip: 'Upload Activities CSV',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: _openCsvImport,
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.ios_share_rounded),
          tooltip: 'Import / Export & Templates',
          onSelected: (val) {
            switch (val) {
              case 'template':
                _downloadTemplate();
                break;
              case 'csv':
                _exportCsv();
                break;
              case 'pdf':
                _exportPdf();
                break;
              case 'docx':
                _exportDocx();
                break;
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'template',
              child: Row(
                children: [
                  Icon(Icons.download_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Download CSV Template'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'csv',
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Export as CSV'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Export as PDF Document'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'docx',
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 20, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('Export as Word (.docx)'),
                ],
              ),
            ),
          ],
        ),
      ],
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openComposer(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Event'),
            )
          : null,
      body: StreamBuilder<List<SchoolCalendarEvent>>(
        stream: SchoolCalendarRepository.instance.watchAll(_schoolId),
        builder: (context, snap) {
          final events = snap.data ?? const [];
          _currentEvents = events;
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final upcoming = SchoolCalendarRepository.instance.upcomingFrom(events);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MonthGrid(
                month: _month,
                events: events,
                onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
              const SizedBox(height: 8),
              _Legend(),
              const SizedBox(height: 20),
              Text('Upcoming Events', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
              const SizedBox(height: 10),
              if (upcoming.isEmpty)
                Text('No upcoming events.', style: GoogleFonts.inter(color: ac.muted))
              else
                for (final e in upcoming)
                  _EventTile(
                    event: e,
                    onTap: _canManage ? () => _openComposer(existing: e) : null,
                    onDelete: _canManage ? () => SchoolCalendarRepository.instance.delete(_schoolId, e.id) : null,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<SchoolCalendarEvent> events;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthGrid({required this.month, required this.events, required this.onPrev, required this.onNext});

  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<Color> _colorsFor(AppColors ac, DateTime day) {
    return events
        .where((e) => !day.isBefore(DateTime(e.startDate.year, e.startDate.month, e.startDate.day)) &&
            !day.isAfter(DateTime(e.endDate.year, e.endDate.month, e.endDate.day)))
        .map((e) => _categoryColor(ac, e.category))
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday-first grid
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
      child: Column(children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: onPrev),
          Expanded(
            child: Text('${_monthNames[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
          ),
          IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: onNext),
        ]),
        Row(children: [
          for (final l in _weekdayLabels)
            Expanded(child: Center(child: Text(l, style: GoogleFonts.inter(fontSize: 11, color: ac.muted)))),
        ]),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, i) {
            if (i < leadingBlanks) return const SizedBox.shrink();
            final day = DateTime(month.year, month.month, i - leadingBlanks + 1);
            final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
            final dots = _colorsFor(ac, day);
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: isToday ? BoxDecoration(color: ac.primary, shape: BoxShape.circle) : null,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${day.day}',
                    style: GoogleFonts.inter(fontSize: 12, color: isToday ? Colors.white : ac.txt,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
                if (dots.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final c in dots.take(3))
                        Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    ]),
                  ),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Wrap(spacing: 14, runSpacing: 6, children: [
      for (final c in SchoolEventCategory.values)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _categoryColor(ac, c), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(c.label, style: GoogleFonts.inter(fontSize: 11, color: ac.muted)),
        ]),
    ]);
  }
}

class _EventTile extends StatelessWidget {
  final SchoolCalendarEvent event;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const _EventTile({required this.event, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr2)),
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          Container(width: 44, alignment: Alignment.center, child: Column(children: [
            Text('${event.startDate.day}', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: _categoryColor(ac, event.category))),
            Text(_MonthGrid._monthNames[event.startDate.month - 1].substring(0, 3), style: GoogleFonts.inter(fontSize: 10, color: ac.muted)),
          ])),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(event.title, style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: ac.txt))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _categoryColor(ac, event.category).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: Text(event.category.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _categoryColor(ac, event.category))),
                ),
              ]),
              if (event.location != null && event.location!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text(event.location!, style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted))),
              Padding(padding: const EdgeInsets.only(top: 2),
                  child: Text(event.isAllClasses ? 'All Classes' : event.affectedClasses.join(', '),
                      style: GoogleFonts.inter(fontSize: 11, color: ac.muted))),
            ]),
          ),
          if (onDelete != null)
            IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: ac.muted), onPressed: onDelete),
        ]),
      ),
    );
  }
}

class _EventComposerSheet extends StatefulWidget {
  final String schoolId;
  final SchoolCalendarEvent? existing;
  const _EventComposerSheet({required this.schoolId, this.existing});

  @override
  State<_EventComposerSheet> createState() => _EventComposerSheetState();
}

class _EventComposerSheetState extends State<_EventComposerSheet> {
  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _locationCtrl = TextEditingController(text: widget.existing?.location ?? '');
  late SchoolEventCategory _category = widget.existing?.category ?? SchoolEventCategory.academic;
  late DateTime _startDate = widget.existing?.startDate ?? DateTime.now();
  late DateTime _endDate = widget.existing?.endDate ?? DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, 'Enter a title.', isError: true);
      return;
    }
    setState(() => _saving = true);
    final event = SchoolCalendarEvent(
      id: widget.existing?.id ?? '',
      schoolId: widget.schoolId,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      startDate: _startDate,
      endDate: _endDate,
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
    );
    final result = widget.existing == null
        ? await SchoolCalendarRepository.instance.create(event)
        : await SchoolCalendarRepository.instance.update(event);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Failure<void>) {
      showToast(context, result.message, isError: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(color: ac.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.existing == null ? 'New Event' : 'Edit Event',
                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ac.txt)),
            const SizedBox(height: 16),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            TextField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Location (optional)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<SchoolEventCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in SchoolEventCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isStart: true),
                  child: Text('Start ${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isStart: false),
                  child: Text('End ${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            PrimaryBtn(label: widget.existing == null ? 'Create Event' : 'Save Changes', loading: _saving, onTap: _save),
          ],
        ),
      ),
    );
  }
}

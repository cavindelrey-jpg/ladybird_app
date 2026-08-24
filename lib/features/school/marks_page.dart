// lib/features/school/marks_page.dart
// School Navigation's "Marks" module -- a real, data-driven academic
// record, not a static mockup. Term/sequence selection, a /20-/100
// display toggle (same underlying score, just rescaled for display --
// see SchoolMark.scoreOutOf), comparison against the previous sequence,
// an overall analysis summary, and a per-subject breakdown table.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/school_mark.dart';
import '../../repositories/school_marks_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'marks_entry_page.dart';

class MarksPage extends StatefulWidget {
  final AppUser user;
  const MarksPage({super.key, required this.user});

  @override
  State<MarksPage> createState() => _MarksPageState();
}

class _MarksPageState extends State<MarksPage> {
  AcademicSequence _selected = AcademicSequence.t1s1;
  bool _showOn100 = true;

  String? _cacheKey;
  Future<(List<SchoolMark>, List<SchoolMark>)>? _cachedFuture;

  Future<(List<SchoolMark>, List<SchoolMark>)> get _future {
    final key = '${widget.user.id}:${_selected.name}';
    if (_cachedFuture == null || _cacheKey != key) {
      _cacheKey = key;
      _cachedFuture = _load();
    }
    return _cachedFuture!;
  }

  Future<(List<SchoolMark>, List<SchoolMark>)> _load() async {
    final repo = SchoolMarksRepository.instance;
    final current = await repo.getForSequenceOnce(widget.user.id, _selected);
    final prev = _selected.previous;
    final previous = prev != null ? await repo.getForSequenceOnce(widget.user.id, prev) : <SchoolMark>[];
    return (current, previous);
  }

  void _refresh() => setState(() => _cachedFuture = null);

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final u = widget.user;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        title: Text('Marks', style: AppText.h2.copyWith(color: ac.txt)),
        iconTheme: IconThemeData(color: ac.txt),
        actions: [
          if (u.canUploadContent)
            IconButton(
              icon: Icon(Icons.edit_note_rounded, color: ac.txt2),
              tooltip: 'Enter marks',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MarksEntryPage(staff: u))).then((_) => _refresh()),
            ),
        ],
      ),
      body: Column(children: [
        _header(ac, u),
        _controls(ac),
        Expanded(
          child: FutureBuilder<(List<SchoolMark>, List<SchoolMark>)>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              final (current, previous) = snap.data ?? (const <SchoolMark>[], const <SchoolMark>[]);
              if (current.isEmpty) return _emptyState(ac);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _analysisCard(ac, current),
                  const SizedBox(height: 16),
                  _subjectTable(ac, current, previous),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _header(AppColors ac, AppUser u) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surf, borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20, backgroundColor: ac.primaryBg,
          backgroundImage: (u.photoUrl ?? '').isNotEmpty ? NetworkImage(u.photoUrl!) : null,
          child: (u.photoUrl ?? '').isEmpty
              ? Text(u.initials, style: GoogleFonts.sora(color: ac.primary, fontWeight: FontWeight.w700))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: ac.txt)),
            Text(u.classLevel.isEmpty ? 'No class set' : u.classLevel,
                style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
          ]),
        ),
      ]),
    );
  }

  Widget _controls(AppColors ac) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<AcademicSequence>(
            initialValue: _selected,
            decoration: InputDecoration(
              filled: true, fillColor: ac.surf3, isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
            style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt),
            items: [
              for (final s in AcademicSequence.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selected = v);
            },
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: ac.surf3,
          borderRadius: BorderRadius.circular(Rad.sm),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _toggleChip(ac, label: '/20', selected: !_showOn100, onTap: () => setState(() => _showOn100 = false)),
            _toggleChip(ac, label: '/100', selected: _showOn100, onTap: () => setState(() => _showOn100 = true)),
          ]),
        ),
      ]),
    );
  }

  Widget _toggleChip(AppColors ac, {required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Rad.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ac.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(Rad.sm),
        ),
        child: Text(label, style: GoogleFonts.sora(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : ac.txt2)),
      ),
    );
  }

  Widget _analysisCard(AppColors ac, List<SchoolMark> current) {
    final avgPct = averagePercentage(current);
    final avgOnScale = _showOn100 ? avgPct : avgPct / 5; // /100 -> /20
    final grade = overallGradeFor(avgPct);
    final status = academicStatusFor(avgPct);
    final startingPoint = _selected.previous == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ac.navy, ac.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Rad.lg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Overall Analysis · ${_selected.label}',
            style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .85))),
        const SizedBox(height: 14),
        Row(children: [
          _analysisStat('Average', _showOn100 ? avgOnScale.toStringAsFixed(1) : avgOnScale.toStringAsFixed(1),
              _showOn100 ? '/100' : '/20'),
          _analysisStat('Percentage', avgPct.toStringAsFixed(1), '%'),
          _analysisStat('Grade', grade, ''),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
          child: Text(status, style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        if (startingPoint) ...[
          const SizedBox(height: 8),
          Text('Starting point: ${_selected.label} — no earlier sequence to compare against yet.',
              style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: .7))),
        ],
      ]),
    );
  }

  Widget _analysisStat(String label, String value, String suffix) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value$suffix', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: .7))),
      ]),
    );
  }

  Widget _subjectTable(AppColors ac, List<SchoolMark> current, List<SchoolMark> previous) {
    final prevBySubject = {for (final m in previous) m.subject: m};
    return Container(
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(flex: 3, child: Text('Subject', style: _headStyle(ac))),
            Expanded(flex: 2, child: Text(_showOn100 ? 'Mark /100' : 'Mark /20', style: _headStyle(ac), textAlign: TextAlign.center)),
            Expanded(flex: 1, child: Text('Grade', style: _headStyle(ac), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('Change', style: _headStyle(ac), textAlign: TextAlign.end)),
          ]),
        ),
        Divider(height: 1, color: ac.bdr),
        for (var i = 0; i < current.length; i++) ...[
          if (i > 0) Divider(height: 1, color: ac.bdr2),
          _subjectRow(ac, current[i], prevBySubject[current[i].subject]),
        ],
      ]),
    );
  }

  TextStyle _headStyle(AppColors ac) =>
      GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.muted);

  Widget _subjectRow(AppColors ac, SchoolMark mark, SchoolMark? previous) {
    final scale = _showOn100 ? 100.0 : 20.0;
    final markOnScale = mark.scoreOutOf(scale);
    final prevOnScale = previous?.scoreOutOf(scale);
    final change = prevOnScale != null ? markOnScale - prevOnScale : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(flex: 3, child: Text(mark.subject,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.txt))),
        Expanded(flex: 2, child: Text(markOnScale.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt))),
        Expanded(flex: 1, child: Text(mark.grade,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.primary))),
        Expanded(flex: 2, child: change == null
            ? Text('—', textAlign: TextAlign.end, style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted))
            : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Icon(change >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 13, color: change >= 0 ? ac.grn : ac.red),
                const SizedBox(width: 2),
                Text(change.abs().toStringAsFixed(1),
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700,
                        color: change >= 0 ? ac.grn : ac.red)),
              ])),
      ]),
    );
  }

  Widget _emptyState(AppColors ac) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.assessment_outlined, size: 48, color: ac.muted),
            const SizedBox(height: 16),
            Text('No marks recorded for ${_selected.label} yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
          ]),
        ),
      );
}

// lib/features/school/marks_page.dart
// School Navigation's "Marks" module -- matches mockups/mockup3.jpg:
// separate Term/Sequence selectors, a /20-/100 display toggle (same
// underlying score, just rescaled -- see SchoolMark.scoreOutOf), a
// comparison target selector, a light "Overall Performance" summary
// card, and a Subject/Teacher/Mark/Grade/Change table.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/school_mark.dart';
import '../../repositories/school_marks_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'marks_entry_page.dart';
import 'marks_csv_import_page.dart';
import 'widgets/school_shared_widgets.dart';
import '../../widgets/application_shell.dart';

enum _CompareTarget { previousSequence, firstSequence }

class MarksPage extends StatefulWidget {
  final AppUser user;
  const MarksPage({super.key, required this.user});

  @override
  State<MarksPage> createState() => _MarksPageState();
}

class _MarksPageState extends State<MarksPage> {
  int _termIndex = 0; // 0/1/2 -> Term 1/2/3
  int _seqIndex = 0;  // 0/1 -> Sequence 1/2 within that term
  bool _showOn100 = false;
  _CompareTarget _compareTarget = _CompareTarget.previousSequence;

  AcademicSequence get _selected => AcademicSequence.values[_termIndex * 2 + _seqIndex];

  AcademicSequence? get _compareSequence {
    switch (_compareTarget) {
      case _CompareTarget.previousSequence:
        return _selected.previous;
      case _CompareTarget.firstSequence:
        return _selected == AcademicSequence.t1s1 ? null : AcademicSequence.t1s1;
    }
  }

  String? _cacheKey;
  Future<(List<SchoolMark>, List<SchoolMark>)>? _cachedFuture;

  Future<(List<SchoolMark>, List<SchoolMark>)> get _future {
    final key = '${widget.user.id}:${_selected.name}:${_compareTarget.name}';
    if (_cachedFuture == null || _cacheKey != key) {
      _cacheKey = key;
      _cachedFuture = _load();
    }
    return _cachedFuture!;
  }

  Future<(List<SchoolMark>, List<SchoolMark>)> _load() async {
    final repo = SchoolMarksRepository.instance;
    final current = await repo.getForSequenceOnce(widget.user.id, _selected);
    final compare = _compareSequence;
    final previous = compare != null ? await repo.getForSequenceOnce(widget.user.id, compare) : <SchoolMark>[];
    return (current, previous);
  }

  void _refresh() => setState(() => _cachedFuture = null);

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final u = widget.user;

    // Staff have no report card of their own -- showing them the student
    // view ("Student ID —", "No marks recorded yet") with the real
    // actions hidden behind two unlabeled icons was the old behavior.
    if (u.canRecordAnyMarks && !u.isStudent) return _StaffMarksHome(staff: u);

    return ApplicationShell(
      user: u,
      currentTitle: 'Marks',
      currentDestination: AppNavDestination.marks,
      child: Column(children: [
        if (u.canRecordAnyMarks)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ac.primaryBg,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.primary.withValues(alpha: .3)),
            ),
            child: Row(children: [
              Icon(Icons.edit_note_rounded, color: ac.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Teacher Marks Console', style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt)),
                  Text('Record marks or import class results spreadsheet', style: GoogleFonts.inter(fontSize: 11, color: ac.txt2)),
                ]),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MarksEntryPage(staff: u))).then((_) => _refresh()),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Record Marks'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MarksCsvImportPage(staff: u))).then((res) {
                  if (res != null && mounted) {
                    final result = res is MarksImportResult ? res : null;
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MarksEntryPage(
                        staff: u,
                        initialClass: result?.classLevel,
                        initialSubject: result?.subject,
                        initialSequence: result?.sequence,
                      ),
                    ));
                  }
                }),
                icon: const Icon(Icons.upload_file_rounded, size: 14),
                label: const Text('CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11.5),
                ),
              ),
            ]),
          ),
        StudentInfoCard(user: u),
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
                  const SizedBox(height: 16),
                  _tipBanner(ac),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _controls(AppColors ac) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _dropdown(ac, label: 'Term', value: _termIndex,
                items: const ['Term 1', 'Term 2', 'Term 3'],
                onChanged: (v) => setState(() => _termIndex = v)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _dropdown(ac, label: 'Sequence', value: _seqIndex,
                items: const ['Sequence 1', 'Sequence 2'],
                onChanged: (v) => setState(() => _seqIndex = v)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _dropdown(ac, label: 'View Results As', value: _showOn100 ? 1 : 0,
                items: const ['Marks (/20)', 'Marks (/100)'],
                onChanged: (v) => setState(() => _showOn100 = v == 1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _dropdown(ac, label: 'Compare With', value: _compareTarget.index,
                items: const ['Previous Seq.', 'Sequence 1'],
                onChanged: (v) => setState(() => _compareTarget = _CompareTarget.values[v])),
          ),
        ]),
      ]),
    );
  }

  Widget _dropdown(AppColors ac, {required String label, required int value, required List<String> items, required void Function(int) onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: ac.muted)),
      const SizedBox(height: 4),
      DropdownButtonFormField<int>(
        initialValue: value,
        isDense: true,
        decoration: InputDecoration(
          filled: true, fillColor: ac.surf3,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
        ),
        style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt),
        items: [for (var i = 0; i < items.length; i++) DropdownMenuItem(value: i, child: Text(items[i]))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ]);
  }

  Widget _analysisCard(AppColors ac, List<SchoolMark> current) {
    final avgPct = averagePercentage(current);
    final avgOnScale = _showOn100 ? avgPct : avgPct / 5; // /100 -> /20
    final grade = overallGradeFor(avgPct);
    final compare = _compareSequence;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: ac.bdr)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.show_chart_rounded, color: ac.pur, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Overall Performance', style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.pur)),
            const SizedBox(height: 10),
            Wrap(spacing: 18, runSpacing: 8, children: [
              _analysisStat(ac, avgOnScale.toStringAsFixed(1), _showOn100 ? '/100' : '/20', 'Average Mark'),
              _analysisStat(ac, avgPct.toStringAsFixed(0), '%', 'Overall Percentage'),
              _analysisStat(ac, grade, '', 'Overall Grade'),
            ]),
            if (compare != null) ...[
              const SizedBox(height: 8),
              FutureBuilder<List<SchoolMark>>(
                future: SchoolMarksRepository.instance.getForSequenceOnce(widget.user.id, compare),
                builder: (context, snap) {
                  final compareMarks = snap.data ?? const <SchoolMark>[];
                  if (compareMarks.isEmpty) {
                    return Text('Starting point: ${_selected.label} — no earlier sequence to compare against yet.',
                        style: GoogleFonts.inter(fontSize: 10.5, color: ac.muted));
                  }
                  final delta = avgPct - averagePercentage(compareMarks);
                  final up = delta >= 0;
                  return Row(children: [
                    Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: up ? ac.grn : ac.red),
                    Text('${delta.abs().toStringAsFixed(1)}% from ${compare.label}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: up ? ac.grn : ac.red)),
                  ]);
                },
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _analysisStat(AppColors ac, String value, String suffix, String label) {
    return SizedBox(
      width: 96,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: value, style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w800, color: ac.txt)),
          TextSpan(text: suffix, style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
        ])),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: ac.muted)),
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
            SizedBox(width: 20, child: Text('#', style: _headStyle(ac))),
            Expanded(flex: 3, child: Text('Subject', style: _headStyle(ac))),
            Expanded(flex: 3, child: Text('Teacher', style: _headStyle(ac))),
            Expanded(flex: 2, child: Text(_showOn100 ? '/100' : '/20', style: _headStyle(ac), textAlign: TextAlign.center)),
            Expanded(flex: 1, child: Text('Grade', style: _headStyle(ac), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('Change', style: _headStyle(ac), textAlign: TextAlign.end)),
          ]),
        ),
        Divider(height: 1, color: ac.bdr),
        for (var i = 0; i < current.length; i++) ...[
          if (i > 0) Divider(height: 1, color: ac.bdr2),
          _subjectRow(ac, i + 1, current[i], prevBySubject[current[i].subject]),
        ],
      ]),
    );
  }

  TextStyle _headStyle(AppColors ac) =>
      GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.muted);

  Widget _subjectRow(AppColors ac, int number, SchoolMark mark, SchoolMark? previous) {
    final scale = _showOn100 ? 100.0 : 20.0;
    final markOnScale = mark.scoreOutOf(scale);
    final prevOnScale = previous?.scoreOutOf(scale);
    final change = prevOnScale != null ? markOnScale - prevOnScale : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        SizedBox(width: 20, child: Text('$number', style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted))),
        Expanded(flex: 3, child: Text(mark.subject,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ac.txt))),
        Expanded(flex: 3, child: Text(mark.teacherName.isEmpty ? '—' : mark.teacherName,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2))),
        Expanded(flex: 2, child: Text(formatMark(double.parse(markOnScale.toStringAsFixed(2))),
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

  Widget _tipBanner(AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(Rad.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lightbulb_outline_rounded, color: ac.pur, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tip', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w800, color: ac.pur)),
            const SizedBox(height: 2),
            Text('Keep up the great work! Focus on your weak areas to improve even more.',
                style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2, height: 1.35)),
          ]),
        ),
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

/// What a teacher / class master / admin sees on "Marks":
/// Prominent "Record Marks" and "Upload CSV" controls, plus one card per class/subject.
class _StaffMarksHome extends StatelessWidget {
  final AppUser staff;
  const _StaffMarksHome({required this.staff});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final availableClasses = recordableClassesFor(staff);

    final cards = <(String, String?)>[];
    if (staff.teachingAssignments.isEmpty) {
      // Default: All classes are accessible with "All subjects"
      for (final c in availableClasses) {
        cards.add((c, null));
      }
    } else {
      final pairs = <(String, String)>[
        for (final c in availableClasses)
          for (final s in recordableSubjectsFor(staff, c))
            if (staff.hasMinRole(UserRole.schoolAdmin) ||
                staff.classMasterOfClass == c ||
                staff.teachingAssignments.any((a) => a.classLevel == c && a.subject == s))
              (c, s),
      ];
      for (final (c, s) in pairs) {
        final wholeClass = staff.hasMinRole(UserRole.schoolAdmin) || staff.classMasterOfClass == c;
        if (wholeClass) {
          if (!cards.any((e) => e.$1 == c && e.$2 == null)) cards.add((c, null));
        } else {
          cards.add((c, s));
        }
      }
      if (cards.isEmpty) {
        for (final c in availableClasses) {
          cards.add((c, null));
        }
      }
    }

    void open(String? cls, String? subject, {AcademicSequence? sequence}) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MarksEntryPage(
              staff: staff,
              initialClass: cls,
              initialSubject: subject,
              initialSequence: sequence,
            )));

    Future<void> openCsvImport() async {
      final res = await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MarksCsvImportPage(staff: staff)));
      if (res != null && context.mounted) {
        if (res is MarksImportResult && res.classLevel != null) {
          open(res.classLevel, res.subject, sequence: res.sequence);
        } else {
          open(cards.isNotEmpty ? cards.first.$1 : null, null);
        }
      }
    }

    return ApplicationShell(
      user: staff,
      currentTitle: 'Marks',
      currentDestination: AppNavDestination.marks,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ── Prominent Teacher Marks Action Card ──────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ac.primaryBg, ac.surf],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: ac.primary.withValues(alpha: .35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: ac.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Record Student Marks',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt)),
                      const SizedBox(height: 2),
                      Text('Enter scores directly for any class or import via CSV spreadsheet.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => open(cards.isNotEmpty ? cards.first.$1 : null, null),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Record / Enter Marks'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: openCsvImport,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Upload Marks CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: ac.primary.withValues(alpha: .5)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text('Classes & Subjects', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 10),
          for (final (cls, subject) in cards)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ac.surf,
                borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: ac.bdr2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: ac.primaryBg,
                        child: Icon(Icons.groups_rounded, color: ac.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cls,
                                softWrap: true,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
                            const SizedBox(height: 2),
                            Text(
                              subject ?? (staff.classMasterOfClass == cls ? 'All subjects · Class master' : 'All subjects'),
                              softWrap: true,
                              style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => open(cls, subject),
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('Enter Marks', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.primaryBg,
                        foregroundColor: ac.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: ac.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Tip: Tap any class to view, enter, or edit student marks. You can also export class marks as CSV anytime.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted, height: 1.4)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// lib/features/school/exam_composer/question_bank_picker_sheet.dart
// Intelligent search and filtering sheet for the School Question Bank and
// indexed Academia Library resources. Displays selectable question cards with
// an obvious "Add to Exam" action.

import 'package:flutter/material.dart';
import '../../../models/exam_question.dart';
import '../../../models/test.dart';
import '../../../repositories/exam_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';

class QuestionBankPickerSheet extends StatefulWidget {
  final String schoolId;
  final String defaultSubject;
  final String defaultClassLevel;
  final Set<String> alreadyAddedIds;
  final void Function(ExamQuestion question) onQuestionAdded;

  const QuestionBankPickerSheet({
    super.key,
    required this.schoolId,
    required this.defaultSubject,
    required this.defaultClassLevel,
    required this.alreadyAddedIds,
    required this.onQuestionAdded,
  });

  @override
  State<QuestionBankPickerSheet> createState() => _QuestionBankPickerSheetState();
}

class _QuestionBankPickerSheetState extends State<QuestionBankPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  late String _subject;
  late String _classLevel;
  String _difficulty = ''; // '' = all
  String _source = ''; // '' = all

  bool _loading = false;
  List<ExamQuestion> _results = [];
  final Set<String> _addedInThisSession = {};

  @override
  void initState() {
    super.initState();
    _subject = widget.defaultSubject;
    _classLevel = widget.defaultClassLevel;
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await ExamRepository.instance.searchQuestionBank(
        schoolId: widget.schoolId,
        query: _query,
        subject: _subject.isNotEmpty ? _subject : null,
        classLevel: _classLevel.isNotEmpty ? _classLevel : null,
        difficulty: _difficulty.isNotEmpty ? _difficulty : null,
        source: _source.isNotEmpty ? _source : null,
      );
      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _add(ExamQuestion q) {
    widget.onQuestionAdded(q);
    setState(() => _addedInThisSession.add(q.id));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: ac.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ac.muted.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: ac.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Question Bank & Library Search',
                          style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) {
                    _query = v;
                    _fetch();
                  },
                  style: AppText.bodySm.copyWith(color: ac.txt),
                  decoration: InputDecoration(
                    hintText: 'Search topic, past paper, or keyword (e.g. algebra, GCE 2024, mechanics)…',
                    hintStyle: AppText.bodySm.copyWith(color: ac.muted, fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: ac.primary),
                    filled: true,
                    fillColor: ac.surf2,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    // Source Filter Tabs
                    _filterChip(
                      ac: ac,
                      label: 'All Sources',
                      isSelected: _source.isEmpty,
                      onTap: () {
                        setState(() => _source = '');
                        _fetch();
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      ac: ac,
                      label: '📄 PDF Past Papers',
                      isSelected: _source == 'Past Paper',
                      onTap: () {
                        setState(() => _source = 'Past Paper');
                        _fetch();
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      ac: ac,
                      label: '🏛️ Question Bank',
                      isSelected: _source == 'Question Bank',
                      onTap: () {
                        setState(() => _source = 'Question Bank');
                        _fetch();
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      ac: ac,
                      label: '📚 Library & Books',
                      isSelected: _source == 'Library',
                      onTap: () {
                        setState(() => _source = 'Library');
                        _fetch();
                      },
                    ),
                    const SizedBox(width: 8),

                    // Difficulty Filter
                    _filterChip(
                      ac: ac,
                      label: _difficulty.isEmpty ? 'Difficulty: All' : 'Difficulty: ${_difficulty.toUpperCase()}',
                      isSelected: _difficulty.isNotEmpty,
                      onTap: () {
                        setState(() {
                          if (_difficulty.isEmpty) {
                            _difficulty = 'easy';
                          } else if (_difficulty == 'easy') {
                            _difficulty = 'medium';
                          } else if (_difficulty == 'medium') {
                            _difficulty = 'hard';
                          } else {
                            _difficulty = '';
                          }
                        });
                        _fetch();
                      },
                    ),
                    const SizedBox(width: 8),

                    // Reset Filters
                    if (_difficulty.isNotEmpty || _source.isNotEmpty)
                      ActionChip(
                        label: const Text('Reset Filters', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setState(() {
                            _difficulty = '';
                            _source = '';
                          });
                          _fetch();
                        },
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Results Count / Loading
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _loading ? 'Searching…' : '${_results.length} questions available',
                      style: AppText.caption.copyWith(color: ac.muted),
                    ),
                    if (_addedInThisSession.isNotEmpty)
                      Text(
                        '${_addedInThisSession.length} added to exam',
                        style: AppText.caption.copyWith(color: ac.grn, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),

              // Question List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: ac.muted),
                                  const SizedBox(height: 12),
                                  Text('No matching questions found.',
                                      style: AppText.title.copyWith(fontSize: 14, color: ac.txt)),
                                  const SizedBox(height: 4),
                                  Text('Try clearing filters or search terms.',
                                      style: AppText.caption.copyWith(color: ac.muted)),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final q = _results[i];
                              final isAlreadyAdded = widget.alreadyAddedIds.contains(q.id) ||
                                  _addedInThisSession.contains(q.id);

                              return _QuestionSearchCard(
                                question: q,
                                isAdded: isAlreadyAdded,
                                onAdd: () => _add(q),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip({
    required AppColors ac,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : ac.txt)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: ac.primary,
      backgroundColor: ac.surf2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _QuestionSearchCard extends StatelessWidget {
  final ExamQuestion question;
  final bool isAdded;
  final VoidCallback onAdd;

  const _QuestionSearchCard({
    required this.question,
    required this.isAdded,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAdded ? ac.grn.withValues(alpha: .5) : ac.bdr2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chips Row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(6)),
                child: Text(question.type.label,
                    style: AppText.caption.copyWith(fontSize: 10, color: ac.pur, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ac.bluBg, borderRadius: BorderRadius.circular(6)),
                child: Text('${question.marks} marks',
                    style: AppText.caption.copyWith(fontSize: 10, color: ac.blu, fontWeight: FontWeight.bold)),
              ),
              if (question.topic.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(6)),
                  child: Text(question.topic,
                      style: AppText.caption.copyWith(fontSize: 10, color: ac.txt2)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: question.source.contains('Past Paper') || question.source.contains('GCE')
                      ? ac.bluBg
                      : (question.source.contains('Library') ? ac.purBg : ac.goldBg),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      question.source.contains('Past Paper') || question.source.contains('GCE')
                          ? Icons.picture_as_pdf_rounded
                          : (question.source.contains('Library') ? Icons.menu_book_rounded : Icons.account_balance_rounded),
                      size: 11,
                      color: question.source.contains('Past Paper') || question.source.contains('GCE')
                          ? ac.blu
                          : (question.source.contains('Library') ? ac.pur : ac.gold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      question.source,
                      style: AppText.caption.copyWith(
                        fontSize: 10,
                        color: question.source.contains('Past Paper') || question.source.contains('GCE')
                            ? ac.blu
                            : (question.source.contains('Library') ? ac.pur : ac.gold),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question Prompt
          Text(
            question.content,
            style: AppText.bodySm.copyWith(color: ac.txt, height: 1.4),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),

          // MCQ Options preview
          if (question.type == QuestionType.mcq && question.options.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (int i = 0; i < question.options.length.clamp(0, 4); i++)
                  Text(
                    '${String.fromCharCode(65 + i)}. ${question.options[i]}',
                    style: AppText.caption.copyWith(
                      color: i == question.correctOptionIndex ? ac.grn : ac.txt2,
                      fontWeight: i == question.correctOptionIndex ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Difficulty: ${question.difficulty.toUpperCase()}',
                style: AppText.caption.copyWith(fontSize: 11, color: ac.muted),
              ),
              ElevatedButton.icon(
                onPressed: isAdded ? null : onAdd,
                icon: Icon(
                  isAdded ? Icons.check_circle_rounded : Icons.add_rounded,
                  size: 16,
                  color: isAdded ? ac.grn : Colors.white,
                ),
                label: Text(
                  isAdded ? 'Added to Exam' : 'Add to Exam',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isAdded ? ac.grn : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdded ? ac.grnBg : ac.primary,
                  elevation: isAdded ? 0 : 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

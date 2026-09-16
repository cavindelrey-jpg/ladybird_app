import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../repositories/offline_marks_queue.dart';

class MarksSpreadsheet extends StatefulWidget {
  final String schoolId;
  final String sequenceId;
  final List<String> studentIds;
  final List<String> subjects;

  const MarksSpreadsheet({
    Key? key,
    required this.schoolId,
    required this.sequenceId,
    required this.studentIds,
    required this.subjects,
  }) : super(key: key);

  @override
  _MarksSpreadsheetState createState() => _MarksSpreadsheetState();
}

class _MarksSpreadsheetState extends State<MarksSpreadsheet> {
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  final Map<String, Map<String, FocusNode>> _focusNodes = {};
  final OfflineMarksQueue _queue = OfflineMarksQueue();

  @override
  void initState() {
    super.initState();
    for (var student in widget.studentIds) {
      _controllers[student] = {};
      _focusNodes[student] = {};
      for (var subject in widget.subjects) {
        _controllers[student]![subject] = TextEditingController();
        _focusNodes[student]![subject] = FocusNode();
      }
    }
  }

  void _onFieldSubmitted(String studentId, String subject, String value) {
    final mark = double.tryParse(value);
    if (mark != null && mark >= 0 && mark <= 20) {
      _queue.enqueueMarkUpdate(
        schoolId: widget.schoolId,
        studentId: studentId,
        subject: subject,
        sequenceId: widget.sequenceId,
        mark: mark,
      );
    }

    // Keyboard navigation (Tab / Enter moves focus)
    final subIndex = widget.subjects.indexOf(subject);
    final stuIndex = widget.studentIds.indexOf(studentId);

    if (subIndex < widget.subjects.length - 1) {
      _focusNodes[studentId]![widget.subjects[subIndex + 1]]!.requestFocus();
    } else if (stuIndex < widget.studentIds.length - 1) {
      _focusNodes[widget.studentIds[stuIndex + 1]]![widget.subjects[0]]!.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      _queue.syncQueue(); // Trigger sync at end of sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Student ID')),
          ...widget.subjects.map((s) => DataColumn(label: Text(s))),
        ],
        rows: widget.studentIds.map((stu) {
          return DataRow(
            cells: [
              DataCell(Text(stu)),
              ...widget.subjects.map((sub) {
                return DataCell(
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _controllers[stu]![sub],
                      focusNode: _focusNodes[stu]![sub],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (val) => _onFieldSubmitted(stu, sub, val),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}

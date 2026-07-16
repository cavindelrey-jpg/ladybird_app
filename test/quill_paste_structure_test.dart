// test/quill_paste_structure_test.dart
//
// TASKS_LOOP6.md section 3: confirm whether flutter_quill's paste handling
// preserves structure (headings, bold, numbered/bullet lists) or flattens
// it to plain text.
//
// No live device is available in this environment to actually paste from
// an external app (Word/Google Docs) into the running editor — that half
// of the pipeline (native OS clipboard -> HTML string) is untestable here
// and is logged as a REPORT.md follow-up. What IS testable headlessly is
// the other half of the same pipeline flutter_quill 11.x already wires up
// by default (QuillController's paste handler, enableExternalRichPaste
// defaults to true): once HTML text is obtained from the clipboard, it is
// converted to a Quill Delta via package:flutter_quill_delta_from_html's
// HtmlToDelta — the exact same call flutter_quill's internal pasteHTML()
// makes. Running that conversion directly on HTML shaped like a paste
// from Word/Google Docs tells us, with real evidence, exactly what
// structure survives.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

void main() {
  test('HtmlToDelta preserves headings, bold, numbered and bullet lists', () {
    // Representative of what Word/Google Docs put on the system clipboard
    // as the "text/html" flavor when you copy a formatted document.
    const html = '''
      <h1>Document Title</h1>
      <p>This is <b>bold text</b> and <i>italic text</i> in a paragraph.</p>
      <ol>
        <li>First step</li>
        <li>Second step</li>
        <li>Third step</li>
      </ol>
      <ul>
        <li>Bullet one</li>
        <li>Bullet two</li>
      </ul>
    ''';

    final delta = HtmlToDelta().convert(html);
    final ops = delta.toJson();

    bool hasInsertContaining(String text) =>
        ops.any((op) => (op['insert'] as String?)?.contains(text) ?? false);

    bool hasAttribute(String key, dynamic value) => ops.any((op) {
          final attrs = op['attributes'] as Map?;
          return attrs != null && attrs[key] == value;
        });

    // Headings survive as a 'header' block attribute on the newline
    // terminating that line — not flattened to plain text.
    expect(hasInsertContaining('Document Title'), isTrue);
    expect(hasAttribute('header', 1), isTrue, reason: 'H1 should map to header:1');

    // Bold survives as an inline 'bold' attribute on the run.
    expect(
      ops.any((op) =>
          (op['insert'] as String?) == 'bold text' &&
          (op['attributes'] as Map?)?['bold'] == true),
      isTrue,
      reason: 'Bold run should carry attributes: {bold: true}',
    );

    // Numbered list survives as list:'ordered' block attributes, one per line.
    final orderedCount =
        ops.where((op) => (op['attributes'] as Map?)?['list'] == 'ordered').length;
    expect(orderedCount, 3, reason: 'All 3 <ol><li> lines should carry list: ordered');

    // Bullet list survives as list:'bullet' block attributes.
    final bulletCount =
        ops.where((op) => (op['attributes'] as Map?)?['list'] == 'bullet').length;
    expect(bulletCount, 2, reason: 'Both <ul><li> lines should carry list: bullet');
  });
}

// lib/core/docx_parser.dart
// Converts a .docx file into a Quill Delta (the rich-text format the
// course editor uses) — entirely client-side, no Cloud Function. A .docx
// is just a zip of XML files; the actual document lives at
// word/document.xml as a sequence of paragraphs (w:p), each containing
// runs (w:r) with their own formatting (w:rPr) and text (w:t).
//
// What's preserved: bold, italic, underline, paragraph breaks, headings
// (Word's default Heading1/2/3 styles), and bullet/numbered lists.
// What's NOT preserved: tables, exact fonts/colors/sizes, images embedded
// in the Word doc itself (add those manually in the editor after import
// instead), footnotes, and any non-default/custom Word styles. This is a
// real limitation of doing this without a heavier conversion pipeline
// (like docx -> mammoth.js -> HTML on a server) — worth knowing before
// relying on it for anything more than standard formatted body text.

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class DocxParseResult {
  final String deltaJson;   // ready to hand to Quill's Document.fromJson
  final String plainText;   // for the body/excerpt fallback field
  final List<String> warnings; // things we couldn't preserve, if any
  const DocxParseResult({required this.deltaJson, required this.plainText, this.warnings = const []});
}

class DocxParser {
  DocxParser._();

  static T? _first<T>(Iterable<T> items) => items.isEmpty ? null : items.first;

  static const _headingStyles = {
    'Heading1': 1, 'Heading2': 2, 'Heading3': 3,
    'heading 1': 1, 'heading 2': 2, 'heading 3': 3, // some docs use spaced style IDs
  };

  static DocxParseResult parse(Uint8List bytes) {
    final warnings = <String>[];
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? docXml;
    for (final f in archive) {
      if (f.name == 'word/document.xml') { docXml = f; break; }
    }
    if (docXml == null) {
      throw const FormatException('Not a valid .docx file — word/document.xml not found.');
    }

    final xmlString = utf8.decode(docXml.content as List<int>);
    final doc = XmlDocument.parse(xmlString);

    final body = _first(doc.findAllElements('body'));
    if (body == null) {
      throw const FormatException('Could not find a document body in this .docx.');
    }

    final ops = <Map<String, dynamic>>[];
    final plainTextBuffer = StringBuffer();
    bool sawTable = false;

    for (final child in body.children.whereType<XmlElement>()) {
      final localName = child.name.local;
      if (localName == 'tbl') {
        sawTable = true;
        continue; // tables not supported — see header comment
      }
      if (localName != 'p') continue; // skip sectPr and anything else

      _appendParagraph(child, ops, plainTextBuffer);
    }

    if (sawTable) {
      warnings.add('This document contains a table — tables aren\'t converted; '
          'add that content manually after import.');
    }
    if (ops.isEmpty) {
      // Nothing extracted — still return a valid (empty) Delta rather
      // than throwing, so the editor just opens blank instead of crashing.
      ops.add({'insert': '\n'});
    }

    return DocxParseResult(
      deltaJson: jsonEncode(ops),
      plainText: plainTextBuffer.toString().trim(),
      warnings: warnings,
    );
  }

  static void _appendParagraph(
      XmlElement p, List<Map<String, dynamic>> ops, StringBuffer plainText) {
    final pPr = _first(p.findElements('pPr'));

    // Heading detection via the paragraph's style reference.
    int? headingLevel;
    final styleVal = _first(pPr?.findElements('pStyle') ?? const <XmlElement>[])?.getAttribute('val');
    if (styleVal != null) headingLevel = _headingStyles[styleVal];

    // List detection — presence of numPr means this paragraph is a
    // bullet/numbered list item. Word doesn't trivially expose which
    // without reading numbering.xml's abstract-numbering definitions, so
    // we treat every list paragraph as a bullet — close enough for a
    // first pass; numbered vs. bulleted can be fixed up manually.
    final isListItem = pPr != null && _first(pPr.findElements('numPr')) != null;

    bool wroteAnyRun = false;
    // findAllElements (recursive), not findElements (direct-children only)
    // -- <w:r> runs are frequently nested inside <w:hyperlink> or <w:sdt>
    // (content controls), and direct-child matching silently dropped that
    // text entirely.
    for (final r in p.findAllElements('r')) {
      final rPr = _first(r.findElements('rPr'));
      final bold = rPr != null && _first(rPr.findElements('b')) != null;
      final italic = rPr != null && _first(rPr.findElements('i')) != null;
      final underline = rPr != null && _first(rPr.findElements('u')) != null;

      // A run can contain multiple text/break nodes in sequence.
      for (final node in r.children) {
        if (node is! XmlElement) continue;
        if (node.name.local == 't') {
          final text = node.innerText;
          if (text.isEmpty) continue;
          final attrs = <String, dynamic>{};
          if (bold) attrs['bold'] = true;
          if (italic) attrs['italic'] = true;
          if (underline) attrs['underline'] = true;
          ops.add({'insert': text, if (attrs.isNotEmpty) 'attributes': attrs});
          plainText.write(text);
          wroteAnyRun = true;
        } else if (node.name.local == 'br') {
          ops.add({'insert': '\n'});
          plainText.write('\n');
        }
      }
    }

    // Terminate the paragraph with its own newline, carrying any
    // block-level attribute (heading/list) per Quill Delta convention.
    final blockAttrs = <String, dynamic>{};
    if (headingLevel != null) blockAttrs['header'] = headingLevel;
    if (isListItem) blockAttrs['list'] = 'bullet';
    ops.add({'insert': '\n', if (blockAttrs.isNotEmpty) 'attributes': blockAttrs});
    plainText.write('\n');

    if (!wroteAnyRun && headingLevel == null && !isListItem) {
      // Genuinely empty paragraph (spacing) — already accounted for by
      // the newline above, nothing else to do.
    }
  }
}

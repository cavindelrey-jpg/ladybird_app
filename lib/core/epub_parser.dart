// lib/core/epub_parser.dart
// Parses an .epub file entirely client-side using the archive and xml packages.
// An EPUB is a zip archive containing container.xml, an OPF package file
// (metadata, manifest, spine), and XHTML/HTML chapter content files.

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class EpubChapter {
  final String id;
  final String title;
  final String content;
  final String html;

  const EpubChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.html,
  });
}

class EpubDocument {
  final String title;
  final String author;
  final List<EpubChapter> chapters;

  const EpubDocument({
    required this.title,
    required this.author,
    required this.chapters,
  });
}

class EpubParser {
  EpubParser._();

  static const int _maxInputBytes = 50 * 1024 * 1024; // 50MB ceiling

  static EpubDocument parse(Uint8List bytes) {
    if (bytes.length > _maxInputBytes) {
      throw FormatException(
        'EPUB file exceeds size limit (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB).',
      );
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final fileMap = <String, ArchiveFile>{};
    for (final f in archive) {
      fileMap[f.name] = f;
      // Also map normalized path without leading slash
      if (f.name.startsWith('/')) {
        fileMap[f.name.substring(1)] = f;
      }
    }

    // 1. Locate container.xml
    final containerFile = fileMap['META-INF/container.xml'] ??
        archive.firstWhere(
          (f) => f.name.toLowerCase() == 'meta-inf/container.xml',
          orElse: () => throw const FormatException('Invalid EPUB: META-INF/container.xml not found.'),
        );

    final containerXml = utf8.decode(containerFile.content as List<int>);
    final containerDoc = XmlDocument.parse(containerXml);
    final rootfileElem = containerDoc.findAllElements('rootfile').firstOrNull;
    if (rootfileElem == null) {
      throw const FormatException('Invalid EPUB: No rootfile declared in container.xml.');
    }

    final opfPath = rootfileElem.getAttribute('full-path') ?? 'OEBPS/content.opf';
    final opfFile = fileMap[opfPath] ??
        archive.firstWhere(
          (f) => f.name.toLowerCase() == opfPath.toLowerCase(),
          orElse: () => throw FormatException('Invalid EPUB: OPF file "$opfPath" not found.'),
        );

    // Determine base directory of the OPF file
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

    // 2. Parse OPF document
    final opfXml = utf8.decode(opfFile.content as List<int>);
    final opfDoc = XmlDocument.parse(opfXml);

    // Metadata
    String bookTitle = 'Untitled Book';
    String bookAuthor = 'Unknown Author';

    final titleElem = opfDoc.findAllElements('dc:title').firstOrNull ??
        opfDoc.findAllElements('title').firstOrNull;
    if (titleElem != null && titleElem.innerText.trim().isNotEmpty) {
      bookTitle = titleElem.innerText.trim();
    }

    final creatorElem = opfDoc.findAllElements('dc:creator').firstOrNull ??
        opfDoc.findAllElements('creator').firstOrNull;
    if (creatorElem != null && creatorElem.innerText.trim().isNotEmpty) {
      bookAuthor = creatorElem.innerText.trim();
    }

    // Manifest: id -> href
    final manifestMap = <String, String>{};
    for (final item in opfDoc.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        manifestMap[id] = href;
      }
    }

    // Spine: reading order of idrefs
    final spineIds = <String>[];
    for (final itemref in opfDoc.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null) {
        spineIds.add(idref);
      }
    }

    // 3. Extract and parse chapters
    final chapters = <EpubChapter>[];
    var chapterIndex = 1;

    for (final id in spineIds) {
      final relativeHref = manifestMap[id];
      if (relativeHref == null) continue;

      // Handle URL decoding and directory resolution
      final decodedHref = Uri.decodeFull(relativeHref);
      final fullPath = _resolvePath(opfDir, decodedHref);

      final chapterFile = fileMap[fullPath] ??
          fileMap[decodedHref] ??
          archive.firstWhere(
            (f) => f.name.toLowerCase() == fullPath.toLowerCase() ||
                f.name.toLowerCase() == decodedHref.toLowerCase(),
            orElse: () => ArchiveFile('', 0, []),
          );

      if (chapterFile.size == 0) continue;

      try {
        final chapterHtml = utf8.decode(chapterFile.content as List<int>);
        final parsedText = _htmlToPlainText(chapterHtml);
        final title = _extractChapterTitle(chapterHtml, chapterIndex);

        if (parsedText.trim().isNotEmpty) {
          chapters.add(EpubChapter(
            id: id,
            title: title,
            content: parsedText,
            html: chapterHtml,
          ));
          chapterIndex++;
        }
      } catch (_) {
        // Skip unparseable chapter gracefully
      }
    }

    return EpubDocument(
      title: bookTitle,
      author: bookAuthor,
      chapters: chapters,
    );
  }

  static String _resolvePath(String baseDir, String relativePath) {
    if (!relativePath.startsWith('../')) {
      return '$baseDir$relativePath';
    }
    var currentBase = baseDir.endsWith('/') ? baseDir.substring(0, baseDir.length - 1) : baseDir;
    var rel = relativePath;
    while (rel.startsWith('../')) {
      rel = rel.substring(3);
      if (currentBase.contains('/')) {
        currentBase = currentBase.substring(0, currentBase.lastIndexOf('/'));
      } else {
        currentBase = '';
      }
    }
    return currentBase.isEmpty ? rel : '$currentBase/$rel';
  }

  static String _extractChapterTitle(String html, int fallbackIndex) {
    try {
      final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null && titleMatch.group(1)!.trim().isNotEmpty) {
        final raw = titleMatch.group(1)!.trim();
        if (!raw.toLowerCase().contains('.html') && !raw.toLowerCase().contains('.xhtml')) {
          return _cleanText(raw);
        }
      }

      final h1Match = RegExp(r'<h[1-2][^>]*>(.*?)</h[1-2]>', caseSensitive: false).firstMatch(html);
      if (h1Match != null && h1Match.group(1)!.trim().isNotEmpty) {
        return _cleanText(h1Match.group(1)!.trim());
      }
    } catch (_) {}

    return 'Chapter $fallbackIndex';
  }

  static String _htmlToPlainText(String html) {
    var text = html;

    // The <head> (its <title>, meta) isn't reading text -- keeping it made
    // every chapter start with its title twice (head <title> + body <h1>).
    text = text.replaceAll(RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false), '');

    // Remove scripts and styles
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

    // Convert block elements to double line breaks
    text = text.replaceAll(RegExp(r'</?(p|div|section|article|h[1-6])[^>]*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'</?li[^>]*>', caseSensitive: false), '\n• ');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Strip all other HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    return _cleanText(text);
  }

  static String _cleanText(String text) {
    var cleaned = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");

    // Condense excessive whitespace while preserving paragraphs
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }
}

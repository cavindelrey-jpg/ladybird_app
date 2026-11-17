// lib/core/epub_parser.dart
// Parses an .epub file entirely client-side using the archive and xml packages.
// An EPUB is a zip archive containing container.xml, an OPF package file
// (metadata, manifest, spine), TOC (NCX or NAV XHTML), images, and chapter files.

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

enum EpubBlockType {
  heading,
  paragraph,
  table,
  image,
  list,
  divider,
  blockquote,
  code,
}

class EpubInlineSpan {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isCode;

  const EpubInlineSpan({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isCode = false,
  });
}

abstract class EpubBlock {
  final EpubBlockType type;
  const EpubBlock(this.type);
}

class EpubHeadingBlock extends EpubBlock {
  final int level;
  final String text;
  const EpubHeadingBlock({required this.level, required this.text}) : super(EpubBlockType.heading);
}

class EpubParagraphBlock extends EpubBlock {
  final List<EpubInlineSpan> spans;
  final String plainText;
  const EpubParagraphBlock({required this.spans, required this.plainText}) : super(EpubBlockType.paragraph);
}

class EpubTableBlock extends EpubBlock {
  final List<String> headers;
  final List<List<String>> rows;
  const EpubTableBlock({required this.headers, required this.rows}) : super(EpubBlockType.table);
}

class EpubImageBlock extends EpubBlock {
  final Uint8List? imageBytes;
  final String alt;
  const EpubImageBlock({required this.imageBytes, required this.alt}) : super(EpubBlockType.image);
}

class EpubListBlock extends EpubBlock {
  final List<String> items;
  final bool isOrdered;
  const EpubListBlock({required this.items, required this.isOrdered}) : super(EpubBlockType.list);
}

class EpubDividerBlock extends EpubBlock {
  const EpubDividerBlock() : super(EpubBlockType.divider);
}

class EpubBlockquoteBlock extends EpubBlock {
  final String text;
  final List<EpubInlineSpan> spans;
  const EpubBlockquoteBlock({required this.text, this.spans = const []}) : super(EpubBlockType.blockquote);
}

class EpubCodeBlock extends EpubBlock {
  final String code;
  const EpubCodeBlock({required this.code}) : super(EpubBlockType.code);
}

class EpubChapter {
  final String id;
  final String title;
  final String content;
  final String html;
  final List<EpubBlock> blocks;
  final String? href;

  const EpubChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.html,
    this.blocks = const [],
    this.href,
  });

  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
}

class EpubDocument {
  final String title;
  final String author;
  final List<EpubChapter> chapters;
  final Map<String, Uint8List> images;

  const EpubDocument({
    required this.title,
    required this.author,
    required this.chapters,
    this.images = const {},
  });

  int get totalWords => chapters.fold<int>(0, (sum, ch) => sum + ch.wordCount);
}

class EpubParser {
  EpubParser._();

  static const int _maxInputBytes = 100 * 1024 * 1024; // 100MB ceiling

  /// Safe encoding decoder: handles UTF-8 with seamless fallback to Latin-1/ISO-8859-1
  /// so accented characters and European encodings never corrupt or throw exceptions.
  static String decodeBytesWithFallback(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  static EpubDocument parse(Uint8List bytes) {
    if (bytes.length > _maxInputBytes) {
      throw FormatException(
        'EPUB file exceeds size limit (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB).',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw FormatException('Failed to extract EPUB zip archive: $e');
    }

    final fileMap = <String, ArchiveFile>{};
    for (final f in archive) {
      fileMap[f.name] = f;
      // Map normalized path without leading slash
      if (f.name.startsWith('/')) {
        fileMap[f.name.substring(1)] = f;
      }
      fileMap[f.name.toLowerCase()] = f;
    }

    // 1. Locate META-INF/container.xml
    ArchiveFile? containerFile = fileMap['META-INF/container.xml'] ??
        fileMap['meta-inf/container.xml'];
    if (containerFile == null) {
      for (final f in archive) {
        if (f.name.toLowerCase() == 'meta-inf/container.xml') {
          containerFile = f;
          break;
        }
      }
    }

    if (containerFile == null) {
      throw const FormatException('Invalid EPUB: META-INF/container.xml not found.');
    }

    final containerXml = decodeBytesWithFallback(containerFile.content as List<int>);
    final XmlDocument containerDoc;
    try {
      containerDoc = XmlDocument.parse(containerXml);
    } catch (e) {
      throw FormatException('Malformed container.xml in EPUB: $e');
    }

    final rootfileElem = containerDoc.findAllElements('rootfile').firstOrNull;
    if (rootfileElem == null) {
      throw const FormatException('Invalid EPUB: No rootfile declared in container.xml.');
    }

    final opfPath = rootfileElem.getAttribute('full-path') ?? 'OEBPS/content.opf';
    ArchiveFile? opfFile = fileMap[opfPath] ?? fileMap[opfPath.toLowerCase()];
    if (opfFile == null) {
      for (final f in archive) {
        if (f.name.toLowerCase() == opfPath.toLowerCase()) {
          opfFile = f;
          break;
        }
      }
    }

    if (opfFile == null) {
      throw FormatException('Invalid EPUB: OPF package document "$opfPath" not found.');
    }

    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

    // 2. Parse OPF document
    final opfXml = decodeBytesWithFallback(opfFile.content as List<int>);
    final XmlDocument opfDoc;
    try {
      opfDoc = XmlDocument.parse(opfXml);
    } catch (e) {
      throw FormatException('Malformed OPF document in EPUB: $e');
    }

    // Metadata
    String bookTitle = 'Untitled Book';
    String bookAuthor = 'Unknown Author';

    final titleElem = opfDoc.findAllElements('dc:title').firstOrNull ??
        opfDoc.findAllElements('title').firstOrNull;
    if (titleElem != null && titleElem.innerText.trim().isNotEmpty) {
      bookTitle = _cleanText(titleElem.innerText.trim());
    }

    final creatorElem = opfDoc.findAllElements('dc:creator').firstOrNull ??
        opfDoc.findAllElements('creator').firstOrNull;
    if (creatorElem != null && creatorElem.innerText.trim().isNotEmpty) {
      bookAuthor = _cleanText(creatorElem.innerText.trim());
    }

    // Manifest: id -> href, and media-type
    final manifestHrefMap = <String, String>{};
    final manifestTypeMap = <String, String>{};
    for (final item in opfDoc.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final mType = item.getAttribute('media-type');
      if (id != null && href != null) {
        manifestHrefMap[id] = href;
        if (mType != null) manifestTypeMap[id] = mType;
      }
    }

    // Extract images into a lookup map
    final imagesMap = <String, Uint8List>{};
    manifestHrefMap.forEach((id, href) {
      final mType = manifestTypeMap[id] ?? '';
      if (mType.startsWith('image/') || mType.contains('svg') || _isImageExtension(href)) {
        final decodedHref = Uri.decodeFull(href);
        final fullPath = _resolvePath(opfDir, decodedHref);
        final imgFile = fileMap[fullPath] ?? fileMap[decodedHref] ?? fileMap[fullPath.toLowerCase()];
        if (imgFile != null && imgFile.content is List<int>) {
          final bytes = Uint8List.fromList(imgFile.content as List<int>);
          imagesMap[href] = bytes;
          imagesMap[decodedHref] = bytes;
          imagesMap[fullPath] = bytes;
          imagesMap[fullPath.toLowerCase()] = bytes;
          final filename = decodedHref.contains('/') ? decodedHref.substring(decodedHref.lastIndexOf('/') + 1) : decodedHref;
          imagesMap[filename] = bytes;
          imagesMap[filename.toLowerCase()] = bytes;
        }
      }
    });

    // Direct archive scan for image files to ensure complete asset availability
    for (final f in archive) {
      if (_isImageExtension(f.name) && f.size > 0 && f.content is List<int>) {
        final bytes = Uint8List.fromList(f.content as List<int>);
        imagesMap.putIfAbsent(f.name, () => bytes);
        imagesMap.putIfAbsent(f.name.toLowerCase(), () => bytes);
        final fname = f.name.contains('/') ? f.name.substring(f.name.lastIndexOf('/') + 1) : f.name;
        imagesMap.putIfAbsent(fname, () => bytes);
        imagesMap.putIfAbsent(fname.toLowerCase(), () => bytes);
      }
    }

    // 3. Extract Table of Contents (NCX or EPUB 3 NAV document)
    final tocTitlesByHref = <String, String>{};

    // 3a. Check for NCX (EPUB 2)
    String? ncxHref;
    for (final entry in manifestHrefMap.entries) {
      final id = entry.key;
      final href = entry.value;
      final mType = manifestTypeMap[id] ?? '';
      if (mType == 'application/x-dtbncx+xml' || id.toLowerCase() == 'ncx' || href.toLowerCase().endsWith('.ncx')) {
        ncxHref = href;
        break;
      }
    }

    if (ncxHref != null) {
      final ncxPath = _resolvePath(opfDir, Uri.decodeFull(ncxHref));
      final ncxFile = fileMap[ncxPath] ?? fileMap[ncxPath.toLowerCase()];
      if (ncxFile != null && ncxFile.content is List<int>) {
        try {
          final ncxXml = decodeBytesWithFallback(ncxFile.content as List<int>);
          final ncxDoc = XmlDocument.parse(ncxXml);
          for (final navPoint in ncxDoc.findAllElements('navPoint')) {
            final textElem = navPoint.findElements('navLabel').firstOrNull?.findElements('text').firstOrNull;
            final contentElem = navPoint.findElements('content').firstOrNull;
            final title = textElem?.innerText.trim();
            final src = contentElem?.getAttribute('src');
            if (title != null && title.isNotEmpty && src != null && src.isNotEmpty) {
              final cleanSrc = Uri.decodeFull(src.split('#').first.split('?').first);
              final cleanTitle = _cleanText(title);
              tocTitlesByHref[cleanSrc] = cleanTitle;
              if (cleanSrc.contains('/')) {
                tocTitlesByHref[cleanSrc.substring(cleanSrc.lastIndexOf('/') + 1)] = cleanTitle;
              }
            }
          }
        } catch (_) {}
      }
    }

    // 3b. Check for EPUB 3 Navigation Document (nav.xhtml)
    for (final item in opfDoc.findAllElements('item')) {
      final props = item.getAttribute('properties') ?? '';
      final href = item.getAttribute('href') ?? '';
      if (props.contains('nav') || href.toLowerCase().endsWith('nav.xhtml') || href.toLowerCase().endsWith('nav.html')) {
        final navPath = _resolvePath(opfDir, Uri.decodeFull(href));
        final navFile = fileMap[navPath] ?? fileMap[navPath.toLowerCase()];
        if (navFile != null && navFile.content is List<int>) {
          try {
            final navXml = decodeBytesWithFallback(navFile.content as List<int>);
            final navDoc = XmlDocument.parse(navXml);
            for (final a in navDoc.findAllElements('a')) {
              final aHref = a.getAttribute('href');
              final aText = a.innerText.trim();
              if (aHref != null && aText.isNotEmpty) {
                final cleanSrc = Uri.decodeFull(aHref.split('#').first.split('?').first);
                final cleanTitle = _cleanText(aText);
                if (!tocTitlesByHref.containsKey(cleanSrc)) {
                  tocTitlesByHref[cleanSrc] = cleanTitle;
                  if (cleanSrc.contains('/')) {
                    tocTitlesByHref[cleanSrc.substring(cleanSrc.lastIndexOf('/') + 1)] = cleanTitle;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    // 4. Spine: reading order of idrefs
    final spineIds = <String>[];
    for (final itemref in opfDoc.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null) {
        spineIds.add(idref);
      }
    }

    // 5. Extract and parse chapters
    final chapters = <EpubChapter>[];
    var chapterIndex = 1;

    for (final id in spineIds) {
      final relativeHref = manifestHrefMap[id];
      if (relativeHref == null) continue;

      final decodedHref = Uri.decodeFull(relativeHref);
      final fullPath = _resolvePath(opfDir, decodedHref);

      ArchiveFile? chapterFile = fileMap[fullPath] ??
          fileMap[decodedHref] ??
          fileMap[fullPath.toLowerCase()] ??
          fileMap[decodedHref.toLowerCase()];

      if (chapterFile == null) {
        for (final f in archive) {
          if (f.name.toLowerCase() == fullPath.toLowerCase() ||
              f.name.toLowerCase() == decodedHref.toLowerCase()) {
            chapterFile = f;
            break;
          }
        }
      }

      if (chapterFile == null || chapterFile.size == 0) continue;

      try {
        final chapterHtml = decodeBytesWithFallback(chapterFile.content as List<int>);
        final chapterDir = fullPath.contains('/')
            ? fullPath.substring(0, fullPath.lastIndexOf('/') + 1)
            : opfDir;

        final cleanHref = decodedHref.split('#').first.split('?').first;
        final filename = cleanHref.contains('/') ? cleanHref.substring(cleanHref.lastIndexOf('/') + 1) : cleanHref;

        // Title preference: TOC entry > Heading in document > Clean HTML Title > Fallback
        String title = tocTitlesByHref[cleanHref] ?? tocTitlesByHref[filename] ?? '';
        if (title.isEmpty) {
          title = _extractChapterTitle(chapterHtml, bookTitle, chapterIndex);
        }

        final blocks = _parseHtmlToBlocks(chapterHtml, imagesMap, chapterDir);
        final plainText = _htmlToPlainText(chapterHtml);

        if (plainText.trim().isNotEmpty || blocks.isNotEmpty) {
          chapters.add(EpubChapter(
            id: id,
            title: title,
            content: plainText,
            html: chapterHtml,
            blocks: blocks,
            href: relativeHref,
          ));
          chapterIndex++;
        }
      } catch (_) {
        // Skip unparseable chapter gracefully
      }
    }

    if (chapters.isEmpty) {
      // Fallback: search for any HTML/XHTML files in archive
      for (final f in archive) {
        final lower = f.name.toLowerCase();
        if ((lower.endsWith('.html') || lower.endsWith('.xhtml') || lower.endsWith('.htm')) &&
            !lower.contains('toc') && f.size > 0) {
          try {
            final html = decodeBytesWithFallback(f.content as List<int>);
            final title = _extractChapterTitle(html, bookTitle, chapterIndex);
            final blocks = _parseHtmlToBlocks(html, imagesMap, opfDir);
            final plainText = _htmlToPlainText(html);
            if (plainText.trim().isNotEmpty || blocks.isNotEmpty) {
              chapters.add(EpubChapter(
                id: 'fallback_$chapterIndex',
                title: title,
                content: plainText,
                html: html,
                blocks: blocks,
                href: f.name,
              ));
              chapterIndex++;
            }
          } catch (_) {}
        }
      }
    }

    return EpubDocument(
      title: bookTitle,
      author: bookAuthor,
      chapters: chapters,
      images: imagesMap,
    );
  }

  static bool _isImageExtension(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg');
  }

  static String _resolvePath(String baseDir, String relativePath) {
    var cleanRel = relativePath.split('?').first.split('#').first;
    if (cleanRel.startsWith('/')) cleanRel = cleanRel.substring(1);
    if (cleanRel.startsWith('./')) cleanRel = cleanRel.substring(2);

    final combined = baseDir.isEmpty ? cleanRel : (baseDir.endsWith('/') ? '$baseDir$cleanRel' : '$baseDir/$cleanRel');
    final segments = <String>[];
    for (final seg in combined.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else {
        segments.add(seg);
      }
    }
    return segments.join('/');
  }

  static String _extractChapterTitle(String html, String bookTitle, int fallbackIndex) {
    try {
      // 1. First Heading h1 / h2 / h3 in document
      final hMatch = RegExp(r'<h[1-3][^>]*>(.*?)</h[1-3]>', caseSensitive: false, dotAll: true).firstMatch(html);
      if (hMatch != null && hMatch.group(1)!.trim().isNotEmpty) {
        final hText = _cleanText(_stripTags(hMatch.group(1)!));
        if (hText.isNotEmpty && hText.toLowerCase() != bookTitle.toLowerCase()) {
          return hText;
        }
      }

      // 2. <title> tag, but ignore if it just repeats the overall book title or has file extension
      final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
      if (titleMatch != null && titleMatch.group(1)!.trim().isNotEmpty) {
        final tText = _cleanText(_stripTags(titleMatch.group(1)!));
        if (tText.isNotEmpty &&
            tText.toLowerCase() != bookTitle.toLowerCase() &&
            !tText.toLowerCase().contains('.html') &&
            !tText.toLowerCase().contains('.xhtml')) {
          return tText;
        }
      }
    } catch (_) {}

    return 'Chapter $fallbackIndex';
  }

  /// Sanitizes HTML markup so that it can be parsed cleanly by XmlDocument without errors.
  static String _sanitizeForXml(String rawHtml) {
    var s = rawHtml;
    // Strip comments, head, script, style, doctype, and xml declaration
    s = s.replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<\?xml[^>]*\?>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    s = s.replaceAll(RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

    // Replace named HTML entities with Unicode characters before XML parse
    s = _cleanEntities(s);

    // Escape any remaining bare ampersands not part of a valid XML entity reference
    s = s.replaceAllMapped(RegExp(r'&(?!(?:amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)'), (m) => '&amp;');

    // Self-close void HTML elements if they are not already self-closed
    s = s.replaceAllMapped(RegExp(r'<br\b([^>]*?)(?<!/)>', caseSensitive: false), (m) => '<br${m[1]}/>');
    s = s.replaceAllMapped(RegExp(r'<hr\b([^>]*?)(?<!/)>', caseSensitive: false), (m) => '<hr${m[1]}/>');
    s = s.replaceAllMapped(RegExp(r'<img\b([^>]*?)(?<!/)>', caseSensitive: false), (m) => '<img${m[1]}/>');

    return s;
  }

  static const _blockTags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'table',
    'ul',
    'ol',
    'blockquote',
    'pre',
    'hr',
    'img',
    'image',
    'svg',
  };

  static const _containerTags = {
    'div',
    'section',
    'article',
    'main',
    'header',
    'footer',
    'aside',
    'figure',
    'figcaption',
    'details',
    'center',
    'dd',
    'dt',
    'li',
    'body',
    'html',
  };

  static bool _hasBlockDescendants(XmlNode node) {
    if (node is! XmlElement) return false;
    for (final child in node.children) {
      if (child is XmlElement) {
        final t = child.name.local.toLowerCase();
        if (_blockTags.contains(t)) return true;
        if (_containerTags.contains(t) && _hasBlockDescendants(child)) return true;
      }
    }
    return false;
  }

  static List<EpubBlock> _parseHtmlToBlocks(
    String html,
    Map<String, Uint8List> imagesMap,
    String chapterDir,
  ) {
    final blocks = <EpubBlock>[];

    try {
      final sanitized = _sanitizeForXml(html);

      XmlDocument doc;
      try {
        doc = XmlDocument.parse(sanitized);
      } catch (_) {
        doc = XmlDocument.parse('<body>$sanitized</body>');
      }

      final bodies = doc.findAllElements('body');
      final root = bodies.isNotEmpty ? bodies.last : doc.rootElement;

      void processContainer(XmlNode containerNode) {
        final inlineBuffer = <EpubInlineSpan>[];

        void flushInlineBuffer() {
          if (inlineBuffer.isEmpty) return;
          _normalizeInlineSpans(inlineBuffer);
          if (inlineBuffer.isNotEmpty) {
            final plain = inlineBuffer.map((s) => s.text).join('').trim();
            if (plain.isNotEmpty) {
              blocks.add(EpubParagraphBlock(
                spans: List<EpubInlineSpan>.from(inlineBuffer),
                plainText: plain,
              ));
            }
          }
          inlineBuffer.clear();
        }

        for (final child in containerNode.children) {
          if (child is XmlText) {
            final decoded = _cleanEntities(child.value);
            final collapsed = decoded.replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
            if (collapsed.isNotEmpty && collapsed != ' ') {
              inlineBuffer.add(EpubInlineSpan(text: collapsed));
            } else if (collapsed == ' ') {
              if (inlineBuffer.isNotEmpty && !inlineBuffer.last.text.endsWith(' ')) {
                inlineBuffer.add(const EpubInlineSpan(text: ' '));
              }
            }
          } else if (child is XmlElement) {
            final tag = child.name.local.toLowerCase();

            if (tag == 'br') {
              inlineBuffer.add(const EpubInlineSpan(text: '\n'));
            } else if (tag.startsWith('h') && tag.length == 2 && int.tryParse(tag.substring(1)) != null) {
              flushInlineBuffer();
              final lvl = int.parse(tag.substring(1));
              final txt = _cleanText(child.innerText);
              if (txt.isNotEmpty) blocks.add(EpubHeadingBlock(level: lvl, text: txt));
            } else if (tag == 'p') {
              flushInlineBuffer();
              _extractImagesFromElement(child, blocks, imagesMap, chapterDir);
              final spans = _extractInlineSpans(child);
              final txt = _cleanText(child.innerText);
              if (spans.isNotEmpty && txt.isNotEmpty) {
                blocks.add(EpubParagraphBlock(spans: spans, plainText: txt));
              }
            } else if (tag == 'img' || tag == 'image') {
              flushInlineBuffer();
              final src = child.getAttribute('src') ??
                  child.getAttribute('xlink:href') ??
                  child.getAttribute('href') ??
                  '';
              final alt = child.getAttribute('alt') ?? '';
              final bytes = _lookupImage(src, imagesMap, chapterDir);
              if (bytes != null) blocks.add(EpubImageBlock(imageBytes: bytes, alt: alt));
            } else if (tag == 'svg') {
              flushInlineBuffer();
              final imgElem = child.findAllElements('image').firstOrNull;
              if (imgElem != null) {
                final src = imgElem.getAttribute('xlink:href') ?? imgElem.getAttribute('href') ?? '';
                final bytes = _lookupImage(src, imagesMap, chapterDir);
                if (bytes != null) blocks.add(EpubImageBlock(imageBytes: bytes, alt: ''));
              }
            } else if (tag == 'table') {
              flushInlineBuffer();
              final headers = <String>[];
              final rows = <List<String>>[];
              for (final tr in child.findAllElements('tr')) {
                final ths = tr.findElements('th').map((e) => _cleanText(e.innerText)).toList();
                if (ths.isNotEmpty) {
                  headers.addAll(ths);
                } else {
                  final tds = tr.findElements('td').map((e) => _cleanText(e.innerText)).toList();
                  if (tds.isNotEmpty) rows.add(tds);
                }
              }
              if (headers.isNotEmpty || rows.isNotEmpty) {
                blocks.add(EpubTableBlock(headers: headers, rows: rows));
              }
            } else if (tag == 'ul' || tag == 'ol') {
              flushInlineBuffer();
              final items = child
                  .findElements('li')
                  .map((li) => _cleanText(li.innerText))
                  .where((t) => t.isNotEmpty)
                  .toList();
              if (items.isEmpty) {
                items.addAll(
                  child.findAllElements('li').map((li) => _cleanText(li.innerText)).where((t) => t.isNotEmpty),
                );
              }
              if (items.isNotEmpty) blocks.add(EpubListBlock(items: items, isOrdered: tag == 'ol'));
            } else if (tag == 'blockquote') {
              flushInlineBuffer();
              final spans = _extractInlineSpans(child);
              final txt = _cleanText(child.innerText);
              if (txt.isNotEmpty) {
                blocks.add(EpubBlockquoteBlock(text: txt, spans: spans));
              }
            } else if (tag == 'pre') {
              flushInlineBuffer();
              final code = _cleanEntities(child.innerText);
              if (code.trim().isNotEmpty) {
                blocks.add(EpubCodeBlock(code: code.trimRight()));
              }
            } else if (tag == 'hr') {
              flushInlineBuffer();
              blocks.add(const EpubDividerBlock());
            } else if (_containerTags.contains(tag)) {
              if (_hasBlockDescendants(child)) {
                flushInlineBuffer();
                processContainer(child);
              } else {
                _extractImagesFromElement(child, blocks, imagesMap, chapterDir);
                final spans = _extractInlineSpans(child);
                inlineBuffer.addAll(spans);
              }
            } else {
              // Inline element: span, b, i, strong, em, a, code, sub, sup, etc.
              final spans = _extractInlineSpans(child);
              inlineBuffer.addAll(spans);
            }
          }
        }

        flushInlineBuffer();
      }

      processContainer(root);
    } catch (_) {
      // Regex fallback parser for non-well-formed HTML
      _parseWithRegex(html, blocks, imagesMap, chapterDir);
    }

    return blocks;
  }

  static void _extractImagesFromElement(
    XmlElement elem,
    List<EpubBlock> blocks,
    Map<String, Uint8List> imagesMap,
    String chapterDir,
  ) {
    final imgTags = elem.findAllElements('img').toList();
    imgTags.addAll(elem.findAllElements('image'));

    for (final imgElem in imgTags) {
      final src = imgElem.getAttribute('src') ??
          imgElem.getAttribute('xlink:href') ??
          imgElem.getAttribute('href') ??
          '';
      final alt = imgElem.getAttribute('alt') ?? '';
      final bytes = _lookupImage(src, imagesMap, chapterDir);
      if (bytes != null) blocks.add(EpubImageBlock(imageBytes: bytes, alt: alt));
    }
  }

  static Uint8List? _lookupImage(String src, Map<String, Uint8List> imagesMap, String chapterDir) {
    if (src.isEmpty) return null;
    final clean = src.split('?').first.split('#').first;
    final decoded = Uri.decodeFull(clean);

    // 1. Direct match
    if (imagesMap.containsKey(clean)) return imagesMap[clean];
    if (imagesMap.containsKey(decoded)) return imagesMap[decoded];
    if (imagesMap.containsKey(clean.toLowerCase())) return imagesMap[clean.toLowerCase()];
    if (imagesMap.containsKey(decoded.toLowerCase())) return imagesMap[decoded.toLowerCase()];

    // 2. Resolved relative to chapter file directory
    final resolved = _resolvePath(chapterDir, decoded);
    if (imagesMap.containsKey(resolved)) return imagesMap[resolved];
    if (imagesMap.containsKey(resolved.toLowerCase())) return imagesMap[resolved.toLowerCase()];

    // 3. Resolved clean
    final resolvedClean = _resolvePath(chapterDir, clean);
    if (imagesMap.containsKey(resolvedClean)) return imagesMap[resolvedClean];
    if (imagesMap.containsKey(resolvedClean.toLowerCase())) return imagesMap[resolvedClean.toLowerCase()];

    // 4. Fallback by filename
    final filename = decoded.contains('/') ? decoded.substring(decoded.lastIndexOf('/') + 1) : decoded;
    if (imagesMap.containsKey(filename)) return imagesMap[filename];
    if (imagesMap.containsKey(filename.toLowerCase())) return imagesMap[filename.toLowerCase()];

    return null;
  }

  static void _normalizeInlineSpans(List<EpubInlineSpan> spans) {
    if (spans.isEmpty) return;
    spans.removeWhere((s) => s.text.isEmpty);
    if (spans.isEmpty) return;

    // Trim leading whitespace on first span
    final first = spans.first;
    if (first.text.startsWith(' ')) {
      final t = first.text.trimLeft();
      if (t.isEmpty) {
        spans.removeAt(0);
      } else {
        spans[0] = EpubInlineSpan(
          text: t,
          isBold: first.isBold,
          isItalic: first.isItalic,
          isUnderline: first.isUnderline,
          isCode: first.isCode,
        );
      }
    }
    if (spans.isEmpty) return;

    // Trim trailing whitespace on last span
    final last = spans.last;
    if (last.text.endsWith(' ')) {
      final t = last.text.trimRight();
      if (t.isEmpty) {
        spans.removeLast();
      } else {
        spans[spans.length - 1] = EpubInlineSpan(
          text: t,
          isBold: last.isBold,
          isItalic: last.isItalic,
          isUnderline: last.isUnderline,
          isCode: last.isCode,
        );
      }
    }
  }

  static List<EpubInlineSpan> _extractInlineSpans(XmlNode root) {
    final spans = <EpubInlineSpan>[];

    void recurse(
      XmlNode n, {
      bool isB = false,
      bool isI = false,
      bool isU = false,
      bool isC = false,
    }) {
      if (n is XmlText) {
        final decoded = _cleanEntities(n.value);
        // Collapse tabs, newlines, and multiple spaces into a single space
        final collapsed = decoded.replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
        if (collapsed.isNotEmpty && collapsed != ' ') {
          spans.add(EpubInlineSpan(
            text: collapsed,
            isBold: isB,
            isItalic: isI,
            isUnderline: isU,
            isCode: isC,
          ));
        } else if (collapsed == ' ') {
          // Preserve inter-word single space
          if (spans.isNotEmpty && !spans.last.text.endsWith(' ')) {
            spans.add(const EpubInlineSpan(text: ' '));
          }
        }
      } else if (n is XmlElement) {
        final tag = n.name.local.toLowerCase();
        if (tag == 'br') {
          spans.add(const EpubInlineSpan(text: '\n'));
          return;
        }
        if (tag == 'img' || tag == 'image') return;

        final nextB = isB || tag == 'b' || tag == 'strong';
        final nextI = isI || tag == 'i' || tag == 'em' || tag == 'cite' || tag == 'dfn';
        final nextU = isU || tag == 'u' || tag == 'ins' || tag == 'a';
        final nextC = isC || tag == 'code' || tag == 'kbd' || tag == 'samp' || tag == 'tt';

        for (final child in n.children) {
          recurse(child, isB: nextB, isI: nextI, isU: nextU, isC: nextC);
        }
      }
    }

    recurse(root);
    _normalizeInlineSpans(spans);
    return spans;
  }

  static void _parseWithRegex(
    String html,
    List<EpubBlock> blocks,
    Map<String, Uint8List> imagesMap,
    String chapterDir,
  ) {
    final pattern = RegExp(
      r'<(h[1-6]|p|div|section|table|ul|ol|blockquote|pre|figure|img|hr)[^>]*>([\s\S]*?)<\/\1>|<(img|hr)[^>]*\/?>',
      caseSensitive: false,
    );

    final matches = pattern.allMatches(html);
    for (final m in matches) {
      final tag = (m.group(1) ?? m.group(3) ?? '').toLowerCase();
      final inner = m.group(2) ?? '';

      if (tag.startsWith('h')) {
        final lvl = int.tryParse(tag.substring(1)) ?? 1;
        final txt = _cleanText(_stripTags(inner));
        if (txt.isNotEmpty) blocks.add(EpubHeadingBlock(level: lvl, text: txt));
      } else if (tag == 'p' || tag == 'div' || tag == 'section' || tag == 'figure') {
        // Look for image inside
        final srcMatch = RegExp(r'<img[^>]+src=["\x27](.*?)["\x27]', caseSensitive: false).firstMatch(inner);
        if (srcMatch != null) {
          final src = srcMatch.group(1) ?? '';
          final bytes = _lookupImage(src, imagesMap, chapterDir);
          if (bytes != null) blocks.add(EpubImageBlock(imageBytes: bytes, alt: ''));
        }
        final txt = _cleanText(_stripTags(inner));
        if (txt.isNotEmpty) {
          blocks.add(EpubParagraphBlock(
            spans: [EpubInlineSpan(text: txt)],
            plainText: txt,
          ));
        }
      } else if (tag == 'ul' || tag == 'ol') {
        final liPattern = RegExp(r'<li[^>]*>([\s\S]*?)<\/li>', caseSensitive: false);
        final items = liPattern
            .allMatches(inner)
            .map((lm) => _cleanText(_stripTags(lm.group(1) ?? '')))
            .where((t) => t.isNotEmpty)
            .toList();
        if (items.isNotEmpty) blocks.add(EpubListBlock(items: items, isOrdered: tag == 'ol'));
      } else if (tag == 'blockquote') {
        final txt = _cleanText(_stripTags(inner));
        if (txt.isNotEmpty) blocks.add(EpubBlockquoteBlock(text: txt));
      } else if (tag == 'pre') {
        final code = _cleanEntities(inner);
        if (code.trim().isNotEmpty) blocks.add(EpubCodeBlock(code: code.trimRight()));
      } else if (tag == 'img') {
        final fullMatch = m.group(0) ?? '';
        final srcMatch = RegExp(r'src=["\x27](.*?)["\x27]', caseSensitive: false).firstMatch(fullMatch);
        if (srcMatch != null) {
          final src = srcMatch.group(1) ?? '';
          final bytes = _lookupImage(src, imagesMap, chapterDir);
          if (bytes != null) blocks.add(EpubImageBlock(imageBytes: bytes, alt: ''));
        }
      } else if (tag == 'hr') {
        blocks.add(const EpubDividerBlock());
      }
    }
  }

  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  static String _htmlToPlainText(String html) {
    var text = html;
    text = text.replaceAll(RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</?(p|div|section|article|h[1-6]|blockquote)[^>]*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'</?li[^>]*>', caseSensitive: false), '\n• ');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    return _cleanText(text);
  }

  static String _cleanEntities(String s) {
    if (!s.contains('&')) return s;
    var out = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&egrave;', 'è')
        .replaceAll('&agrave;', 'à')
        .replaceAll('&ccedil;', 'ç')
        .replaceAll('&ocirc;', 'ô')
        .replaceAll('&ucirc;', 'û')
        .replaceAll('&icirc;', 'î')
        .replaceAll('&iuml;', 'ï')
        .replaceAll('&euml;', 'ë');

    out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      if (code != null && code > 0 && code < 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return m.group(0)!;
    });

    out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      if (code != null && code > 0 && code < 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return m.group(0)!;
    });

    return out;
  }

  static String _cleanText(String text) {
    var cleaned = _cleanEntities(text);
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }
}

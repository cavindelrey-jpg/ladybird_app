// test/epub_parser_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/epub_parser.dart';

Uint8List createMockEpubBytes({
  required String title,
  required String author,
  required List<Map<String, String>> chapters, // [{id, href, title, html}]
  Map<String, Uint8List>? images,
  bool useLatin1Encoding = false,
}) {
  final archive = Archive();

  // 1. mimetype (uncompressed first file in EPUB standard)
  final mimeBytes = utf8.encode('application/epub+zip');
  archive.addFile(ArchiveFile('mimetype', mimeBytes.length, mimeBytes));

  // 2. META-INF/container.xml
  const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
  final containerBytes = utf8.encode(containerXml);
  archive.addFile(ArchiveFile('META-INF/container.xml', containerBytes.length, containerBytes));

  // 3. OEBPS/content.opf
  final manifestBuf = StringBuffer();
  final spineBuf = StringBuffer();

  for (final ch in chapters) {
    manifestBuf.writeln('<item id="${ch['id']}" href="${ch['href']}" media-type="application/xhtml+xml"/>');
    spineBuf.writeln('<itemref idref="${ch['id']}"/>');
  }

  if (images != null) {
    var imgIdx = 1;
    images.forEach((path, _) {
      manifestBuf.writeln('<item id="img$imgIdx" href="$path" media-type="image/png"/>');
      imgIdx++;
    });
  }

  final opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    $manifestBuf
  </manifest>
  <spine>
    $spineBuf
  </spine>
</package>''';
  final opfBytes = utf8.encode(opfXml);
  archive.addFile(ArchiveFile('OEBPS/content.opf', opfBytes.length, opfBytes));

  // 4. Chapter content files
  for (final ch in chapters) {
    final html = ch['html'] ?? '<p>Default text</p>';
    final htmlBytes = useLatin1Encoding ? latin1.encode(html) : utf8.encode(html);
    archive.addFile(ArchiveFile('OEBPS/${ch['href']}', htmlBytes.length, htmlBytes));
  }

  // 5. Images
  if (images != null) {
    images.forEach((path, bytes) {
      archive.addFile(ArchiveFile('OEBPS/$path', bytes.length, bytes));
    });
  }

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  group('EPUB Parser and Engine Tests (P2)', () {
    test('1. Correctly unzips, reads container.xml and OPF, extracts metadata', () {
      final epubBytes = createMockEpubBytes(
        title: 'Physics for Advanced Level',
        author: 'Dr. John Ngu',
        chapters: [
          {
            'id': 'ch1',
            'href': 'chapter1.xhtml',
            'title': 'Chapter 1: Kinematics',
            'html': '''<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1: Kinematics</title></head>
<body>
  <h1>Chapter 1: Kinematics</h1>
  <p>Motion in one and two dimensions.</p>
</body>
</html>''',
          },
        ],
      );

      final doc = EpubParser.parse(epubBytes);

      expect(doc.title, equals('Physics for Advanced Level'));
      expect(doc.author, equals('Dr. John Ngu'));
      expect(doc.chapters.length, equals(1));
      expect(doc.chapters[0].title, equals('Chapter 1: Kinematics'));
      expect(doc.chapters[0].content, contains('Motion in one and two dimensions.'));
    });

    test('2. Accented characters and French/Cameroonian text render without corruption', () {
      const accentedHtml = '''<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Littérature et Éducation</title></head>
<body>
  <h1>Introduction générale à l'écosystème éducatif</h1>
  <p>L'élève camerounais découvre la géographie et l'économie avec ferveur : ça commence à Yaoundé !</p>
  <p>Caractères accentués : à é è ê ë î ï ô ö ù û ü ç œ æ.</p>
</body>
</html>''';

      final epubBytes = createMockEpubBytes(
        title: 'Manuel de Français Form 3',
        author: 'Professeur Amadou',
        chapters: [
          {
            'id': 'ch1',
            'href': 'french.xhtml',
            'title': 'Littérature et Éducation',
            'html': accentedHtml,
          },
        ],
        useLatin1Encoding: false,
      );

      final doc = EpubParser.parse(epubBytes);
      final ch = doc.chapters[0];

      expect(ch.content, contains("L'élève camerounais découvre la géographie"));
      expect(ch.content, contains('ça commence à Yaoundé'));
      expect(ch.content, contains('à é è ê ë î ï ô ö ù û ü ç'));
    });

    test('3. Fallback encoding decodes Latin-1 encoded archives without crashing', () {
      const latin1Text = '''<html xmlns="http://www.w3.org/1999/xhtml">
<body>
  <h2>Chapitre spécialisé</h2>
  <p>Résultats de l'évaluation : succès garanti.</p>
</body>
</html>''';

      final epubBytes = createMockEpubBytes(
        title: 'Latin-1 Book',
        author: 'Auteur',
        chapters: [
          {
            'id': 'ch1',
            'href': 'latin1.xhtml',
            'title': 'Chapitre',
            'html': latin1Text,
          },
        ],
        useLatin1Encoding: true,
      );

      final doc = EpubParser.parse(epubBytes);
      expect(doc.chapters[0].content, contains("Résultats de l'évaluation"));
    });

    test('4. Renders XHTML headings, tables, lists, and images in structured blocks', () {
      final fakeImageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      const richHtml = '''<html xmlns="http://www.w3.org/1999/xhtml">
<body>
  <h1>Periodic Table Study</h1>
  <p>Here is an overview of <b>elements</b> and <i>compounds</i>:</p>
  <table>
    <tr><th>Element</th><th>Symbol</th><th>Atomic Number</th></tr>
    <tr><td>Hydrogen</td><td>H</td><td>1</td></tr>
    <tr><td>Helium</td><td>He</td><td>2</td></tr>
  </table>
  <img src="periodic_table.png" alt="Periodic Table Diagram" />
  <ul>
    <li>Alkali metals</li>
    <li>Noble gases</li>
  </ul>
</body>
</html>''';

      final epubBytes = createMockEpubBytes(
        title: 'Chemistry Book',
        author: 'Mme. Biya',
        chapters: [
          {
            'id': 'ch1',
            'href': 'chem.xhtml',
            'title': 'Chemistry',
            'html': richHtml,
          },
        ],
        images: {
          'periodic_table.png': fakeImageBytes,
        },
      );

      final doc = EpubParser.parse(epubBytes);
      final blocks = doc.chapters[0].blocks;

      expect(blocks.any((b) => b is EpubHeadingBlock), isTrue);
      expect(blocks.any((b) => b is EpubParagraphBlock), isTrue);
      expect(blocks.any((b) => b is EpubTableBlock), isTrue);
      expect(blocks.any((b) => b is EpubImageBlock), isTrue);
      expect(blocks.any((b) => b is EpubListBlock), isTrue);

      final tableBlock = blocks.firstWhere((b) => b is EpubTableBlock) as EpubTableBlock;
      expect(tableBlock.headers, equals(['Element', 'Symbol', 'Atomic Number']));
      expect(tableBlock.rows.length, equals(2));
      expect(tableBlock.rows[0], equals(['Hydrogen', 'H', '1']));

      final imageBlock = blocks.firstWhere((b) => b is EpubImageBlock) as EpubImageBlock;
      expect(imageBlock.imageBytes, isNotNull);
      expect(imageBlock.imageBytes, equals(fakeImageBytes));
    });

    test('5. Multi-chapter navigation follows spine reading order', () {
      final epubBytes = createMockEpubBytes(
        title: 'Biology 101',
        author: 'Teacher Paul',
        chapters: [
          {
            'id': 'c1',
            'href': 'c1.xhtml',
            'title': 'Chapter 1: Cells',
            'html': '<h1>Cells</h1><p>The unit of life.</p>',
          },
          {
            'id': 'c2',
            'href': 'c2.xhtml',
            'title': 'Chapter 2: Genetics',
            'html': '<h1>Genetics</h1><p>DNA and inheritance.</p>',
          },
          {
            'id': 'c3',
            'href': 'c3.xhtml',
            'title': 'Chapter 3: Ecology',
            'html': '<h1>Ecology</h1><p>Biomes and ecosystems.</p>',
          },
        ],
      );

      final doc = EpubParser.parse(epubBytes);

      expect(doc.chapters.length, equals(3));
      expect(doc.chapters[0].id, equals('c1'));
      expect(doc.chapters[1].id, equals('c2'));
      expect(doc.chapters[2].id, equals('c3'));
    });

    test('6. Preserves spaces around inline formatted spans without fusing words', () {
      final epubBytes = createMockEpubBytes(
        title: 'Grammar and Style',
        author: 'Prof. Fonlon',
        chapters: [
          {
            'id': 'c1',
            'href': 'c1.xhtml',
            'title': 'Chapter 1: Formatting',
            'html': '<p>This is <i>very</i> <b>important</b> text for <code>all</code> students.</p>',
          },
        ],
      );

      final doc = EpubParser.parse(epubBytes);
      final pBlock = doc.chapters[0].blocks.firstWhere((b) => b is EpubParagraphBlock) as EpubParagraphBlock;
      final reconstructed = pBlock.spans.map((s) => s.text).join();

      // Words must NOT be fused together (e.g. NOT "This isveryimportanttext")
      expect(reconstructed, contains('This is '));
      expect(reconstructed, contains('very'));
      expect(reconstructed, contains('important'));
      expect(reconstructed, equals('This is very important text for all students.'));
    });

    test('7. Extracts images wrapped inside paragraph tags and blockquotes', () {
      final fakeImg = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02]);
      final epubBytes = createMockEpubBytes(
        title: 'Art of Cameroon',
        author: 'Foumban Artisan',
        chapters: [
          {
            'id': 'c1',
            'href': 'c1.xhtml',
            'title': 'Chapter 1: Bronze Casting',
            'html': '''
              <blockquote>Art is the signature of civilization.</blockquote>
              <p><img src="bronze.png" alt="Bamum bronze statue" /></p>
              <pre>void castBronze() { heatFurnace(); }</pre>
            ''',
          },
        ],
        images: {
          'bronze.png': fakeImg,
        },
      );

      final doc = EpubParser.parse(epubBytes);
      final blocks = doc.chapters[0].blocks;

      expect(blocks.any((b) => b is EpubBlockquoteBlock), isTrue);
      expect(blocks.any((b) => b is EpubImageBlock), isTrue);
      expect(blocks.any((b) => b is EpubCodeBlock), isTrue);

      final img = blocks.firstWhere((b) => b is EpubImageBlock) as EpubImageBlock;
      expect(img.imageBytes, equals(fakeImg));
      expect(img.alt, equals('Bamum bronze statue'));
    });

    test('8. Parses Calibre-style nested divs, loose container text, entities, and unclosed void tags', () {
      final fakeImg = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x05, 0x06]);
      final epubBytes = createMockEpubBytes(
        title: 'Calibre Generated Book',
        author: 'Converter',
        chapters: [
          {
            'id': 'c1',
            'href': 'text/c1.xhtml',
            'title': 'Chapter 1: Div Layout',
            'html': '''
              <div class="calibre_1">
                Loose introduction text before heading.
                <div class="calibre_title"><h3>Section &nbsp; 1 &mdash; Diversity</h3></div>
                <div class="calibre_para">
                  <span>This paragraph is</span> authored inside <i>nested</i> divs.<br>
                  Second line after void break tag with accent: Caf&eacute;!
                </div>
                <div class="calibre_img">
                  <img src="../images/diagram.png" alt="Calibre diagram">
                </div>
                Loose concluding remarks after all divs.
              </div>
            ''',
          },
        ],
        images: {
          'images/diagram.png': fakeImg,
        },
      );

      final doc = EpubParser.parse(epubBytes);
      final blocks = doc.chapters[0].blocks;

      expect(blocks.isNotEmpty, isTrue);

      // Verify heading parsed
      final heading = blocks.whereType<EpubHeadingBlock>().firstOrNull;
      expect(heading, isNotNull);
      expect(heading!.text, contains('Section'));
      expect(heading.text, contains('Diversity'));

      // Verify paragraph blocks extracted from divs and loose text
      final paragraphs = blocks.whereType<EpubParagraphBlock>().toList();
      expect(paragraphs.length, greaterThanOrEqualTo(2));

      final allText = paragraphs.map((p) => p.plainText).join(' ');
      expect(allText, contains('Loose introduction text'));
      expect(allText, contains('authored inside nested divs'));
      expect(allText, contains('Café'));
      expect(allText, contains('Loose concluding remarks'));

      // Verify image resolved across relative path "../images/diagram.png"
      final img = blocks.whereType<EpubImageBlock>().firstOrNull;
      expect(img, isNotNull);
      expect(img!.imageBytes, equals(fakeImg));
    });
  });
}

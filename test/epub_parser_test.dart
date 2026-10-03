import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/epub_parser.dart';

void main() {
  test('parses chapters in spine order with titles, no duplicated heading', () {
    final doc = EpubParser.parse(File('test/fixtures/stories_of_cameroon.epub').readAsBytesSync());
    expect(doc.title, 'Stories of Cameroon');
    expect(doc.chapters.map((c) => c.title), ['The River at Edea', 'Market Day in Bafoussam', 'The Mountain']);
    final first = doc.chapters.first.content;
    expect('The River at Edea'.allMatches(first).length, 1, reason: 'head <title> must not be rendered as text');
    expect(first, contains('The Sanaga river runs wide'));
  });
}

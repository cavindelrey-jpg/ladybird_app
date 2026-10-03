import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/services/dictionary_service.dart';

void main() {
  test('every entry in the bundled dictionary parses (both JSON shapes)', () {
    final list = jsonDecode(File('assets/data/academia_dictionary.json').readAsStringSync()) as List;
    final entries = list.map((e) => DictionaryEntry.fromJson(e as Map<String, dynamic>)).toList();
    expect(entries.length, list.length);
    expect(entries.map((e) => e.id).toSet().length, entries.length, reason: 'ids must be unique');
    final aldehyde = entries.firstWhere((e) => e.word == 'Aldehyde');
    expect(aldehyde.difficulty, 4);
    expect(aldehyde.partOfSpeech, 'noun');
  });
}

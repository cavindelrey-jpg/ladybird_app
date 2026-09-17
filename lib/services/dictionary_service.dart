import 'dart:convert';
import 'package:flutter/services.dart';

class DictionaryEntry {
  final String word;
  final String definition;
  final String subject;
  final String example;

  DictionaryEntry({
    required this.word,
    required this.definition,
    required this.subject,
    required this.example,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      example: json['example'] as String? ?? '',
    );
  }
}

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  factory DictionaryService() => _instance;
  DictionaryService._internal();

  List<DictionaryEntry> _entries = [];
  bool _isLoaded = false;

  Future<void> loadDictionary() async {
    if (_isLoaded) return;
    try {
      final String response = await rootBundle.loadString('assets/data/academia_dictionary.json');
      final List<dynamic> data = json.decode(response);
      _entries = data.map((json) => DictionaryEntry.fromJson(json)).toList();
      _isLoaded = true;
    } catch (e) {
      print('Error loading dictionary: $e');
    }
  }

  List<DictionaryEntry> search(String query) {
    if (query.isEmpty) return _entries;
    final lowerQuery = query.toLowerCase();
    return _entries.where((entry) {
      return entry.word.toLowerCase().contains(lowerQuery) ||
             entry.subject.toLowerCase().contains(lowerQuery) ||
             entry.definition.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  List<DictionaryEntry> getAllEntries() => _entries;
}

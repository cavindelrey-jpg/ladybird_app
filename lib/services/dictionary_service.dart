import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class DictionaryEntry {
  final String id;
  final String word;
  final String definition;
  final String partOfSpeech;
  final String example;
  final int syllableCount;
  final int difficulty;
  final String discipline;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> relatedWords;
  final List<String> broaderTerms;
  final List<String> narrowerTerms;

  DictionaryEntry({
    required this.id, required this.word, required this.definition,
    required this.partOfSpeech, required this.example,
    required this.syllableCount, required this.difficulty,
    required this.discipline, required this.synonyms,
    required this.antonyms, required this.relatedWords,
    required this.broaderTerms, required this.narrowerTerms,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      id: json['id'] ?? '',
      word: json['word'] ?? '',
      definition: json['definition'] ?? '',
      partOfSpeech: json['part_of_speech'] ?? '',
      example: json['example'] ?? '',
      syllableCount: json['syllable_count'] ?? 1,
      difficulty: json['difficulty'] ?? 1,
      discipline: json['discipline'] ?? 'General',
      synonyms: List<String>.from(json['synonyms'] ?? []),
      antonyms: List<String>.from(json['antonyms'] ?? []),
      relatedWords: List<String>.from(json['related_words'] ?? []),
      broaderTerms: List<String>.from(json['broader_terms'] ?? []),
      narrowerTerms: List<String>.from(json['narrower_terms'] ?? []),
    );
  }
}

class DictionaryService {
  static final DictionaryService instance = DictionaryService._internal();
  factory DictionaryService() => instance;
  DictionaryService._internal();

  List<DictionaryEntry> _entries = [];
  Map<String, DictionaryEntry> _idMap = {};
  List<String> _recentIds = [];
  bool _isLoaded = false;
  
  List<DictionaryEntry> get allEntries => _entries;
  
  List<DictionaryEntry> get recentEntries => 
      _recentIds.map((id) => _idMap[id]).whereType<DictionaryEntry>().toList();

  Future<void> loadDictionary() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/data/academia_dictionary.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      _entries = jsonList.map((e) => DictionaryEntry.fromJson(e)).toList();
      _entries.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      
      for (var e in _entries) {
        _idMap[e.id] = e;
      }
      
      final prefs = await SharedPreferences.getInstance();
      _recentIds = prefs.getStringList('dictionary_recents') ?? [];
      
      _isLoaded = true;
    } catch (e) {
      print('Error loading Dictionary: \$e');
    }
  }
  
  DictionaryEntry? getEntryById(String id) => _idMap[id];
  
  void markAsViewed(String id) {
    _recentIds.remove(id);
    _recentIds.insert(0, id);
    if (_recentIds.length > 10) _recentIds = _recentIds.sublist(0, 10);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('dictionary_recents', _recentIds);
    });
  }

  List<DictionaryEntry> search(String query) {
    if (query.isEmpty) return _entries;
    final q = query.toLowerCase();
    
    // exact word matches first
    final exact = _entries.where((e) => e.word.toLowerCase() == q).toList();
    
    // partial word matches
    final partial = _entries.where((e) => e.word.toLowerCase().contains(q) && e.word.toLowerCase() != q).toList();
    
    // definition matches
    final inDef = _entries.where((e) => !e.word.toLowerCase().contains(q) && e.definition.toLowerCase().contains(q)).toList();
    
    // synonyms / related
    final related = _entries.where((e) {
      if (e.word.toLowerCase().contains(q) || e.definition.toLowerCase().contains(q)) return false;
      // We stored IDs in synonyms array, so we need to resolve them to words to search
      // Actually we just check if the query matches the words of those linked IDs
      bool matchLinks(List<String> ids) {
        for (var id in ids) {
           final linked = _idMap[id];
           if (linked != null && linked.word.toLowerCase().contains(q)) return true;
        }
        return false;
      }
      return matchLinks(e.synonyms) || matchLinks(e.relatedWords);
    }).toList();
    
    return [...exact, ...partial, ...inDef, ...related];
  }
  
  List<DictionaryEntry> getByLetter(String letter) {
    final l = letter.toLowerCase();
    return _entries.where((e) => e.word.toLowerCase().startsWith(l)).toList();
  }
  
  List<DictionaryEntry> getByDiscipline(String discipline) {
    return _entries.where((e) => e.discipline.toLowerCase() == discipline.toLowerCase()).toList();
  }
  
  List<String> getAllDisciplines() {
    final s = <String>{};
    for (var e in _entries) s.add(e.discipline);
    final l = s.toList();
    l.sort();
    return l;
  }
}

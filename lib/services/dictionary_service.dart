import 'dart:convert';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class DictionaryEntry {
  final String id;
  final String word;
  final String definition;
  final String explanation; // NEW FIELD
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
    required this.explanation,
    required this.partOfSpeech, required this.example,
    required this.syllableCount, required this.difficulty,
    required this.discipline, required this.synonyms,
    required this.antonyms, required this.relatedWords,
    required this.broaderTerms, required this.narrowerTerms,
  });

  /// Tolerates both shapes found in academia_dictionary.json: 10,001
  /// entries use snake_case with an int difficulty, but 8 (Aldehyde,
  /// Gravity, Addition...) use camelCase, a text difficulty ("Advanced")
  /// and no id. A single one of those used to throw and abort loading the
  /// WHOLE dictionary, so the Dictionary screen was empty for everyone.
  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    T? pick<T>(String snake, String camel) => (json[snake] ?? json[camel]) as T?;
    List<String> list(String snake, String camel) =>
        ((json[snake] ?? json[camel]) as List?)?.map((e) => e.toString()).toList() ?? const [];
    final word = (json['word'] ?? '').toString();
    return DictionaryEntry(
      id: (json['id'] ?? 'dict_${word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}').toString(),
      word: word,
      definition: (json['definition'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString(),
      partOfSpeech: pick<String>('part_of_speech', 'partOfSpeech') ?? '',
      example: (json['example'] ?? '').toString(),
      syllableCount: (pick<num>('syllable_count', 'syllableCount') ?? 1).toInt(),
      difficulty: _difficulty(json['difficulty']),
      discipline: (json['discipline'] ?? 'General').toString(),
      synonyms: list('synonyms', 'synonyms'),
      antonyms: list('antonyms', 'antonyms'),
      relatedWords: list('related_words', 'relatedWords'),
      broaderTerms: list('broader_terms', 'broaderTerms'),
      narrowerTerms: list('narrower_terms', 'narrowerTerms'),
    );
  }

  static int _difficulty(Object? v) {
    if (v is num) return v.toInt();
    switch (v?.toString().toLowerCase()) {
      case 'beginner': return 1;
      case 'elementary': return 2;
      case 'intermediate': return 3;
      case 'advanced': return 4;
      case 'expert': return 5;
    }
    return 3;
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
  bool _loadFailed = false;
  bool get isLoaded => _isLoaded;
  /// The last load attempt failed (the screen offers Retry instead of an
  /// endless spinner).
  bool get loadFailed => _loadFailed;
  
  List<DictionaryEntry> get allEntries => _entries;
  
  List<DictionaryEntry> get recentEntries => 
      _recentIds.map((id) => _idMap[id]).whereType<DictionaryEntry>().toList();

  Future<void>? _loading;

  /// Loads the bundled dictionary (assets/data -- nothing here ever touches
  /// the network). The 6 MB JSON is decoded and parsed on a background
  /// isolate: main() used to await this on the UI thread before the first
  /// frame, delaying every app launch. Concurrent callers share one load;
  /// a failed load can be retried.
  Future<void> loadDictionary() {
    if (_isLoaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    _loadFailed = false;
    try {
      final jsonString = await rootBundle.loadString('assets/data/academia_dictionary.json');
      final entries = await compute(_parseAll, jsonString);
      _entries = entries;
      _idMap = {for (final e in entries) e.id: e};
      try {
        final prefs = await SharedPreferences.getInstance();
        _recentIds = prefs.getStringList('dictionary_recents') ?? [];
      } catch (_) {}
      _isLoaded = true;
    } catch (e) {
      _loadFailed = true;
      debugPrint('Error loading Dictionary: $e');
    }
  }

  static List<DictionaryEntry> _parseAll(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    // Per-entry: one malformed entry must never empty the dictionary.
    final entries = [
      for (final e in jsonList)
        if (e is Map<String, dynamic>)
          if (_tryParse(e) case final entry?) entry,
    ]..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    return entries;
  }

  static DictionaryEntry? _tryParse(Map<String, dynamic> json) {
    try {
      final entry = DictionaryEntry.fromJson(json);
      return entry.word.isEmpty ? null : entry;
    } catch (e) {
      debugPrint('Skipping malformed dictionary entry ${json['word']}: $e');
      return null;
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
    
    // definition & explanation matches
    final inDef = _entries.where((e) {
      if (e.word.toLowerCase().contains(q)) return false;
      return e.definition.toLowerCase().contains(q) || e.explanation.toLowerCase().contains(q);
    }).toList();
    
    // synonyms / related
    final related = _entries.where((e) {
      if (e.word.toLowerCase().contains(q) || e.definition.toLowerCase().contains(q) || e.explanation.toLowerCase().contains(q)) return false;
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

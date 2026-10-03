import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dictionary_service.dart';
import '../theme/app_colors.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _searchController = TextEditingController();
  List<DictionaryEntry> _searchResults = [];
  bool _isSearching = false;
  String? _selectedLetter;
  String? _selectedDiscipline;
  
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DictionaryService.instance.loadDictionary();
    if (mounted) setState(() {});
  }
  
  void _onSearch(String q) {
    if (q.trim().isEmpty) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    setState(() {
      _isSearching = true;
      _selectedLetter = null;
      _selectedDiscipline = null;
      _searchResults = DictionaryService.instance.search(q.trim());
    });
  }
  
  void _openEntry(DictionaryEntry entry) {
    DictionaryService.instance.markAsViewed(entry.id);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DictionaryEntryScreen(entry: entry)));
  }
  
  void _openRandom() {
    final all = DictionaryService.instance.allEntries;
    if (all.isEmpty) return;
    final r = all[Random().nextInt(all.length)];
    _openEntry(r);
  }

  @override
  Widget build(BuildContext context) {
    final ac = Theme.of(context).extension<AppColors>()!;
    final all = DictionaryService.instance.allEntries;
    
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        title: Text('Academia Dictionary', style: GoogleFonts.lora(color: ac.txt, fontWeight: FontWeight.w600, fontSize: 18)),
        iconTheme: IconThemeData(color: ac.txt),
        actions: [
          IconButton(
            icon: Icon(Icons.casino_outlined, color: ac.primary),
            tooltip: 'Random Concept',
            onPressed: _openRandom,
          ),
        ],
      ),
      body: all.isEmpty
          ? Center(
              child: DictionaryService.instance.loadFailed
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('The dictionary couldn\'t be opened on this device.',
                            textAlign: TextAlign.center, style: TextStyle(color: ac.txt2)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () { setState(() {}); _load(); },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ]),
                    )
                  : CircularProgressIndicator(color: ac.primary),
            )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: TextStyle(color: ac.txt),
              decoration: InputDecoration(
                hintText: 'Search concepts, definitions, synonyms...',
                hintStyle: TextStyle(color: ac.muted),
                prefixIcon: Icon(Icons.search, color: ac.muted),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 20, color: ac.muted),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
                filled: true,
                fillColor: ac.surf,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          if (!_isSearching && _selectedLetter == null && _selectedDiscipline == null)
            _buildLanding(ac),
            
          if (_isSearching || _selectedLetter != null || _selectedDiscipline != null)
            Expanded(child: _buildResultsList(ac)),
        ],
      ),
    );
  }
  
  Widget _buildResultsList(AppColors ac) {
    List<DictionaryEntry> items = [];
    if (_isSearching) items = _searchResults;
    else if (_selectedLetter != null) items = DictionaryService.instance.getByLetter(_selectedLetter!);
    else if (_selectedDiscipline != null) items = DictionaryService.instance.getByDiscipline(_selectedDiscipline!);
    
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: ac.muted),
            const SizedBox(height: 16),
            Text('No concepts found', style: TextStyle(color: ac.txt, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('We couldn\'t find anything matching your search. Try adjusting your terms.', textAlign: TextAlign.center, style: TextStyle(color: ac.muted, fontSize: 14)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  label: const Text('Clear Search'),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                ),
                ActionChip(
                  label: const Text('Try a broader search'),
                  onPressed: () {},
                ),
                ActionChip(
                  label: const Text('Browse Academic Disciplines'),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                ),
              ],
            )
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final entry = items[i];
        return Card(
          elevation: 0,
          color: ac.surf,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: ac.bdr2)),
          child: ListTile(
            title: Row(
              children: [
                Expanded(child: Text(entry.word, style: GoogleFonts.lora(fontWeight: FontWeight.bold, fontSize: 16, color: ac.txt))),
                Text(entry.partOfSpeech, style: TextStyle(color: ac.muted, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(entry.definition, style: TextStyle(color: ac.txt2, height: 1.3)),
            ),
            onTap: () => _openEntry(entry),
          ),
        );
      },
    );
  }

  Widget _buildLanding(AppColors ac) {
    final recent = DictionaryService.instance.recentEntries;
    final disciplines = DictionaryService.instance.getAllDisciplines();
    
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Text('A-Z Index', style: TextStyle(color: ac.muted, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 26,
              itemBuilder: (context, i) {
                final letter = String.fromCharCode(65 + i);
                return InkWell(
                  onTap: () => setState(() { _selectedLetter = letter; _selectedDiscipline = null; }),
                  child: Container(
                    width: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ac.surf,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ac.bdr),
                    ),
                    alignment: Alignment.center,
                    child: Text(letter, style: GoogleFonts.lora(fontWeight: FontWeight.bold, color: ac.primary)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          if (recent.isNotEmpty) ...[
            Text('Recently Viewed', style: TextStyle(color: ac.muted, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: recent.map((e) => ActionChip(
                backgroundColor: ac.surf,
                side: BorderSide(color: ac.bdr),
                label: Text(e.word, style: TextStyle(color: ac.txt)),
                onPressed: () => _openEntry(e),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          Text('Academic Disciplines', style: TextStyle(color: ac.muted, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: disciplines.map((d) => InkWell(
              onTap: () => setState(() { _selectedDiscipline = d; _selectedLetter = null; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ac.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ac.primary.withValues(alpha: .3)),
                ),
                child: Text(d, style: TextStyle(color: ac.primary, fontWeight: FontWeight.w500, fontSize: 13)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class DictionaryEntryScreen extends StatelessWidget {
  final DictionaryEntry entry;
  const DictionaryEntryScreen({super.key, required this.entry});

  Widget _linkChip(BuildContext context, String id, AppColors ac, Color color) {
    final linked = DictionaryService.instance.getEntryById(id);
    if (linked == null) return const SizedBox.shrink();
    return ActionChip(
      backgroundColor: color.withValues(alpha: .1),
      side: BorderSide(color: color.withValues(alpha: .3)),
      label: Text(linked.word, style: TextStyle(color: color, fontSize: 13)),
      onPressed: () {
        DictionaryService.instance.markAsViewed(linked.id);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DictionaryEntryScreen(entry: linked)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(entry.word, style: GoogleFonts.lora(fontSize: 32, fontWeight: FontWeight.bold, color: ac.txt))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(entry.partOfSpeech, style: TextStyle(color: ac.primary, fontStyle: FontStyle.italic, fontSize: 16)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(4), border: Border.all(color: ac.bdr)),
                  child: Text(entry.discipline, style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('Lvl ${entry.difficulty}', style: TextStyle(color: ac.muted, fontSize: 12)),
                const SizedBox(width: 8),
                Text('${entry.syllableCount} syl', style: TextStyle(color: ac.muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 24),
            
            Text('DEFINITION', style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(entry.definition, style: GoogleFonts.lora(fontSize: 22, color: ac.txt, height: 1.3)),
            
            if (entry.explanation.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('EXPLANATION', style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(entry.explanation, style: TextStyle(color: ac.txt, fontSize: 16, height: 1.6)),
            ],
            
            if (entry.example.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('EXAMPLE', style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(8), border: Border.all(color: ac.bdr2)),
                child: Text('"${entry.example}"', style: TextStyle(color: ac.txt, fontStyle: FontStyle.italic, fontSize: 15, height: 1.4)),
              ),
            ],
            
            const SizedBox(height: 32),
            if (entry.synonyms.isNotEmpty) ...[
              Text('SYNONYMS', style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: entry.synonyms.map((id) => _linkChip(context, id, ac, ac.grn)).toList()),
              const SizedBox(height: 20),
            ],
            
            if (entry.antonyms.isNotEmpty) ...[
              Text('ANTONYMS', style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: entry.antonyms.map((id) => _linkChip(context, id, ac, Colors.red)).toList()),
              const SizedBox(height: 20),
            ],
            
            if (entry.relatedWords.isNotEmpty) ...[
              Text('RELATED CONCEPTS', style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: entry.relatedWords.map((id) => _linkChip(context, id, ac, ac.primary)).toList()),
              const SizedBox(height: 20),
            ],
            
            if (entry.broaderTerms.isNotEmpty) ...[
              Text('BROADER TERMS', style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: entry.broaderTerms.map((id) => _linkChip(context, id, ac, ac.gold)).toList()),
              const SizedBox(height: 20),
            ],
            
            if (entry.narrowerTerms.isNotEmpty) ...[
              Text('NARROWER TERMS', style: TextStyle(color: ac.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: entry.narrowerTerms.map((id) => _linkChip(context, id, ac, ac.pur)).toList()),
              const SizedBox(height: 20),
            ],
            
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

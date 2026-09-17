import 'package:flutter/material.dart';
import '../services/dictionary_service.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({Key? key}) : super(key: key);

  @override
  _DictionaryScreenState createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  List<DictionaryEntry> _results = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _dictionaryService.loadDictionary();
    setState(() {
      _results = _dictionaryService.getAllEntries();
    });
  }

  void _onSearch(String query) {
    setState(() {
      _query = query;
      _results = _dictionaryService.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academia Dictionary'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search offline dictionary...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No entries found.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final entry = _results[index];
                      return ListTile(
                        title: Text(entry.word, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${entry.subject}\n${entry.definition}'),
                        isThreeLine: true,
                        onTap: () {
                          // Show detail dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(entry.word),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Subject: ${entry.subject}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(entry.definition),
                                  const SizedBox(height: 8),
                                  if (entry.example.isNotEmpty) ...[
                                    const Text('Example:', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                                    Text(entry.example),
                                  ]
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

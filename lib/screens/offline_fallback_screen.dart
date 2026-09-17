import 'package:flutter/material.dart';
import 'dictionary_screen.dart';

class OfflineFallbackScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const OfflineFallbackScreen({Key? key, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'You are offline',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'It looks like you have lost your internet connection. Don\'t worry! You can still access your saved content and the Academia Dictionary.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text('Open Academia Dictionary'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DictionaryScreen()));
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

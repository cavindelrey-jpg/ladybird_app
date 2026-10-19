import 'package:flutter/material.dart';

class PublicPortalScreen extends StatelessWidget {
  const PublicPortalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CFPMI - Admissions & Portal'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Welcome to CFPMI', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text('Admissions Open for 2026/2027', style: TextStyle(fontSize: 24)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {}, 
                        style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                        child: const Text('Apply Now'),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Public Announcements', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const ListTile(
                title: Text('Term 1 Commences on September 15th'),
                subtitle: Text('Ensure all school fees are paid via MTN MoMo before the deadline.'),
                leading: Icon(Icons.campaign),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

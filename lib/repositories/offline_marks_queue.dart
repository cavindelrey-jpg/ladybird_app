import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineMarksQueue {
  static const String _queueKey = 'offline_marks_queue';

  Future<void> enqueueMarkUpdate({
    required String schoolId,
    required String studentId,
    required String subject,
    required String sequenceId,
    required double mark,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList(_queueKey) ?? [];
    
    final payload = {
      'schoolId': schoolId,
      'studentId': studentId,
      'subject': subject,
      'sequenceId': sequenceId,
      'mark': mark,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    queueJson.add(jsonEncode(payload));
    await prefs.setStringList(_queueKey, queueJson);
  }

  Future<void> syncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList(_queueKey) ?? [];
    if (queueJson.isEmpty) return;

    final supabase = Supabase.instance.client;
    List<String> failed = [];

    for (var item in queueJson) {
      try {
        final payload = jsonDecode(item);
        // Upsert logic for marks
        await supabase.from('school_marks').upsert({
          'school_id': payload['schoolId'],
          'student_id': payload['studentId'],
          'subject': payload['subject'],
          'sequence_id': payload['sequenceId'],
          'mark': payload['mark'],
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'school_id, student_id, subject, sequence_id');
      } catch (e) {
        failed.add(item);
      }
    }

    // Retain only failed requests
    await prefs.setStringList(_queueKey, failed);
  }
}

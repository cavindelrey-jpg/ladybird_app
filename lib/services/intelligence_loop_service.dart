import 'package:supabase_flutter/supabase_flutter.dart';

/// Connects academic performance to the AI tutoring ecosystem (Phase 5)
class IntelligenceLoopService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Triggered after sequence generation to route diagnostic gaps to the student
  Future<void> surfaceRemedialMaterials(String studentId, List<String> failingSubjects) async {
    for (var subject in failingSubjects) {
      // Create a personalized recommendation in the user's Academia feed
      await _supabase.from('ai_recommendations').insert({
        'user_id': studentId,
        'subject': subject,
        'type': 'remedial',
        'title': 'Targeted Revision: $subject',
        'reason': 'Detected gap during recent sequence evaluation.',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
}

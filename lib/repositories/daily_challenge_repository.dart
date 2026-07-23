// lib/repositories/daily_challenge_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_challenge.dart';
import '../core/result.dart';

class DailyChallengeRepository {
  DailyChallengeRepository._();
  static final DailyChallengeRepository instance = DailyChallengeRepository._();

  final _col = FirebaseFirestore.instance.collection('dailyChallenges');

  static String todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Null if superAdmin/lecturer hasn't seeded one for today — this is the
  /// normal state until challenges are being authored regularly.
  Future<DailyChallenge?> getToday() async {
    final doc = await _col.doc(todayKey()).get();
    return doc.exists ? DailyChallenge.fromFirestore(doc) : null;
  }

  /// Whether [userId] already attempted today's challenge (caps XP farming
  /// via repeated attempts, and lets Home show "Completed" instead of
  /// "Start Challenge").
  Future<bool> hasAttempted(String dateKey, String userId) async {
    if (userId.isEmpty) return false;
    final doc = await _col.doc(dateKey).collection('attempts').doc(userId).get();
    return doc.exists;
  }

  Future<Result<int>> submitAttempt({
    required DailyChallenge challenge,
    required String userId,
    required List<int> selectedAnswers, // same length/order as questions
  }) async {
    try {
      final attemptRef = _col.doc(challenge.dateKey).collection('attempts').doc(userId);
      if ((await attemptRef.get()).exists) {
        return const Failure('Already attempted today\'s challenge.', null);
      }
      var correct = 0;
      for (var i = 0; i < challenge.questions.length && i < selectedAnswers.length; i++) {
        if (selectedAnswers[i] == challenge.questions[i].correctIndex) correct++;
      }
      final xpAwarded = correct * challenge.xpPerCorrect;

      await attemptRef.set({
        'selectedAnswers': selectedAnswers,
        'correctCount': correct,
        'xpAwarded': xpAwarded,
        'submittedAt': FieldValue.serverTimestamp(),
      });
      return Success(xpAwarded);
    } catch (e) {
      return Failure('Failed to submit challenge', e);
    }
  }

  /// For superAdmin/lecturer seeding — creates or overwrites today's
  /// challenge doc. No auto-generated/fake questions ship with this repo.
  Future<Result<void>> seedToday(DailyChallenge challenge) async {
    try {
      await _col.doc(challenge.dateKey).set(challenge.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save challenge', e);
    }
  }
}

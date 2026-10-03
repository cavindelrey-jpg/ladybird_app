// lib/repositories/daily_challenge_repository.dart
// No Postgres table yet — the dailyChallenges Firestore collection had
// zero real documents at migration time (nobody had seeded a challenge).
// getToday() returning null is already the documented normal state
// ("Null if superAdmin/lecturer hasn't seeded one for today"), so this
// stub preserves exactly that behavior honestly rather than fabricating
// a challenge.
import '../models/daily_challenge.dart';

import '../core/result.dart';

class DailyChallengeRepository {
  DailyChallengeRepository._();
  static final DailyChallengeRepository instance = DailyChallengeRepository._();

  static String todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<DailyChallenge?> getToday() async => null;

  Future<bool> hasAttempted(String dateKey, String userId) async => false;

  Future<Result<int>> submitAttempt({
    required DailyChallenge challenge,
    required String userId,
    required List<int> selectedAnswers,
  }) async => const Failure('Daily challenges aren\'t available yet.', null);

  Future<Result<void>> seedToday(DailyChallenge challenge) async =>
      const Failure('Daily challenges aren\'t available yet.', null);
}

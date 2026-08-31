// lib/models/daily_challenge.dart
// One real challenge per calendar day, keyed by date so there's never a
// question of "which one is today's" and no risk of duplicate seeding.
// No Postgres table yet — see daily_challenge_repository.dart's header.
// If no challenge exists for today, Home shows an honest "No challenge
// today" state — never Gamma's hardcoded "Today's Physics Quiz".

class ChallengeQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;

  const ChallengeQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });
}

class DailyChallenge {
  final String dateKey; // yyyy-MM-dd
  final String subject;
  final String title;
  final List<ChallengeQuestion> questions;

  /// XP for each correct answer — matches the decided MCQ rate (10 XP).
  final int xpPerCorrect;

  const DailyChallenge({
    required this.dateKey,
    required this.subject,
    required this.title,
    required this.questions,
    this.xpPerCorrect = 10,
  });
}

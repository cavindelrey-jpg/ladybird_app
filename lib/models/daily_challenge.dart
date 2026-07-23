// lib/models/daily_challenge.dart
// One real challenge per calendar day, keyed by date so there's never a
// question of "which one is today's" and no risk of duplicate seeding.
// If no doc exists for today, Home shows an honest "No challenge today"
// state — never Gamma's hardcoded "Today's Physics Quiz".
//
// Firestore: dailyChallenges/{yyyy-MM-dd}
//            dailyChallenges/{yyyy-MM-dd}/attempts/{uid}  (1 attempt/user/day)

import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;

  const ChallengeQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  factory ChallengeQuestion.fromMap(Map<String, dynamic> m) => ChallengeQuestion(
        prompt: m['prompt'] ?? '',
        options: List<String>.from(m['options'] ?? []),
        correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'prompt': prompt, 'options': options, 'correctIndex': correctIndex};
}

class DailyChallenge {
  final String dateKey; // yyyy-MM-dd, also the doc id
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

  factory DailyChallenge.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DailyChallenge(
      dateKey: doc.id,
      subject: d['subject'] ?? '',
      title: d['title'] ?? '',
      questions: (d['questions'] as List<dynamic>? ?? [])
          .map((q) => ChallengeQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList(),
      xpPerCorrect: (d['xpPerCorrect'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'subject': subject,
        'title': title,
        'questions': questions.map((q) => q.toMap()).toList(),
        'xpPerCorrect': xpPerCorrect,
      };
}

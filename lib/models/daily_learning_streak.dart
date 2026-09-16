class DailyLearningStreak {
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompletedDate;

  const DailyLearningStreak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    this.lastCompletedDate,
  });

  factory DailyLearningStreak.fromSupabase(Map<String, dynamic> data) {
    return DailyLearningStreak(
      userId: data['user_id'] as String,
      currentStreak: (data['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longest_streak'] as num?)?.toInt() ?? 0,
      lastCompletedDate: data['last_completed_date'] != null 
          ? DateTime.tryParse(data['last_completed_date'].toString()) 
          : null,
    );
  }
}

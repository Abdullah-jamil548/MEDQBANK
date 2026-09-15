class WeeklyProgress {
  const WeeklyProgress({
    required this.questionsCompleted,
    required this.accuracyPercent,
    required this.studyMinutes,
    required this.weeklyGoal,
    required this.dailyCounts,
  });

  final int questionsCompleted;
  final int accuracyPercent;
  final int studyMinutes;
  final int weeklyGoal;
  final List<int> dailyCounts;

  double get goalProgress {
    if (weeklyGoal == 0) return 0;
    return (questionsCompleted / weeklyGoal).clamp(0, 1);
  }
}

class ContinueReading {
  const ContinueReading({
    required this.bookTitle,
    required this.chapterTitle,
    required this.progress,
  });

  final String bookTitle;
  final String chapterTitle;
  final double progress;
}

class DailyMcqTarget {
  const DailyMcqTarget({
    required this.completed,
    required this.target,
  });

  final int completed;
  final int target;

  double get progress => target == 0 ? 0 : (completed / target).clamp(0, 1);
}

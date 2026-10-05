import '../../core/storage/study_stats_store.dart';
import '../entities/weekly_progress.dart';

abstract class DashboardRepository {
  Future<WeeklyProgress> getWeeklyProgress();
  Future<ContinueReading> getContinueReading();
  Future<int> getNotesCount();
  Future<int> recordDailyOpen();
  Future<StudyHomeStats> getHomeStats();
  Future<void> addStudySeconds(int seconds);
  Future<void> saveLastReading({
    required String bookId,
    required String bookTitle,
    required int pageNo,
    double progressPct = 0,
  });
  Future<int> setWeeklyGoal(int minutes);
  Future<GoalOutcome> evaluateGoals();
}

class StudyHomeStats {
  const StudyHomeStats({
    required this.streakDays,
    required this.todayMinutes,
    required this.notesCount,
    required this.weekly,
    required this.reading,
    required this.rewardPoints,
    required this.dailyTargetMinutes,
  });

  final int streakDays;
  final int todayMinutes;
  final int notesCount;
  final WeeklyProgress weekly;
  final ContinueReading reading;
  final int rewardPoints;
  final int dailyTargetMinutes;
}

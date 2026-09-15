import '../entities/weekly_progress.dart';

abstract class DashboardRepository {
  Future<WeeklyProgress> getWeeklyProgress();
  Future<ContinueReading> getContinueReading();
  Future<DailyMcqTarget> getDailyMcqTarget();
}

import '../../domain/entities/weekly_progress.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  @override
  Future<WeeklyProgress> getWeeklyProgress() async {
    return const WeeklyProgress(
      questionsCompleted: 86,
      accuracyPercent: 78,
      studyMinutes: 214,
      weeklyGoal: 120,
      dailyCounts: [12, 18, 9, 15, 14, 10, 8],
    );
  }

  @override
  Future<ContinueReading> getContinueReading() async {
    return const ContinueReading(
      bookTitle: 'Medical Histology',
      chapterTitle: 'Epithelial Tissue',
      progress: 0.18,
    );
  }

  @override
  Future<DailyMcqTarget> getDailyMcqTarget() async {
    return const DailyMcqTarget(completed: 8, target: 15);
  }
}

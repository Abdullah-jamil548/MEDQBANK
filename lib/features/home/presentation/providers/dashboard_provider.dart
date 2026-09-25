import 'package:flutter/foundation.dart';

import '../../../../domain/entities/weekly_progress.dart';
import '../../../../domain/repositories/dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._repository) {
    load();
  }

  final DashboardRepository _repository;

  WeeklyProgress weeklyProgress = const WeeklyProgress(
    questionsCompleted: 0,
    accuracyPercent: 0,
    studyMinutes: 0,
    weeklyGoal: 0,
    dailyCounts: [0, 0, 0, 0, 0, 0, 0],
  );
  ContinueReading continueReading = const ContinueReading(
    bookTitle: '',
    chapterTitle: '',
    progress: 0,
  );
  DailyMcqTarget dailyMcq = const DailyMcqTarget(completed: 0, target: 0);
  bool isLoading = true;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    weeklyProgress = await _repository.getWeeklyProgress();
    continueReading = await _repository.getContinueReading();
    dailyMcq = await _repository.getDailyMcqTarget();
    isLoading = false;
    notifyListeners();
  }
}

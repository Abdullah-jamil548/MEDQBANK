import 'package:flutter/foundation.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/storage/study_stats_store.dart';
import '../../../../domain/entities/weekly_progress.dart';
import '../../../../domain/repositories/dashboard_repository.dart';
import '../../../session/presentation/providers/session_provider.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._repository, this._session) {
    load();
  }

  final DashboardRepository _repository;
  final SessionProvider _session;

  WeeklyProgress weeklyProgress = const WeeklyProgress(
    notesCount: 0,
    highlightsCount: 0,
    studyMinutes: 0,
    weeklyGoal: 120,
    dailyCounts: [0, 0, 0, 0, 0, 0, 0],
  );
  ContinueReading continueReading = const ContinueReading(
    bookTitle: '',
    chapterTitle: 'Open a book from your library',
    progress: 0,
  );
  int todayMinutes = 0;
  int notesCount = 0;
  int streakDays = 0;
  int rewardPoints = 0;
  int dailyTargetMinutes = 18;
  String? goalBanner;
  bool isLoading = true;

  DateTime? _readingStartedAt;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      final streak = await _repository.recordDailyOpen();
      streakDays = streak;
      _session.updateProfile(_session.profile.copyWith(streakDays: streak));
      final home = await _repository.getHomeStats();
      weeklyProgress = home.weekly;
      continueReading = home.reading;
      todayMinutes = home.todayMinutes;
      notesCount = home.notesCount;
      rewardPoints = home.rewardPoints;
      dailyTargetMinutes = home.dailyTargetMinutes;
      streakDays = home.streakDays == 0 ? streak : home.streakDays;
      await _runGoalEvaluation();
    } catch (_) {
      // keep last known values
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _runGoalEvaluation() async {
    try {
      if (_session.profile.notificationsEnabled) {
        await NotificationService.instance.requestPermission();
      }
      final outcome = await _repository.evaluateGoals();
      rewardPoints = outcome.points;
      for (final event in outcome.events) {
        goalBanner = event.body;
        if (event.bomb) {
          await NotificationService.instance.showPenaltyBomb(
            title: event.title,
            body: event.body,
          );
        } else {
          await NotificationService.instance.showStudyAlert(
            title: event.title,
            body: event.body,
            penalty: event.kind == GoalEventKind.dailyPenalty,
          );
        }
      }
      // Refresh totals after points change.
      final home = await _repository.getHomeStats();
      rewardPoints = home.rewardPoints;
      weeklyProgress = home.weekly;
      todayMinutes = home.todayMinutes;
      dailyTargetMinutes = home.dailyTargetMinutes;
    } catch (_) {}
  }

  Future<void> setWeeklyGoal(int minutes) async {
    final next = await _repository.setWeeklyGoal(minutes);
    weeklyProgress = WeeklyProgress(
      notesCount: weeklyProgress.notesCount,
      highlightsCount: weeklyProgress.highlightsCount,
      studyMinutes: weeklyProgress.studyMinutes,
      weeklyGoal: next,
      dailyCounts: weeklyProgress.dailyCounts,
    );
    dailyTargetMinutes = (next / 7).ceil().clamp(5, next);
    notifyListeners();
    await _runGoalEvaluation();
    notifyListeners();
  }

  void beginReading() {
    _readingStartedAt ??= DateTime.now();
  }

  Future<void> endReading() async {
    final started = _readingStartedAt;
    _readingStartedAt = null;
    if (started == null) return;
    final seconds = DateTime.now().difference(started).inSeconds;
    if (seconds < 5) return;
    await _repository.addStudySeconds(seconds);
    await load();
  }

  Future<void> rememberReading({
    required String bookId,
    required String bookTitle,
    required int pageNo,
    double progressPct = 0,
  }) {
    continueReading = ContinueReading(
      bookId: bookId,
      bookTitle: bookTitle,
      chapterTitle: 'Page $pageNo',
      progress: progressPct.clamp(0, 1),
      pageNo: pageNo,
    );
    return _repository.saveLastReading(
      bookId: bookId,
      bookTitle: bookTitle,
      pageNo: pageNo,
      progressPct: progressPct,
    );
  }
}

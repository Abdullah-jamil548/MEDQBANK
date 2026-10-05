import '../../core/storage/study_stats_store.dart';
import '../../domain/entities/weekly_progress.dart';
import '../../domain/repositories/books_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._books, this._stats);

  final BooksRepository _books;
  final StudyStatsStore _stats;

  @override
  Future<int> recordDailyOpen() => _stats.recordDailyOpen();

  @override
  Future<void> addStudySeconds(int seconds) => _stats.addStudySeconds(seconds);

  @override
  Future<void> saveLastReading({
    required String bookId,
    required String bookTitle,
    required int pageNo,
    double progressPct = 0,
  }) {
    return _stats.saveLastReading(
      bookId: bookId,
      bookTitle: bookTitle,
      pageNo: pageNo,
      progressPct: progressPct,
    );
  }

  @override
  Future<int> setWeeklyGoal(int minutes) => _stats.setWeeklyGoal(minutes);

  @override
  Future<GoalOutcome> evaluateGoals() => _stats.evaluateGoals();

  @override
  Future<int> getNotesCount() async {
    try {
      final notes = await _books.listNotes();
      return notes.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<WeeklyProgress> getWeeklyProgress() async {
    final home = await getHomeStats();
    return home.weekly;
  }

  @override
  Future<ContinueReading> getContinueReading() async {
    final home = await getHomeStats();
    return home.reading;
  }

  @override
  Future<StudyHomeStats> getHomeStats() async {
    final snap = await _stats.snapshot();
    var notesCount = 0;
    var highlightsCount = 0;
    try {
      notesCount = (await _books.listNotes()).length;
    } catch (_) {}
    try {
      highlightsCount = (await _books.listHighlights()).length;
    } catch (_) {}

    ContinueReading reading = ContinueReading(
      bookId: snap.lastBookId,
      bookTitle: snap.lastBookTitle ?? '',
      chapterTitle: snap.lastBookId == null
          ? 'Open a book from your library'
          : 'Page ${snap.lastPageNo}',
      progress: snap.lastProgressPct.clamp(0, 1),
      pageNo: snap.lastPageNo,
    );

    try {
      final rows = await _books.listProgress();
      if (rows.isNotEmpty) {
        rows.sort((a, b) {
          final at = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });
        final latest = rows.first;
        final books = await _books.listBooks();
        String title = snap.lastBookTitle ?? '';
        for (final book in books) {
          if (book.id == latest.bookId) {
            title = book.title;
            break;
          }
        }
        reading = ContinueReading(
          bookId: latest.bookId,
          bookTitle: title.isEmpty ? 'Continue reading' : title,
          chapterTitle: 'Page ${latest.pageNo}',
          progress: (latest.progressPct ?? snap.lastProgressPct).clamp(0, 1),
          pageNo: latest.pageNo,
        );
      }
    } catch (_) {}

    return StudyHomeStats(
      streakDays: snap.streakDays,
      todayMinutes: snap.todayMinutes,
      notesCount: notesCount,
      rewardPoints: snap.rewardPoints,
      dailyTargetMinutes: snap.dailyTargetMinutes,
      weekly: WeeklyProgress(
        notesCount: notesCount,
        highlightsCount: highlightsCount,
        studyMinutes: snap.weekMinutes,
        weeklyGoal: snap.weeklyGoalMinutes,
        dailyCounts: snap.dailyMinutes,
      ),
      reading: reading,
    );
  }
}

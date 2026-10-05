class WeeklyProgress {
  const WeeklyProgress({
    required this.notesCount,
    required this.highlightsCount,
    required this.studyMinutes,
    required this.weeklyGoal,
    required this.dailyCounts,
  });

  final int notesCount;
  final int highlightsCount;
  final int studyMinutes;
  final int weeklyGoal;
  final List<int> dailyCounts;

  double get goalProgress {
    if (weeklyGoal == 0) return 0;
    return (studyMinutes / weeklyGoal).clamp(0, 1);
  }
}

class ContinueReading {
  const ContinueReading({
    required this.bookTitle,
    required this.chapterTitle,
    required this.progress,
    this.bookId,
    this.pageNo = 1,
  });

  final String? bookId;
  final String bookTitle;
  final String chapterTitle;
  final double progress;
  final int pageNo;

  bool get hasBook => (bookId ?? '').isNotEmpty && bookTitle.isNotEmpty;
}

class BookReadingProgress {
  const BookReadingProgress({
    required this.bookId,
    required this.pageNo,
    this.progressPct,
    this.updatedAt,
  });

  final String bookId;
  final int pageNo;
  final double? progressPct;
  final DateTime? updatedAt;

  factory BookReadingProgress.fromJson(Map<String, dynamic> json) {
    return BookReadingProgress(
      bookId: json['book_id']?.toString() ?? '',
      pageNo: json['page_no'] as int? ?? 1,
      progressPct: (json['progress_pct'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

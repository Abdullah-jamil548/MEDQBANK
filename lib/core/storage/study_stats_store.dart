import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local study streak, daily minutes, weekly goal, and reward/penalty state.
class StudyStatsStore {
  static const _key = 'medqbank.study_stats.v1';
  static const defaultWeeklyGoalMinutes = 120;
  static const minWeeklyGoal = 30;
  static const maxWeeklyGoal = 600;

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<_StudyStats> _load() async {
    final prefs = await _prefs();
    final raw = prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return const _StudyStats();
    try {
      return _StudyStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const _StudyStats();
    }
  }

  Future<void> _save(_StudyStats stats) async {
    final prefs = await _prefs();
    await prefs?.setString(_key, jsonEncode(stats.toJson()));
  }

  String _todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _weekKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final monday = _dateOnly(d).subtract(Duration(days: d.weekday - 1));
    return _todayKey(monday);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Call whenever the user opens the app. Consecutive calendar days keep the streak.
  Future<int> recordDailyOpen() async {
    final stats = await _load();
    final today = _dateOnly(DateTime.now());
    final last = stats.lastOpenDate;
    int streak = stats.streakDays;
    if (last == null) {
      streak = 1;
    } else {
      final lastDay = _dateOnly(last);
      final gap = today.difference(lastDay).inDays;
      if (gap == 0) {
        streak = streak == 0 ? 1 : streak;
      } else if (gap == 1) {
        streak = (streak == 0 ? 1 : streak) + 1;
      } else {
        streak = 1;
      }
    }
    await _save(stats.copyWith(lastOpenDate: today, streakDays: streak));
    return streak;
  }

  Future<void> addStudySeconds(int seconds) async {
    if (seconds <= 0) return;
    final stats = await _load();
    final key = _todayKey();
    final next = Map<String, int>.from(stats.secondsByDay);
    next[key] = (next[key] ?? 0) + seconds;
    await _save(stats.copyWith(secondsByDay: next));
  }

  Future<void> saveLastReading({
    required String bookId,
    required String bookTitle,
    required int pageNo,
    double progressPct = 0,
  }) async {
    final stats = await _load();
    await _save(
      stats.copyWith(
        lastBookId: bookId,
        lastBookTitle: bookTitle,
        lastPageNo: pageNo,
        lastProgressPct: progressPct,
      ),
    );
  }

  Future<int> setWeeklyGoal(int minutes) async {
    final clamped = minutes.clamp(minWeeklyGoal, maxWeeklyGoal);
    final stats = await _load();
    await _save(stats.copyWith(weeklyGoalMinutes: clamped));
    return clamped;
  }

  Future<StudySnapshot> snapshot() async {
    final stats = await _load();
    final todayKey = _todayKey();
    final now = DateTime.now();
    final monday = _dateOnly(now).subtract(Duration(days: now.weekday - 1));
    final dailyMinutes = List<int>.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final secs = stats.secondsByDay[_todayKey(day)] ?? 0;
      return (secs / 60).floor();
    });
    final weekMinutes = dailyMinutes.fold<int>(0, (a, b) => a + b);
    final todayMinutes = ((stats.secondsByDay[todayKey] ?? 0) / 60).floor();
    final dailyTarget = (stats.weeklyGoalMinutes / 7).ceil().clamp(5, stats.weeklyGoalMinutes);
    return StudySnapshot(
      streakDays: stats.streakDays,
      todayMinutes: todayMinutes,
      weekMinutes: weekMinutes,
      dailyMinutes: dailyMinutes,
      weeklyGoalMinutes: stats.weeklyGoalMinutes,
      dailyTargetMinutes: dailyTarget,
      rewardPoints: stats.rewardPoints,
      lastBookId: stats.lastBookId,
      lastBookTitle: stats.lastBookTitle,
      lastPageNo: stats.lastPageNo,
      lastProgressPct: stats.lastProgressPct,
    );
  }

  /// Evaluate rewards / penalties whenever the app checks goals.
  /// Penalties can fire at any time of day (throttled every 3 hours).
  Future<GoalOutcome> evaluateGoals() async {
    var stats = await _load();
    final snap = await snapshot();
    final today = _todayKey();
    final week = _weekKey();
    final now = DateTime.now();
    final events = <GoalEvent>[];
    var score = stats.rewardPoints;

    // Reward: finished today's share of the weekly goal
    if (snap.todayMinutes >= snap.dailyTargetMinutes && stats.lastDailyRewardDate != today) {
      score += 15;
      stats = stats.copyWith(
        rewardPoints: score,
        lastDailyRewardDate: today,
      );
      events.add(
        GoalEvent(
          kind: GoalEventKind.dailyReward,
          title: 'Today’s goal done',
          body: 'You studied ${snap.todayMinutes}m (need ${snap.dailyTargetMinutes}m/day). '
              'Reward: +15 study score.',
          pointsDelta: 15,
        ),
      );
    }

    // Reward: finished the full weekly goal
    if (snap.weekMinutes >= snap.weeklyGoalMinutes && stats.lastWeekRewardKey != week) {
      score += 50;
      stats = stats.copyWith(
        rewardPoints: score,
        lastWeekRewardKey: week,
      );
      events.add(
        GoalEvent(
          kind: GoalEventKind.weeklyReward,
          title: 'Weekly goal done',
          body: 'You hit ${snap.weeklyGoalMinutes}m this week. Reward: +50 study score.',
          pointsDelta: 50,
        ),
      );
    }

    // Penalty anytime if behind — not tied to evening hours.
    // Throttle to once every 3 hours so opening Home doesn't spam forever.
    final behind = snap.todayMinutes < snap.dailyTargetMinutes;
    final lastPenalty = stats.lastPenaltyAt;
    final canPenalize = lastPenalty == null || now.difference(lastPenalty).inHours >= 3;
    if (behind && canPenalize) {
      final need = snap.dailyTargetMinutes - snap.todayMinutes;
      final lost = score >= 5 ? 5 : score;
      score = (score - lost).clamp(0, 999999);
      stats = stats.copyWith(
        rewardPoints: score,
        lastPenaltyAt: now,
        lastPenaltyDate: today,
      );
      events.add(
        GoalEvent(
          kind: GoalEventKind.dailyPenalty,
          title: 'Behind on today’s goal',
          body: 'Studied ${snap.todayMinutes}m — still need ${need}m today. '
              '${lost > 0 ? 'Penalty: −$lost study score. ' : ''}'
              'Open a book to catch up.',
          pointsDelta: -lost,
          bomb: true,
        ),
      );
    }

    await _save(stats);
    return GoalOutcome(
      points: score,
      events: events,
      todayMinutes: snap.todayMinutes,
      dailyTarget: snap.dailyTargetMinutes,
      weekMinutes: snap.weekMinutes,
      weeklyGoal: snap.weeklyGoalMinutes,
    );
  }
}

enum GoalEventKind { dailyReward, weeklyReward, dailyPenalty, nudgeBomb }

class GoalEvent {
  const GoalEvent({
    required this.kind,
    required this.title,
    required this.body,
    required this.pointsDelta,
    this.bomb = false,
  });

  final GoalEventKind kind;
  final String title;
  final String body;
  final int pointsDelta;
  final bool bomb;
}

class GoalOutcome {
  const GoalOutcome({
    required this.points,
    required this.events,
    required this.todayMinutes,
    required this.dailyTarget,
    required this.weekMinutes,
    required this.weeklyGoal,
  });

  final int points;
  final List<GoalEvent> events;
  final int todayMinutes;
  final int dailyTarget;
  final int weekMinutes;
  final int weeklyGoal;
}

class StudySnapshot {
  const StudySnapshot({
    this.streakDays = 0,
    this.todayMinutes = 0,
    this.weekMinutes = 0,
    this.dailyMinutes = const [0, 0, 0, 0, 0, 0, 0],
    this.weeklyGoalMinutes = StudyStatsStore.defaultWeeklyGoalMinutes,
    this.dailyTargetMinutes = 18,
    this.rewardPoints = 0,
    this.lastBookId,
    this.lastBookTitle,
    this.lastPageNo = 1,
    this.lastProgressPct = 0,
  });

  final int streakDays;
  final int todayMinutes;
  final int weekMinutes;
  final List<int> dailyMinutes;
  final int weeklyGoalMinutes;
  final int dailyTargetMinutes;
  final int rewardPoints;
  final String? lastBookId;
  final String? lastBookTitle;
  final int lastPageNo;
  final double lastProgressPct;
}

class _StudyStats {
  const _StudyStats({
    this.lastOpenDate,
    this.streakDays = 0,
    this.secondsByDay = const {},
    this.lastBookId,
    this.lastBookTitle,
    this.lastPageNo = 1,
    this.lastProgressPct = 0,
    this.weeklyGoalMinutes = StudyStatsStore.defaultWeeklyGoalMinutes,
    this.rewardPoints = 0,
    this.lastDailyRewardDate,
    this.lastWeekRewardKey,
    this.lastPenaltyDate,
    this.lastPenaltyAt,
  });

  final DateTime? lastOpenDate;
  final int streakDays;
  final Map<String, int> secondsByDay;
  final String? lastBookId;
  final String? lastBookTitle;
  final int lastPageNo;
  final double lastProgressPct;
  final int weeklyGoalMinutes;
  final int rewardPoints;
  final String? lastDailyRewardDate;
  final String? lastWeekRewardKey;
  final String? lastPenaltyDate;
  final DateTime? lastPenaltyAt;

  _StudyStats copyWith({
    DateTime? lastOpenDate,
    int? streakDays,
    Map<String, int>? secondsByDay,
    String? lastBookId,
    String? lastBookTitle,
    int? lastPageNo,
    double? lastProgressPct,
    int? weeklyGoalMinutes,
    int? rewardPoints,
    String? lastDailyRewardDate,
    String? lastWeekRewardKey,
    String? lastPenaltyDate,
    DateTime? lastPenaltyAt,
  }) {
    return _StudyStats(
      lastOpenDate: lastOpenDate ?? this.lastOpenDate,
      streakDays: streakDays ?? this.streakDays,
      secondsByDay: secondsByDay ?? this.secondsByDay,
      lastBookId: lastBookId ?? this.lastBookId,
      lastBookTitle: lastBookTitle ?? this.lastBookTitle,
      lastPageNo: lastPageNo ?? this.lastPageNo,
      lastProgressPct: lastProgressPct ?? this.lastProgressPct,
      weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      lastDailyRewardDate: lastDailyRewardDate ?? this.lastDailyRewardDate,
      lastWeekRewardKey: lastWeekRewardKey ?? this.lastWeekRewardKey,
      lastPenaltyDate: lastPenaltyDate ?? this.lastPenaltyDate,
      lastPenaltyAt: lastPenaltyAt ?? this.lastPenaltyAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'lastOpenDate': lastOpenDate?.toIso8601String(),
        'streakDays': streakDays,
        'secondsByDay': secondsByDay,
        'lastBookId': lastBookId,
        'lastBookTitle': lastBookTitle,
        'lastPageNo': lastPageNo,
        'lastProgressPct': lastProgressPct,
        'weeklyGoalMinutes': weeklyGoalMinutes,
        'rewardPoints': rewardPoints,
        'lastDailyRewardDate': lastDailyRewardDate,
        'lastWeekRewardKey': lastWeekRewardKey,
        'lastPenaltyDate': lastPenaltyDate,
        'lastPenaltyAt': lastPenaltyAt?.toIso8601String(),
      };

  factory _StudyStats.fromJson(Map<String, dynamic> json) {
    final rawDays = json['secondsByDay'];
    final days = <String, int>{};
    if (rawDays is Map) {
      rawDays.forEach((k, v) {
        if (v is num) days[k.toString()] = v.toInt();
      });
    }
    return _StudyStats(
      lastOpenDate: json['lastOpenDate'] != null
          ? DateTime.tryParse(json['lastOpenDate'] as String)
          : null,
      streakDays: json['streakDays'] as int? ?? 0,
      secondsByDay: days,
      lastBookId: json['lastBookId'] as String?,
      lastBookTitle: json['lastBookTitle'] as String?,
      lastPageNo: json['lastPageNo'] as int? ?? 1,
      lastProgressPct: (json['lastProgressPct'] as num?)?.toDouble() ?? 0,
      weeklyGoalMinutes: json['weeklyGoalMinutes'] as int? ??
          StudyStatsStore.defaultWeeklyGoalMinutes,
      rewardPoints: json['rewardPoints'] as int? ?? 0,
      lastDailyRewardDate: json['lastDailyRewardDate'] as String?,
      lastWeekRewardKey: json['lastWeekRewardKey'] as String?,
      lastPenaltyDate: json['lastPenaltyDate'] as String?,
      lastPenaltyAt: json['lastPenaltyAt'] != null
          ? DateTime.tryParse(json['lastPenaltyAt'] as String)
          : null,
    );
  }
}

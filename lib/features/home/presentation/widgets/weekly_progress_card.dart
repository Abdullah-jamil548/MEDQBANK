import 'package:flutter/material.dart';

import '../../../../core/storage/study_stats_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/weekly_progress.dart';

class WeeklyProgressCard extends StatelessWidget {
  const WeeklyProgressCard({
    super.key,
    required this.progress,
    required this.rewardPoints,
    required this.dailyTargetMinutes,
    required this.todayMinutes,
    this.onEditGoal,
  });

  final WeeklyProgress progress;
  final int rewardPoints;
  final int dailyTargetMinutes;
  final int todayMinutes;
  final VoidCallback? onEditGoal;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final maxCount = progress.dailyCounts.fold<int>(1, (a, b) => a > b ? a : b);
    final dailyMet = todayMinutes >= dailyTargetMinutes;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              _stat('${progress.notesCount}', 'Notes'),
              _divider(),
              _stat('$rewardPoints', 'Score'),
              _divider(),
              _stat('${progress.studyMinutes}m', 'This week'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: dailyMet ? AppColors.successSoft : AppColors.streakSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  dailyMet ? Icons.emoji_events_outlined : Icons.warning_amber_rounded,
                  size: 18,
                  color: dailyMet ? AppColors.success : AppColors.streak,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dailyMet
                        ? 'Today done: $todayMinutes / ${dailyTargetMinutes}m'
                        : 'Today: $todayMinutes / ${dailyTargetMinutes}m left to earn reward',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: dailyMet ? AppColors.success : AppColors.streak,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 118,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(progress.dailyCounts.length, (index) {
                final value = progress.dailyCounts[index];
                final height = 16.0 + (value / maxCount) * 68;
                final today = index == DateTime.now().weekday - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: height,
                          decoration: BoxDecoration(
                            color: today ? AppColors.primary : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _days[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: today ? FontWeight.w800 : FontWeight.w600,
                            color: today ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Weekly study goal',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onEditGoal,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Adjust'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress.goalProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceMuted,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${progress.studyMinutes}/${progress.weeklyGoal}m',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'How score works\n'
              '• Study score is your running total — not money, just progress.\n'
              '• Finish today’s minutes → +15 score + reward notification.\n'
              '• Finish the weekly goal → +50 score.\n'
              '• Still short of today → reminder bomb anytime + −5 score '
              '(at most once every 3 hours).',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showWeeklyGoalEditor(
  BuildContext context, {
  required int currentGoal,
  required ValueChanged<int> onSave,
}) async {
  var value = currentGoal.clamp(
    StudyStatsStore.minWeeklyGoal,
    StudyStatsStore.maxWeeklyGoal,
  );
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly study goal',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Daily pace ≈ ${(value / 7).ceil()} minutes',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${value}m',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${StudyStatsStore.minWeeklyGoal}–${StudyStatsStore.maxWeeklyGoal}m',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value.toDouble(),
                  min: StudyStatsStore.minWeeklyGoal.toDouble(),
                  max: StudyStatsStore.maxWeeklyGoal.toDouble(),
                  divisions: ((StudyStatsStore.maxWeeklyGoal - StudyStatsStore.minWeeklyGoal) / 15)
                      .round(),
                  label: '${value}m',
                  onChanged: (v) => setModal(() => value = v.round()),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      onSave(value);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save goal'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

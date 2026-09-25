import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/weekly_progress.dart';

class WeeklyProgressCard extends StatelessWidget {
  const WeeklyProgressCard({super.key, required this.progress});

  final WeeklyProgress progress;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final maxCount = progress.dailyCounts.fold<int>(1, (a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              _stat('${progress.questionsCompleted}', 'Questions'),
              _divider(),
              _stat('${progress.accuracyPercent}%', 'Accuracy'),
              _divider(),
              _stat('${progress.studyMinutes}m', 'Study time'),
            ],
          ),
          const SizedBox(height: 20),
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
          const Row(
            children: [
              Text(
                'Weekly goal',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Spacer(),
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
                '${progress.questionsCompleted}/${progress.weeklyGoal}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
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

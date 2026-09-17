import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../../home/presentation/widgets/weekly_progress_card.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  static const _subjects = [
    ('Anatomy', 0.84),
    ('Physiology', 0.76),
    ('Pathology', 0.71),
    ('Pharmacology', 0.69),
  ];

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final rs = context.rs;
    final weekly = dashboard.weeklyProgress;

    return ResponsiveBody(
      mode: ResponsiveMode.scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            title: 'Progress',
            subtitle: 'See where you are strong, and what still needs a ward-round pass.',
          ),
          SizedBox(height: rs.scale(20)),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Accuracy',
                  value: '${weekly.accuracyPercent}%',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Questions',
                  value: '${weekly.questionsCompleted}',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: rs.scale(20)),
          const SectionLabel('This week'),
          SizedBox(height: rs.scale(12)),
          WeeklyProgressCard(progress: weekly),
          SizedBox(height: rs.scale(24)),
          const SectionLabel('Subject accuracy'),
          SizedBox(height: rs.scale(12)),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < _subjects.length; i++) ...[
                  _SubjectRow(name: _subjects[i].$1, value: _subjects[i].$2),
                  if (i != _subjects.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 26,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.name, required this.value});

  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: AppColors.surfaceMuted,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

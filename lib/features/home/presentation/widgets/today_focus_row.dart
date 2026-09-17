import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';

class TodayFocusRow extends StatelessWidget {
  const TodayFocusRow({
    super.key,
    required this.mcqsLeft,
    required this.minutes,
    required this.notes,
    required this.onPractice,
  });

  final int mcqsLeft;
  final int minutes;
  final int notes;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FocusTile(
            icon: Icons.quiz_outlined,
            tint: AppColors.primarySoft,
            color: AppColors.primary,
            label: 'MCQs left',
            value: '$mcqsLeft',
            onTap: onPractice,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FocusTile(
            icon: Icons.schedule_outlined,
            tint: AppColors.secondarySoft,
            color: AppColors.secondary,
            label: 'Study min',
            value: '${minutes}m',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FocusTile(
            icon: Icons.sticky_note_2_outlined,
            tint: AppColors.streakSoft,
            color: AppColors.streak,
            label: 'Notes',
            value: '$notes',
          ),
        ),
      ],
    );
  }
}

class _FocusTile extends StatelessWidget {
  const _FocusTile({
    required this.icon,
    required this.tint,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

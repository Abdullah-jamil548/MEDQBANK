import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/weekly_progress.dart';

class QuickAccessCards extends StatelessWidget {
  const QuickAccessCards({
    super.key,
    required this.reading,
    required this.notesCount,
    required this.highlightsCount,
    required this.onContinueReading,
    required this.onOpenNotes,
  });

  final ContinueReading reading;
  final int notesCount;
  final int highlightsCount;
  final VoidCallback onContinueReading;
  final VoidCallback onOpenNotes;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _AccessCard(
        tint: AppColors.primarySoft,
        iconColor: AppColors.primary,
        icon: Icons.menu_book_rounded,
        title: AppStrings.continueReading,
        subtitle: reading.hasBook ? reading.bookTitle : 'No book in progress',
        detail: reading.hasBook ? reading.chapterTitle : 'Browse the library to start',
        actionLabel: reading.hasBook ? AppStrings.continueAction : 'Open library',
        progress: reading.progress,
        onTap: onContinueReading,
      ),
      _AccessCard(
        tint: AppColors.secondarySoft,
        iconColor: AppColors.secondary,
        icon: Icons.sticky_note_2_rounded,
        title: 'Notes & highlights',
        subtitle: '$notesCount notes · $highlightsCount highlights',
        detail: 'Your annotations across all books',
        actionLabel: 'Open library',
        progress: notesCount + highlightsCount == 0
            ? 0
            : ((notesCount + highlightsCount) / 20).clamp(0.08, 1),
        onTap: onOpenNotes,
      ),
    ];

    if (context.rs.cardColumns > 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
        ],
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 12),
        cards[1],
      ],
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.tint,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.actionLabel,
    required this.progress,
    required this.onTap,
  });

  final Color tint;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final String actionLabel;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceMuted,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                actionLabel,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 16, color: iconColor),
            ],
          ),
        ],
      ),
    );
  }
}

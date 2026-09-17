import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../../shell/presentation/providers/main_nav_provider.dart';

class McqBankPage extends StatelessWidget {
  const McqBankPage({super.key});

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label will open in the next update.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final rs = context.rs;
    final daily = dashboard.dailyMcq;

    return ResponsiveBody(
      mode: ResponsiveMode.scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            title: 'MCQ Bank',
            subtitle: 'Practice like a ward test — timed papers, subjects, and explanations.',
          ),
          SizedBox(height: rs.scale(20)),
          AppCard(
            onTap: () => _soon(context, 'Daily MCQs'),
            color: AppColors.primarySoft,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.quiz_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today’s paper',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${daily.completed} of ${daily.target} MCQs completed',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: daily.progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.secondary,
            ),
          ),
          SizedBox(height: rs.scale(24)),
          const SectionLabel('Practice modes'),
          SizedBox(height: rs.scale(12)),
          _ModeCard(
            icon: Icons.timer_outlined,
            title: 'Timed quiz',
            body: '20-minute blocks with a viva-style timer.',
            onTap: () => _soon(context, 'Timed quiz'),
          ),
          const SizedBox(height: 10),
          _ModeCard(
            icon: Icons.biotech_outlined,
            title: 'Subject bank',
            body: 'Anatomy, physiology, pathology, and more.',
            onTap: () => _soon(context, 'Subject bank'),
          ),
          const SizedBox(height: 10),
          _ModeCard(
            icon: Icons.replay_outlined,
            title: 'Incorrects',
            body: 'Revisit the questions you missed.',
            onTap: () => _soon(context, 'Incorrects'),
          ),
          const SizedBox(height: 10),
          _ModeCard(
            icon: Icons.menu_book_outlined,
            title: 'From the library',
            body: 'MCQs tagged to the book you are reading.',
            onTap: () => context.read<MainNavProvider>().setIndex(1),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

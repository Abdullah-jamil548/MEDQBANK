import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/medical_motifs.dart';
import '../../../session/presentation/providers/session_provider.dart';
import '../../../shell/presentation/providers/main_nav_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/quick_access_cards.dart';
import '../widgets/today_focus_row.dart';
import '../widgets/weekly_progress_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final rs = context.rs;

    return ResponsiveBody(
      mode: ResponsiveMode.fill,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DashboardHeader(profile: session.profile),
          SizedBox(height: rs.scale(16)),
          TodayFocusRow(
            mcqsLeft: dashboard.dailyMcq.target - dashboard.dailyMcq.completed,
            minutes: dashboard.weeklyProgress.studyMinutes,
            onPractice: () => context.read<MainNavProvider>().setIndex(2),
          ),
          SizedBox(height: rs.scale(24)),
          const SectionLabel('Subjects'),
          SizedBox(height: rs.scale(12)),
          SubjectChips(
            onTap: (_) => context.read<MainNavProvider>().setIndex(2),
          ),
          SizedBox(height: rs.scale(24)),
          SectionLabel(
            'Quick access',
            action: 'See all',
            onAction: () => context.read<MainNavProvider>().setIndex(1),
          ),
          SizedBox(height: rs.scale(12)),
          QuickAccessCards(
            reading: dashboard.continueReading,
            dailyMcq: dashboard.dailyMcq,
            onContinueReading: () {
              context.read<MainNavProvider>().setIndex(1);
            },
            onStartPractice: () => context.read<MainNavProvider>().setIndex(2),
          ),
          SizedBox(height: rs.scale(24)),
          const SectionLabel(AppStrings.weeklyProgress),
          SizedBox(height: rs.scale(12)),
          WeeklyProgressCard(progress: dashboard.weeklyProgress),
          SizedBox(height: rs.scale(16)),
        ],
      ),
    );
  }
}

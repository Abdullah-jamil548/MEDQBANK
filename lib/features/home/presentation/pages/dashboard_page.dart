import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/medical_motifs.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../session/presentation/providers/session_provider.dart';
import '../../../shell/presentation/providers/main_nav_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/quick_access_cards.dart';
import '../widgets/today_focus_row.dart';
import '../widgets/weekly_progress_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  Future<void> _openContinueReading() async {
    final dashboard = context.read<DashboardProvider>();
    final library = context.read<LibraryProvider>();
    final nav = context.read<MainNavProvider>();
    final reading = dashboard.continueReading;
    if (!reading.hasBook) {
      nav.setIndex(1);
      return;
    }
    if (library.books.isEmpty) {
      await library.load();
    }
    if (!mounted) return;
    CatalogBook? book;
    for (final item in library.books) {
      if (item.id == reading.bookId) {
        book = item;
        break;
      }
    }
    if (book == null) {
      nav.setIndex(1);
      return;
    }
    if (!(library.downloaded[book.id] ?? false)) {
      nav.setIndex(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download ${book.title} from Library first')),
      );
      return;
    }
    final ok = await library.openBook(book, initialPage: reading.pageNo);
    if (!mounted) return;
    if (!ok) {
      nav.setIndex(1);
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.bookReader);
  }

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
            streakDays: dashboard.streakDays,
            minutes: dashboard.todayMinutes,
            notesCount: dashboard.notesCount,
            onStreak: () => context.read<MainNavProvider>().setIndex(1),
            onStudy: () => context.read<MainNavProvider>().setIndex(1),
            onNotes: () => context.read<MainNavProvider>().setIndex(2),
          ),
          SizedBox(height: rs.scale(24)),
          const SectionLabel('Subjects'),
          SizedBox(height: rs.scale(12)),
          SubjectChips(
            onTap: (_) => context.read<MainNavProvider>().setIndex(1),
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
            notesCount: dashboard.notesCount,
            highlightsCount: dashboard.weeklyProgress.highlightsCount,
            onContinueReading: _openContinueReading,
            onOpenNotes: () => context.read<MainNavProvider>().setIndex(2),
          ),
          SizedBox(height: rs.scale(24)),
          const SectionLabel(AppStrings.weeklyProgress),
          SizedBox(height: rs.scale(12)),
          if (dashboard.goalBanner != null) ...[
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dashboard.goalBanner!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: rs.scale(12)),
          ],
          WeeklyProgressCard(
            progress: dashboard.weeklyProgress,
            rewardPoints: dashboard.rewardPoints,
            dailyTargetMinutes: dashboard.dailyTargetMinutes,
            todayMinutes: dashboard.todayMinutes,
            onEditGoal: () {
              showWeeklyGoalEditor(
                context,
                currentGoal: dashboard.weeklyProgress.weeklyGoal,
                onSave: (minutes) => dashboard.setWeeklyGoal(minutes),
              );
            },
          ),
          SizedBox(height: rs.scale(16)),
        ],
      ),
    );
  }
}

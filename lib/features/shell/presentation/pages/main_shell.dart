import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/dashboard_page.dart';
import '../../../library/presentation/pages/library_page.dart';
import '../../../notes/presentation/pages/notes_hub_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../progress/presentation/pages/progress_page.dart';
import '../providers/main_nav_provider.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _pages = [
    DashboardPage(),
    LibraryPage(),
    NotesHubPage(),
    ProgressPage(),
    ProfilePage(),
  ];

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, AppStrings.home),
    (Icons.local_library_outlined, Icons.local_library_rounded, AppStrings.library),
    (Icons.sticky_note_2_outlined, Icons.sticky_note_2_rounded, AppStrings.notes),
    (Icons.insights_outlined, Icons.insights_rounded, AppStrings.progress),
    (Icons.person_outline_rounded, Icons.person_rounded, AppStrings.profile),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<MainNavProvider>();

    return Scaffold(
      body: IndexedStack(index: nav.index, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final selected = nav.index == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => nav.setIndex(index),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primarySoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? item.$2 : item.$1,
                            size: 22,
                            color: selected ? AppColors.primary : AppColors.textMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

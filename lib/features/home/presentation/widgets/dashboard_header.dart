import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/user_profile.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.profile});

  final UserProfile profile;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final year = profile.year?.label ?? 'MBBS';
    final streak = profile.streakDays;
    final rs = context.rs;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                    fontSize: rs.font(13),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: rs.font(24),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$year  ·  $streak day streak',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: rs.font(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: rs.scale(24),
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../session/presentation/providers/session_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<SessionProvider>().profile;
    final rs = context.rs;

    return ResponsiveBody(
      mode: ResponsiveMode.scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: rs.font(26),
                  letterSpacing: -0.4,
                ),
          ),
          SizedBox(height: rs.scale(20)),
          AppCard(
            padding: EdgeInsets.all(rs.scale(20)),
            child: Column(
              children: [
                CircleAvatar(
                  radius: rs.scale(38),
                  backgroundColor: AppColors.primary,
                  child: Text(
                    profile.initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: rs.font(22),
                    ),
                  ),
                ),
                SizedBox(height: rs.scale(14)),
                Text(
                  profile.fullName.isEmpty ? 'MBBS Student' : profile.fullName,
                  style: TextStyle(fontSize: rs.font(20), fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (profile.year != null) profile.year!.label,
                    if (profile.college != null) profile.college!.name,
                  ].join(' • '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: rs.scale(20)),
          if (context.watch<SessionProvider>().subscriptionExpiresAt != null)
            Padding(
              padding: EdgeInsets.only(bottom: rs.scale(12)),
              child: Text(
                'Access until ${context.watch<SessionProvider>().subscriptionExpiresAt}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await context.read<SessionProvider>().signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.login,
                  (_) => false,
                );
              },
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}

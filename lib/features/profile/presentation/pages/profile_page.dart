import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../../session/presentation/providers/session_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final profile = session.profile;
    final friends = context.watch<FriendsProvider>();
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
                if (profile.email.isNotEmpty)
                  Text(
                    profile.email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
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
          SizedBox(height: rs.scale(16)),
          AppCard(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.friends),
            child: Row(
              children: [
                const Icon(Icons.people_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Friends',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        friends.friends.isEmpty
                            ? 'Add friends and see their study status'
                            : '${friends.friends.length} friend${friends.friends.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (friends.requests.where((r) => r.isIncoming).isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${friends.requests.where((r) => r.isIncoming).length}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
          SizedBox(height: rs.scale(12)),
          AppCard(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.chats),
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, color: AppColors.secondary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chats',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Message friends and open shared book passages',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
          SizedBox(height: rs.scale(16)),
          const SectionLabel('Privacy with friends'),
          SizedBox(height: rs.scale(10)),
          AppCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Hide online status',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Friends won’t see if you’re online or last seen',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  value: profile.hidePresence,
                  onChanged: friends.acting
                      ? null
                      : (value) => friends.setPrivacy(hidePresence: value),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Hide reading activity',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Friends won’t see your last book or progress',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  value: profile.hideReadingActivity,
                  onChanged: friends.acting
                      ? null
                      : (value) => friends.setPrivacy(hideReadingActivity: value),
                ),
              ],
            ),
          ),
          SizedBox(height: rs.scale(20)),
          if (session.subscriptionExpiresAt != null)
            Padding(
              padding: EdgeInsets.only(bottom: rs.scale(12)),
              child: Text(
                'Access until ${session.subscriptionExpiresAt}',
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
                context.read<FriendsProvider>().stopPresence();
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

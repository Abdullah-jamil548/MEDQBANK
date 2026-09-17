import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../session/presentation/providers/session_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final profile = session.profile;
    final rs = context.rs;
    final streak = profile.streakDays == 0 ? 12 : profile.streakDays;

    return ResponsiveBody(
      mode: ResponsiveMode.scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            title: 'Profile',
            subtitle: 'Your year, college, and study preferences.',
          ),
          SizedBox(height: rs.scale(20)),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.fullName.isEmpty ? 'MBBS Student' : profile.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
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
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _MiniStat(label: 'Streak', value: '$streak d')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Year',
                        value: profile.year?.shortLabel ?? '—',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Alerts',
                        value: profile.notificationsEnabled ? 'On' : 'Off',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: rs.scale(20)),
          const SectionLabel('Preferences'),
          SizedBox(height: rs.scale(12)),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  title: const Text('Study reminders', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Daily MCQ and streak nudges'),
                  value: profile.notificationsEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) {
                    session.updateProfile(profile.copyWith(notificationsEnabled: value));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.school_outlined, color: AppColors.primary),
                  title: const Text('Medical college', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(profile.college?.name ?? 'Not set'),
                ),
              ],
            ),
          ),
          SizedBox(height: rs.scale(20)),
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
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.errorSoft),
                backgroundColor: AppColors.errorSoft,
              ),
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

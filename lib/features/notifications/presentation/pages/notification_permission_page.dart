import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/widgets/illustrations.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../session/presentation/providers/session_provider.dart';

class NotificationPermissionPage extends StatelessWidget {
  const NotificationPermissionPage({super.key});

  void _continue(BuildContext context, {required bool allowed}) {
    final session = context.read<SessionProvider>();
    session.updateProfile(session.profile.copyWith(notificationsEnabled: allowed));
    Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return Scaffold(
      body: ResponsiveBody(
        child: Column(
          children: [
            const Spacer(),
            const BellIllustration(),
            SizedBox(height: rs.scale(24)),
            const ScreenTitle(
              title: AppStrings.enableNotifications,
              subtitle: AppStrings.notificationsHint,
              center: true,
            ),
            const Spacer(),
            PrimaryButton(
              label: AppStrings.allow,
              onPressed: () => _continue(context, allowed: true),
            ),
            SizedBox(height: rs.scale(12)),
            SecondaryButton(
              label: AppStrings.notNow,
              onPressed: () => _continue(context, allowed: false),
            ),
          ],
        ),
      ),
    );
  }
}

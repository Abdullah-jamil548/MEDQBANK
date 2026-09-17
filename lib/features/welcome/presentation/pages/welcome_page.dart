import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/widgets/illustrations.dart';
import '../../../../core/widgets/medical_motifs.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../session/presentation/providers/session_provider.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveBody(
        child: Column(
          children: [
            const Spacer(),
            const SuccessCheckmark(),
            const SizedBox(height: 24),
            const ScreenTitle(
              title: AppStrings.youreAllSet,
              subtitle: AppStrings.startJourney,
              center: true,
            ),
            const SizedBox(height: 16),
            const MedicalBadge(label: 'Ready for MBBS revision'),
            const Spacer(),
            PrimaryButton(
              label: AppStrings.goToDashboard,
              onPressed: () async {
                await context.read<SessionProvider>().signIn();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.home,
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

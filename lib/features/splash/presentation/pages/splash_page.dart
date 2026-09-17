import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/medical_motifs.dart';
import '../../../session/presentation/providers/session_provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    final session = context.read<SessionProvider>();
    await session.hydrate();
    if (!mounted) return;
    final wait = const Duration(milliseconds: 1600) - DateTime.now().difference(started);
    _timer = Timer(wait < Duration.zero ? Duration.zero : wait, () {
      if (!mounted) return;
      final route = session.isLoggedIn
          ? AppRoutes.home
          : session.onboardingDone
              ? AppRoutes.login
              : AppRoutes.onboarding;
      Navigator.of(context).pushReplacementNamed(route);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFF), AppColors.primarySoft],
          ),
        ),
        child: ResponsiveBody(
          mode: ResponsiveMode.fill,
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: AppLogo(size: AppLogoSize.large, showWordmark: true),
                ),
              ),
              const MedicalBadge(),
              SizedBox(height: rs.scale(12)),
              Text(
                AppStrings.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: rs.font(15),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              SizedBox(height: rs.scale(28)),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
              ),
              SizedBox(height: rs.scale(16)),
            ],
          ),
        ),
      ),
    );
  }
}

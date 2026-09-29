import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/illustrations.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/step_progress.dart';
import '../../../session/presentation/providers/session_provider.dart';
import '../providers/onboarding_provider.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await context.read<SessionProvider>().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  void _next(OnboardingProvider provider) {
    if (provider.isLastPage) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final rs = context.rs;

    return Scaffold(
      body: ResponsiveBody(
        mode: ResponsiveMode.fill,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const AppLogo(size: AppLogoSize.small),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (!provider.isLastPage)
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(48, 40),
                      ),
                      child: const Text(AppStrings.skip),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: provider.setPage,
                children: const [
                  _OnboardingSlide(
                    illustration: BooksIllustration(),
                    title: AppStrings.onboardingTitle1,
                    body: AppStrings.onboardingBody1,
                  ),
                  _OnboardingSlide(
                    illustration: McqIllustration(),
                    title: AppStrings.onboardingTitle2,
                    body: AppStrings.onboardingBody2,
                  ),
                  _OnboardingSlide(
                    illustration: ProgressIllustration(),
                    title: AppStrings.onboardingTitle3,
                    body: AppStrings.onboardingBody3,
                  ),
                ],
              ),
            ),
            SizedBox(height: rs.scale(16)),
            PageDots(
              count: OnboardingProvider.totalPages,
              index: provider.pageIndex,
            ),
            SizedBox(height: rs.scale(20)),
            PrimaryButton(
              label: provider.isLastPage ? AppStrings.getStarted : AppStrings.next,
              onPressed: () => _next(provider),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final Widget illustration;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                SizedBox(height: rs.scale(12)),
                illustration,
                SizedBox(height: rs.scale(28)),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                        fontSize: rs.font(22),
                      ),
                ),
                SizedBox(height: rs.scale(10)),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                        fontSize: rs.font(15),
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

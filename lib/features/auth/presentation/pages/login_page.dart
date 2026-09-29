import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _login(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithApi();
    if (!context.mounted) return;
    if (!ok) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final rs = context.rs;

    // Prefill test credentials for local development convenience
    if (auth.emailController.text.isEmpty) {
      auth.emailController.text = 'test@medqbank.com';
      auth.passwordController.text = 'Test1234';
    }

    return Scaffold(
      body: ResponsiveBody(
        mode: ResponsiveMode.scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeader(
              title: AppStrings.welcomeBack,
              subtitle: AppStrings.welcomeBackHint,
            ),
            SizedBox(height: rs.scale(24)),
            AppTextField(
              controller: auth.emailController,
              label: AppStrings.email,
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: auth.emailError,
            ),
            SizedBox(height: rs.scale(12)),
            AppTextField(
              controller: auth.passwordController,
              label: AppStrings.password,
              hint: 'Enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: auth.obscurePassword,
              onToggleObscure: auth.togglePassword,
              errorText: auth.passwordError,
            ),
            if (auth.formError != null) ...[
              SizedBox(height: rs.scale(8)),
              Text(
                auth.formError!,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  auth.resetForgotPassword();
                  Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text(AppStrings.forgotPassword),
              ),
            ),
            SizedBox(height: rs.scale(8)),
            PrimaryButton(
              label: auth.isLoading ? 'Signing in…' : AppStrings.login,
              enabled: !auth.isLoading,
              onPressed: () => _login(context),
            ),
            SizedBox(height: rs.scale(12)),
            Text(
              'Test user: test@medqbank.com / Test1234 (60-day access)',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: rs.font(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

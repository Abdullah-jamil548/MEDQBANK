import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/auth_switch_line.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../../../core/widgets/or_divider.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/medical_motifs.dart';
import '../../../../domain/entities/mbbs_year.dart';
import '../../../session/presentation/providers/session_provider.dart';
import '../providers/auth_provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _enterApp(BuildContext context) async {
    final session = context.read<SessionProvider>();
    if (session.profile.year == null) {
      session.updateProfile(
        session.profile.copyWith(
          fullName: session.profile.fullName.isEmpty ? 'Abdullah' : session.profile.fullName,
          year: MbbsYear.third,
          streakDays: 12,
        ),
      );
    }
    await session.signIn();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final rs = context.rs;

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
            SizedBox(height: rs.scale(16)),
            const MedicalBadge(),
            SizedBox(height: rs.scale(20)),
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
              label: AppStrings.login,
              onPressed: () {
                if (!auth.validateLogin()) return;
                auth.completeLogin();
                _enterApp(context);
              },
            ),
            SizedBox(height: rs.scale(20)),
            const OrDivider(),
            SizedBox(height: rs.scale(16)),
            GoogleSignInButton(
              onPressed: () {
                auth.completeGoogleAuth(isSignup: false);
                _enterApp(context);
              },
            ),
            SizedBox(height: rs.scale(28)),
            AuthSwitchLine(
              prompt: AppStrings.dontHaveAccount,
              action: AppStrings.signUp,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
              },
            ),
          ],
        ),
      ),
    );
  }
}

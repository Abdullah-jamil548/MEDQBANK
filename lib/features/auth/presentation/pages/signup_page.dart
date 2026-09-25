import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/auth_switch_line.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../../../core/widgets/or_divider.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../profile_setup/presentation/providers/profile_setup_provider.dart';
import '../providers/auth_provider.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  void _openSetup(BuildContext context) {
    context.read<ProfileSetupProvider>().prepareFromSession();
    Navigator.of(context).pushReplacementNamed(AppRoutes.profileSetup);
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
              title: AppStrings.createAccount,
              subtitle: AppStrings.createAccountHint,
            ),
            SizedBox(height: rs.scale(24)),
            AppTextField(
              controller: auth.fullNameController,
              label: AppStrings.fullName,
              hint: 'e.g. Abdullah Khan',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              errorText: auth.fullNameError,
            ),
            SizedBox(height: rs.scale(12)),
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
              hint: 'At least 6 characters',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: auth.obscurePassword,
              onToggleObscure: auth.togglePassword,
              textInputAction: TextInputAction.next,
              errorText: auth.passwordError,
            ),
            SizedBox(height: rs.scale(12)),
            AppTextField(
              controller: auth.confirmPasswordController,
              label: AppStrings.confirmPassword,
              hint: 'Re-enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: auth.obscureConfirmPassword,
              onToggleObscure: auth.toggleConfirmPassword,
              errorText: auth.confirmPasswordError,
            ),
            SizedBox(height: rs.scale(16)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: auth.agreedToTerms,
                    onChanged: auth.setAgreedToTerms,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    AppStrings.agreeTerms,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (auth.termsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 34),
                child: Text(
                  auth.termsError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            if (auth.formError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  auth.formError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            SizedBox(height: rs.scale(20)),
            PrimaryButton(
              label: auth.isLoading ? 'Creating account…' : AppStrings.signUp,
              enabled: !auth.isLoading,
              onPressed: () async {
                final ok = await auth.registerWithApi();
                if (!context.mounted || !ok) return;
                _openSetup(context);
              },
            ),
            SizedBox(height: rs.scale(20)),
            const OrDivider(),
            SizedBox(height: rs.scale(16)),
            GoogleSignInButton(
              onPressed: () {
                auth.completeGoogleAuth(isSignup: true);
              },
            ),
            SizedBox(height: rs.scale(28)),
            AuthSwitchLine(
              prompt: AppStrings.alreadyHaveAccount,
              action: AppStrings.login,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              },
            ),
          ],
        ),
      ),
    );
  }
}

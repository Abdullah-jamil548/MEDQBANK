import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/illustrations.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final rs = context.rs;

    return Scaffold(
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppBackButton(),
            SizedBox(height: rs.scale(24)),
            Center(child: auth.resetLinkSent ? const SuccessCheckmark() : const LockIllustration()),
            SizedBox(height: rs.scale(24)),
            ScreenTitle(
              title: auth.resetLinkSent ? AppStrings.resetEmailSent : AppStrings.forgotPassword,
              subtitle: auth.resetLinkSent ? null : AppStrings.forgotPasswordHint,
              center: true,
            ),
            SizedBox(height: rs.scale(24)),
            if (!auth.resetLinkSent) ...[
              AppTextField(
                controller: auth.resetEmailController,
                label: AppStrings.email,
                hint: 'you@example.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                errorText: auth.resetEmailError,
              ),
              SizedBox(height: rs.scale(20)),
              PrimaryButton(
                label: AppStrings.sendResetLink,
                onPressed: () {
                  if (!auth.validateResetEmail()) return;
                  auth.sendResetLink();
                },
              ),
            ] else
              PrimaryButton(
                label: AppStrings.backToLogin,
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

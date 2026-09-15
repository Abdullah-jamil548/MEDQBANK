import 'package:flutter/material.dart';

import '../responsive/app_responsive.dart';
import '../theme/app_colors.dart';
import 'app_logo.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(size: AppLogoSize.small),
        SizedBox(height: rs.scale(20)),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: rs.font(24),
                height: 1.25,
              ),
        ),
        SizedBox(height: rs.scale(8)),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.45,
            fontSize: rs.font(15),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.center = false,
  });

  final String title;
  final String? subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final align = center ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: rs.font(24),
                height: 1.25,
              ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: rs.scale(8)),
          Text(
            subtitle!,
            textAlign: align,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: rs.font(15),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

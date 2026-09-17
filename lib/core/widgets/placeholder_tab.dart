import 'package:flutter/material.dart';

import '../responsive/app_responsive.dart';
import '../responsive/responsive_body.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';
import 'page_header.dart';

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle(title: title, subtitle: subtitle),
          const Spacer(),
          AppCard(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
            child: Column(
              children: [
                Container(
                  width: rs.scale(72),
                  height: rs.scale(72),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, size: rs.scale(34), color: AppColors.primary),
                ),
                SizedBox(height: rs.scale(16)),
                Text(
                  'Coming next',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: rs.font(18),
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: rs.scale(8)),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontSize: rs.font(14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

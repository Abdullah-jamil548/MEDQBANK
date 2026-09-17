import 'package:flutter/material.dart';

import '../responsive/app_responsive.dart';
import '../theme/app_colors.dart';

enum AppLogoSize { small, medium, large }

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = AppLogoSize.medium,
    this.showWordmark = false,
    this.lightWordmark = false,
  });

  final AppLogoSize size;
  final bool showWordmark;
  final bool lightWordmark;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final markSize = rs.scale(switch (size) {
      AppLogoSize.small => 44,
      AppLogoSize.medium => 68,
      AppLogoSize.large => 92,
    });

    final mark = Container(
      width: markSize,
      height: markSize,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(markSize * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(painter: _MedQBankMarkPainter()),
    );

    if (!showWordmark) return mark;

    final titleColor = lightWordmark ? Colors.white : AppColors.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: rs.scale(size == AppLogoSize.large ? 14 : 10)),
        Text(
          'MedQBank',
          style: TextStyle(
            fontSize: rs.font(size == AppLogoSize.large ? 30 : 22),
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _MedQBankMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    final teal = Paint()..color = Colors.white;
    final crease = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;

    final left = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.38,
        size.width * 0.28,
        size.height * 0.34,
      ),
      Radius.circular(size.width * 0.04),
    );
    final right = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.38,
        size.width * 0.28,
        size.height * 0.34,
      ),
      Radius.circular(size.width * 0.04),
    );
    canvas.drawRRect(left, white);
    canvas.drawRRect(right, white);
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.40),
      Offset(size.width * 0.50, size.height * 0.70),
      crease,
    );

    final cross = Offset(size.width * 0.50, size.height * 0.30);
    final barW = size.width * 0.055;
    final barH = size.width * 0.20;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: cross, width: barW, height: barH),
        const Radius.circular(3),
      ),
      teal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: cross, width: barH, height: barW),
        const Radius.circular(3),
      ),
      teal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

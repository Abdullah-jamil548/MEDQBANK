import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../responsive/app_responsive.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.rs.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(size: const Size(20, 20), painter: _GoogleGPainter()),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                AppStrings.continueGoogle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect.deflate(2), -0.2, 1.8, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect.deflate(2), 1.6, 1.2, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect.deflate(2), 2.8, 0.8, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect.deflate(2), 3.6, 1.1, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

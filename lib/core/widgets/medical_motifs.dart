import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Heartbeat waveform used as a medical signature across the app.
class EcgLine extends StatelessWidget {
  const EcgLine({
    super.key,
    this.color = AppColors.secondary,
    this.height = 28,
    this.stroke = 2,
  });

  final Color color;
  final double height;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: EcgPainter(color: color, stroke: stroke),
      ),
    );
  }
}

class EcgPainter extends CustomPainter {
  const EcgPainter({required this.color, this.stroke = 2});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final mid = size.height * 0.58;
    final w = size.width;

    path.moveTo(0, mid);
    path.lineTo(w * 0.18, mid);
    path.lineTo(w * 0.24, mid - size.height * 0.12);
    path.lineTo(w * 0.30, mid);
    path.lineTo(w * 0.38, mid);
    path.lineTo(w * 0.44, mid + size.height * 0.18);
    path.lineTo(w * 0.50, mid - size.height * 0.42);
    path.lineTo(w * 0.56, mid + size.height * 0.28);
    path.lineTo(w * 0.62, mid);
    path.lineTo(w * 0.74, mid);
    path.lineTo(w * 0.80, mid - size.height * 0.10);
    path.lineTo(w * 0.86, mid);
    path.lineTo(w, mid);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant EcgPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.stroke != stroke;
}

class MedicalCross extends StatelessWidget {
  const MedicalCross({
    super.key,
    this.size = 18,
    this.color = AppColors.secondary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CrossPainter(color)),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bar = size.width * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: bar,
          height: size.height,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width,
          height: bar,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossPainter oldDelegate) => oldDelegate.color != color;
}

class MedicalBadge extends StatelessWidget {
  const MedicalBadge({
    super.key,
    this.label = 'For MBBS students',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MedicalCross(size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectChips extends StatelessWidget {
  const SubjectChips({super.key, this.onTap});

  final ValueChanged<String>? onTap;

  static const subjects = [
    (Icons.accessibility_new_rounded, 'Anatomy'),
    (Icons.biotech_rounded, 'Physiology'),
    (Icons.science_rounded, 'Pathology'),
    (Icons.medication_rounded, 'Pharmacology'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final subject in subjects) ...[
            _chip(subject.$1, subject.$2),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(label),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

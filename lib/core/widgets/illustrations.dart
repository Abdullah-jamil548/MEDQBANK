import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../responsive/app_responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

class IllustrationFrame extends StatelessWidget {
  const IllustrationFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = context.rs.illustrationHeight;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(child: child),
    );
  }
}

class BooksIllustration extends StatelessWidget {
  const BooksIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return IllustrationFrame(
      child: SizedBox(
        width: 230,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(left: 16, bottom: 22, child: _book(AppColors.secondary, -0.14, 88)),
            Positioned(right: 18, bottom: 26, child: _book(AppColors.primaryDark, 0.16, 82)),
            _book(AppColors.primary, 0, 108),
          ],
        ),
      ),
    );
  }

  Widget _book(Color color, double angle, double height) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 76,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class McqIllustration extends StatelessWidget {
  const McqIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return IllustrationFrame(
      child: Container(
        width: 248,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Question 12',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
                Spacer(),
                _TimerChip(),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Which nerve innervates the diaphragm?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
            SizedBox(height: 10),
            _OptionChip(label: 'Phrenic nerve', selected: true),
            SizedBox(height: 6),
            _OptionChip(label: 'Vagus nerve'),
          ],
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.streakSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.timer_outlined, size: 12, color: AppColors.streak),
          SizedBox(width: 4),
          Text(
            '01:24',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.streak,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.successSoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? AppColors.success : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: selected ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressIllustration extends StatelessWidget {
  const ProgressIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return IllustrationFrame(
      child: Container(
        width: 252,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                _MiniStat(label: 'MCQs', value: '86'),
                _MiniStat(label: 'Accuracy', value: '78%'),
                _MiniStat(label: 'Week', value: '+12%'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(28),
                _bar(46),
                _bar(34),
                _bar(58),
                _bar(50),
                _bar(40),
                _bar(64, highlight: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double height, {bool highlight = false}) {
    return Expanded(
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primary : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class LockIllustration extends StatelessWidget {
  const LockIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(Icons.lock_reset_rounded, size: 40, color: AppColors.primary),
    );
  }
}

class BellIllustration extends StatelessWidget {
  const BellIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: AppColors.secondarySoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.notifications_active_rounded, size: 52, color: AppColors.secondary),
    );
  }
}

class SuccessCheckmark extends StatelessWidget {
  const SuccessCheckmark({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.86, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: 108,
        height: 108,
        decoration: const BoxDecoration(
          color: AppColors.successSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 56, color: AppColors.success),
      ),
    );
  }
}

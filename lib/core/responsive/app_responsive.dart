import 'package:flutter/material.dart';

enum AppBreakpoint { mobile, tablet, desktop }

/// Screen-aware sizes for the whole app.
///
/// Use via `context.rs`. Designed against a 390pt mobile canvas,
/// then clamped so tablet/desktop stay readable without stretching.
class AppResponsive {
  const AppResponsive._({
    required this.width,
    required this.height,
    required this.shortestSide,
    required this.orientation,
  });

  factory AppResponsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AppResponsive._(
      width: size.width,
      height: size.height,
      shortestSide: size.shortestSide,
      orientation: MediaQuery.orientationOf(context),
    );
  }

  static const double designWidth = 390;
  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  final double width;
  final double height;
  final double shortestSide;
  final Orientation orientation;

  bool get isMobile => width < mobileMax;
  bool get isTablet => width >= mobileMax && width < tabletMax;
  bool get isDesktop => width >= tabletMax;
  bool get isShort => height < 700;
  bool get isLandscape => orientation == Orientation.landscape;

  AppBreakpoint get breakpoint {
    if (isDesktop) return AppBreakpoint.desktop;
    if (isTablet) return AppBreakpoint.tablet;
    return AppBreakpoint.mobile;
  }

  /// Centered content width on large screens.
  double get contentWidth {
    if (isDesktop) return 720;
    if (isTablet) return 600;
    return width;
  }

  double get pagePadding {
    if (isDesktop) return 32;
    if (isTablet) return 28;
    return width < 360 ? 16 : 20;
  }

  EdgeInsets get pageInsets => EdgeInsets.fromLTRB(
        pagePadding,
        isShort ? 12 : 20,
        pagePadding,
        isShort ? 16 : 24,
      );

  double get buttonHeight => isShort ? 48 : 54;

  double get illustrationHeight {
    if (isShort) return 168;
    if (isTablet || isDesktop) return 260;
    return 220;
  }

  int get cardColumns {
    if (isDesktop) return 2;
    if (isTablet && isLandscape) return 2;
    return 1;
  }

  /// Scale a design-token size from the 390pt canvas.
  double scale(double value, {double min = 0.88, double max = 1.12}) {
    return value * (width / designWidth).clamp(min, max);
  }

  /// Slightly scaled type — keeps headlines readable, never huge.
  double font(double value) => scale(value, min: 0.92, max: 1.06);

  T when<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}

extension AppResponsiveX on BuildContext {
  AppResponsive get rs => AppResponsive.of(this);
}

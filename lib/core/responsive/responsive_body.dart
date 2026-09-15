import 'package:flutter/material.dart';

import 'app_responsive.dart';

enum ResponsiveMode {
  /// Page already scrolls (ListView) or uses Expanded. Bounded height.
  fill,

  /// Always scroll. Forms and short content.
  scroll,

  /// Fill tall screens, scroll on short ones. Safe with Column + Spacer.
  fillOrScroll,
}

/// Applies the app responsive rules to any screen:
/// safe area, horizontal padding, and a centered max-width on tablet/desktop.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.mode = ResponsiveMode.fillOrScroll,
    this.padding,
    this.safeArea = true,
  });

  final Widget child;
  final ResponsiveMode mode;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final insets = padding ?? rs.pageInsets;

    Widget content = switch (mode) {
      ResponsiveMode.fill => Padding(padding: insets, child: child),
      ResponsiveMode.scroll => SingleChildScrollView(
          padding: insets,
          child: child,
        ),
      ResponsiveMode.fillOrScroll => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: insets,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: child,
              ),
            ),
          ],
        ),
    };

    Widget body = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > rs.contentWidth
            ? rs.contentWidth
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: content,
          ),
        );
      },
    );

    if (safeArea) {
      body = SafeArea(child: body);
    }
    return body;
  }
}

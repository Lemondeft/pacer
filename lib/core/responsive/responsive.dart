import 'package:flutter/widgets.dart';

/// Breakpoints for the whole app. Defined ONCE — screens never inline widths.
class Breakpoints {
  static const double compact = 600; // phone
  static const double medium = 900; // small tablet, narrow window
  static const double expanded = 1200; // large tablet, desktop
}

enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeOf(double width) {
  if (width < Breakpoints.compact) return ScreenSize.compact;
  if (width < Breakpoints.expanded) return ScreenSize.medium;
  return ScreenSize.expanded;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  ScreenSize get screenSize => screenSizeOf(screenWidth);
  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isMedium => screenSize == ScreenSize.medium;
  bool get isExpanded => screenSize == ScreenSize.expanded;
}

/// Smoothly scales a value between [min] at [from] width and [max] at [to]
/// width. Clamped outside the range — no extrapolation.
double fluid(
  double width,
  double min,
  double max, {
  double from = 360,
  double to = 1200,
}) {
  final t = ((width - from) / (to - from)).clamp(0.0, 1.0);
  return min + (max - min) * t;
}

/// Page shell every screen uses: fluid gutters, wide max content width
/// (1100 for dashboards/lists/grids, 720 for text-heavy forms and settings).
/// Content renders NATIVE at every size — never a scaled phone column.
class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.child, this.maxWidth = 1100});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final gutter = fluid(context.screenWidth, 16, 40);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}

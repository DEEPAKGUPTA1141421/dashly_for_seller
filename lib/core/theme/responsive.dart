import 'package:flutter/widgets.dart';

class Responsive {
  static const double _mobileBreak  = 768;
  static const double _desktopBreak = 1280;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _mobileBreak;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= _mobileBreak && w < _desktopBreak;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _desktopBreak;

  /// Returns [mobile], or [tablet]/[desktop] overrides when screen is wider.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  static double horizontalPadding(BuildContext context) =>
      value(context, mobile: 16.0, tablet: 32.0, desktop: 48.0);

  static int gridColumns(BuildContext context) =>
      value(context, mobile: 1, tablet: 2, desktop: 3);

  static int statColumns(BuildContext context) =>
      value(context, mobile: 2, tablet: 3, desktop: 4);
}

import 'package:flutter/material.dart';

/// Standard Material 3 & MNC-Grade Responsive Window Class Breakpoints
/// Supports:
/// - Compact: Phones in portrait (iOS & Android)
/// - Medium: Foldables open, small tablets, iPad mini, landscape phones
/// - Expanded: Laptops, standard desktop monitors, iPad in landscape
/// - Large: Ultra-wide monitors, 4K displays, interactive Touchscreen Smartboards
class ResponsiveBreakpoints {
  static const double compactMaxWidth = 600.0;
  static const double mediumMaxWidth = 1024.0;
  static const double expandedMaxWidth = 1440.0;

  // Clamped max width for forms and readable pages on ultra-wide screens & smartboards
  static const double maxContentWidth = 1200.0;
  static const double maxFormWidth = 800.0;
  static const double maxDialogWidth = 520.0;

  /// Check if the viewport is Compact (Mobile phones)
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMaxWidth;

  /// Check if the viewport is Medium (Tablets, foldables)
  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactMaxWidth && width < mediumMaxWidth;
  }

  /// Check if the viewport is Expanded (Laptops, regular desktops)
  static bool isExpanded(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mediumMaxWidth && width < expandedMaxWidth;
  }

  /// Check if the viewport is Large (Ultra-wide, 4K, Touchscreen Smartboards)
  static bool isLarge(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expandedMaxWidth;

  /// True if device should use mobile/tablet touch patterns (single column, bottom sheets, etc.)
  static bool isMobileOrTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mediumMaxWidth;

  /// True if device has enough real estate for desktop sidebars and multi-column tables
  static bool isDesktopOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumMaxWidth;
}

/// Handy extension on [BuildContext] for responsive access everywhere
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get screenPadding => MediaQuery.paddingOf(this);
  EdgeInsets get screenViewInsets => MediaQuery.viewInsetsOf(this);

  bool get isCompact => ResponsiveBreakpoints.isCompact(this);
  bool get isMedium => ResponsiveBreakpoints.isMedium(this);
  bool get isExpanded => ResponsiveBreakpoints.isExpanded(this);
  bool get isLarge => ResponsiveBreakpoints.isLarge(this);

  bool get isMobileOrTablet => ResponsiveBreakpoints.isMobileOrTablet(this);
  bool get isDesktopOrLarger => ResponsiveBreakpoints.isDesktopOrLarger(this);

  /// Safe adaptive horizontal padding for content based on screen width
  EdgeInsets get adaptiveHorizontalPadding {
    if (isCompact) return const EdgeInsets.symmetric(horizontal: 16.0);
    if (isMedium) return const EdgeInsets.symmetric(horizontal: 24.0);
    return const EdgeInsets.symmetric(horizontal: 32.0);
  }
}

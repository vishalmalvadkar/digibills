import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// A wrapper widget that clamps content width on wide monitors, desktops,
/// and interactive touchscreen boards (4K/ultra-wide) so forms and text
/// do not stretch across thousands of pixels while remaining responsive on phones.
class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  /// Specific helper for form screens (Billing, Settings, Quotes)
  const MaxWidthContainer.form({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxFormWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? context.adaptiveHorizontalPadding,
          child: child,
        ),
      ),
    );
  }
}

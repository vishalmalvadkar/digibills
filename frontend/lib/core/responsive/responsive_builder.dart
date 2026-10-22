import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// A widget that renders different UI trees based on the window size class.
/// At minimum, [compact] (mobile) must be provided.
/// Other sizes fall back gracefully to the next smaller available size:
/// large -> expanded -> medium -> compact.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) compact;
  final Widget Function(BuildContext context)? medium;
  final Widget Function(BuildContext context)? expanded;
  final Widget Function(BuildContext context)? large;

  const ResponsiveBuilder({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
    this.large,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= ResponsiveBreakpoints.expandedMaxWidth && large != null) {
          return large!(context);
        }
        if (width >= ResponsiveBreakpoints.mediumMaxWidth && expanded != null) {
          return expanded!(context);
        }
        if (width >= ResponsiveBreakpoints.compactMaxWidth && medium != null) {
          return medium!(context);
        }
        return compact(context);
      },
    );
  }
}

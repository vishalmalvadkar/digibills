import 'package:flutter/material.dart';
import 'universal_top_header.dart';
export 'universal_top_header.dart';

/// DesktopTopBar is now unified with [UniversalTopHeader] to ensure
/// a single, consistent, responsive top navigation header across all screen sizes.
class DesktopTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNavigateToSettings;
  final bool isScrolled;

  const DesktopTopBar({
    super.key,
    this.onNavigateToSettings,
    this.isScrolled = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(isScrolled ? 58 : 84);

  @override
  Widget build(BuildContext context) {
    return UniversalTopHeader(
      onNavigateToSettings: onNavigateToSettings,
      isScrolled: isScrolled,
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum SnackBarType { success, warning, error, info }

/// Universal SnackBar Helper for DigiInvi.
/// Enforces consistent UI across the entire application:
/// - Success: Green (#10B981) with check icon
/// - Warning: Amber (#D97706 / Amber-600) with warning icon
/// - Error: Red (#EF4444) with error icon
/// - Info: Primary Midnight Blue (#112E65) with info icon
class SnackbarHelper {
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Universal Color Palette for SnackBars
  static const Color successColor = Color(0xFF10B981); // Emerald Green
  static const Color warningColor = Color(0xFFD97706); // Amber-600 (High contrast with white text)
  static const Color errorColor = Color(0xFFEF4444);   // Vivid Crimson Red
  static const Color infoColor = AppColors.primary;    // Midnight Blue

  /// Show a Success (Green) SnackBar using BuildContext
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showWithContext(
      context,
      message: message,
      title: title,
      type: SnackBarType.success,
      duration: duration,
      action: action,
    );
  }

  /// Show a Warning (Amber) SnackBar using BuildContext
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showWithContext(
      context,
      message: message,
      title: title,
      type: SnackBarType.warning,
      duration: duration,
      action: action,
    );
  }

  /// Show an Error (Red) SnackBar using BuildContext
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showWithContext(
      context,
      message: message,
      title: title,
      type: SnackBarType.error,
      duration: duration,
      action: action,
    );
  }

  /// Show an Info (Blue) SnackBar using BuildContext
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showWithContext(
      context,
      message: message,
      title: title,
      type: SnackBarType.info,
      duration: duration,
      action: action,
    );
  }

  /// Global Success (Green) SnackBar (usable without BuildContext or across route pops)
  static void showGlobalSuccess(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showGlobal(
      message: message,
      title: title,
      type: SnackBarType.success,
      duration: duration,
      action: action,
    );
  }

  /// Global Warning (Amber) SnackBar
  static void showGlobalWarning(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showGlobal(
      message: message,
      title: title,
      type: SnackBarType.warning,
      duration: duration,
      action: action,
    );
  }

  /// Global Error (Red) SnackBar
  static void showGlobalError(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showGlobal(
      message: message,
      title: title,
      type: SnackBarType.error,
      duration: duration,
      action: action,
    );
  }

  /// Global Info (Blue) SnackBar
  static void showGlobalInfo(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showGlobal(
      message: message,
      title: title,
      type: SnackBarType.info,
      duration: duration,
      action: action,
    );
  }

  // --- Internal Builders ---

  static void _showWithContext(
    BuildContext context, {
    required String message,
    String? title,
    required SnackBarType type,
    required Duration duration,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      _showGlobal(
        message: message,
        title: title,
        type: type,
        duration: duration,
        action: action,
      );
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      _buildSnackBar(
        message: message,
        title: title,
        type: type,
        duration: duration,
        action: action,
      ),
    );
  }

  static void _showGlobal({
    required String message,
    String? title,
    required SnackBarType type,
    required Duration duration,
    SnackBarAction? action,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      _buildSnackBar(
        message: message,
        title: title,
        type: type,
        duration: duration,
        action: action,
      ),
    );
  }

  static SnackBar _buildSnackBar({
    required String message,
    String? title,
    required SnackBarType type,
    required Duration duration,
    SnackBarAction? action,
  }) {
    final Color backgroundColor;
    final IconData iconData;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = successColor;
        iconData = Icons.check_circle_rounded;
        break;
      case SnackBarType.warning:
        backgroundColor = warningColor;
        iconData = Icons.warning_amber_rounded;
        break;
      case SnackBarType.error:
        backgroundColor = errorColor;
        iconData = Icons.error_outline_rounded;
        break;
      case SnackBarType.info:
        backgroundColor = infoColor;
        iconData = Icons.info_outline_rounded;
        break;
    }

    return SnackBar(
      elevation: 6,
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration,
      action: action,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title.isNotEmpty) ...[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

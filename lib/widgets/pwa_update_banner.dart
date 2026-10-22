import 'package:flutter/material.dart';
import '../services/pwa_update_service.dart';
import '../theme/app_colors.dart';

class PwaUpdateBanner extends StatelessWidget {
  const PwaUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PwaUpdateService().updateAvailable,
      builder: (context, available, child) {
        if (!available) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.system_update, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'New Update Available',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Refresh to get the latest features.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    PwaUpdateService().reloadApp();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Refresh',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    // Temporarily hide for this session?
                    // For now, allow dismissing via ValueNotifier if we add a 'dismissed' state
                    // or just ignored. The user asked for "Dismiss option (optional)".
                    // Implementing simple local dismiss logic would require more state.
                    // Let's just update the value to false for the UI session.
                    PwaUpdateService().updateAvailable.value = false;
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

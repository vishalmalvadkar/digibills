import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../theme/app_colors.dart';

class LicenseRenewalSuccessDialog extends StatefulWidget {
  final String planName;
  final DateTime expiryDate;
  final VoidCallback? onDismiss;

  const LicenseRenewalSuccessDialog({
    Key? key,
    required this.planName,
    required this.expiryDate,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<LicenseRenewalSuccessDialog> createState() => _LicenseRenewalSuccessDialogState();
}

class _LicenseRenewalSuccessDialogState extends State<LicenseRenewalSuccessDialog> {
  late ConfettiController _controllerCenter;

  @override
  void initState() {
    super.initState();
    _controllerCenter = ConfettiController(duration: const Duration(seconds: 3));
    _controllerCenter.play();
  }

  @override
  void dispose() {
    _controllerCenter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dialog in the center
        Align(
          alignment: Alignment.center,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: AppColors.success, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your license has been successfully renewed!',
                  style: TextStyle(fontSize: 16, color: AppColors.textGrey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Plan:', style: TextStyle(color: AppColors.textGrey)),
                          Text(
                            widget.planName.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valid Until:', style: TextStyle(color: AppColors.textGrey)),
                          Text(
                            "${widget.expiryDate.day}/${widget.expiryDate.month}/${widget.expiryDate.year}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (widget.onDismiss != null) {
                        widget.onDismiss!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Confetti Widget - Top Center 
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controllerCenter,
            blastDirection: pi / 2, // down
            maxBlastForce: 20, // increased for more impact
            minBlastForce: 8,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.2, // faster fall
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.red,
            ], 
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../theme/app_colors.dart';

class LicenseCelebrationCard extends StatefulWidget {
  final String planName;
  final DateTime expiryDate;
  final VoidCallback onDismiss;

  const LicenseCelebrationCard({
    Key? key,
    required this.planName,
    required this.expiryDate,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<LicenseCelebrationCard> createState() => _LicenseCelebrationCardState();
}

class _LicenseCelebrationCardState extends State<LicenseCelebrationCard> {
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.success.withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: AppColors.success, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'License Renewed!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textGrey),
                    onPressed: widget.onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your ${widget.planName} plan is now active until ${widget.expiryDate.day}/${widget.expiryDate.month}/${widget.expiryDate.year}.',
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Confetti Widget - Within the card bounds, usually centered top
        Positioned(
          top: 0,
          left: MediaQuery.of(context).size.width / 2 - 20, // Approx center for card context
          child: ConfettiWidget(
            confettiController: _controllerCenter,
            blastDirection: -pi / 2, // Up
            maxBlastForce: 10,
            minBlastForce: 5,
            emissionFrequency: 0.05,
            numberOfParticles: 10,
            gravity: 0.1,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
            ], 
          ),
        ),
      ],
    );
  }
}

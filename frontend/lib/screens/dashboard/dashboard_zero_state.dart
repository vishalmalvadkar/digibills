import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../create_bill_screen.dart';

class DashboardZeroState extends StatelessWidget {
  final VoidCallback? onActionComplete;
  const DashboardZeroState({super.key, this.onActionComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Graphic / Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Text
          const Text(
            "Ready to grow your business?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Welcome! Start by creating your first invoice to unlock professional business analytics, income trends, and success metrics here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          // Action (Optional - can just inform, but CTA is better)
          ElevatedButton.icon(
            onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const CreateBillScreen())
                ).then((_) {
                  if (onActionComplete != null) onActionComplete!();
                });
             },
            icon: const Icon(Icons.add, size: 20),
            label: const Text("Create First Invoice"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'create_bill_screen.dart';
import 'create_quote_screen.dart'; // NEW
import 'purchases/create_purchase_screen.dart';
import 'create_credit_note_screen.dart'; // NEW import

class CreationMenuScreen extends StatelessWidget {
  const CreationMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Document'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOptionCard(
            context,
            title: 'Invoice',
            description: 'Request payment for completed work',
            icon: Icons.receipt_long,
            color: Colors.blue,
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateBillScreen()),
              );
            },
          ),
          _buildOptionCard(
            context,
            title: 'Quotation',
            description: 'Propose prices to clients before work',
            icon: Icons.description_outlined,
            color: Colors.orange,
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateQuoteScreen()),
              );
            },
          ),
          _buildOptionCard(
            context,
            title: 'Proforma Invoice',
            description: 'Preliminary bill before delivery',
            icon: Icons.receipt,
            color: Colors.purple,
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateQuoteScreen(initialDocType: 'Proforma')),
              );
            },
          ),
          _buildOptionCard(
            context,
            title: 'Purchase Bill',
            description: 'Record goods received from a supplier',
            icon: Icons.shopping_bag_outlined,
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePurchaseScreen()),
              );
            },
          ),
          _buildOptionCard(
            context,
            title: 'Delivery Note',
            description: 'Proof of goods delivery',
            icon: Icons.local_shipping_outlined,
            color: Colors.indigo,
            onTap: () => _showComingSoon(context, 'Delivery Note'),
          ),
          _buildOptionCard(
            context,
            title: 'Sales Return (Credit Note)',
            description: 'Process return of goods',
            icon: Icons.undo,
            color: Colors.redAccent,
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateCreditNoteScreen()),
              );
            },
          ),
          _buildOptionCard(
            context,
            title: 'Receipt',
            description: 'Proof of payment received',
            icon: Icons.check_circle_outline,
            color: Colors.green,
            onTap: () => _showComingSoon(context, 'Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature Coming Soon!')),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/settings_model.dart';
import '../theme/app_colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // NEW

class PaymentRemindersCard extends StatefulWidget {
  final List<BillModel> bills;
  final AppSettings? settings;

  const PaymentRemindersCard({
    super.key,
    required this.bills,
    required this.settings,
  });

  @override
  State<PaymentRemindersCard> createState() => _PaymentRemindersCardState();
}

class _PaymentRemindersCardState extends State<PaymentRemindersCard> {
  bool _isExpanded = true;
  final PageController _pageController = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter Pending/Partial Bills
    final pendingBills = widget.bills.where((b) {
      return b.paymentStatus == 'Pending' || b.paymentStatus == 'Partial';
    }).toList();

    // Sort by days pending (oldest first)
    pendingBills.sort((a, b) => a.billDate.compareTo(b.billDate));

    if (pendingBills.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.access_time_filled, color: Colors.orange.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Payment Reminders',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingBills.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          AnimatedCrossFade(
            firstChild: SizedBox(
              height: 140, // Height for the carousel
              child: PageView.builder(
                controller: _pageController,
                itemCount: pendingBills.length,
                itemBuilder: (context, index) {
                  return _buildReminderItem(pendingBills[index]);
                },
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
          
          if (_isExpanded) const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildReminderItem(BillModel bill) {
    final daysPending = DateTime.now().difference(bill.billDate).inDays;
    final balanceDue = bill.totalAmount - bill.advanceAmount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Left: Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bill.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${balanceDue.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                    ),
                    const Text(' • ', style: TextStyle(color: Colors.grey)),
                    const Icon(Icons.history, size: 12, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '$daysPending days',
                      style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  'Inv: ${bill.invoiceNumber}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),


          // WhatsApp Action Removed
        ],
      ),
    );
  }
}

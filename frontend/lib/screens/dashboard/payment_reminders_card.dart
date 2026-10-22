import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bill_model.dart';
import '../../models/settings_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/pdf_invoice_helper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../bills_screen.dart';

class PaymentRemindersCard extends StatefulWidget {
  final List<BillModel> bills;
  final AppSettings? settings;

  const PaymentRemindersCard({
    super.key,
    required this.bills,
    this.settings,
  });

  @override
  State<PaymentRemindersCard> createState() => _PaymentRemindersCardState();
}

class _PaymentRemindersCardState extends State<PaymentRemindersCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // 1. Filter & Sort Pending Bills
    final pendingBills = widget.bills.where((b) {
      return b.paymentStatus != 'Paid';
    }).toList();

    // Sort by Date (Oldest First - Most Urgent)
    pendingBills.sort((a, b) => a.billDate.compareTo(b.billDate));

    if (pendingBills.isEmpty) {
      return const SizedBox.shrink(); // Hide if no pending bills
    }

    final totalPendingAmount = pendingBills.fold(0.0, (sum, item) {
       final paid = item.advanceAmount; // Advance is essentially partial payment here? 
       // Note: In BillModel logic elsewhere, balance = total - advance. 
       // If status is partial, we should technically check payments list, but simplified model uses advance/status.
       // Let's stick to (total - advance) for consistency with BillViewScreen.
       return sum + (item.totalAmount - item.advanceAmount);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (Clickable to Toggle)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(20)), // All if collapsed
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: AppColors.warning.withOpacity(0.1),
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(Icons.timer_outlined, color: AppColors.warning, size: 20),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text(
                           'Payment Reminders',
                           style: TextStyle(
                             fontSize: 16,
                             fontWeight: FontWeight.bold,
                             color: AppColors.textDark,
                           ),
                         ),
                         Text(
                           '${pendingBills.length} Pending • ₹${totalPendingAmount.toStringAsFixed(0)}',
                           style: const TextStyle(
                             fontSize: 12,
                             color: AppColors.textGrey,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                       ],
                     ),
                   ),
                   Icon(
                     _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                     color: AppColors.textGrey,
                   ),
                ],
              ),
            ),
          ),
          
          // Body (List)
          if (_isExpanded) ...[
             const Divider(height: 1, color: AppColors.border),
             ListView.separated(
               shrinkWrap: true,
               physics: const NeverScrollableScrollPhysics(),
               padding: const EdgeInsets.all(0),
               itemCount: pendingBills.length > 5 ? 5 : pendingBills.length, // Show max 5
               separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.border),
               itemBuilder: (context, index) {
                 final bill = pendingBills[index];
                 final days = DateTime.now().difference(bill.billDate).inDays;
                 final balance = bill.totalAmount - bill.advanceAmount;
                 
                 String timeText;
                 Color timeColor;
                 
                 if (days > 0) {
                   timeText = '$days days overdue';
                   timeColor = AppColors.error;
                 } else if (days == 0) {
                   timeText = 'Due today';
                   timeColor = AppColors.warning;
                 } else {
                   timeText = 'Due in ${days.abs()} days';
                   timeColor = AppColors.success;
                 }

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                   contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                   title: Text(
                     bill.customerName,
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                   subtitle: Row(
                     children: [
                       Text(
                         '#${bill.invoiceNumber} • ',
                         style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                       ),
                       Text(
                         timeText,
                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: timeColor),
                       ),
                     ],
                   ),
                   trailing: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         '₹${balance.toStringAsFixed(0)}',
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                       ),
                       const SizedBox(width: 12),
                       IconButton(
                         icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20, color: Colors.green),
                         onPressed: () {
                           // Reuse the exact verification logic
                           PdfInvoiceHelper.openWhatsApp(context, bill, overrideSettings: widget.settings, isReminder: true);
                         },
                         tooltip: 'Send Reminder',
                       ),
                     ],
                   ),
                   onTap: () {
                     // Navigate to detail
                     Navigator.pushNamed(context, '/view-bill?id=${bill.billId}'); 
                     // Or standard nav if route not set up for internal:
                     // Navigator.push(context, MaterialPageRoute(builder: (_) => BillViewScreen(billId: bill.billId)));
                     // But let's assume standard named route or reuse dashboard nav logic if possible.
                     // Since BillViewScreen handles it:
                     // Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillViewScreen(billId: bill.billId)));
                     // Actually, let's keep it simple and just do the WhatsApp action as requested primarily.
                     // But clicking might be nice. 
                   },
                  ),
                  );
               },
             ),
             if (pendingBills.length > 5)
               InkWell(
                 onTap: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (_) => const BillsScreen(
                         initialIndex: 0,
                         initialFilterStatus: 'Pending',
                       ),
                     ),
                   );
                 },
                 child: Padding(
                   padding: const EdgeInsets.all(12),
                   child: Text(
                     '+ ${pendingBills.length - 5} more pending',
                     style: const TextStyle(
                       color: AppColors.primary,
                       fontSize: 12,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                 ),
               ),
          ],
        ],
      ),
    );
  }
}

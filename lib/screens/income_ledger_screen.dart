import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart'; // NEW
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/credit_note_model.dart'; // NEW
import '../theme/app_colors.dart';
import '../services/bills_service.dart';
import '../services/credit_note_service.dart'; // NEW

class IncomeLedgerScreen extends StatefulWidget {
  const IncomeLedgerScreen({super.key});

  @override
  State<IncomeLedgerScreen> createState() => _IncomeLedgerScreenState();
}

class _IncomeLedgerScreenState extends State<IncomeLedgerScreen> {
  late Stream<List<dynamic>> _ledgerStream;

  @override
  void initState() {
    super.initState();
    _ledgerStream = _manualMerge();
  }

  // Manual Merge using Listeners
  Stream<List<dynamic>> _manualMerge() {
     final controller = StreamController<List<dynamic>>();
     List<BillModel> bills = [];
     List<CreditNoteModel> notes = [];

     void emit() {
       // Enrich notes with Customer Name from Bills
       final enrichedNotes = notes.map((note) {
          if (note.customerName.isNotEmpty) return note;
          
          // Find bill
          try {
             final bill = bills.firstWhere((b) => b.billId == note.billId);
             return CreditNoteModel(
                id: note.id,
                tenantId: note.tenantId,
                billId: note.billId,
                clientId: note.clientId,
                creditNoteNumber: note.creditNoteNumber,
                invoiceNumber: note.invoiceNumber,
                customerName: bill.customerName, // Found name!
                returnDate: note.returnDate,
                totalAmount: note.totalAmount,
                subtotal: note.subtotal,
                taxAmount: note.taxAmount,
                cgstAmount: note.cgstAmount,
                sgstAmount: note.sgstAmount,
                igstAmount: note.igstAmount,
                reason: note.reason,
                createdAt: note.createdAt,
                createdBy: note.createdBy,
                items: note.items,
             );
          } catch (_) {
            return note;
          }
       }).toList();

       final mixed = <dynamic>[...bills, ...enrichedNotes];
       // Sort by Date Descending
       mixed.sort((a, b) {
          DateTime dateA;
          if (a is BillModel) dateA = a.paymentReceivedDate ?? a.createdAt;
          else if (a is CreditNoteModel) dateA = a.returnDate;
          else dateA = DateTime.now();

          DateTime dateB;
          if (b is BillModel) dateB = b.paymentReceivedDate ?? b.createdAt;
          else if (b is CreditNoteModel) dateB = b.returnDate;
          else dateB = DateTime.now();

          return dateB.compareTo(dateA);
       });
       if (!controller.isClosed) controller.add(mixed);
     }

     // Initial emit to clear loading state immediately
     if (!controller.isClosed) controller.add([]);

     late StreamSubscription sub1;
     late StreamSubscription sub2;

     controller.onCancel = () {
       sub1.cancel();
       sub2.cancel();
       controller.close();
     };

     sub1 = BillsService().streamBills().listen((data) {
        bills = data.where((b) => b.paymentStatus == 'Paid').toList(); 
        emit();
     });

     sub2 = CreditNoteService().streamCreditNotes().listen((data) {
        notes = data; 
        emit();
     });

     return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.incomeLedger ?? 'Income Ledger'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: _ledgerStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("${AppLocalizations.of(context)?.error ?? 'Error'}: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)?.noIncomeEntries ?? 'No income entries found.'));
          }

          final items = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              
              if (item is BillModel) {
                 final bill = item;
                 final date = bill.paymentReceivedDate ?? bill.createdAt;
                 // Calculate actual income received logic if partial? 
                 // For now, assuming Paid = Total. 
                 // But wait, if return exists, is it deducted?
                 // If status is Paid, and return exists, Net Received = Total - Return.
                 // But we are showing Return separately as a negative entry.
                 // So showing Full Bill + Negative Return = Net Correct.
                 
                 return _buildLedgerItem(
                    title: bill.customerName,
                    subtitle: "${AppLocalizations.of(context)?.invoiceHash ?? 'Invoice #'} ${bill.invoiceNumber}",
                    date: date,
                    amount: bill.totalAmount, // Show full, return will offset
                    isPositive: true,
                 );
              } else if (item is CreditNoteModel) {
                 final note = item;
                 return _buildLedgerItem(
                    title: 'Return: ${note.customerName}', // Or note.reason
                    subtitle: "${AppLocalizations.of(context)?.cnHash ?? 'CN #'} ${note.creditNoteNumber} (Inv #${note.invoiceNumber})",
                    date: note.returnDate,
                    amount: note.totalAmount,
                    isPositive: false,
                 );
              }
              return const SizedBox();
            },
          );
        },
      ),
    );
  }

  Widget _buildLedgerItem({
    required String title,
    required String subtitle,
    required DateTime date,
    required double amount,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
                isPositive ? Icons.arrow_downward : Icons.arrow_upward, 
                color: isPositive ? AppColors.success : AppColors.error, 
                size: 20
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniTag(isPositive ? Icons.receipt : Icons.description, subtitle),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'} ₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isPositive ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textGrey),
        const SizedBox(width: 2),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

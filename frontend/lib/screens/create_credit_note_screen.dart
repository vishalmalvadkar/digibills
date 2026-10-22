import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/credit_note_model.dart';
import '../services/bills_service.dart';
import '../services/credit_note_service.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar_helper.dart';

class CreateCreditNoteScreen extends StatefulWidget {
  final BillModel? preSelectedBill; // Optional: If coming from Bill Detail

  const CreateCreditNoteScreen({super.key, this.preSelectedBill});

  @override
  State<CreateCreditNoteScreen> createState() => _CreateCreditNoteScreenState();
}

class _CreateCreditNoteScreenState extends State<CreateCreditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billsService = BillsService();
  final _creditNoteService = CreditNoteService();
  
  BillModel? _selectedBill;
  bool _isLoading = false;
  
  // Return Quantities Map: Item Index -> Quantity to Return
  final Map<int, double> _returnQuantities = {};
  final TextEditingController _reasonController = TextEditingController();

  List<BillModel> _allBills = [];

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedBill != null) {
      _selectBill(widget.preSelectedBill!);
    } else {
      _loadBills();
    }
  }

  Future<void> _loadBills() async {
    // Fetch recent bills for dropdown search
    final bills = await _billsService.fetchBillsSnapshot(); 
    if (mounted) {
      setState(() {
        _allBills = bills;
      });
    }
  }

  void _selectBill(BillModel bill) {
    setState(() {
      _selectedBill = bill;
      _returnQuantities.clear();
      // Initialize with 0
      for (int i = 0; i < bill.items.length; i++) {
        _returnQuantities[i] = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Sales Return'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Select Invoice
              if (widget.preSelectedBill == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Autocomplete<BillModel>(
                    optionsBuilder: (text) {
                      if (text.text.isEmpty) return const Iterable.empty();
                      return _allBills.where((b) => 
                        b.invoiceNumber.toLowerCase().contains(text.text.toLowerCase()) || 
                        b.customerName.toLowerCase().contains(text.text.toLowerCase())
                      );
                    },
                    displayStringForOption: (b) => '${b.invoiceNumber} - ${b.customerName}',
                    onSelected: _selectBill,
                    fieldViewBuilder: (ctx, controller, node, onSubmit) {
                      return TextField(
                        controller: controller,
                        focusNode: node,
                        decoration: const InputDecoration(
                          labelText: 'Search Invoice',
                          hintText: 'Enter Invoice # or Customer Name',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 16),

              if (_selectedBill != null) ...[
                // Bill Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoice #${_selectedBill!.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Date: ${DateFormat('dd MMM yyyy').format(_selectedBill!.billDate)}'),
                      Text('Customer: ${_selectedBill!.customerName}'),
                      const Divider(),
                      const Text('Select Items to Return', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),

                // Items List
                ..._selectedBill!.items.asMap().entries.map((entry) {
                   final index = entry.key;
                   final item = entry.value;
                   final currentQty = _returnQuantities[index] ?? 0;
                   
                   return GestureDetector(
                     onTap: () {
                        // Toggle logic: if 0, set to 1. If >0, do nothing (let them use buttons)
                        if (currentQty == 0) {
                          setState(() => _returnQuantities[index] = 1);
                        }
                     },
                     child: Card(
                       margin: const EdgeInsets.only(bottom: 8),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       child: Padding(
                         padding: const EdgeInsets.all(12),
                         child: Row(
                           children: [
                             Expanded(
                               flex: 3,
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                                   Text('${item.quantity} ${item.unit} @ ₹${item.unitPrice}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                 ],
                               ),
                             ),
                             // Quantity Selector
                             Expanded(
                               flex: 2,
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.end,
                                 children: [
                                   IconButton(
                                     icon: const Icon(Icons.remove_circle_outline),
                                     onPressed: currentQty > 0 
                                        ? () => setState(() => _returnQuantities[index] = currentQty - 1) 
                                        : null,
                                   ),
                                   Text(
                                     currentQty.toStringAsFixed(0),
                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                   ),
                                   IconButton(
                                     icon: const Icon(Icons.add_circle_outline),
                                     onPressed: currentQty < item.quantity 
                                        ? () => setState(() => _returnQuantities[index] = currentQty + 1) // Can return up to original qty
                                        : null, 
                                   ),
                                 ],
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                   );
                }).toList(),

                const SizedBox(height: 16),
                
                // Reason
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Return',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 24),

                // Totals & Save
                _buildSummary(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    double returnSubtotal = 0;
    
    // Calculate refund
    for (int i = 0; i < _selectedBill!.items.length; i++) {
      final item = _selectedBill!.items[i];
      final qty = _returnQuantities[i] ?? 0;
      if (qty > 0) {
        returnSubtotal += (qty * item.unitPrice);
      }
    }
    
    // Tax Reversal
    final taxRate = _selectedBill!.taxPercentage;
    final refundTax = (returnSubtotal * taxRate) / 100;
    final totalRefund = returnSubtotal + refundTax;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Refund Subtotal'),
            Text('₹${returnSubtotal.toStringAsFixed(2)}'),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Tax Reversal'),
            Text('₹${refundTax.toStringAsFixed(2)}'),
          ]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Refund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('₹${totalRefund.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.error)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: totalRefund > 0 && !_isLoading ? _saveCreditNote : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text('Create Credit Note'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCreditNote() async {
    setState(() => _isLoading = true);
    try {
      // Calculate final values (re-calc to be safe)
      double subtotal = 0;
      List<CreditNoteItem> returnItems = [];
      
      for (int i = 0; i < _selectedBill!.items.length; i++) {
        final item = _selectedBill!.items[i];
        final qty = _returnQuantities[i];
        if (qty != null && qty > 0) {
           final amount = qty * item.unitPrice;
           subtotal += amount;
           
           returnItems.add(CreditNoteItem(
             id: '', // Generated
             creditNoteId: '',
             productId: item.productId,
             description: item.description,
             quantity: qty,
             unitPrice: item.unitPrice,
             returnAmount: amount,
           ));
        }
      }

      final taxAmount = (subtotal * _selectedBill!.taxPercentage) / 100;
      
      // Split Logic Reverse
      double cgst = 0, sgst = 0, igst = 0;
      if (_selectedBill!.igstAmount > 0) {
        igst = taxAmount;
      } else {
        cgst = taxAmount / 2;
        sgst = taxAmount / 2;
      }

      final note = CreditNoteModel(
        id: '',
        tenantId: '',
        billId: _selectedBill!.billId,
        clientId: _selectedBill!.clientId,
        creditNoteNumber: 'CN-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}', // Simple Gen
        invoiceNumber: _selectedBill!.invoiceNumber,
        returnDate: DateTime.now(),
        totalAmount: subtotal + taxAmount,
        subtotal: subtotal,
        taxAmount: taxAmount,
        cgstAmount: cgst,
        sgstAmount: sgst,
        igstAmount: igst,
        reason: _reasonController.text,
        createdAt: DateTime.now(),
        createdBy: '',
        items: returnItems,
      );

      await _creditNoteService.createCreditNote(note);
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Credit Note created successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

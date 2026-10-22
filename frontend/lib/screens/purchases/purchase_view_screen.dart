import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_model.dart';
import '../../services/purchase_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_helper.dart';

class PurchaseViewScreen extends StatefulWidget {
  final String purchaseId;
  const PurchaseViewScreen({super.key, required this.purchaseId});

  @override
  State<PurchaseViewScreen> createState() => _PurchaseViewScreenState();
}

class _PurchaseViewScreenState extends State<PurchaseViewScreen> {
  final PurchasesService _purchaseService = PurchasesService();
  PurchaseModel? _purchase;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchase();
  }

  Future<void> _loadPurchase() async {
    try {
      final purchase = await _purchaseService.getPurchaseById(widget.purchaseId);
      setState(() {
        _purchase = purchase;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) SnackbarHelper.showError(context, 'Error loading purchase: $e');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase'),
        content: const Text('Are you sure you want to delete this purchase bill?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _purchaseService.deletePurchase(widget.purchaseId);
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Purchase deleted');
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) SnackbarHelper.showError(context, 'Error deleting: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_purchase == null) return const Scaffold(body: Center(child: Text('Purchase not found')));

    final p = _purchase!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchase Bill Details'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(p),
                  const SizedBox(height: 24),
                  _buildItemsList(p),
                  const SizedBox(height: 24),
                  _buildSummary(p),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(PurchaseModel p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withAlpha(127)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(p.supplierName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: const Text('PURCHASE', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
          const Divider(height: 32),
          _infoRow('GSTIN', p.supplierGstin ?? 'N/A'),
          _infoRow('Invoice No', p.invoiceNumber ?? 'N/A'),
          _infoRow('Date', DateFormat('dd MMM yyyy').format(p.date)),
          _infoRow('Contact', p.contactNumber ?? 'N/A'),
          _infoRow('Location', '${p.city ?? ""}, ${p.state ?? ""}'),
        ],
      ),
    );
  }

  Widget _buildItemsList(PurchaseModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Items', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey)),
        ),
        ...p.items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withAlpha(76)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${item.hsnType}: ${item.hsnCode} • Qty: ${item.quantity} ${item.unit}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (item.discountAmount > 0)
                        Text('-₹${item.discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSummary(PurchaseModel p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Column(
        children: [
          _summaryRow('Total Quantity', p.totalQuantity.toStringAsFixed(2)),
          _summaryRow('Subtotal', '₹${p.subtotal.toStringAsFixed(2)}'),
          if (p.cgst > 0) _summaryRow('CGST (${(p.taxPercentage / 2).toStringAsFixed(1)}%)', '₹${p.cgst.toStringAsFixed(2)}'),
          if (p.sgst > 0) _summaryRow('SGST (${(p.taxPercentage / 2).toStringAsFixed(1)}%)', '₹${p.sgst.toStringAsFixed(2)}'),
          if (p.igst > 0) _summaryRow('IGST (${p.taxPercentage.toStringAsFixed(1)}%)', '₹${p.igst.toStringAsFixed(2)}'),
          if (p.roundOff != 0) _summaryRow('Round Off', '₹${p.roundOff.toStringAsFixed(2)}'),
          const Divider(height: 24),
          _summaryRow('Grand Total', '₹${p.totalAmount.toStringAsFixed(2)}', isBold: true, fontSize: 18),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: isBold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}

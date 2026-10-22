import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart'; // NEW
import 'dart:io';
import '../../models/supplier_bill_model.dart';
import '../../services/supplier_bill_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'review_bill_screen.dart';

class SupplierBillsScreen extends StatefulWidget {
  final bool showAppBar;
  const SupplierBillsScreen({super.key, this.showAppBar = true});

  @override
  State<SupplierBillsScreen> createState() => _SupplierBillsScreenState();
}

class _SupplierBillsScreenState extends State<SupplierBillsScreen> {
  final SupplierBillService _service = SupplierBillService();
  bool _isProcessing = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _showPlatformNotice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.important_devices, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)?.mobileFeature ?? 'Mobile Feature'),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)?.mobileFeatureMsg ?? 'AI-powered bill scanning is currently exclusive to our mobile experience to ensure high accuracy using on-device hardware. \n\nPlease use the DigiInvi mobile app for the best scanning results.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.gotIt ?? 'GOT IT'),
          ),
        ],
      ),
    );
  }

  Future<void> _startScanning() async {
    _showPlatformNotice();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildBody(),
        floatingActionButton: _buildFAB(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.purchaseLedger ?? 'Purchase Ledger'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        StreamBuilder<List<SupplierBillModel>>(
          stream: _service.streamBills(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final bills = snapshot.data ?? [];
            if (bills.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textGrey),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)?.noPurchaseRecords ?? 'No purchase records found.', style: const TextStyle(color: AppColors.textGrey, fontSize: 16)),
                  ],
                ),
              );
            }

            final grouped = _groupBills(bills);
            final now = DateTime.now();
            final currentMonthKey = DateFormat('MMMM yyyy').format(now);

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: grouped.keys.length,
              itemBuilder: (context, index) {
                final key = grouped.keys.elementAt(index);
                final monthBills = grouped[key]!;
                final monthTotal = monthBills.fold(0.0, (sum, b) => sum + b.totalAmount);
                final isCurrentMonth = key == currentMonthKey;

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isCurrentMonth,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          key,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '₹${monthTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: EdgeInsets.zero,
                    children: monthBills.map((bill) => _buildBillCard(bill)).toList(),
                  ),
                );
              },
            );
          },
        ),
        if (_isProcessing)
          Container(
            color: Colors.black45,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(AppLocalizations.of(context)?.analyzingBill ?? 'Analyzing Bill...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFAB() {
    return const SizedBox.shrink(); // Removed to consolidate scanning at PO
  }

  Future<void> _deleteBill(String billId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: const Text('This action cannot be undone. The digital record will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
           TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await _service.deleteBill(billId);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showBillImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      Text('Image not available'),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard(SupplierBillModel bill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.white, 
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Needed for InkWell ripple
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReviewBillScreen(bill: bill)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bill.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
                        const SizedBox(height: 4),
                        Text('Inv: ${bill.invoiceNumber ?? 'N/A'} • ${DateFormat('dd MMM yyyy').format(bill.date)}', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  Text('₹${bill.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
                ],
              ),
              const Divider(height: 24, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Delete Button
                  TextButton.icon(
                    onPressed: () => _deleteBill(bill.id),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<SupplierBillModel>> _groupBills(List<SupplierBillModel> bills) {
    final Map<String, List<SupplierBillModel>> grouped = {};
    for (var bill in bills) {
      final key = DateFormat('MMMM yyyy').format(bill.date);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(bill);
    }
    return grouped;
  }
}

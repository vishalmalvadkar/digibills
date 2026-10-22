import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_order_model.dart';
import '../../services/purchase_order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // New Import
import '../../services/product_service.dart';
import '../../services/settings_service.dart'; // New
import '../../models/settings_model.dart'; // New
import '../../theme/app_colors.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/pdf_po_helper.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../providers/shell_provider.dart';
import 'package:provider/provider.dart';
import '../../utils/responsive.dart';

class POViewScreen extends StatefulWidget {
  final PurchaseOrderModel? po;
  final String? poId; // Support for Deep Links

  const POViewScreen({super.key, this.po, this.poId}); // Allow either

  @override
  State<POViewScreen> createState() => _POViewScreenState();
}

class _POViewScreenState extends State<POViewScreen> {
  PurchaseOrderModel? _po;
  AppSettings? _settings;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData(); // Updated load method
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      PurchaseOrderModel? fetchedPO;
      AppSettings? fetchedSettings;

      // 1. Use passed object if available
      if (widget.po != null) {
        fetchedPO = widget.po;
      } 
      // 2. Otherwise fetch by ID
      else if (widget.poId != null) {
        fetchedPO = await PurchaseOrderService().getPO(widget.poId!);
      }

      if (fetchedPO == null) throw 'Purchase Order not found';

      // 3. Fetch Settings (Publicly via Tenant ID)
       // 3. Fetch Settings (Authenticated)
       final currentUser = Supabase.instance.client.auth.currentUser;
       if (currentUser != null) {
          _settings = await SettingsService().fetchSettings();
          fetchedSettings = _settings; 
       }

      if (mounted) {
        setState(() {
          _po = fetchedPO;
          _settings = fetchedSettings;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateShell();
  }

  void _updateShell() {
    if (Responsive.isDesktop(context)) {
      final po = _po;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ShellState>().update(
            title: po != null ? 'PO: ${po.poNumber}' : 'Purchase Order Details',
            leading: BackButton(onPressed: () => Navigator.of(context).pop()),
            actions: [
              if (po != null) ...[
                 IconButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                  onPressed: () => PdfPOHelper.openWhatsApp(context, po, overrideSettings: _settings),
                  tooltip: 'Share on WhatsApp',
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: AppColors.primary, size: 20), 
                  onPressed: () => PdfPOHelper.generateAndPrint(po, overrideSettings: _settings),
                  tooltip: 'Print PO',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(context, po),
                  tooltip: 'Delete PO',
                )
              ]
            ],
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage.isNotEmpty) return Scaffold(body: Center(child: Text(_errorMessage)));
    if (_po == null) return const Scaffold(body: Center(child: Text('PO not found')));

    final po = _po!; // Valid PO
    final tenantName = _settings?.tenantName ?? 'Start-Up Agency';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: Responsive.isDesktop(context) 
        ? null 
        : AppBar(
        title: Text(tenantName),
        backgroundColor: Colors.white,
        actions: [
           IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
            onPressed: () => PdfPOHelper.openWhatsApp(context, po, overrideSettings: _settings),
          ),
          IconButton(
            icon: const Icon(Icons.print, color: AppColors.primary), 
            onPressed: () => PdfPOHelper.generateAndPrint(po, overrideSettings: _settings),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context, po),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Status', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                    Text(po.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                  if (po.status == 'Sent')
                    ElevatedButton(
                      onPressed: () => _updateStatus(context, po, 'Received'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Mark Received'),
                    )
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Vendor Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VENDOR', style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(po.vendorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (po.vendorContact.isNotEmpty) Text(po.vendorContact, style: const TextStyle(color: AppColors.textGrey)),
                  if (po.vendorAddress.isNotEmpty) Text(po.vendorAddress, style: const TextStyle(color: AppColors.textGrey)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ...po.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${item.quantity} ${item.unit} x ₹${item.unitPrice}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        ]),
                        Text('₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),

                  const Divider(),
                  // Breakdown
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Subtotal', style: TextStyle(color: AppColors.textGrey)),
                    Text('₹${(po.totalAmount / (1 + po.taxPercentage/100)).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  if (po.taxPercentage > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Tax (${po.taxPercentage.toStringAsFixed(1)}%)', style: const TextStyle(color: AppColors.textGrey)),
                      Text('₹${(po.totalAmount - (po.totalAmount / (1 + po.taxPercentage/100))).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('₹${po.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, PurchaseOrderModel po, String status) async {
    try {
      await PurchaseOrderService().updateStatus(po.poId, status);
      
      // Auto-create Expense if Received
      if (status == 'Received') {
        final expense = ExpenseModel(
          id: '',
          title: 'PO #${po.poNumber} - ${po.vendorName}',
          amount: po.totalAmount,
          category: 'Purchase',
          date: DateTime.now(),
          notes: 'Auto-generated from Purchase Order ${po.poNumber}. Items: ${po.items.length}',
          tenantId: '', // Service handles this
        );
        await ExpenseService().addExpense(expense);

        // STOCK INCREMENT
        final productService = ProductService();
        for (var item in po.items) {
          if (item.productId != null) {
            try {
              await productService.updateStock(item.productId!, item.quantity);
            } catch (e) {
              print('Stock increment failed for ${item.description}: $e');
            }
          }
        }
      }

      if (context.mounted) {
        String msg = status == 'Received' ? 'Marked Received & Expense Added' : 'Status updated to $status';
        SnackbarHelper.showSuccess(context, msg);
        _loadData(); // REFRESH 
      }
    } catch (e) {
      if (context.mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  void _confirmDelete(BuildContext context, PurchaseOrderModel po) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PO?'),
        content: const Text('Irreversible action.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await PurchaseOrderService().deletePO(po.poId);
              if (context.mounted) {
                Navigator.pop(context);
                SnackbarHelper.showSuccess(context, 'PO Deleted');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

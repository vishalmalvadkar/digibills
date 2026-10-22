import 'package:flutter/material.dart';
import '../../models/purchase_order_model.dart';
import '../../models/settings_model.dart';
import '../../services/public_service.dart';
import '../../utils/pdf_po_helper.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

class PublicPOViewScreen extends StatefulWidget {
  final String poId;
  const PublicPOViewScreen({super.key, required this.poId});

  @override
  State<PublicPOViewScreen> createState() => _PublicPOViewScreenState();
}

class _PublicPOViewScreenState extends State<PublicPOViewScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  PurchaseOrderModel? _po;
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final po = await PublicService().getPublicPO(widget.poId);
      if (po == null) throw 'Purchase Order not found';

      final settings = await PublicService().getPublicSettings(po.tenantId);

      if (mounted) {
        setState(() {
          _po = po;
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage.isNotEmpty) return Scaffold(body: Center(child: Text(_errorMessage)));
    if (_po == null) return const Scaffold(body: Center(child: Text('Purchase Order not found')));

    final po = _po!;
    final tenantName = _settings?.tenantName ?? 'Business Name';
    final date = DateFormat('dd MMM yyyy').format(po.date);
    final deliveryDate = DateFormat('dd MMM yyyy').format(po.expectedDeliveryDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tenantName), 
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
             constraints: const BoxConstraints(maxWidth: 600),
             child: Column(
              children: [
                // PO Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                    'PURCHASE ORDER',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppColors.textGrey,
                                    ),
                                   ),
                                   Text(
                                    '#${po.poNumber}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                   ),
                                 ],
                               ),
                             ),
                             Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Text(
                                  po.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const Divider(height: 40, color: AppColors.border),

                        _infoRow('Vendor', po.vendorName),
                        _infoRow('Order Date', date),
                        _infoRow('Delivery By', deliveryDate),
                        if (po.vendorContact.isNotEmpty) _infoRow('Contact', po.vendorContact),
                        
                        const SizedBox(height: 12),
                        const Text('Safe & Secure by DigiInvi', style: TextStyle(color: Colors.grey)),
                        const Text('Items', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                         ...po.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.description,
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textDark),
                                ),
                              ),
                              Text(
                                '₹${item.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                            ],
                          ),
                        )),

                        const Divider(height: 40, color: AppColors.border),

                        // Calculation Section
                        if (po.taxPercentage > 0)
                           _infoRow('Subtotal', '₹${(po.totalAmount / (1 + po.taxPercentage/100)).toStringAsFixed(2)}'),
                        
                        if (po.taxPercentage > 0)
                           _infoRow('Tax (${po.taxPercentage.toStringAsFixed(0)}%)', '₹${(po.totalAmount - (po.totalAmount / (1 + po.taxPercentage/100))).toStringAsFixed(2)}'),

                        Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text(
                             'Total Amount',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.w600,
                               color: AppColors.textDark,
                             ),
                           ),
                           Text(
                             '₹${po.totalAmount.toStringAsFixed(2)}',
                             style: const TextStyle(
                               fontSize: 24,
                               fontWeight: FontWeight.bold,
                               color: AppColors.primary,
                             ),
                           ),
                         ],
                       ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => PdfPOHelper.generateAndPrint(_po!, overrideSettings: _settings), 
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                  ),
                ),
             ],
           ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isAmount = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/bill_model.dart';
import '../../models/settings_model.dart';
import '../../services/public_service.dart';
import '../../utils/pdf_invoice_helper.dart';
import '../../theme/app_colors.dart';
import '../../utils/upi_helper.dart'; 
import '../../utils/responsive.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/credit_note_model.dart';
import '../../widgets/bill_items_table.dart';
import 'package:flutter/services.dart';
import '../../utils/snackbar_helper.dart';

class PublicBillViewScreen extends StatefulWidget {
  final String billId;
  const PublicBillViewScreen({super.key, required this.billId});

  @override
  State<PublicBillViewScreen> createState() => _PublicBillViewScreenState();
}

class _PublicBillViewScreenState extends State<PublicBillViewScreen> {

  Future<Map<String, dynamic>?> _loadAll(String billId) async {
    final result = await PublicService().getPublicBill(billId);
    if (result == null) return null;

    final bill = result.bill;
    final creditNotes = result.creditNotes;
    final settings = await PublicService().getPublicSettings(bill.tenantId, createdBy: bill.createdBy);
    if (settings == null) return null;

    return {
      'bill': bill,
      'creditNotes': creditNotes,
      'settings': settings,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadAll(widget.billId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Text(snapshot.hasError ? 'Error: ${snapshot.error}' : 'Invoice not found'),
            ),
          );
        }

        final data = snapshot.data!;
        final bill = data['bill'] as BillModel;
        final settings = data['settings'] as AppSettings;
        final creditNotes = data['creditNotes'] as List<CreditNoteModel>;
        final date = DateFormat('dd MMM yyyy').format(bill.billDate);

        return Title(
          title: 'Invoice #${bill.invoiceNumber}',
          color: AppColors.primary,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Invoice Details'),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textDark,
              elevation: 0,
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: AppColors.border, height: 1),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Download PDF',
                  onPressed: () => PdfInvoiceHelper.generateAndDownload(bill, overrideSettings: settings, creditNotes: creditNotes),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => PdfInvoiceHelper.generateAndDownload(bill, overrideSettings: settings, creditNotes: creditNotes),
              icon: const Icon(Icons.print),
              label: const Text('Download / Print'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 800),
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
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  settings.tenantName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16, color: AppColors.textGrey),
                                      tooltip: 'Copy Invoice No',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: bill.invoiceNumber));
                                        SnackbarHelper.showSuccess(context, 'Invoice Number copied!');
                                      },
                                    ),
                                    if (creditNotes.isNotEmpty)
                                      _statusBadge('RETURNED', AppColors.error),
                                    _statusBadge(bill.paymentStatus.toUpperCase(), _getStatusColor(bill.paymentStatus)),
                                  ],
                                ),
                              ],
                            ),
                            
                            const Divider(height: 40, color: AppColors.border),

                            // Client & Invoice Details
                            if (Responsive.isMobile(context)) ...[
                              const Text('Client Details', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _infoRow('Client', bill.customerName),
                              if (bill.clientId.isNotEmpty) _infoRow('Client ID', bill.clientId),
                              if (bill.clientAddress.isNotEmpty) _infoRow('Address', bill.clientAddress),
                              if (bill.clientCity != null && bill.clientCity!.isNotEmpty) _infoRow('City', bill.clientCity!),
                              if (bill.placeOfSupply.isNotEmpty) _infoRow('State', bill.placeOfSupply),
                              if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty) _infoRow('Client GST', bill.gstNumber!),
                              const SizedBox(height: 16),
                              const Text('Invoice Details', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _infoRow('Invoice No', bill.invoiceNumber),
                              _infoRow('Bill Date', date),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Client Details', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 8),
                                        _infoRow('Client', bill.customerName),
                                        if (bill.clientId.isNotEmpty) _infoRow('Client ID', bill.clientId),
                                        if (bill.clientAddress.isNotEmpty) _infoRow('Address', bill.clientAddress),
                                        if (bill.clientCity != null && bill.clientCity!.isNotEmpty) _infoRow('City', bill.clientCity!),
                                        if (bill.placeOfSupply.isNotEmpty) _infoRow('State', bill.placeOfSupply),
                                        if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty) _infoRow('Client GST', bill.gstNumber!),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Invoice Details', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 8),
                                        _infoRow('Invoice No', bill.invoiceNumber),
                                        _infoRow('Bill Date', date),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                            const Text('ITEMS', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            
                            // Responsive Items Table
                            BillItemsTable(items: bill.items),
                            
                            // Returns / Credit Notes
                            if (creditNotes.isNotEmpty) ...[
                              const Divider(height: 40, color: AppColors.border),
                              const Text('Returns / Credit Notes', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ...creditNotes.expand((note) => note.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('${item.description} (Returned)', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textGrey, fontStyle: FontStyle.italic))),
                                    Text('- ₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                                  ],
                                ),
                              ))),
                            ],
                            
                            const Divider(height: 40, color: AppColors.border),
                            
                            // Totals
                            _calculationSection(bill),
                            
                            // Bank Details
                            if (bill.paymentStatus.toLowerCase() != 'paid' && settings.bankName.isNotEmpty) ...[
                              const Divider(height: 40, color: AppColors.border),
                              const Text('Bank Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                                child: Column(
                                  children: [
                                    _infoRow('Bank Name', settings.bankName),
                                    _infoRow('Account No', settings.accountNumber),
                                    _infoRow('IFSC Code', settings.ifscCode),
                                    _infoRow('Acc Holder', settings.accountHolderName),
                                    if (settings.upiId.isNotEmpty) _infoRow('UPI ID', settings.upiId),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // UPI QR Code
                    if (bill.paymentStatus.toLowerCase() != 'paid' && settings.upiId.isNotEmpty && settings.payeeName.isNotEmpty && (bill.totalAmount - bill.advanceAmount - bill.returnAmount) > 0) ...[
                      const SizedBox(height: 24),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                        child: Column(
                          children: [
                            const Text('Scan to Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(height: 16),
                            QrImageView(
                              data: UpiHelper.generateUpiUrl(
                                pa: settings.upiId,
                                pn: settings.payeeName,
                                am: (bill.totalAmount - bill.advanceAmount - bill.returnAmount),
                                tn: 'Invoice ${bill.invoiceNumber}',
                              ),
                              version: QrVersions.auto,
                              size: 180.0,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            const Text('Accepted via any UPI App', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    const Text('Powered by DigiInvi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _calculationSection(BillModel bill) {
    return Column(
      children: [
        if (bill.taxPercentage > 0)
          _infoRow('Subtotal', '₹${(bill.totalAmount / (1 + bill.taxPercentage/100)).toStringAsFixed(2)}'),
        if (bill.igstAmount > 0)
          _infoRow('IGST (${bill.taxPercentage.toStringAsFixed(0)}%)', '₹${bill.igstAmount.toStringAsFixed(2)}'),
        if (bill.cgstAmount > 0)
          _infoRow('CGST (${(bill.taxPercentage/2).toStringAsFixed(1)}%)', '₹${bill.cgstAmount.toStringAsFixed(2)}'),
        if (bill.sgstAmount > 0)
          _infoRow('SGST (${(bill.taxPercentage/2).toStringAsFixed(1)}%)', '₹${bill.sgstAmount.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            Text('₹${bill.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid': return AppColors.success;
      case 'Partial': return Colors.amber.shade700;
      default: return AppColors.error;
    }
  }

  Widget _infoRow(String label, String value, {bool isAmount = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textGrey))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 16, fontWeight: isAmount ? FontWeight.bold : FontWeight.w500, color: color ?? AppColors.textDark))),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  height: 200,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBox(width: 150, height: 24),
                        const SizedBox(height: 40),
                        _skeletonBox(width: 100, height: 12),
                        const SizedBox(height: 12),
                        _skeletonBox(width: double.infinity, height: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  height: 300,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: List.generate(5, (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _skeletonBox(width: 100, height: 16),
                            _skeletonBox(width: 60, height: 16),
                          ],
                        ),
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
    );
  }
}

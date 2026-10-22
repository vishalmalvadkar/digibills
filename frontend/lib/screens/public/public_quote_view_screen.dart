import 'package:flutter/material.dart';
import '../../models/quote_model.dart';
import '../../models/settings_model.dart';
import '../../services/public_service.dart';
import '../../utils/pdf_quote_helper.dart';
import '../../theme/app_colors.dart';
import '../../utils/upi_helper.dart'; // NEW
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart'; // NEW

class PublicQuoteViewScreen extends StatefulWidget {
  final String quoteId;
  const PublicQuoteViewScreen({super.key, required this.quoteId});

  @override
  State<PublicQuoteViewScreen> createState() => _PublicQuoteViewScreenState();
}

class _PublicQuoteViewScreenState extends State<PublicQuoteViewScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  QuoteModel? _quote;
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final quote = await PublicService().getPublicQuote(widget.quoteId);
      if (quote == null) throw 'Quote not found';

      final settings = await PublicService().getPublicSettings(quote.tenantId, createdBy: quote.createdBy);

      if (mounted) {
        setState(() {
          _quote = quote;
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
    if (_quote == null) return const Scaffold(body: Center(child: Text('Quote not found')));

    final quote = _quote!;
    final settings = _settings!;
    final tenantName = settings.tenantName;
    final docTitle = quote.docType == 'Proforma' ? 'PROFORMA INVOICE' : 'QUOTATION';
    final date = DateFormat('dd MMM yyyy').format(quote.date);
    final expiryDate = DateFormat('dd MMM yyyy').format(quote.expiryDate);

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
                // Quote Card
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
                                    docTitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppColors.textGrey,
                                    ),
                                   ),
                                   Text(
                                    '#${quote.quoteNumber}',
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
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Text(
                                  quote.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const Divider(height: 40, color: AppColors.border),

                        _infoRow('For', quote.customerName),
                        _infoRow('Date', date),
                        _infoRow('Valid Until', expiryDate),
                        
                        const SizedBox(height: 12),
                        const Text('Items', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                         ...quote.items.map((item) => Padding(
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
                        if (quote.taxPercentage > 0)
                           _infoRow('Subtotal', '₹${(quote.totalAmount / (1 + quote.taxPercentage/100)).toStringAsFixed(2)}'),
                        
                        if (quote.taxPercentage > 0)
                           _infoRow('Tax (${quote.taxPercentage.toStringAsFixed(0)}%)', '₹${(quote.totalAmount - (quote.totalAmount / (1 + quote.taxPercentage/100))).toStringAsFixed(2)}'),

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
                             '₹${quote.totalAmount.toStringAsFixed(2)}',
                             style: const TextStyle(
                               fontSize: 24,
                               fontWeight: FontWeight.bold,
                               color: AppColors.primary,
                             ),
                           ),
                         ],
                       ),
                       
                        // Bank Details Section (Useful for Proforma)
                        if (settings.bankName.isNotEmpty) ...[
                          const Divider(height: 40, color: AppColors.border),
                          const Text(
                            'Bank Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                _infoRow('Bank Name', settings.bankName),
                                _infoRow('Account No', settings.accountNumber),
                                _infoRow('IFSC Code', settings.ifscCode),
                                _infoRow('Acc Holder', settings.accountHolderName),
                                if (settings.upiId.isNotEmpty)
                                  _infoRow('UPI ID', settings.upiId),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // QR Code Section
                if (settings.upiId.isNotEmpty && settings.payeeName.isNotEmpty && quote.totalAmount > 0) ...[
                   Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Scan to Pay',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                           QrImageView(
                              data: UpiHelper.generateUpiUrl(
                                pa: settings.upiId,
                                pn: settings.payeeName,
                                am: quote.totalAmount,
                                tn: '${quote.docType} ${quote.quoteNumber}',
                              ),
                              version: QrVersions.auto,
                              size: 180.0,
                              backgroundColor: Colors.white,
                            ),
                          const SizedBox(height: 12),
                          const Text(
                            'Accepted via any UPI App',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                ],
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => PdfQuoteHelper.generateAndDownload(_quote!, overrideSettings: _settings), 
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Safe & Secure by DigiInvi', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
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

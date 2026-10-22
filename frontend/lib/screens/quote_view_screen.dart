import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // NEW
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/quote_model.dart';
import '../models/bill_model.dart';
import '../models/settings_model.dart';
import '../services/quote_service.dart';
import '../services/bills_service.dart';
import '../services/settings_service.dart';
import '../utils/pdf_quote_helper.dart';
import '../theme/app_colors.dart';
import '../widgets/license_scope.dart';
import '../utils/snackbar_helper.dart';
import '../providers/shell_provider.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';

class QuoteViewScreen extends StatefulWidget {
  final String quoteId;
  const QuoteViewScreen({super.key, required this.quoteId});

  @override
  State<QuoteViewScreen> createState() => _QuoteViewScreenState();
}

class _QuoteViewScreenState extends State<QuoteViewScreen> {
  QuoteModel? _quote;
  AppSettings? _settings;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      QuoteModel? fetchedQuote;

      // Only fetch if authenticated
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
          fetchedQuote = await QuoteService().getQuoteStream(widget.quoteId).first;
      }

      if (fetchedQuote == null) {
        throw 'Quote not found';
      }

      // 3. Fetch Settings (Authenticated)
      // 3. Fetch Settings (Authenticated)
      AppSettings? fetchedSettings;
      if (currentUser != null) {
         fetchedSettings = await SettingsService().fetchSettings();
      }

      if (mounted) {
        setState(() {
          _quote = fetchedQuote;
          _settings = fetchedSettings;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateShell();
  }

  void _updateShell() {
    if (Responsive.isDesktop(context)) {
      final quote = _quote;
      // final isReadOnly = (_quote != null && !LicenseScope.isReadOnlyMode(context)); // Unused for now

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ShellState>().update(
            title: quote != null ? 'Quote: ${quote.quoteNumber}' : 'Quote Details',
            leading: BackButton(onPressed: () => Navigator.of(context).pop()),
            actions: [
              if (quote != null) ...[
                 IconButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                  onPressed: () => PdfQuoteHelper.openWhatsApp(context, quote, overrideSettings: _settings),
                  tooltip: 'Share on WhatsApp',
                ),
                if (!LicenseScope.isReadOnlyMode(context))
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _confirmDelete(context),
                    tooltip: 'Delete Quote',
                  ),
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
    if (_quote == null) return const Scaffold(body: Center(child: Text('Quote not found')));
    
    final quote = _quote!;
    // Use fetched settings, or fallback to default if absolutely necessary
    final tenantName = _settings?.tenantName ?? 'Start-Up Agency';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: Responsive.isDesktop(context) 
        ? null 
        : AppBar(
        title: Text(tenantName),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
           IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
            onPressed: () => PdfQuoteHelper.openWhatsApp(context, quote, overrideSettings: _settings),
          ),
          
          if (!LicenseScope.isReadOnlyMode(context))
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(quote),
            const SizedBox(height: 16),
            _buildCustomerSection(quote),
            const SizedBox(height: 16),
            _buildItemsSection(quote),
            const SizedBox(height: 24),
            _buildActions(context, quote),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(QuoteModel quote) {
    Color statusColor = Colors.grey;
    Color statusBg = Colors.grey.withOpacity(0.1);
    
    if (quote.status == 'Sent') { statusColor = Colors.blue; statusBg = Colors.blue.shade50; }
    if (quote.status == 'Accepted') { statusColor = Colors.green; statusBg = Colors.green.shade50; }
    if (quote.status == 'Converted') { statusColor = AppColors.primary; statusBg = AppColors.primary.withOpacity(0.1); }
    if (quote.status == 'Expired') { statusColor = Colors.red; statusBg = Colors.red.shade50; }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: quote.docType == 'Proforma' ? Colors.orange : AppColors.primary, 
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Text(
                  quote.docType == 'Proforma' ? 'PROFORMA INVOICE' : 'QUOTATION', 
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(quote.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Grand Total', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 4),
          Text('₹${quote.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.0)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quote No', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    const SizedBox(height: 2),
                    Text('#${quote.quoteNumber}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade200),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    const SizedBox(height: 2),
                    Text(DateFormat('dd MMM yyyy').format(quote.date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade200),
               Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Valid Until', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM').format(quote.expiryDate), 
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(QuoteModel quote) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    quote.customerName.isNotEmpty ? quote.customerName[0].toUpperCase() : 'C',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prepared For', style: TextStyle(fontSize: 12, color: AppColors.textGrey, letterSpacing: 0.5)),
                    Text(quote.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              if (quote.clientId.isNotEmpty)
                Expanded(
                  child: _infoPill(Icons.badge_outlined, 'Client ID', quote.clientId),
                ),
              if (quote.clientId.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: _infoPill(Icons.location_on_outlined, 'Status', quote.status),
              ),
            ],
          ),
          if (quote.whatsappNumber.isNotEmpty || quote.customerEmail.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Contact Information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  if (quote.whatsappNumber.isNotEmpty)
                    _contactRow(
                      FontAwesomeIcons.whatsapp, 
                      quote.whatsappNumber, 
                      Colors.green,
                      () async {
                         final url = Uri.parse('https://wa.me/${quote.whatsappNumber.replaceAll(RegExp(r'\D'), '')}');
                         if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    ),
                  if (quote.whatsappNumber.isNotEmpty && quote.customerEmail.isNotEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                  if (quote.customerEmail.isNotEmpty)
                    _contactRow(
                      Icons.email_outlined, 
                      quote.customerEmail, 
                      Colors.blue,
                      () async {
                         final subject = Uri.encodeComponent('Quotation: ${quote.quoteNumber}');
                         final body = Uri.encodeComponent('Dear ${quote.customerName},\n\nPlease find the attached quotation ${quote.quoteNumber}.\n\nTotal: ₹${quote.totalAmount.toStringAsFixed(2)}\nValid until: ${DateFormat('dd MMM yyyy').format(quote.expiryDate)}\n\nThank you.');
                         final url = Uri.parse('mailto:${quote.customerEmail}?subject=$subject&body=$body');
                         if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _contactRow(dynamic icon, String value, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: icon is IconData
                ? Icon(icon, size: 16, color: color)
                : FaIcon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const Spacer(),
          Icon(Icons.arrow_outward, size: 14, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _buildItemsSection(QuoteModel quote) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Row(
            children: [
              Expanded(child: Text('ITEM / SERVICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGrey, letterSpacing: 0.5))),
              Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGrey, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          
          ...quote.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
                        child: Text('${item.quantity} ${item.unit} x ₹${item.unitPrice}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ),
                    ],
                  ),
                ),
                Text('₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          )),
          const Divider(),
          const SizedBox(height: 8),
          _summaryRow('Subtotal', _calculateSubtotal(quote)),
          if (quote.taxPercentage > 0)
             _summaryRow('GST (${quote.taxPercentage.toStringAsFixed(0)}%)', _calculateTax(quote)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: _summaryRow('Grand Total', quote.totalAmount, isBold: true),
          ),
        ],
      ),
    );
  }

  double _calculateSubtotal(QuoteModel quote) {
    return quote.items.fold(0, (sum, item) => sum + item.amount);
  }

  double _calculateTax(QuoteModel quote) {
    return (_calculateSubtotal(quote) * quote.taxPercentage) / 100;
  }

  Widget _summaryRow(String label, double amount, {bool isBold = false, bool isGrey = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold? 16:14, fontWeight: isBold? FontWeight.bold : FontWeight.w500, color: isGrey ? AppColors.textGrey : AppColors.textDark)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: isBold? 18:14, fontWeight: isBold? FontWeight.bold : FontWeight.w500, color: isBold ? AppColors.primary : AppColors.textDark)),
        ],
      ),
    );
  }


  Widget _buildActions(BuildContext context, QuoteModel quote) {
    if (LicenseScope.isReadOnlyMode(context)) return const SizedBox();

    return Column(
      children: [
        // Communication Row
        Row(
          children: [
            if (quote.customerEmail.isNotEmpty)
              Expanded(
                child: ElevatedButton.icon(
                   onPressed: () async {
                     final docTitle = quote.docType == 'Proforma' ? 'Proforma Invoice' : 'Quotation';
                     final subject = Uri.encodeComponent('$docTitle: ${quote.quoteNumber}');
                     final body = Uri.encodeComponent('Dear ${quote.customerName},\n\nPlease find the attached $docTitle ${quote.quoteNumber}.\n\nTotal: ₹${quote.totalAmount.toStringAsFixed(2)}\nValid until: ${DateFormat('dd MMM yyyy').format(quote.expiryDate)}\n\nThank you.');
                     final url = Uri.parse('mailto:${quote.customerEmail}?subject=$subject&body=$body');
                     if (await canLaunchUrl(url)) {
                       await launchUrl(url, mode: LaunchMode.externalApplication);
                     } else {
                       if (context.mounted) SnackbarHelper.showError(context, 'Could not open email client');
                     }
                   },
                   icon: const Icon(Icons.email_outlined, color: Colors.white, size: 18),
                   label: const Text('Email'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.blueAccent, // Email Blue
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     elevation: 2,
                   ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Share PDF
        SizedBox(
          width: double.infinity,
           child: OutlinedButton.icon(
            onPressed: () => PdfQuoteHelper.generateAndDownload(quote),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Share PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              side: const BorderSide(color: AppColors.textGrey),
              foregroundColor: AppColors.textDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        // Convert Action
        if (quote.status != 'Converted') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _convertToInvoice(context, quote),
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text('Convert to Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quote?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close Dialog
              try {
                await QuoteService().deleteQuote(widget.quoteId);
                if (context.mounted) {
                  SnackbarHelper.showSuccess(context, 'Quote deleted successfully');
                  Navigator.pop(context); // Close Screen
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarHelper.showError(context, 'Failed to delete quote: $e');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _convertToInvoice(BuildContext context, QuoteModel quote) async {
    // Logic to convert
    try {
      final double subTotal = quote.items.fold(0, (sum, item) => sum + item.amount);
      final double taxAmount = (subTotal * quote.taxPercentage) / 100;

      final bill = BillModel(
        billId: '', // Let DB generate UUID to prevent type errors
        customerName: quote.customerName,
        serviceName: quote.items.isNotEmpty ? quote.items.first.description : 'Service', 
        billDate: DateTime.now(),
        price: subTotal, // Required: Subtotal
        taxPercentage: quote.taxPercentage, // Required
        taxAmount: taxAmount, // Required
        createdAt: DateTime.now(), // Required
        totalAmount: quote.totalAmount,
        advanceAmount: 0,
        paymentStatus: 'Pending',
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        items: quote.items,
        whatsappNumber: quote.whatsappNumber,
        tenantId: quote.tenantId, 
        clientAddress: '', 
        clientId: quote.clientId,
      );

      await BillsService().addBill(bill);
      await QuoteService().updateStatus(quote.quoteId, 'Converted');
      
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Invoice created successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to convert: $e');
      }
    }
  }
}

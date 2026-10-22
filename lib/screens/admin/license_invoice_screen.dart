import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/bill_model.dart';
import '../../models/client_model.dart';
import '../../models/settings_model.dart';
import '../../services/settings_service.dart';
import '../../services/client_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/pdf_invoice_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/upi_helper.dart'; // NEW

class LicenseInvoiceScreen extends StatefulWidget {
  final String clientId;

  const LicenseInvoiceScreen({super.key, required this.clientId});

  @override
  State<LicenseInvoiceScreen> createState() => _LicenseInvoiceScreenState();
}

class _LicenseInvoiceScreenState extends State<LicenseInvoiceScreen> {
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<List<dynamic>> _fetchData() async {
    final client = await ClientService().getClient(widget.clientId);
    if (client == null) throw Exception('Client not found');
    final appSettings = await SettingsService().fetchSettings();
    return [client, appSettings];
  }

  Future<void> _shareViaWhatsApp(ClientModel client, AppSettings settings, double balance, double total) async {
    final phone = client.whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      if (mounted) SnackbarHelper.showError(context, 'No WhatsApp number available');
      return;
    }

    final invoiceUrl = 'https://digibills-c97a9.web.app/#/license-invoice/${client.clientId}';
    // final amount = balance > 0 ? balance : total; // Unused variable

    final message = '''
Dear ${client.businessName},

Your DigiInvi License Invoice is ready.

📋 *Invoice Details*
Plan: ${client.license.plan}
Amount: ₹${total.toStringAsFixed(2)}
${balance > 0 ? 'Balance Due: ₹${balance.toStringAsFixed(2)}' : '✅ PAID IN FULL'}

🔗 View & Download Invoice:
$invoiceUrl

For any queries, contact us.
''';

    final whatsappUrl = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) SnackbarHelper.showError(context, 'Could not launch WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading Invoice...', style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final client = snapshot.data![0] as ClientModel;
        final settings = snapshot.data![1] as AppSettings;

        // Calculations
        double totalPaid = client.advances.fold(0, (sum, item) => sum + item.amount);
        double subTotal = client.amount;
        double taxAmount = (subTotal * client.taxPercentage) / 100;
        double totalAmount = subTotal + taxAmount;
        String payStatus = client.paymentStatus.isNotEmpty ? client.paymentStatus : 'Pending';
        double balance = (payStatus == 'Paid') ? 0.0 : (totalAmount - totalPaid);
        if (balance < 0) balance = 0;

        final bill = BillModel(
          billId: 'LIC-${client.clientId.substring(0, 5).toUpperCase()}',
          customerName: client.businessName,
          clientId: client.clientId,
          serviceName: 'Software License',
          billDate: client.createdAt,
          price: subTotal,
          taxPercentage: client.taxPercentage,
          taxAmount: taxAmount,
          advanceAmount: totalPaid,
          totalAmount: totalAmount,
          paymentStatus: payStatus,
          whatsappNumber: client.whatsappNumber,
          createdAt: DateTime.now(),
          clientAddress: '',
          invoiceNumber: 'INV-${client.clientId.substring(0, 5).toUpperCase()}',
          items: [
            BillItem(
              description: 'DigiInvi Subscription (${client.license.plan})\nPeriod: ${DateFormat('dd MMM yyyy').format(client.license.startDate)} - ${DateFormat('dd MMM yyyy').format(client.license.endDate)}',
              amount: subTotal,
              unitPrice: subTotal,
              quantity: 1,
            )
          ],
          payments: client.advances,
          tenantId: 'SUPERADMIN',
        );

        final upiString = UpiHelper.generateUpiUrl(
          pa: settings.upiId,
          pn: settings.payeeName,
          am: balance > 0 ? balance : totalAmount,
          tn: 'License Invoice ${bill.invoiceNumber}',
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('License Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textDark,
            elevation: 0,
            actions: [
              // WhatsApp Share Button
              IconButton(
                onPressed: () => _shareViaWhatsApp(client, settings, balance, totalAmount),
                icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                tooltip: 'Share via WhatsApp',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // --- Premium Header Gradient ---
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      // Logo
                      if (settings.logoBase64 != null && settings.logoBase64!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.memory(
                            base64Decode(settings.logoBase64!),
                            width: 60,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        settings.tenantName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.fullAddress,
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // --- Invoice Card (Overlapping Header) ---
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Invoice Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('INVOICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.textGrey)),
                                const SizedBox(height: 2),
                                Text(bill.invoiceNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              ],
                            ),
                            _statusBadge(payStatus),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Billed To Section
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              radius: 24,
                              child: Text(
                                client.businessName.isNotEmpty ? client.businessName[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(client.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(client.ownerName, style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 14, color: AppColors.textGrey),
                                      const SizedBox(width: 4),
                                      Text(client.whatsappNumber, style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Date', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                                Text(DateFormat('dd MMM yyyy').format(bill.billDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Service Details Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.verified, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('DigiInvi Subscription', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('Plan: ${client.license.plan.toUpperCase()}', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _dateChip(Icons.play_arrow, 'Start', client.license.startDate),
                                  _dateChip(Icons.stop, 'End', client.license.endDate),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Financial Summary
                        _summaryRow('Sub Total', '₹${subTotal.toStringAsFixed(2)}'),
                        if (client.taxPercentage > 0)
                          _summaryRow('Tax (${client.taxPercentage.toStringAsFixed(0)}%)', '₹${taxAmount.toStringAsFixed(2)}'),
                        const Divider(),
                        _summaryRow('Total Amount', '₹${totalAmount.toStringAsFixed(2)}', isBold: true, fontSize: 18),

                        if (client.advances.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('PAYMENTS RECEIVED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.textGrey)),
                          const SizedBox(height: 8),
                          ...client.advances.map((p) => _summaryRow(
                            '${DateFormat('dd MMM').format(p.date)} (${p.mode})',
                            '-₹${p.amount.toStringAsFixed(2)}',
                            color: AppColors.success,
                            fontSize: 13,
                          )),
                        ],

                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: balance > 0 ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Balance Due', style: TextStyle(fontWeight: FontWeight.bold, color: balance > 0 ? AppColors.error : AppColors.success)),
                              Text('₹${balance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: balance > 0 ? AppColors.error : AppColors.success)),
                            ],
                          ),
                        ),

                        // UPI Payment Section
                        if (balance > 0 && settings.upiId.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.purple.shade50, Colors.blue.shade50]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.purple.shade100),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Scan to Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 8),
                                      if (settings.bankName.isNotEmpty) Text(settings.bankName, style: const TextStyle(fontSize: 12)),
                                      if (settings.accountNumber.isNotEmpty) Text('Acc: ${settings.accountNumber}', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                      if (settings.ifscCode.isNotEmpty) Text('IFSC: ${settings.ifscCode}', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: QrImageView(data: upiString, version: QrVersions.auto, size: 90),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // --- Action Buttons ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await PdfInvoiceHelper.generateAndDownload(bill, overrideSettings: settings);
                            } catch (e) {
                              if (context.mounted) SnackbarHelper.showError(context, 'PDF Error: $e');
                            }
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download PDF'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareViaWhatsApp(client, settings, balance, totalAmount),
                          icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                          label: const Text('Share Invoice', style: TextStyle(color: Colors.green)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'Paid' ? AppColors.success : status == 'Partial' ? Colors.orange : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color, letterSpacing: 0.5),
      ),
    );
  }

  Widget _dateChip(IconData icon, String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
              Text(DateFormat('dd MMM yy').format(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color, double? fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textGrey, fontSize: fontSize ?? 14)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? AppColors.textDark, fontSize: fontSize ?? 14)),
        ],
      ),
    );
  }
}

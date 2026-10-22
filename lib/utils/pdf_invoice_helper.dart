import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../services/settings_service.dart';
import 'snackbar_helper.dart'; // NEW

import '../models/settings_model.dart'; // RESTORED
import '../models/credit_note_model.dart'; // NEW
import '../utils/upi_helper.dart'; // NEW

import 'package:url_launcher/url_launcher.dart'; // NEW
import '../utils/file_download_helper.dart'; // NEW
import 'package:flutter/material.dart';

class PdfInvoiceHelper {

  static Future<void> openWhatsApp(BuildContext context, BillModel bill, {AppSettings? overrideSettings, List<CreditNoteModel>? creditNotes, bool isReminder = false}) async {
    // Using hash style routing to match default Flutter Web behavior and user example
    final link = 'https://digibills-c97a9.web.app/#/view-bill?id=${bill.billId}';
    
    String businessName = 'Business';
    if (overrideSettings != null) {
      businessName = overrideSettings.tenantName;
    } else {
      // Fetch settings if not provided (e.g. from List View)
      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
           final settings = await SettingsService().fetchSettings();
           businessName = settings.tenantName;
        } else {
           final settings = await SettingsService().fetchTenantSettings(bill.tenantId);
           businessName = settings.tenantName;
        }
      } catch (e) {
        // Fallback to generic if fetch fails
        businessName = 'Business'; 
      }
    }

    final date = DateFormat('dd MMM yyyy').format(bill.billDate);
    final netPayable = bill.totalAmount - bill.returnAmount;
    final balanceDue = (bill.paymentStatus.toLowerCase() == 'paid') ? 0.0 : (netPayable - bill.advanceAmount);

    String calculationLines = 'Grand Total: ₹${bill.totalAmount.toStringAsFixed(2)}';
    if (bill.returnAmount > 0) {
      calculationLines += '\nLess Returns: -₹${bill.returnAmount.toStringAsFixed(2)}';
      calculationLines += '\nNet Payable: ₹${netPayable.toStringAsFixed(2)}';
    }
    calculationLines += '\nTotal Advance: ₹${bill.advanceAmount.toStringAsFixed(2)}';
    calculationLines += '\nBalance Due: ₹${balanceDue.toStringAsFixed(2)}';

    if (bill.ewayBillNo != null && bill.ewayBillNo!.isNotEmpty) {
      calculationLines += '\ne-Way Bill No: ${bill.ewayBillNo}';
    }

    final messageHeader = isReminder ? 'Payment Reminder' : 'Invoice';

    final message = '''$messageHeader: ${bill.invoiceNumber} - Payment Request from $businessName

Hello ${bill.customerName},
${isReminder ? 'This is a reminder regarding your invoice from $businessName.' : 'Please find your invoice details from $businessName.'}

Invoice No: ${bill.invoiceNumber}
Date: $date

$calculationLines
Status: ${bill.paymentStatus.toUpperCase()}

View & Pay Here: $link

Please clear the dues at your earliest convenience.
- $businessName''';
    
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('whatsapp://send?phone=${bill.whatsappNumber}&text=$encoded');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback to web whatsapp if app not installed or error
      final webUrl = Uri.parse('https://wa.me/${bill.whatsappNumber}?text=$encoded');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) SnackbarHelper.showError(context, 'Could not launch WhatsApp');
      }
    }
  }
  /// Generates the PDF bytes for an invoice
  static Future<Uint8List> generateInvoicePdf(BillModel bill, {AppSettings? overrideSettings, List<CreditNoteModel>? creditNotes}) async {
    // Fetch Settings
    AppSettings settings;
    try {
      if (overrideSettings != null) {
        settings = overrideSettings;
      } else {
           final currentUser = Supabase.instance.client.auth.currentUser;
           if (currentUser != null) {
              settings = await SettingsService().fetchSettings();
            } else {
               settings = await SettingsService().fetchTenantSettings(bill.tenantId); 
            }
      }
    } catch (_) {
      settings = await SettingsService().fetchTenantSettings(bill.tenantId);
    }
    
    pw.Font font;
    pw.Font fontBold;

    try {
      font = await PdfGoogleFonts.notoSansRegular();
      fontBold = await PdfGoogleFonts.notoSansBold();
    } catch (e) {
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    pw.MemoryImage? profileLogo;
    if (settings.logoBase64 != null) {
      try {
        profileLogo = pw.MemoryImage(base64Decode(settings.logoBase64!));
      } catch (e) {
        // Ignore invalid logo
      }
    }

    final pdf = pw.Document();

    final date = DateFormat('dd MMM yyyy').format(bill.billDate);
    final bool isPaid = bill.paymentStatus.toLowerCase() == 'paid';
    
    // Calculate Returns
    double totalReturns = 0;
    if (creditNotes != null) {
      for (var note in creditNotes) {
        totalReturns += note.totalAmount;
      }
    }

    final netAmount = bill.totalAmount - totalReturns;
    final double balanceDue = isPaid ? 0.0 : (netAmount - bill.advanceAmount);

    final upiUrl = UpiHelper.generateUpiUrl(
      pa: settings.upiId,
      pn: settings.payeeName,
      am: balanceDue,
      tn: 'Invoice ${bill.invoiceNumber}',
    );

    // Define Theme Colors
    const PdfColor primaryColor = PdfColor.fromInt(0xFF112E65);
    const PdfColor accentColor = PdfColor.fromInt(0xFF1E4AB0);
    const PdfColor tableHeaderColor = PdfColor.fromInt(0xFFEFF6FF);
    const PdfColor paidColor = PdfColors.green700;
    const PdfColor dueColor = PdfColors.red700;

    // GST Logic Calculation
    // If placeOfSupply matches settings.state (Same State) -> CGST + SGST
    // Else -> IGST
    final placeOfSupply = bill.placeOfSupply.isNotEmpty ? bill.placeOfSupply : (bill.clientAddress.contains(settings.state) ? settings.state : 'Other');
    final isIntraState = placeOfSupply.toLowerCase() == settings.state.toLowerCase();
    
    double computedCgst = 0;
    double computedSgst = 0;
    double computedIgst = 0;

    // Use stored values if available (historical accuracy), else calculate
    if (bill.cgstAmount > 0 || bill.sgstAmount > 0 || bill.igstAmount > 0) {
       computedCgst = bill.cgstAmount;
       computedSgst = bill.sgstAmount;
       computedIgst = bill.igstAmount;
    } else if (bill.taxPercentage > 0) {
       // Calculation on fly for old bills
       if (isIntraState) {
          computedCgst = bill.taxAmount / 2;
          computedSgst = bill.taxAmount / 2;
       } else {
          computedIgst = bill.taxAmount;
       }
    }

    pw.Widget buildBankRow(String label, String value) {
      return pw.Row(
        children: [
          pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black))),
        ],
      );
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(32),
      buildBackground: (context) {
        if (isPaid) {
          return pw.Center(
            child: pw.Transform.rotate(
              angle: -0.2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: const PdfColor(
                          232 / 255, 
                          245 / 255, 
                          233 / 255, 
                          0.4
                        ), 
                        width: 3
                      ),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      'PAID',
                      style: pw.TextStyle(
                        color: PdfColor(
                          232 / 255, 
                          245 / 255, 
                          233 / 255, 
                          0.4
                        ),
                        fontSize: 60,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
            ),
          );
        }
        return pw.Container();
      },
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      settings.tenantName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        letterSpacing: 2,
                        color: accentColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (settings.fullAddress.isNotEmpty)
                      pw.Text(
                        settings.fullAddress,
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    if (settings.gstNumber.isNotEmpty)
                      pw.Text(
                        'GST: ${settings.gstNumber}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
                if (profileLogo != null)
                  pw.Container(
                    height: settings.logoHeight,
                    width: settings.logoWidth,
                    child: pw.Image(
                      profileLogo,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: accentColor, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Powered by DigiInvi',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        build: (context) {
          return [
            // Bill info & Status
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          const pw.TextSpan(text: 'Invoice No: ', style: pw.TextStyle(color: PdfColors.grey700)),
                          pw.TextSpan(text: bill.invoiceNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        ],
                      ),
                    ),
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          const pw.TextSpan(text: 'Bill Date: ', style: pw.TextStyle(color: PdfColors.grey700)),
                          pw.TextSpan(text: date, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        ],
                      ),
                    ),
                    if (bill.ewayBillNo != null && bill.ewayBillNo!.isNotEmpty)
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            const pw.TextSpan(text: 'e-Way Bill No: ', style: pw.TextStyle(color: PdfColors.grey700)),
                            pw.TextSpan(text: bill.ewayBillNo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          ],
                        ),
                      ),
                    if (bill.vehicleNo != null && bill.vehicleNo!.isNotEmpty)
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            const pw.TextSpan(text: 'Vehicle No: ', style: pw.TextStyle(color: PdfColors.grey700)),
                            pw.TextSpan(text: bill.vehicleNo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          ],
                        ),
                      ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: isPaid ? PdfColors.green50 : PdfColors.red50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: isPaid ? paidColor : dueColor),
                  ),
                  child: pw.Text(
                    bill.paymentStatus.toUpperCase(),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: isPaid ? paidColor : dueColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),

            // Customer info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Billed To
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: tableHeaderColor,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Billed To:',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(bill.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              if (bill.clientAddress.isNotEmpty)
                                pw.Text(bill.clientAddress, style: const pw.TextStyle(fontSize: 9)),
                              if (bill.clientCity != null && bill.clientCity!.isNotEmpty)
                                pw.Text(bill.clientCity!, style: const pw.TextStyle(fontSize: 9)),
                              if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty)
                                pw.Text('GSTIN: ${bill.gstNumber}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              if (bill.placeOfSupply.isNotEmpty)
                                pw.Text('Place of Supply: ${bill.placeOfSupply}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      // Shipped To (Check if different)
                      if (bill.shippingAddress != null && bill.shippingAddress!.trim().isNotEmpty && bill.shippingAddress != bill.clientAddress) ...[
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: tableHeaderColor,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Shipped To:',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(bill.shippingName ?? bill.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.Text(bill.shippingAddress!, style: const pw.TextStyle(fontSize: 9)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: tableHeaderColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Scan to Verify', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        height: 50,
                        width: 50,
                        padding: const pw.EdgeInsets.all(2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: 'https://digibills-c97a9.web.app/#/view-bill?id=${bill.billId}',
                          drawText: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),

            // Items table
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3), // Description
                1: const pw.FlexColumnWidth(1), // HSN/SAC
                2: const pw.FlexColumnWidth(0.8), // Qty
                3: const pw.FlexColumnWidth(1), // Rate
                4: const pw.FlexColumnWidth(1), // Amount
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: tableHeaderColor,
                    border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 1)),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Service / Description',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        bill.items.isNotEmpty ? bill.items.first.hsnType : 'HSN',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Rate',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Amount',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                ...bill.items.map((item) => pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        item.hsnCode ?? '-', 
                        style: const pw.TextStyle(fontSize: 10)
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '${item.quantity} ${item.unit}',
                         textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        item.unitPrice.toStringAsFixed(2),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '₹${item.amount.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                )),
              ],
            ),

            pw.SizedBox(height: 20),

            // COMBINED TOTALS & BANK DETAILS AREA
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // LEFT: Bank Details & UPI QR (Only if not paid)
                pw.Expanded(
                  flex: 1,
                  child: (!isPaid && (settings.bankName.isNotEmpty || settings.upiId.isNotEmpty))
                  ? pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey50,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (settings.bankName.isNotEmpty) ...[
                            pw.Text('BANK DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: primaryColor)),
                            pw.SizedBox(height: 4),
                            buildBankRow('Bank', settings.bankName),
                            buildBankRow('A/C', settings.accountNumber),
                            buildBankRow('IFSC', settings.ifscCode),
                            pw.SizedBox(height: 8),
                          ],
                          if (settings.upiId.isNotEmpty) ...[
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    border: pw.Border.all(color: PdfColors.grey300),
                                  ),
                                  child: pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: upiUrl,
                                    width: 50,
                                    height: 50,
                                  ),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('UPI PAYMENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: primaryColor)),
                                      pw.Text(settings.upiId, style: const pw.TextStyle(fontSize: 7)),
                                      pw.SizedBox(height: 2),
                                      pw.Text('Scan to Pay', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  : pw.SizedBox(),
                ),

                pw.SizedBox(width: 20),

                // RIGHT: Calculation Details
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('₹${(bill.totalAmount - bill.taxAmount).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                      if (computedCgst > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('CGST (${(bill.taxPercentage/2).toStringAsFixed(1)}%):', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                            pw.Text('₹${computedCgst.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      if (computedSgst > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('SGST (${(bill.taxPercentage/2).toStringAsFixed(1)}%):', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                            pw.Text('₹${computedSgst.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      if (computedIgst > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('IGST (${bill.taxPercentage.toStringAsFixed(0)}%):', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                            pw.Text('₹${computedIgst.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      
                      pw.SizedBox(height: 4),
                      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                      
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Text('₹${bill.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                      
                      if (totalReturns > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Less Returns:', style: pw.TextStyle(fontSize: 10, color: PdfColors.red700)),
                            pw.Text('-₹${totalReturns.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                          ],
                        ),

                      if (bill.payments.isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        pw.Text('Payments:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                        ...bill.payments.map((p) => pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('${p.mode} (${DateFormat('dd/MM').format(p.date)}):', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.Text('₹${p.amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                          ]
                        )),
                      ],

                      if (bill.advanceAmount > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Advance:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
                            pw.Text('-₹${bill.advanceAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                          ],
                        ),

                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: balanceDue == 0 ? PdfColors.green50 : PdfColors.red50,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Balance Due:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: balanceDue == 0 ? PdfColors.green700 : PdfColors.red700)),
                            pw.Text('₹${balanceDue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: balanceDue == 0 ? PdfColors.green700 : PdfColors.red700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateAndDownload(BillModel bill, {AppSettings? overrideSettings, List<CreditNoteModel>? creditNotes}) async {
    final pdfBytes = await generateInvoicePdf(bill, overrideSettings: overrideSettings, creditNotes: creditNotes);

    await FileDownloadHelper.downloadFile(
      pdfBytes, 
      'invoice_${bill.invoiceNumber}', 
      'pdf'
    );
  }
}

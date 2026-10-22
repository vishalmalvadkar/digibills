import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/quote_model.dart';
import '../services/settings_service.dart';
import '../models/settings_model.dart';
import 'snackbar_helper.dart'; // NEW
import 'upi_helper.dart'; // NEW
import 'file_download_helper.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class PdfQuoteHelper {
  static Future<void> openWhatsApp(BuildContext context, QuoteModel quote, {AppSettings? overrideSettings}) async {
    final link = 'https://digibills-c97a9.web.app/#/view-quote?id=${quote.quoteId}';
    
    String businessName = 'Business';
    if (overrideSettings != null) {
      businessName = overrideSettings.tenantName;
    } else {
      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
           final settings = await SettingsService().fetchSettings();
           businessName = settings.tenantName;
        } else {
           final settings = await SettingsService().fetchTenantSettings(quote.tenantId);
           businessName = settings.tenantName;
        }
      } catch (e) {
        businessName = 'Business';
      }
    }

    final docTitle = quote.docType == 'Proforma' ? 'Proforma Invoice' : 'Quotation';
    
    final date = DateFormat('dd MMM yyyy').format(quote.date);
    final expiry = DateFormat('dd MMM yyyy').format(quote.expiryDate);
    
    final message = '''$docTitle: ${quote.quoteNumber} - from $businessName

Hello ${quote.customerName},
Here is the $docTitle you requested.

$docTitle: ${quote.quoteNumber}
Date: $date
Total Amount: ₹${quote.totalAmount.toStringAsFixed(2)}
Valid Until: $expiry
Status: ${quote.status}

View & Download Here: $link

- $businessName''';
    
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('whatsapp://send?phone=${quote.whatsappNumber}&text=$encoded');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse('https://wa.me/${quote.whatsappNumber}?text=$encoded');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) SnackbarHelper.showError(context, 'Could not launch WhatsApp');
      }
    }
  }
  static Future<Uint8List> generateQuotePdf(QuoteModel quote, {AppSettings? overrideSettings}) async {
    // Fetch Settings with Public Fallback
    AppSettings settings;
    try {
      if (overrideSettings != null) {
        settings = overrideSettings;
      } else {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
           settings = await SettingsService().fetchSettings();
        } else {
           // Fallback
           settings = await SettingsService().fetchTenantSettings(quote.tenantId);
        }
      }
    } catch (_) {
      settings = await SettingsService().fetchTenantSettings(quote.tenantId);
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
    final date = DateFormat('dd MMM yyyy').format(quote.date);
    final expiryDate = DateFormat('dd MMM yyyy').format(quote.expiryDate);

    final upiUrl = UpiHelper.generateUpiUrl(
      pa: settings.upiId,
      pn: settings.payeeName,
      am: quote.totalAmount,
      tn: '${quote.docType} ${quote.quoteNumber}',
    );

    // Define Theme Colors
    const PdfColor primaryColor = PdfColor.fromInt(0xFF112E65);
    const PdfColor accentColor = PdfColor.fromInt(0xFF1E4AB0);
    const PdfColor tableHeaderColor = PdfColor.fromInt(0xFFEFF6FF);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(32),
      buildBackground: (context) {
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
                      quote.docType == 'Proforma' ? 'PROFORMA INVOICE' : 'QUOTATION',
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
            // Quote Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          const pw.TextSpan(text: 'Quote No: ', style: pw.TextStyle(color: PdfColors.grey700)),
                          pw.TextSpan(text: quote.quoteNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        ],
                      ),
                    ),
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          const pw.TextSpan(text: 'Date: ', style: pw.TextStyle(color: PdfColors.grey700)),
                          pw.TextSpan(text: date, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        ],
                      ),
                    ),
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          const pw.TextSpan(text: 'Valid Until: ', style: pw.TextStyle(color: PdfColors.grey700)),
                          pw.TextSpan(text: expiryDate, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: tableHeaderColor,
                    border: pw.Border.all(color: accentColor),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    quote.status.toUpperCase(), 
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, 
                      fontSize: 10,
                      color: accentColor,
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
                                'Quotation For:',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10),
                              ),
                              pw.Text(quote.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              if (quote.clientId.isNotEmpty)
                                pw.Text('Client ID: ${quote.clientId}', style: const pw.TextStyle(fontSize: 9)),
                              if (quote.placeOfSupply.isNotEmpty)
                                pw.Text('Place of Supply: ${quote.placeOfSupply}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      // Shipped To (Check if different)
                      if (quote.shippingAddress != null && quote.shippingAddress!.trim().isNotEmpty) ...[
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
                                pw.Text(quote.shippingName ?? quote.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.Text(quote.shippingAddress!, style: const pw.TextStyle(fontSize: 9)),
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
                          data: 'https://digibills-c97a9.web.app/#/view-quote?id=${quote.quoteId}',
                          drawText: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),

            // Items Table
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
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
                    _tableHeader('Description', primaryColor),
                    _tableHeader('HSN/SAC', primaryColor),
                    _tableHeader('Qty', primaryColor),
                    _tableHeader('Rate', primaryColor),
                    _tableHeader('Amount', primaryColor, alignRight: true),
                  ],
                ),
                ...quote.items.map((item) => pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                  ),
                  children: [
                    _tableCell(item.description),
                    _tableCell(item.hsnCode ?? '-'),
                    _tableCell('${item.quantity} ${item.unit}'),
                    _tableCell('₹${item.unitPrice.toStringAsFixed(2)}'),
                    _tableCell('₹${item.amount.toStringAsFixed(2)}', alignRight: true),
                  ],
                )),
              ],
            ),

            pw.SizedBox(height: 20),

            // COMBINED TOTALS & BANK DETAILS AREA
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // LEFT: Bank Details & UPI QR (Only if settings exist)
                pw.Expanded(
                  flex: 1,
                  child: (settings.bankName.isNotEmpty || settings.upiId.isNotEmpty)
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
                            _buildBankRow('Bank', settings.bankName),
                            _buildBankRow('A/C', settings.accountNumber),
                            _buildBankRow('IFSC', settings.ifscCode),
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
                      _summaryRow('Subtotal', quote.subTotal),
                      if (quote.taxPercentage > 0) ...[
                        if (quote.placeOfSupply == 'Inter-state')
                           _summaryRow('IGST (${quote.taxPercentage.toStringAsFixed(0)}%)', quote.taxAmount)
                        else ...[
                           _summaryRow('CGST (${(quote.taxPercentage/2).toStringAsFixed(1)}%)', quote.taxAmount / 2),
                           _summaryRow('SGST (${(quote.taxPercentage/2).toStringAsFixed(1)}%)', quote.taxAmount / 2),
                        ]
                      ],
                      
                      pw.SizedBox(height: 8),
                      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                      
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: accentColor,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            pw.Text('₹${quote.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            if (quote.notes.isNotEmpty) ...[
               pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor, fontSize: 10)),
               pw.Text(quote.notes, style: const pw.TextStyle(fontSize: 9)),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateAndDownload(QuoteModel quote, {AppSettings? overrideSettings}) async {
    final pdfBytes = await generateQuotePdf(quote, overrideSettings: overrideSettings);

    await FileDownloadHelper.downloadFile(
      pdfBytes,
      'quote_${quote.quoteNumber}',
      'pdf'
    );
  }

  static pw.Widget _buildBankRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black))),
      ],
    );
  }

  static pw.Widget _tableHeader(String text, PdfColor color, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text, 
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, 
          fontSize: 10,
          color: color,
        )
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text, 
        style: const pw.TextStyle(fontSize: 10),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left
      ),
    );
  }

  static pw.Widget _summaryRow(String label, double amount) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
        pw.Text('₹${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ],
    );
  }
}

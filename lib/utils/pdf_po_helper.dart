import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/purchase_order_model.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';
import 'snackbar_helper.dart'; // NEW
import 'file_download_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class PdfPOHelper {
  static Future<void> openWhatsApp(BuildContext context, PurchaseOrderModel po, {AppSettings? overrideSettings}) async {
    final link = 'https://digibills-c97a9.web.app/#/view-po?id=${po.poId}';
    
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
           final settings = await SettingsService().fetchTenantSettings(po.tenantId);
           businessName = settings.tenantName;
        }
      } catch (e) {
        businessName = 'Business';
      }
    }
    
    final date = DateFormat('dd MMM yyyy').format(po.date);
    final deliveryDate = DateFormat('dd MMM yyyy').format(po.expectedDeliveryDate);
    
    final message = '''Purchase Order: ${po.poNumber} - from $businessName

Hello ${po.vendorName},
Here is a new purchase order.

PO Number: ${po.poNumber}
Date: $date
Total Amount: ₹${po.totalAmount.toStringAsFixed(2)}
Expected Delivery: $deliveryDate
Status: ${po.status}

View & Download Here: $link

- $businessName''';
    
    final encoded = Uri.encodeComponent(message);
    // Note: PO doesn't always have a "mobile number" field clearly defined like "whatsappNumber" in Bill/Quote
    // But assuming vendorContact might be it, or if not, user might have to pick contact manually. 
    // Wait, PO Model has vendorContact. Let's assume it's a phone number.
    
    final url = Uri.parse('whatsapp://send?phone=${po.vendorContact}&text=$encoded');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
       final webUrl = Uri.parse('https://wa.me/${po.vendorContact}?text=$encoded');
       if (await canLaunchUrl(webUrl)) {
         await launchUrl(webUrl, mode: LaunchMode.externalApplication);
       } else {
         if (context.mounted) SnackbarHelper.showError(context, 'Could not launch WhatsApp');
       }
    }
  }
  static Future<Uint8List> generatePdf(PurchaseOrderModel po, {AppSettings? overrideSettings}) async {
    final pdf = pw.Document();
    
    // Fetch Settings
    AppSettings settings;
    try {
      if (overrideSettings != null) {
        settings = overrideSettings;
      } else {
        settings = await SettingsService().fetchTenantSettings(po.tenantId);
      }
    } catch (_) {
      settings = await SettingsService().fetchTenantSettings(po.tenantId);
    }
    
    // Load Fonts
    pw.Font font;
    pw.Font fontBold;
    try {
       font = await PdfGoogleFonts.nunitoExtraLight();
       fontBold = await PdfGoogleFonts.nunitoBold();
    } catch (e) {
       font = pw.Font.helvetica();
       fontBold = pw.Font.helveticaBold();
    }

    // Define Theme Colors
    final PdfColor primaryColor = PdfColor.fromInt(0xFF112E65);
    final PdfColor accentColor = PdfColor.fromInt(0xFF1E4AB0);
    final PdfColor tableHeaderColor = PdfColor.fromInt(0xFFEFF6FF);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            _buildHeader(po, settings, font, fontBold, primaryColor, accentColor),
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
                      'This is a computer generated purchase order.',
                      style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Powered by DigiInvi',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
        build: (context) => [
          _buildVendorSection(po, font, fontBold, primaryColor, tableHeaderColor),
          pw.SizedBox(height: 20),
          _buildTable(po, font, fontBold, tableHeaderColor, primaryColor, accentColor),
          pw.SizedBox(height: 20),
          
          // SIDE-BY-SIDE TOTALS & BANK AREA
          pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // LEFT: Bank Details
                pw.Expanded(
                  flex: 1,
                  child: settings.bankName.isNotEmpty
                  ? pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: tableHeaderColor,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                            pw.Text('PAYMENT BANK DETAILS', style: pw.TextStyle(font: fontBold, fontSize: 9, color: primaryColor)),
                            pw.SizedBox(height: 4),
                            poBankRow('Bank', settings.bankName, font),
                            poBankRow('A/C', settings.accountNumber, font),
                            poBankRow('IFSC', settings.ifscCode, font),
                        ],
                      ),
                    )
                  : pw.SizedBox(),
                ),

                pw.SizedBox(width: 20),

                // RIGHT: Calculation Details
                pw.Expanded(
                  flex: 1,
                  child: _buildTotal(po, fontBold, primaryColor, accentColor),
                ),
              ],
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> generateAndPrint(PurchaseOrderModel po, {AppSettings? overrideSettings}) async {
    final pdfBytes = await generatePdf(po, overrideSettings: overrideSettings);
    
    await FileDownloadHelper.downloadFile(
      pdfBytes,
      '${po.poNumber}',
      'pdf'
    );
  }

  static pw.Widget _buildHeader(PurchaseOrderModel po, AppSettings settings, pw.Font font, pw.Font fontBold, PdfColor primary, PdfColor accent) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(settings.tenantName, style: pw.TextStyle(font: fontBold, fontSize: 20, color: primary)),
            pw.Text('Address: ${settings.address}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
            pw.Text('Phone: ${settings.contactPhone}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('PURCHASE ORDER', style: pw.TextStyle(font: fontBold, fontSize: 24, color: accent)),
            pw.Text('PO Number: ${po.poNumber}', style: pw.TextStyle(font: font, fontSize: 12)),
            pw.Text('Date: ${DateFormat('dd MMM yyyy').format(po.date)}', style: pw.TextStyle(font: font, fontSize: 12)),
            pw.Text('Status: ${po.status}', style: pw.TextStyle(font: fontBold, color: po.status == 'Sent' ? PdfColors.blue : PdfColors.black)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildVendorSection(PurchaseOrderModel po, pw.Font font, pw.Font fontBold, PdfColor primary, PdfColor tableHeaderColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: tableHeaderColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('VENDOR:', style: pw.TextStyle(font: fontBold, fontSize: 10, color: primary)),
              pw.SizedBox(height: 4),
              pw.Text(po.vendorName, style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.Text(po.vendorContact, style: pw.TextStyle(font: font, fontSize: 12)),
              if (po.vendorAddress.isNotEmpty) pw.Text(po.vendorAddress, style: pw.TextStyle(font: font, fontSize: 10)),
              if (po.vendorGst.isNotEmpty) pw.Text('GSTIN: ${po.vendorGst}', style: pw.TextStyle(font: font, fontSize: 10)),
            ],
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('SHIP TO:', style: pw.TextStyle(font: fontBold, fontSize: 10, color: primary)),
              pw.SizedBox(height: 4),
              pw.Text('Delivery Date:', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text(DateFormat('dd MMM yyyy').format(po.expectedDeliveryDate), style: pw.TextStyle(font: fontBold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable(PurchaseOrderModel po, pw.Font font, pw.Font fontBold, PdfColor headerBg, PdfColor primary, PdfColor accent) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: headerBg,
            border: pw.Border(bottom: pw.BorderSide(color: accent, width: 1)),
          ),
          children: [
            _cell('Description', fontBold, color: primary, align: pw.TextAlign.left),
            _cell('Qty', fontBold, color: primary),
            _cell('Unit', fontBold, color: primary),
            _cell('Rate', fontBold, color: primary),
            _cell('Amount', fontBold, color: primary, align: pw.TextAlign.right),
          ],
        ),
        // Rows
        ...po.items.map((item) => pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
          ),
          children: [
            _cell(item.description, font, align: pw.TextAlign.left),
            _cell(item.quantity.toString(), font),
            _cell(item.unit, font),
            _cell(item.unitPrice.toStringAsFixed(2), font),
            _cell(item.amount.toStringAsFixed(2), font, align: pw.TextAlign.right),
          ],
        )),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.center, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10, color: color), textAlign: align),
    );
  }

  static pw.Widget _buildTotal(PurchaseOrderModel po, pw.Font fontBold, PdfColor primary, PdfColor accent) {
    final subtotal = po.totalAmount / (1 + po.taxPercentage / 100);
    final taxAmount = po.totalAmount - subtotal;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('Subtotal: ', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.grey800)),
          pw.Text('INR ${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
        ]),
        if (po.taxPercentage > 0)
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Text('Tax (${po.taxPercentage.toStringAsFixed(1)}%): ', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.grey800)),
            pw.Text('INR ${taxAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
          ]),
        pw.SizedBox(height: 8),
        
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'Total Amount: ', 
                style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.white),
              ),
              pw.Text(
                'INR ${po.totalAmount.toStringAsFixed(2)}', 
                style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget poBankRow(String label, String value, pw.Font font) {
    return pw.Row(
      children: [
        pw.Text('$label: ', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black))),
      ],
    );
  }
}

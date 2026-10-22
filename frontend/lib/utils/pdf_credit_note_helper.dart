import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/credit_note_model.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'snackbar_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/file_download_helper.dart';
import 'package:flutter/material.dart';

class PdfCreditNoteHelper {

  static Future<void> openWhatsApp(BuildContext context, CreditNoteModel note, {AppSettings? overrideSettings}) async {
    // Current route for public view (Proposed)
    final link = 'https://digibills-c97a9.web.app/#/view-return?id=${note.id}';
    
    String businessName = 'Business';
    if (overrideSettings != null) {
      businessName = overrideSettings.tenantName;
    } else {
      try {
         final settings = await SettingsService().fetchTenantSettings(note.tenantId);
         businessName = settings.tenantName;
      } catch (e) {
         businessName = 'Business'; 
      }
    }

    final date = DateFormat('dd MMM yyyy').format(note.returnDate);

    final message = '''CREDIT NOTE: ${note.creditNoteNumber} - Return Processed by $businessName

Hello,
This is a confirmation regarding your sales return.

Credit Note: ${note.creditNoteNumber}
Original Invoice: ${note.invoiceNumber}
Date: $date
Refund/Credit Amount: ₹${note.totalAmount.toStringAsFixed(2)}

View Details Here: $link

The amount has been credited to your account.
- $businessName''';
    
    final encoded = Uri.encodeComponent(message);
    // Use client phone number? CreditNoteModel doesn't have it explicitly, might need to fetch or use bill's if linked.
    // For now, allow sharing to anyone (empty phone) or if we add phone to CreditNoteModel.
    // Let's assume user picks contact if phone is empty.
    
    final url = Uri.parse('whatsapp://send?text=$encoded');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
       if (context.mounted) SnackbarHelper.showError(context, 'Could not launch WhatsApp');
    }
  }

  static Future<Uint8List> generateCreditNotePdf(CreditNoteModel note, {AppSettings? overrideSettings}) async {
    // Fetch Settings
    AppSettings settings;
    try {
      if (overrideSettings != null) {
        settings = overrideSettings;
      } else {
         settings = await SettingsService().fetchTenantSettings(note.tenantId); 
      }
    } catch (_) {
      settings = AppSettings(
        tenantName: 'Business', 
        contactEmail: '',
        contactPhone: '',
        bankName: '',
        accountNumber: '',
        ifscCode: '',
        accountHolderName: '',
        upiId: '',
        payeeName: '',
        gstNumber: '',
        address: '',
        city: '',
        district: '',
        pincode: '',
      ); // Fallback
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
    final date = DateFormat('dd MMM yyyy').format(note.returnDate);

    // Define Theme Colors (Red/Error for Credit Note)
    final PdfColor primaryColor = PdfColors.red800;
    final PdfColor accentColor = PdfColors.red900;
    final PdfColor tableHeaderColor = PdfColors.red50;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          margin: const pw.EdgeInsets.all(32),
        ),
        build: (context) {
          return [
             // HEADER
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
                      'CREDIT NOTE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        letterSpacing: 2,
                        color: accentColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (settings.fullAddress.isNotEmpty)
                      pw.Text(settings.fullAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    if (settings.gstNumber.isNotEmpty)
                      pw.Text('GST: ${settings.gstNumber}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                if (profileLogo != null)
                  pw.Container(
                    height: 60,
                    width: 60,
                    child: pw.Image(profileLogo, fit: pw.BoxFit.contain),
                  ),
              ],
            ),

            pw.SizedBox(height: 20),

            // INFO ROW
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Note #: ${note.creditNoteNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: $date'),
                    pw.Text('Ref Invoice: ${note.invoiceNumber}'),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.red700),
                  ),
                  child: pw.Text(
                    'RETURNED',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 10),
            if (note.reason != null && note.reason!.isNotEmpty)
               pw.Text('Reason: ${note.reason}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),

            pw.SizedBox(height: 20),

            // TABLE
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
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
                      child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ),
                  ],
                ),
                ...note.items.map((item) => pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                  ),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.description)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹${item.amount.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                  ],
                )),
              ],
            ),

            pw.SizedBox(height: 20),

            // TOTALS
             pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                     pw.Text('Subtotal: ₹${(note.subtotal).toStringAsFixed(2)}'),
                   
                   if (note.igstAmount > 0)
                     pw.Text('IGST: ₹${note.igstAmount.toStringAsFixed(2)}'),
                   if (note.cgstAmount > 0)
                     pw.Text('CGST: ₹${note.cgstAmount.toStringAsFixed(2)}'),
                   if (note.sgstAmount > 0)
                     pw.Text('SGST: ₹${note.sgstAmount.toStringAsFixed(2)}'),
                  
                  pw.SizedBox(height: 8),
                  
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Refund Total: ',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                        pw.Text(
                          '₹${note.totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
             pw.SizedBox(height: 30),
             pw.Divider(color: accentColor),
             pw.Text(
               'This is a computer generated credit note.',
               style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
             ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateAndDownload(CreditNoteModel note, {AppSettings? overrideSettings}) async {
    final pdfBytes = await generateCreditNotePdf(note, overrideSettings: overrideSettings);

    await FileDownloadHelper.downloadFile(
      pdfBytes, 
      'credit_note_${note.creditNoteNumber}', 
      'pdf'
    );
  }
}

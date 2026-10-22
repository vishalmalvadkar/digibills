
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart'; // For Fonts
import '../models/bill_model.dart';
import '../models/settings_model.dart';
import '../models/credit_note_model.dart'; // NEW

class PdfThermalHelper {
  static const double topPadding = 20;
  static const double bottomPadding = 30;
  static const double sideMargin = 4 * PdfPageFormat.mm; // Professional 4mm margin

  static double estimateHeight(BillModel bill, List<CreditNoteModel>? creditNotes) {
    double h = 0;
    
    h += topPadding;

    // Header Section
    h += 60; // Tenant Name, Address, Phone, GSTIN
    h += 20; // Divider + spacing

    // Invoice Info Section
    h += 20; // Invoice # / Date
    h += 15; // Customer Name
    if (bill.gstNumber?.isNotEmpty ?? false) h += 12;
    if (bill.placeOfSupply.isNotEmpty) h += 12;
    if (bill.clientCity?.isNotEmpty ?? false) h += 12;
    if (bill.ewayBillNo?.isNotEmpty ?? false) h += 12;
    if (bill.vehicleNo?.isNotEmpty ?? false) h += 12;
    
    h += 20; // Divider + spacing

    // Items Section
    for (var _ in bill.items) {
      h += 35; // Description + Qty/Rate/Amount + Padding
    }

    // Returns Section
    if (creditNotes != null && creditNotes.isNotEmpty) {
      h += 25; // Header
      for (var note in creditNotes) {
        h += (note.items.length * 20); // Each item row
      }
      h += 15; // Bottom divider spacing
    }

    h += 20; // Divider + spacing

    // Totals Section
    h += 12; // Subtotal
    if (bill.cgstAmount > 0) h += 12;
    if (bill.sgstAmount > 0) h += 12;
    if (bill.igstAmount > 0) h += 12;
    h += 25; // Divider + Grand Total
    
    if (bill.returnAmount > 0) {
      h += 15; // Less Returns
      h += 30; // Net Payable
    }

    h += 25; // Status Stamp
    h += 70; // QR Code area
    h += 35; // Footer (Thank you, Powered by)
    
    h += bottomPadding;

    return h;
  }

  static Future<Uint8List> generateThermalPdf(
    BillModel bill,
    AppSettings settings, {
    bool is58mm = true, // false = 80mm
    List<CreditNoteModel>? creditNotes, // NEW
    bool isWeb = false, // Kept for signature compatibility
  }) async {
    final pdf = pw.Document();

    // Calculate exact height to avoid Android adding extra whitespace
    final double contentHeight = estimateHeight(bill, creditNotes);
    
    // Create custom page format with finite height and professional side margins
    final PdfPageFormat pageFormat = PdfPageFormat(
      (is58mm ? 57 : 80) * PdfPageFormat.mm,
      contentHeight,
      marginAll: sideMargin,
    );

    // Dynamic Fonts
    pw.Font fontRegular;
    pw.Font fontBold;

    try {
      fontRegular = await PdfGoogleFonts.notoSansRegular();
      fontBold = await PdfGoogleFonts.notoSansBold();
    } catch (e) {
      fontRegular = pw.Font.courier();
      fontBold = pw.Font.courierBold();
    }

    final currency = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 2);
    final dateFormat = DateFormat('dd-MM-yy HH:mm');

    // GST Logic Calculation
    final placeOfSupply = bill.placeOfSupply.isNotEmpty ? bill.placeOfSupply : (bill.clientAddress.contains(settings.state) ? settings.state : 'Other');
    final isIntraState = placeOfSupply.toLowerCase() == settings.state.toLowerCase();
    
    double computedCgst = 0;
    double computedSgst = 0;
    double computedIgst = 0;

    // Labels with Percentages
    String cgstLabel = 'CGST';
    String sgstLabel = 'SGST';
    String igstLabel = 'IGST';

    if (bill.cgstAmount > 0 || bill.sgstAmount > 0 || bill.igstAmount > 0) {
       computedCgst = bill.cgstAmount;
       computedSgst = bill.sgstAmount;
       computedIgst = bill.igstAmount;
       // Try calculate percent from amount if not stored? mostly stored in bill.taxPercentage
    } else if (bill.taxPercentage > 0) {
       if (isIntraState) {
          computedCgst = bill.taxAmount / 2;
          computedSgst = bill.taxAmount / 2;
       } else {
          computedIgst = bill.taxAmount;
       }
    }

    if (bill.taxPercentage > 0) {
      if (isIntraState) {
        cgstLabel = 'CGST (${(bill.taxPercentage / 2).toStringAsFixed(1)}%)';
        sgstLabel = 'SGST (${(bill.taxPercentage / 2).toStringAsFixed(1)}%)';
      } else {
        igstLabel = 'IGST (${bill.taxPercentage.toStringAsFixed(0)}%)';
      }
    }

    // Calculate Returns
    double totalReturns = 0;
    if (creditNotes != null) {
      for (var note in creditNotes) {
        totalReturns += note.totalAmount;
      }
    }
    // Final Payable Calculation
    final grandTotal = bill.totalAmount; 
    final subTotal = grandTotal - bill.taxAmount;
    final finalPayable = grandTotal - totalReturns;


    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // 1. HEADER
              pw.Text(settings.tenantName.toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: 10)),
              if (settings.address.isNotEmpty)
                pw.Text(settings.address,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              if (settings.contactPhone.isNotEmpty)
                pw.Text('Ph: ${settings.contactPhone}',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              if (settings.gstNumber.isNotEmpty)
                pw.Text('GSTIN: ${settings.gstNumber}',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, color: PdfColors.black), 
              pw.SizedBox(height: 5),

              // 2. INVOICE INFO
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Inv: ${bill.invoiceNumber}',
                      style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  pw.Text(dateFormat.format(bill.createdAt),
                      style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                ],
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('To: ${bill.customerName}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 9)),
              ),
              if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('GSTIN: ${bill.gstNumber}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                ),
               if (settings.state.isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('POS: $placeOfSupply',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                ),
              if (bill.clientCity != null && bill.clientCity!.isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('City: ${bill.clientCity}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                ),
              if (bill.ewayBillNo != null && bill.ewayBillNo!.isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('EWB: ${bill.ewayBillNo}',
                      style: pw.TextStyle(font: fontBold, fontSize: 8)),
                ),
              if (bill.vehicleNo != null && bill.vehicleNo!.isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('VEH: ${bill.vehicleNo}',
                      style: pw.TextStyle(font: fontBold, fontSize: 8)),
                ),
              
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed), 
              pw.SizedBox(height: 5),

              // 3. ITEMS TABLE
              ...bill.items.map((item) {
                final total = item.quantity * item.unitPrice;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.description, 
                        style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            '${item.quantity.toStringAsFixed(1)} x ${item.unitPrice.toStringAsFixed(0)}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                        pw.Text(total.toStringAsFixed(2),
                            style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                  ],
                );
              }),

              // RETURNS SECTION
              if (creditNotes != null && creditNotes.isNotEmpty) ...[
                 pw.SizedBox(height: 4),
                 pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                 pw.SizedBox(height: 2),
                 pw.Align(
                   alignment: pw.Alignment.centerLeft,
                   child: pw.Text('RETURNS / CANCELLED:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                 ),
                 pw.SizedBox(height: 2),
                 ...creditNotes.expand((note) => note.items).map((item) {
                   return pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                       pw.Row(
                         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                         children: [
                           pw.Expanded(
                             child: pw.Text('${item.description} (${item.quantity.toStringAsFixed(1)} ret)', 
                               style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700)),
                           ),
                           pw.Text('-${item.returnAmount.toStringAsFixed(2)}', 
                               style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.black)),
                         ],
                       ),
                       pw.SizedBox(height: 2),
                     ]
                   );
                 }),
              ],

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed), 
              pw.SizedBox(height: 5),

              // 4. TOTALS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  pw.Text(subTotal.toStringAsFixed(2), 
                      style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                ],
              ),
              
              // GST Breakdown
              if (computedCgst > 0)
                 pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(cgstLabel, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    pw.Text(computedCgst.toStringAsFixed(2), style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
              if (computedSgst > 0)
                 pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(sgstLabel, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    pw.Text(computedSgst.toStringAsFixed(2), style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
              if (computedIgst > 0)
                 pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(igstLabel, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    pw.Text(computedIgst.toStringAsFixed(2), style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
               
               pw.SizedBox(height: 4),
               pw.Divider(thickness: 1, color: PdfColors.black),
               pw.SizedBox(height: 4),

               // Total Before Returns
               pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text(currency.format(grandTotal), 
                      style: pw.TextStyle(font: fontBold, fontSize: 10)),
                ],
              ),

              if (totalReturns > 0) ...[
                 pw.SizedBox(height: 2),
                 pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Less Returns', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.red)),
                    pw.Text('-${currency.format(totalReturns).replaceAll('INR', '')}', 
                        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.red)),
                  ],
                ),
                pw.SizedBox(height: 2),
                 pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET PAYABLE', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.Text(currency.format(finalPayable), 
                        style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  ],
                ),
              ],
              
              pw.SizedBox(height: 10),

              // 5. STATUS STAMP
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  (totalReturns > 0 && finalPayable <= 0) ? 'RETURNED' : bill.paymentStatus.toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: 12),
                ),
              ),

              // 6. QR CODE FOR VERIFICATION
              pw.SizedBox(height: 10),
              pw.Container(
                height: 50,
                width: 50,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'https://digibills-c97a9.web.app/#/view-bill?id=${bill.billId}',
                  drawText: false,
                ),
              ),
              pw.Text('Scan to Verify', 
                  style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey700)),
              
              pw.SizedBox(height: 10),
              pw.Text('Thank You!',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.Text('Powered by DigiInvi',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import 'package:printing/printing.dart';
import '../models/settings_model.dart'; // NEW
import 'pdf_header_helper.dart'; // NEW

class PdfStatementHelper {
  static Future<List<int>> generate({
    required AppSettings settings, // NEW
    required String clientName,
    required String clientId,
    required String clientAddress,
    required String clientPhone,
    required List<BillModel> bills,
    required double totalBilled,
    required double totalPaid,
    required double totalPending,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return [
            // Header
            PdfHeaderHelper.buildHeader(
              settings: settings,
              title: 'STATEMENT OF ACCOUNT',
              showDate: true
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Client Info & Summary
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Client Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                      pw.Text(clientName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      if (clientId.isNotEmpty) pw.Text('ID: $clientId', style: const pw.TextStyle(fontSize: 9)),
                      if (clientAddress.isNotEmpty) pw.Text(clientAddress, style: const pw.TextStyle(fontSize: 9)),
                      if (clientPhone.isNotEmpty) pw.Text('Phone: $clientPhone', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Total Billed', totalBilled),
                        _buildSummaryRow('Total Received', totalPaid, color: PdfColors.green700),
                        pw.Divider(thickness: 0.5),
                        _buildSummaryRow('Balance Due', totalPending, isBold: true, color: totalPending > 0 ? PdfColors.red700 : PdfColors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(40), // Invoice
                1: const pw.FixedColumnWidth(45), // Date
                2: const pw.FlexColumnWidth(0.8), // Customer
                3: const pw.FlexColumnWidth(1.2), // Service
                4: const pw.FixedColumnWidth(60), // Advance
                5: const pw.FixedColumnWidth(45), // Received
                6: const pw.FixedColumnWidth(45), // Balance
                7: const pw.FixedColumnWidth(40), // Status
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildCell('Inv #', isHeader: true, fontSize: 8),
                    _buildCell('Date', isHeader: true, fontSize: 8),
                    _buildCell('Client', isHeader: true, fontSize: 8),
                    _buildCell('Service', isHeader: true, fontSize: 8),
                    _buildCell('Advance', isHeader: true, fontSize: 8),
                    _buildCell('Recv', isHeader: true, fontSize: 8),
                    _buildCell('Bal', isHeader: true, fontSize: 8),
                    _buildCell('Sts', isHeader: true, fontSize: 8),
                  ],
                ),
                ...bills.map((bill) {
                  final received = bill.paymentStatus == 'Paid' ? bill.totalAmount : bill.advanceAmount;
                  final balance = bill.paymentStatus == 'Paid' ? 0.0 : (bill.totalAmount - bill.advanceAmount);
                  
                  // Advance Text Logic
                  String advanceText = '-';
                  if (bill.payments.isNotEmpty) {
                      final last = bill.payments.last;
                      // Compact date for A4 Portrait
                      advanceText = '${last.amount.toStringAsFixed(0)}\n(${DateFormat('dd/MM').format(last.date)})';
                  } else if (bill.advanceAmount > 0) {
                      advanceText = bill.advanceAmount.toStringAsFixed(0);
                      if (bill.paymentReceivedDate != null) {
                         advanceText += '\n(${DateFormat('dd/MM').format(bill.paymentReceivedDate!)})';
                      }
                  }

                   // Service Logic (More truncation for Portrait)
                  String serviceText = bill.items.map((e) => e.description).join(', ');
                  if (serviceText.isEmpty) serviceText = bill.serviceName;
                  if (serviceText.length > 50) serviceText = '${serviceText.substring(0, 50)}...';

                  // Customer Name Truncate
                  String customerText = bill.customerName;
                  if (customerText.length > 15) customerText = '${customerText.substring(0, 15)}..';

                  return pw.TableRow(
                    children: [
                      _buildCell(bill.invoiceNumber.isNotEmpty ? bill.invoiceNumber : '-', fontSize: 7),
                      _buildCell(DateFormat('dd/MM').format(bill.billDate), fontSize: 7),
                      _buildCell(customerText, fontSize: 7),
                      _buildCell(serviceText, fontSize: 7),
                      _buildCell(advanceText, fontSize: 7),
                      _buildCell(received.toStringAsFixed(0), fontSize: 7),
                      _buildCell(balance.toStringAsFixed(0), fontSize: 7, color: balance > 0 ? PdfColors.red700 : null),
                      _buildCell(bill.paymentStatus.substring(0, 3).toUpperCase(), isBold: true, fontSize: 7, color: bill.paymentStatus == 'Paid' ? PdfColors.green700 : PdfColors.orange700),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.Spacer(),
            pw.Divider(),
             pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Generated by DigiInvi', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, double value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('INR ${value.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildCell(String text, {bool isHeader = false, bool isBold = false, PdfColor? color, double? fontSize}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: fontSize ?? (isHeader ? 10 : 9),
          color: color,
        ),
      ),
    );
  }
}

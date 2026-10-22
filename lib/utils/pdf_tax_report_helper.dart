import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/settings_model.dart';
import '../services/tax_service.dart';
import 'pdf_header_helper.dart';
import 'file_download_helper.dart'; // NEW

class PdfTaxReportHelper {

  Future<void> generateAndDownloadReport(TaxReportData data, String periodLabel, AppSettings settings) async {
    final pdf = pw.Document();

    // Fonts (Fallback to standard)
    final fontRegular = pw.Font.courier();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          PdfHeaderHelper.buildHeader(
            settings: settings, 
            title: 'GST / Tax Report', 
            subtitle: 'Period: $periodLabel',
            showDate: true
          ),
          pw.SizedBox(height: 20),
          _buildSummary(data),
          pw.SizedBox(height: 20),
          _buildTable(data, fontRegular),
        ],
      ),
    );

    // Standardized Download (Handles PWA direct download & Mobile identification correctly)
    await FileDownloadHelper.downloadFile(
      await pdf.save(), 
      'TaxReport_${periodLabel.replaceAll(' ', '_')}', 
      'pdf'
    );
  }

  pw.Widget _buildSummary(TaxReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem('Taxable Value', data.totalTaxable),
          _buildSummaryItem('Output Tax', data.totalOutputTax),
          _buildSummaryItem('Input Tax', data.totalInputTax),
          _buildSummaryItem('Net Payable', data.netPayable),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, double amount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text('INR ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildTable(TaxReportData data, pw.Font font) {
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Invoice #', 'Customer', 'Taxable', 'GST', 'Total'],
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FlexColumnWidth(2),
      },
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font, fontSize: 10),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      data: data.bills.map((bill) {
        return [
          DateFormat('dd-MMM').format(bill.billDate),
          bill.invoiceNumber,
          bill.customerName,
          bill.price.toStringAsFixed(2),
          bill.taxAmount.toStringAsFixed(2),
          bill.totalAmount.toStringAsFixed(2),
        ];
      }).toList(),
    );
  }
}

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; 
import '../models/annual_summary_model.dart';
import '../models/settings_model.dart';
import 'pdf_header_helper.dart';
import 'file_download_helper.dart';

class PdfYearEndHelper {
  Future<void> generateAndDownload(AnnualSummary data, AppSettings settings) async {
    final pdf = pw.Document();
    
    final font = pw.Font.courier();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          PdfHeaderHelper.buildHeader(
            settings: settings, 
            title: 'Year-End Financial Summary', 
            subtitle: 'Fiscal Year: ${data.year}',
            date: DateTime(data.year, 12, 31)
          ),
          pw.SizedBox(height: 20),
          _buildYearSummary(data),
          pw.SizedBox(height: 20),
          pw.Text('Monthly Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: font)),
          pw.SizedBox(height: 10),
          _buildMonthlyTable(data, font),
        ],
      ),
    );

    await FileDownloadHelper.downloadFile(
      await pdf.save(),
      'YearEndSummary_${data.year}',
      'pdf'
    );
  }

  pw.Widget _buildYearSummary(AnnualSummary data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem('Total Revenue', data.totalIncome),
          _buildSummaryItem('Total Expenses', data.totalExpense),
          _buildSummaryItem('Net Profit', data.netProfit, isProfit: true),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, double amount, {bool isProfit = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(
          'INR ${amount.toStringAsFixed(2)}', 
          style: pw.TextStyle(
            fontSize: 14, 
            fontWeight: pw.FontWeight.bold,
            color: isProfit && amount < 0 ? PdfColors.red : PdfColors.black
          )
        ),
      ],
    );
  }

  pw.Widget _buildMonthlyTable(AnnualSummary data, pw.Font font) {
    return pw.TableHelper.fromTextArray(
      headers: ['Month', 'Income', 'Expense', 'Profit'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font, fontSize: 10),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      data: data.monthlyData.map((m) {
        return [
          DateFormat('MMMM').format(DateTime(2000, m.month)),
          m.income.toStringAsFixed(2),
          m.expense.toStringAsFixed(2),
          m.profit.toStringAsFixed(2),
        ];
      }).toList(),
    );
  }
}

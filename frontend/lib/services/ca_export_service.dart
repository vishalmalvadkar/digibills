import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'trial_balance_service.dart';
import 'pnl_service.dart';
import 'balance_sheet_service.dart';
import 'tax_service.dart';
import 'receivables_service.dart';
import 'settings_service.dart';

import '../models/pnl_data_model.dart';
import '../models/balance_sheet_model.dart';
import '../models/client_receivable_model.dart';
import '../models/settings_model.dart';
import '../utils/file_download_helper.dart';
import '../utils/pdf_balance_sheet_helper.dart';

class CaExportService {
  final _trialBalanceService = TrialBalanceService();
  final _pnlService = PnLService();
  final _balanceSheetService = BalanceSheetService();
  final _taxService = TaxService();
  final _receivablesService = ReceivablesService();
  // report_service not needed as separate instance if we use ReportService for generic excel?
  // ReportService has generateExcel method.

  Future<void> downloadCaPack(int startYear, BuildContext context) async {
    // FY: Apr 1, startYear to Mar 31, startYear+1
    final start = DateTime(startYear, 4, 1);
    final end = DateTime(startYear + 1, 3, 31, 23, 59, 59);
    final fyString = 'FY$startYear-${(startYear+1).toString().substring(2)}';

    try {
      // 1. Fetch ALL Data in Parallel
      final results = await Future.wait([
        _trialBalanceService.fetchTrialBalance(start, end),
        _pnlService.fetchPnL(start, end),
        _balanceSheetService.generateBalanceSheet(end),
        _taxService.fetchTaxReport(start, end),
        _receivablesService.fetchReceivables(),
        SettingsService().fetchSettings(),
      ]);

      final tbData = results[0] as List<TrialBalanceEntry>;
      final pnlData = results[1] as PnLData;
      final bsData = results[2] as BalanceSheetData;
      final gstData = results[3] as TaxReportData;
      final agingData = results[4] as List<ClientReceivableModel>;
      final settings = results[5] as AppSettings;

      // 2. Generate Files (Bytes)
      
      // A. Trial Balance (Excel)
      final tbBytes = _generateStyledExcel(
        'Trial Balance', 
        ['Account Name', 'Group', 'Debit', 'Credit'],
        tbData.map((e) => [e.accountName, e.group, e.debit, e.credit]).toList()
      );

      // B. P&L (Excel)
      final pnlBytes = _generateStyledExcel(
        'Profit & Loss',
        ['Head', 'Amount'],
        [
          ['Total Income (Revenue)', pnlData.totalIncome],
          ['Total Expenses', pnlData.totalExpense],
          ['Net Profit / Loss', pnlData.netProfit],
        ]
      );

      // C. Balance Sheet (PDF)
      final bsBytes = await PdfBalanceSheetHelper().generateBytes(bsData, settings);

      // D. GST Report (Excel)
      final gstBytes = _taxService.generateDetailedExcel(gstData, fyString);

      // E. Aging Report (Excel)
      final agingBytes = _generateStyledExcel(
        'Receivables Aging',
        ['Client Name', 'Total Pending', 'Bill Count', 'Oldest Bill', 'Overdue Days'],
        agingData.map((ClientReceivableModel e) => [
          e.clientName,
          e.totalPending,
          e.billCount,
          DateFormat('yyyy-MM-dd').format(e.oldestBillDate),
          e.overdueDays
        ]).toList()
      );

      // 3. Zip
      final archive = Archive();
      archive.addFile(ArchiveFile('1_Trial_Balance.xlsx', tbBytes.length, tbBytes));
      archive.addFile(ArchiveFile('2_Profit_Loss.xlsx', pnlBytes.length, pnlBytes));
      archive.addFile(ArchiveFile('3_Balance_Sheet.pdf', bsBytes.length, bsBytes));
      archive.addFile(ArchiveFile('4_GST_Summary.xlsx', gstBytes.length, gstBytes));
      archive.addFile(ArchiveFile('5_Receivables_Aging.xlsx', agingBytes.length, agingBytes));

      final zipBytes = ZipEncoder().encode(archive);

      // 4. Download
      if (zipBytes != null) {
        await FileDownloadHelper.downloadFile(Uint8List.fromList(zipBytes), 'CAPack_$fyString', 'zip');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CA Pack downloaded successfully!')));
        }
      }

    } catch (e) {
      debugPrint('CA Export Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating CA Pack: $e')));
      }
    }
  }

  List<int> _generateStyledExcel(String title, List<String> headers, List<List<dynamic>> rows) {
    var excel = Excel.createExcel();
    excel.rename('Sheet1', title);
    Sheet sheet = excel[title];

    // 1. Title Row
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
                CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: 0));
    var titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue(title);
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // 2. Define Styles
    CellStyle headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'), // Dark Blue
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    CellStyle rowStyleOdd = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    CellStyle rowStyleEven = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'), // Light Grey
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // 3. Headers
    sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.cellStyle = headerStyle;
    }

    // 4. Rows
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      sheet.appendRow(row.map((cell) {
        if (cell is double || cell is int) {
           return DoubleCellValue(double.parse(cell.toString()));
        } else {
           return TextCellValue(cell.toString());
        }
      }).toList());

      // Apply Zebra Stripes
      CellStyle currentStyle = (i % 2 == 0) ? rowStyleOdd : rowStyleEven;
      for (int col = 0; col < row.length; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 2));
        cell.cellStyle = currentStyle;
      }
    }

    // 5. Column Widths
    for (int i = 0; i < headers.length; i++) {
       sheet.setColumnWidth(i, 20);
    }

    // Return pure bytes using encode() to avoid ghost downloads triggered by save() on web
    return _patchExcelMetadata(excel.encode() ?? [], title);
  }

  List<int> _patchExcelMetadata(List<int> fileBytes, String title) {
    if (fileBytes.isEmpty) return [];
    try {
      final archive = ZipDecoder().decodeBytes(fileBytes);
      final newArchive = Archive();

      for (final file in archive) {
        if (file.name == 'docProps/core.xml') {
          String content = String.fromCharCodes(file.content);
          content = content.replaceAll('Flutter Excel', title);
          content = content.replaceAll('<dc:creator>Flutter</dc:creator>', '<dc:creator>DigiInvi</dc:creator>');
          content = content.replaceAll('Flutter', 'DigiInvi');
          newArchive.addFile(ArchiveFile(file.name, content.length, content.codeUnits));
        } else {
          newArchive.addFile(file);
        }
      }
      return ZipEncoder().encode(newArchive) ?? fileBytes;
    } catch (e) {
      debugPrint('Error patching Excel metadata in CA Pack: $e');
      return fileBytes;
    }
  }
}

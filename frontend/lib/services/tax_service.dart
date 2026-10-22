import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart'; // NEW
import 'package:intl/intl.dart'; // NEW
import 'package:flutter/foundation.dart'; // NEW
import 'package:archive/archive.dart'; // NEW
import '../models/expense_model.dart'; // NEW
import '../models/bill_model.dart';
import 'auth_service.dart';

class TaxReportData {
  final double totalTaxable;
  final double totalOutputTax; // Renamed from totalTax for clarity
  final double totalInvoiceValue;
  final List<BillModel> bills;

  // NEW: Input Tax (ITC)
  final double totalInputTax;
  final double netPayable;
  
  // Breakups
  final double outputIgst;
  final double outputCgst;
  final double outputSgst;
  
  final double inputIgst;
  final double inputCgst;
  final double inputSgst;

  final List<ExpenseModel> expenses;
  final Map<String, TaxStateSummary> stateWiseSales; // NEW

  TaxReportData({
    required this.totalTaxable,
    required this.totalOutputTax,
    required this.totalInvoiceValue,
    required this.bills,
    required this.totalInputTax,
    required this.netPayable,
    required this.outputIgst,
    required this.outputCgst,
    required this.outputSgst,
    required this.inputIgst,
    required this.inputCgst,
    required this.inputSgst,
    required this.expenses,
    required this.stateWiseSales,
  });
}

class TaxStateSummary {
  double taxableValue;
  double taxAmount;
  double totalAmount;
  
  TaxStateSummary({this.taxableValue = 0, this.taxAmount = 0, this.totalAmount = 0});
}

class TaxService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<TaxReportData> fetchTaxReport(DateTime start, DateTime end) async {
    final tenantId = _authService.currentTenantId;

    // --- 1. OUTPUT TAX (Sales) ---
    final response = await _supabase
        .from('bills')
        .select()
        .eq('tenant_id', tenantId)
        .gte('bill_date', start.toIso8601String())
        .lte('bill_date', end.toIso8601String());

    double totalTaxable = 0;
    double totalOutputTax = 0;
    double totalInvoice = 0;
    
    double outputIgst = 0;
    double outputCgst = 0;
    double outputSgst = 0;

    List<BillModel> bills = [];
    Map<String, TaxStateSummary> stateWiseSales = {}; // NEW

    for (var json in response) {
      final bill = BillModel.fromMap(json);
      totalTaxable += bill.price;
      totalOutputTax += bill.taxAmount;
      totalInvoice += bill.totalAmount;
      
      outputIgst += bill.igstAmount;
      outputCgst += bill.cgstAmount;
      outputSgst += bill.sgstAmount;
      
      bills.add(bill);

      // Aggregate State-wise
      final state = bill.placeOfSupply.isNotEmpty ? bill.placeOfSupply : 'Unknown';
      if (!stateWiseSales.containsKey(state)) {
        stateWiseSales[state] = TaxStateSummary();
      }
      stateWiseSales[state]!.taxableValue += bill.price;
      stateWiseSales[state]!.taxAmount += bill.taxAmount;
      stateWiseSales[state]!.totalAmount += bill.totalAmount;
    }

    // Returns (Credit Notes)
    final notesResponse = await _supabase
        .from('credit_notes')
        .select()
        .eq('tenant_id', tenantId)
        .gte('return_date', start.toIso8601String())
        .lte('return_date', end.toIso8601String());

    for (var json in notesResponse) {
       final subtotal = (json['subtotal'] ?? 0).toDouble();
       final tax = (json['tax_amount'] ?? 0).toDouble();
       final total = (json['total_amount'] ?? 0).toDouble();
       
       final igst = (json['igst_amount'] ?? 0).toDouble();
       final cgst = (json['cgst_amount'] ?? 0).toDouble();
       final sgst = (json['sgst_amount'] ?? 0).toDouble();

       totalTaxable -= subtotal;
       totalOutputTax -= tax;
       totalInvoice -= total;
       
       outputIgst -= igst;
       outputCgst -= cgst;
       outputSgst -= sgst;

       // Adjust State-wise (assuming we can get state from Credit Note or linked Bill)
       // Credit Note schema usually has client_id/details. We might miss state if not stored.
       // For now, let's skip state adjustment for simplicity or check if stored?
       // The `credit_notes` table creation not fully visible, but usually doesn't store state directly perfectly.
       // However, to be accurate, we should. 
       // For now, ignoring CN impact on state-summary or assigning to 'Returns'?
       // Let's assign to 'Returns/Adjustments' to avoid skewing a specific state if unknown.
       const state = 'Returns/Adjustments';
       if (!stateWiseSales.containsKey(state)) {
          stateWiseSales[state] = TaxStateSummary();
       }
       stateWiseSales[state]!.taxableValue -= subtotal;
       stateWiseSales[state]!.taxAmount -= tax;
       stateWiseSales[state]!.totalAmount -= total;

       bills.add(BillModel(
         billId: json['id'],
         customerName: 'Return (${json['credit_note_number']})',
         clientId: json['client_id'],
         serviceName: 'Tax Reversal',
         billDate: DateTime.parse(json['return_date']),
         price: -subtotal, 
         taxPercentage: 0,
         taxAmount: -tax, 
         cgstAmount: -cgst,
         sgstAmount: -sgst,
         igstAmount: -igst,
         advanceAmount: 0,
         totalAmount: -total,
         paymentStatus: 'Returned',
         paymentReceivedDate: DateTime.parse(json['return_date']),
         whatsappNumber: '',
         createdAt: DateTime.parse(json['created_at']),
         clientAddress: '',
         invoiceNumber: json['credit_note_number'],
         items: [],
         payments: [],
         tenantId: json['tenant_id'],
         placeOfSupply: '',
         gstNumber: '',
       ));
    }
    
    bills.sort((a, b) => b.billDate.compareTo(a.billDate));


    // --- 2. INPUT TAX (Purchases) ---
    final expenseResponse = await _supabase
        .from('expenses')
        .select()
        .eq('tenant_id', tenantId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String());

    double totalInputTax = 0;
    double inputIgst = 0;
    double inputCgst = 0;
    double inputSgst = 0;
    
    List<ExpenseModel> expenses = [];

    for (var json in expenseResponse) {
       final expense = ExpenseModel.fromMap(json);
       if (expense.isItcEligible) {
          totalInputTax += expense.taxAmount;
          
          if (expense.taxType == 'IGST') {
             inputIgst += expense.taxAmount;
          } else if (expense.taxType == 'CGST_SGST') {
             inputCgst += expense.taxAmount / 2;
             inputSgst += expense.taxAmount / 2;
          }
       }
       expenses.add(expense);
    }
    
    // --- NEW: Add Purchases to ITC ---
    final purchasesResponse = await _supabase
        .from('purchases')
        .select()
        .eq('tenant_id', tenantId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String());

    for (var json in purchasesResponse) {
       final subtotal = (json['subtotal'] as num?)?.toDouble() ?? 0;
       final tax = (json['tax_amount'] as num?)?.toDouble() ?? 0;
       
       totalInputTax += tax;
       
       final igst = (json['igst'] as num?)?.toDouble() ?? 0;
       final cgst = (json['cgst'] as num?)?.toDouble() ?? 0;
       final sgst = (json['sgst'] as num?)?.toDouble() ?? 0;

       inputIgst += igst;
       inputCgst += cgst;
       inputSgst += sgst;

       // Also add to expenses list for visibility in ledger if needed (Optional)
       // For now, these are handled by PurchasesListScreen, but TaxLedger shows details.
       // TaxLedger uses 'expenses' list for purchase ledger view.
       expenses.add(ExpenseModel(
         id: json['purchase_id'],
         title: 'Inventory Purchase: ${json['supplier_name']}',
         category: 'Inventory Purchase',
         amount: subtotal + tax,
         notes: 'Purchase: ${json['supplier_name']} (${json['invoice_number'] ?? ""})',
         date: DateTime.parse(json['date']),
         isItcEligible: true,
         taxAmount: tax,
         taxType: igst > 0 ? 'IGST' : 'CGST_SGST',
         tenantId: json['tenant_id'],
         supplierGstNumber: json['supplier_gstin'],
         invoiceNumber: json['invoice_number'],
       ));
    }
    
    expenses.sort((a, b) => b.date.compareTo(a.date));


    // --- 3. NET PAYABLE ---
    final netPayable = totalOutputTax - totalInputTax;


    return TaxReportData(
      totalTaxable: totalTaxable,
      totalOutputTax: totalOutputTax,
      totalInvoiceValue: totalInvoice,
      bills: bills,
      totalInputTax: totalInputTax,
      netPayable: netPayable,
      outputIgst: outputIgst,
      outputCgst: outputCgst,
      outputSgst: outputSgst,
      inputIgst: inputIgst,
      inputCgst: inputCgst,
      inputSgst: inputSgst,
      expenses: expenses,
      stateWiseSales: stateWiseSales,
    );
  }

  // Generate GSTR-1 Style Excel Report
  List<int> generateDetailedExcel(TaxReportData data, String period) {
    var excel = Excel.createExcel();
    // Rename default sheet
    excel.rename('Sheet1', 'Outward Supplies (Sales)');
    Sheet sheet = excel['Outward Supplies (Sales)'];
    
    // Define Styles
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

    CellStyle totalStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFEB3B'), // Yellow
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Title
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('N1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('GST Ledger Report - $period');
    titleCell.cellStyle = CellStyle(
      bold: true, 
      fontSize: 14, 
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Headers
    List<String> headers = [
      'Date', 
      'Invoice No', 
      'Customer', 
      'GSTIN', 
      'Place of Supply',
      'Taxable Value', 
      'CGST Rate', 
      'CGST Amount', 
      'SGST Rate', 
      'SGST Amount', 
      'IGST Rate', 
      'IGST Amount', 
      'Total Tax', 
      'Total Invoice Value'
    ];
    
    // Append Header Row (Row 1)
    sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());
    
    // Apply Header Style
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.cellStyle = headerStyle;
    }

    // Data Rows
    for (int i = 0; i < data.bills.length; i++) {
       var bill = data.bills[i];
       double rate = bill.taxPercentage;
       double taxable = bill.price;

       List<CellValue> rowData = [
         TextCellValue(DateFormat('dd-MM-yyyy').format(bill.billDate)),
         TextCellValue(bill.invoiceNumber),
         TextCellValue(bill.customerName),
         TextCellValue(bill.gstNumber ?? ''),
         TextCellValue(bill.placeOfSupply),
         DoubleCellValue(taxable),
         TextCellValue(bill.cgstAmount != 0 ? '${(rate/2).toStringAsFixed(1)}%' : '0%'),
         DoubleCellValue(bill.cgstAmount),
         TextCellValue(bill.sgstAmount != 0 ? '${(rate/2).toStringAsFixed(1)}%' : '0%'),
         DoubleCellValue(bill.sgstAmount),
         TextCellValue(bill.igstAmount != 0 ? '${rate.toStringAsFixed(0)}%' : '0%'),
         DoubleCellValue(bill.igstAmount),
         DoubleCellValue(bill.taxAmount),
         DoubleCellValue(bill.totalAmount),
       ];

       sheet.appendRow(rowData);

       // Apply Row Style (Row index start at 2)
       CellStyle currentStyle = (i % 2 == 0) ? rowStyleOdd : rowStyleEven;
       for (int col = 0; col < rowData.length; col++) {
         var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 2));
         cell.cellStyle = currentStyle;
       }
    }

    // Totals Row
    List<CellValue> totalRow = [
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(data.totalTaxable),
      TextCellValue(''),
      DoubleCellValue(data.bills.fold(0, (sum, b) => sum + b.cgstAmount)),
      TextCellValue(''),
      DoubleCellValue(data.bills.fold(0, (sum, b) => sum + b.sgstAmount)),
      TextCellValue(''),
      DoubleCellValue(data.bills.fold(0, (sum, b) => sum + b.igstAmount)),
      DoubleCellValue(data.totalOutputTax),
      DoubleCellValue(data.totalInvoiceValue),
    ];
    
    sheet.appendRow(totalRow);

    // Apply Total Style
    for (int col = 0; col < totalRow.length; col++) {
       var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: data.bills.length + 2));
       cell.cellStyle = totalStyle;
    }

    // Auto-fit widths (Manual approximation)
    sheet.setColumnWidth(0, 15); // Date
    sheet.setColumnWidth(1, 15); // Invoice
    sheet.setColumnWidth(2, 25); // Customer
    sheet.setColumnWidth(3, 18); // GSTIN
    sheet.setColumnWidth(4, 15); // Place
    sheet.setColumnWidth(5, 15); // Taxable

    // --- 2. INWARD SUPPLIES (ITC) SHEET ---
    final itcSheet = excel['Inward Supplies (ITC)'];
    
    // Headers for ITC
    List<String> itcHeaders = [
      'Date', 
      'Invoice No', 
      'Supplier', 
      'Supplier GSTIN', 
      'Category',
      'Taxable Value', 
      'Tax Type', 
      'Tax Amount', 
      'Total Value'
    ];
    
    itcSheet.appendRow(itcHeaders.map((e) => TextCellValue(e)).toList());
    for (int i = 0; i < itcHeaders.length; i++) {
      var cell = itcSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    // Data Rows for ITC
    final eligibleExpenses = data.expenses.where((e) => e.isItcEligible).toList();
    for (int i = 0; i < eligibleExpenses.length; i++) {
        var exp = eligibleExpenses[i];
        double taxableValue = exp.amount - exp.taxAmount;

        List<CellValue> rowData = [
          TextCellValue(DateFormat('dd-MM-yyyy').format(exp.date)),
          TextCellValue(exp.invoiceNumber ?? ''),
          TextCellValue(exp.title),
          TextCellValue(exp.supplierGstNumber ?? ''),
          TextCellValue(exp.category),
          DoubleCellValue(taxableValue),
          TextCellValue(exp.taxType ?? ''),
          DoubleCellValue(exp.taxAmount),
          DoubleCellValue(exp.amount),
        ];

        itcSheet.appendRow(rowData);
        CellStyle currentStyle = (i % 2 == 0) ? rowStyleOdd : rowStyleEven;
        for (int col = 0; col < rowData.length; col++) {
          var cell = itcSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 1));
          cell.cellStyle = currentStyle;
        }
    }

    // Totals for ITC
    List<CellValue> itcTotalRow = [
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(eligibleExpenses.fold(0, (sum, e) => sum + (e.amount - e.taxAmount))),
      TextCellValue(''),
      DoubleCellValue(data.totalInputTax),
      DoubleCellValue(eligibleExpenses.fold(0, (sum, e) => sum + e.amount)),
    ];
    itcSheet.appendRow(itcTotalRow);
    for (int col = 0; col < itcTotalRow.length; col++) {
       var cell = itcSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: eligibleExpenses.length + 1));
       cell.cellStyle = totalStyle;
    }

    for (int i = 0; i < itcHeaders.length; i++) {
       itcSheet.setColumnWidth(i, 20);
    }


    // --- 3. SUMMARY SHEET ---
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('GST Summary Report'), TextCellValue(period)]);
    summarySheet.appendRow([TextCellValue('Head'), TextCellValue('Value')]);
    summarySheet.appendRow([TextCellValue('Total Output Tax (Liability)'), DoubleCellValue(data.totalOutputTax)]);
    summarySheet.appendRow([TextCellValue('Total Input Tax (ITC)'), DoubleCellValue(data.totalInputTax)]);
    summarySheet.appendRow([TextCellValue('Net Tax Payable'), DoubleCellValue(data.netPayable)]);
    
    // SAVE & PATCH METADATA
    List<int>? fileBytes = excel.encode();
    
    if (fileBytes != null) {
      try {
         final archive = ZipDecoder().decodeBytes(fileBytes);
         final newArchive = Archive();

         for (final file in archive) {
            if (file.name == 'docProps/core.xml') {
               String content = String.fromCharCodes(file.content);
               content = content.replaceAll('Flutter Excel', 'GST Report $period');
               content = content.replaceAll('<dc:creator>Flutter</dc:creator>', '<dc:creator>DigiInvi</dc:creator>');
               content = content.replaceAll('Flutter', 'DigiInvi'); 
               newArchive.addFile(ArchiveFile(file.name, content.length, content.codeUnits));
            } else {
               newArchive.addFile(file);
            }
         }
         return ZipEncoder().encode(newArchive) ?? [];
      } catch (e) {
         debugPrint('Error patching Excel metadata: $e');
         return fileBytes;
      }
    }
    
    return fileBytes ?? [];
  }
}

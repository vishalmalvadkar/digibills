import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';
import 'auth_service.dart'; // To get tenantId

enum ReportType { income, expense, receivables, pnl, gstr1, gstr3b }
enum ExportFormat { csv, excel } // PDF handled separately

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // --- DATA FETCHING ---

  Future<List<BillModel>> fetchIncome(DateTime start, DateTime end) async {
    final tenantId = _authService.currentTenantId;
    
    // 1. Fetch Bills
    final billsData = await _supabase
        .from('bills')
        .select('*, bill_items(*)')
        .eq('tenant_id', tenantId)
        .gte('bill_date', start.toIso8601String())
        .lte('bill_date', end.toIso8601String())
        .order('bill_date', ascending: false);
        
    final bills = (billsData as List).map((json) => BillModel.fromMap(json)).toList();

    // 2. Fetch Credit Notes
    final notesData = await _supabase
        .from('credit_notes')
        .select()
        .eq('tenant_id', tenantId)
        .gte('return_date', start.toIso8601String())
        .lte('return_date', end.toIso8601String())
        .order('return_date', ascending: false);

    // 3. Convert Notes to "Negative Bills" for display
    final returns = (notesData as List).map((json) {
       // Map CN fields to Bill fields
       return BillModel(
         billId: json['id'],
         customerName: 'Return: ${json['credit_note_number']}', // Distinguish visual
         clientId: json['client_id'],
         serviceName: json['reason'] ?? 'Sales Return',
         billDate: DateTime.parse(json['return_date']),
         price: -(json['subtotal'] ?? 0).toDouble(), // Negative
         taxPercentage: 0, // Complex to map back, leave 0 or calculate?
         taxAmount: -(json['tax_amount'] ?? 0).toDouble(), // Negative
         cgstAmount: -(json['cgst_amount'] ?? 0).toDouble(), // Negative
         sgstAmount: -(json['sgst_amount'] ?? 0).toDouble(), // Negative
         igstAmount: -(json['igst_amount'] ?? 0).toDouble(), // Negative
         advanceAmount: 0,
         totalAmount: -(json['total_amount'] ?? 0).toDouble(), // Negative
         paymentStatus: 'Returned',
         paymentReceivedDate: DateTime.parse(json['return_date']),
         whatsappNumber: '',
         createdAt: DateTime.parse(json['created_at']),
         clientAddress: '',
         invoiceNumber: json['credit_note_number'], // Show CN# as Invoice#
         items: [], // Details not needed for list view
         payments: [],
         tenantId: json['tenant_id'],
         placeOfSupply: '',
         gstNumber: '',
       );
    }).toList();

    // 4. Merge & Sort
    final all = [...bills, ...returns];
    all.sort((a, b) => b.billDate.compareTo(a.billDate));
    
    return all;
  }

  Future<List<ExpenseModel>> fetchExpenses(DateTime start, DateTime end) async {
    final tenantId = _authService.currentTenantId;

    // 1. Fetch from Expenses Table
    final expenseData = await _supabase
        .from('expenses')
        .select()
        .eq('tenant_id', tenantId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String());
        
    final expenses = (expenseData as List).map((json) => ExpenseModel.fromMap(json)).toList();

    // 2. Fetch from Purchases Table
    final purchaseData = await _supabase
        .from('purchases')
        .select()
        .eq('tenant_id', tenantId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String());

    final purchaseExpenses = (purchaseData as List).map((json) {
       final subtotal = (json['subtotal'] as num?)?.toDouble() ?? 0;
       final tax = (json['tax_amount'] as num?)?.toDouble() ?? 0;
       final igst = (json['igst'] as num?)?.toDouble() ?? 0;

       return ExpenseModel(
         id: json['purchase_id'],
         title: 'Inventory Purchase: ${json['supplier_name']}',
         category: 'Inventory Purchase',
         amount: subtotal + tax,
         notes: 'Purchase Inv: ${json['invoice_number'] ?? ""}',
         date: DateTime.parse(json['date']),
         isItcEligible: true,
         taxAmount: tax,
         taxType: igst > 0 ? 'IGST' : 'CGST_SGST',
         tenantId: json['tenant_id'],
         supplierGstNumber: json['supplier_gstin'],
         invoiceNumber: json['invoice_number'],
       );
    }).toList();

    // 3. Merge & Sort
    final all = [...expenses, ...purchaseExpenses];
    all.sort((a, b) => b.date.compareTo(a.date));
    
    return all;
  }

  Future<List<BillModel>> fetchReceivables() async {
     final tenantId = _authService.currentTenantId;
     
     // Fetch pending/partial bills
     // We can use 'in' filter for status
     final data = await _supabase
        .from('bills')
        .select()
        .eq('tenant_id', tenantId)
        .inFilter('payment_status', ['Pending', 'Partial']);
        
     // Note: .inFilter might be named .in_() in some SDK versions, check references. 
     // Standard is .filter('col', 'in', '(a,b)'), or shortcut .inFilter().
     // checking SDK: .inFilter('column', [val1, val2]) is correct for v1/v2 mapping usually.
     // If not available, we filter client side or use 'or'.
     
     return (data as List).map((json) => BillModel.fromMap(json)).toList();
  }

  // --- GENERATORS ---

  List<int> generateCsv(List<dynamic> data, ReportType type) {
    List<List<dynamic>> rows = [];
    
    // Headers
    if (type == ReportType.income || type == ReportType.receivables) {
      rows.add(['Date', 'Invoice #', 'Customer', 'Amount', 'Tax', 'Total', 'Status']);
      for (var item in data as List<BillModel>) {
        rows.add([
          DateFormat('yyyy-MM-dd').format(item.billDate),
          item.invoiceNumber,
          item.customerName,
          item.price,
          item.taxAmount,
          item.totalAmount,
          item.paymentStatus
        ]);
      }
    } else if (type == ReportType.expense) {
      rows.add(['Date', 'Category', 'Title', 'Amount', 'Notes']);
      for (var item in data as List<ExpenseModel>) {
        rows.add([
          DateFormat('yyyy-MM-dd').format(item.date),
          item.category,
          item.title,
          item.amount,
          item.notes ?? ''
        ]);
      }
    }

    String csv = const ListToCsvConverter().convert(rows);
    return csv.codeUnits;
  }

  List<int> generateExcel(List<dynamic> data, ReportType type) {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    // Headers
    List<String> headers = [];
    if (type == ReportType.income || type == ReportType.receivables) {
      headers = ['Date', 'Invoice #', 'Customer', 'Amount', 'Tax', 'Total', 'Status'];
    } else if (type == ReportType.expense) {
      headers = ['Date', 'Category', 'Title', 'Amount', 'Notes'];
    }
    
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // Define Header Style
    CellStyle headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'), // Dark Blue
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Apply Header Style
    for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = headerStyle;
    }

    // Rows
    if (type == ReportType.income || type == ReportType.receivables) {
      for (var item in data as List<BillModel>) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(item.billDate)),
          TextCellValue(item.invoiceNumber),
          TextCellValue(item.customerName),
          DoubleCellValue(item.price),
          DoubleCellValue(item.taxAmount),
          DoubleCellValue(item.totalAmount),
          TextCellValue(item.paymentStatus),
        ]);
      }
    } else if (type == ReportType.expense) {
      for (var item in data as List<ExpenseModel>) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(item.date)),
          TextCellValue(item.category),
          TextCellValue(item.title),
          DoubleCellValue(item.amount),
          TextCellValue(item.notes ?? ''),
        ]);
      }
    }

    // Auto-fit widths approx
    for (int i = 0; i < headers.length; i++) {
       sheetObject.setColumnWidth(i, 20);
    }

    return excel.encode() ?? [];
  }



  // --- CALCULATIONS ---

  Future<Map<String, double>> calculateIncomeTax(DateTime start, DateTime end) async {
    // 1. Fetch Income
    final incomeList = await fetchIncome(start, end);
    double totalIncome = incomeList.fold(0, (sum, item) {
       // Only count actual sales, subtract returns if beneficial, 
       // but typically fetchIncome returns merged list. 
       // For tax, we want Net Sales (Sales - Sales Return).
       // Our fetchIncome already returns bills and credit notes (negative amounts).
       return sum + item.price; // Use price (taxable value) NOT totalAmount (which includes GST)
    });

    // 2. Fetch Expenses
    final expenseList = await fetchExpenses(start, end);
    double totalExpense = expenseList.fold(0, (sum, item) => sum + item.amount);

    // 3. Net Profit
    double netProfit = totalIncome - totalExpense;

    // 4. Estimate Tax (Old Regime Simplification)
    // 0 - 2.5L : 0%
    // 2.5L - 5L : 5%
    // 5L - 10L : 20%
    // > 10L : 30%
    // Rebate u/s 87A: If income <= 5L, tax is 0.
    
    double tax = 0;
    double taxable = netProfit > 0 ? netProfit : 0;
    
    if (taxable <= 250000) {
      tax = 0;
    } else if (taxable <= 500000) {
      tax = (taxable - 250000) * 0.05;
    } else if (taxable <= 1000000) {
      tax = (250000 * 0.05) + ((taxable - 500000) * 0.20);
    } else {
      tax = (250000 * 0.05) + (500000 * 0.20) + ((taxable - 1000000) * 0.30);
    }

    // 87A Rebate
    if (taxable <= 500000) {
      tax = 0;
    }
    
    // Cess 4%
    if (tax > 0) {
      tax += tax * 0.04;
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'netProfit': netProfit,
      'estimatedTax': tax
    };
  }
}

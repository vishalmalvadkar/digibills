import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';
import 'report_service.dart';
import 'settings_service.dart';

class GSTRService {
  final ReportService _reportService = ReportService();
  final SettingsService _settingsService = SettingsService();

  // Generate GSTR-1 Excel
  Future<List<int>?> generateGSTR1(DateTime startDate, DateTime endDate) async {
    final bills = await _reportService.fetchIncome(startDate, endDate);
    final settings = await _settingsService.fetchSettings();
    final tenantState = settings.state.toLowerCase().trim();

    // Sort bills by date
    bills.sort((a, b) => a.billDate.compareTo(b.billDate));

    final excel = Excel.createExcel();

    // 1. B2B Sheet (Registered Customers)
    _createB2BSheet(excel, bills, tenantState, settings.defaultGstRate);

    // 2. B2C Large (Inter-state > 2.5L)
    _createB2CLSheet(excel, bills, tenantState, settings.defaultGstRate);

    // 3. B2C Small (Others)
    _createB2CSSheet(excel, bills, tenantState, settings.defaultGstRate);

    // 4. HSN Summary
    _createHSNSheet(excel, bills, tenantState, settings.defaultGstRate);

    // Remove default sheet
    if (excel.tables.keys.contains('Sheet1')) {
      excel.delete('Sheet1');
    }

    return excel.encode();
  }

  void _createB2BSheet(Excel excel, List<BillModel> bills, String tenantState, double defaultRate) {
    final sheet = excel['B2B'];
    sheet.appendRow([
      'GSTIN/UIN of Recipient', 'Receiver Name', 'Invoice Number', 'Invoice Date', 
      'Invoice Value', 'Place Of Supply', 'Reverse Charge', 
      'Invoice Type', 'E-Commerce GSTIN', 'Rate', 'Taxable Value', 'Cess Amount'
    ].map((e) => TextCellValue(e)).toList());

    for (var bill in bills) {
      if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty) {
         // Registered Receiver -> B2B
         final isInterState = _isInterState(bill.placeOfSupply, tenantState);
         
         // Aggregate items by Rate (Simplified: Assuming Bill Level aggregation or Single Rate for now)
         // To do it properly, we should iterate items.
         for (var item in bill.items) {
           final rate = defaultRate; // TODO: Item level rate if available
           final values = _calculateTaxValues(item.amount, rate);

           sheet.appendRow([
             TextCellValue(bill.gstNumber!), 
             TextCellValue(bill.customerName),
             TextCellValue(bill.invoiceNumber),
             TextCellValue(DateFormat('dd-MM-yyyy').format(bill.billDate)),
             DoubleCellValue(bill.totalAmount),
             TextCellValue(bill.placeOfSupply),
             TextCellValue('N'), // Reverse Charge
             TextCellValue('Regular'), // Invoice Type
             TextCellValue(''), // E-Commerce
             DoubleCellValue(rate), 
             DoubleCellValue(values['taxable']!), 
             DoubleCellValue(0.0) // Cess
           ]);
         }
      }
    }
  }

  void _createB2CLSheet(Excel excel, List<BillModel> bills, String tenantState, double defaultRate) {
     final sheet = excel['B2CL'];
     sheet.appendRow([
       'Invoice Number', 'Invoice Date', 'Invoice Value', 'Place Of Supply', 
       'Rate', 'Taxable Value', 'Cess Amount', 'E-Commerce GSTIN'
     ].map((e) => TextCellValue(e)).toList());

     for (var bill in bills) {
        if (bill.gstNumber == null || bill.gstNumber!.isEmpty) {
           final isInterState = _isInterState(bill.placeOfSupply, tenantState);
           if (isInterState && bill.totalAmount > 250000) {
              // B2C Large
              for (var item in bill.items) {
                 final rate = defaultRate; 
                 final values = _calculateTaxValues(item.amount, rate);

                 sheet.appendRow([
                   TextCellValue(bill.invoiceNumber),
                   TextCellValue(DateFormat('dd-MM-yyyy').format(bill.billDate)),
                   DoubleCellValue(bill.totalAmount),
                   TextCellValue(bill.placeOfSupply),
                   DoubleCellValue(rate),
                   DoubleCellValue(values['taxable']!),
                   DoubleCellValue(0.0),
                   TextCellValue('')
                 ]);
              }
           }
        }
     }
  }

  void _createB2CSSheet(Excel excel, List<BillModel> bills, String tenantState, double defaultRate) {
    final sheet = excel['B2CS'];
    sheet.appendRow([
      'Type', 'Place Of Supply', 'Rate', 'Taxable Value', 'Cess Amount', 'E-Commerce GSTIN'
    ].map((e) => TextCellValue(e)).toList());

    // B2CS Should likely be aggregated by POS and Rate.
    // Map<POS, Map<Rate, TaxableValue>>
    Map<String, Map<double, double>> b2csData = {};

    for (var bill in bills) {
      if (bill.gstNumber == null || bill.gstNumber!.isEmpty) {
         final isInterState = _isInterState(bill.placeOfSupply, tenantState);
         
         if (!isInterState || bill.totalAmount <= 250000) {
           // B2C Small
           final pos = bill.placeOfSupply.isEmpty ? tenantState : bill.placeOfSupply; // Default to local if empty

           for (var item in bill.items) {
              final rate = defaultRate;
              final values = _calculateTaxValues(item.amount, rate);
              
              if (!b2csData.containsKey(pos)) b2csData[pos] = {};
              if (!b2csData[pos]!.containsKey(rate)) b2csData[pos]![rate] = 0;
              
              b2csData[pos]![rate] = b2csData[pos]![rate]! + values['taxable']!;
           }
         }
      }
    }

    b2csData.forEach((pos, rates) {
       rates.forEach((rate, taxable) {
          sheet.appendRow([
            TextCellValue('OE'), 
            TextCellValue(pos),
            DoubleCellValue(rate),
            DoubleCellValue(taxable),
            DoubleCellValue(0.0),
            TextCellValue('')
          ]);
       });
    });
  }

  void _createHSNSheet(Excel excel, List<BillModel> bills, String tenantState, double defaultRate) {
    final sheet = excel['HSN'];
    sheet.appendRow([
      'HSN/SAC', 'Description', 'UQC', 'Total Quantity', 'Total Value', 
      'Taxable Value', 'Integrated Tax Amount', 'Central Tax Amount', 'State Tax Amount', 'Cess Amount'
    ].map((e) => TextCellValue(e)).toList());

    // Aggregate by HSN
    Map<String, Map<String, dynamic>> hsnMap = {};

    for (var bill in bills) {
      final isInterState = _isInterState(bill.placeOfSupply, tenantState);

      for (var item in bill.items) {
        if (item.hsnCode != null && item.hsnCode!.isNotEmpty) {
          final hsn = item.hsnCode!;
          if (!hsnMap.containsKey(hsn)) {
            hsnMap[hsn] = {
              'desc': item.description,
              'uqc': item.unit,
              'qty': 0.0,
              'val': 0.0, // Total Amount (inc tax)
              'taxable': 0.0,
              'igst': 0.0,
              'cgst': 0.0,
              'sgst': 0.0
            };
          }
          
          final rate = defaultRate;
          final values = _calculateTaxValues(item.amount, rate);

          hsnMap[hsn]!['qty'] += item.quantity;
          hsnMap[hsn]!['val'] += item.amount;
          hsnMap[hsn]!['taxable'] += values['taxable'];
          
          if (isInterState) {
             hsnMap[hsn]!['igst'] += values['tax'];
          } else {
             hsnMap[hsn]!['cgst'] += values['tax']! / 2;
             hsnMap[hsn]!['sgst'] += values['tax']! / 2;
          }
        }
      }
    }

    hsnMap.forEach((hsn, data) {
      sheet.appendRow([
        TextCellValue(hsn),
        TextCellValue(data['desc']),
        TextCellValue(data['uqc']),
        DoubleCellValue(data['qty']),
        DoubleCellValue(data['val']),
        DoubleCellValue(data['taxable']),
        DoubleCellValue(data['igst']),
        DoubleCellValue(data['cgst']),
        DoubleCellValue(data['sgst']),
        DoubleCellValue(0.0)
      ]);
    });
  }

  // Generate GSTR-3B Summary
  Future<Map<String, dynamic>> generateGSTR3B(DateTime startDate, DateTime endDate) async {
    final bills = await _reportService.fetchIncome(startDate, endDate);
    final expenses = await _reportService.fetchExpenses(startDate, endDate);
    final settings = await _settingsService.fetchSettings();
    final tenantState = settings.state.toLowerCase().trim();
    final defaultRate = settings.defaultGstRate;

    double outwardTaxable = 0;
    double outwardIgst = 0;
    double outwardCgst = 0;
    double outwardSgst = 0;

    double itcIgst = 0;
    double itcCgst = 0;
    double itcSgst = 0;

    // Outward Supplies (Sales)
    for (var bill in bills) {
       final isInterState = _isInterState(bill.placeOfSupply, tenantState);

       for (var item in bill.items) {
          // Calculate strictly from Item Amount (which is Total Inc Tax usually in this app context, OR we check logic)
          // App Logic: BillItem amount is line total. 
          final values = _calculateTaxValues(item.amount, defaultRate);
          
          outwardTaxable += values['taxable']!;
          
          if (isInterState) {
             outwardIgst += values['tax']!;
          } else {
             outwardCgst += values['tax']! / 2;
             outwardSgst += values['tax']! / 2;
          }
       }
    }

    // ITC (Purchases)
    for (var exp in expenses) {
      if (exp.isItcEligible) {
        if (exp.taxType == 'IGST') {
          itcIgst += exp.taxAmount;
        } else if (exp.taxType == 'CGST_SGST') {
          itcCgst += exp.taxAmount / 2;
          itcSgst += exp.taxAmount / 2;
        }
      }
    }

    return {
      'outward': {
        'taxable': outwardTaxable,
        'igst': outwardIgst,
        'cgst': outwardCgst,
        'sgst': outwardSgst,
        'total_tax': outwardIgst + outwardCgst + outwardSgst
      },
      'itc': {
        'igst': itcIgst,
        'cgst': itcCgst,
        'sgst': itcSgst,
        'total': itcIgst + itcCgst + itcSgst
      }
    };
  }

  // --- HELPERS ---

  bool _isInterState(String pos, String tenantState) {
    if (pos.isEmpty || tenantState.isEmpty) return false; // Default to Intra
    return pos.toLowerCase().trim() != tenantState;
  }

  Map<String, double> _calculateTaxValues(double totalAmount, double rate) {
    // Assuming totalAmount is Inclusive of Tax
    // Taxable = Total / (1 + Rate/100)
    double taxable = totalAmount / (1 + (rate / 100));
    double tax = totalAmount - taxable;
    return {'taxable': taxable, 'tax': tax};
  }
}

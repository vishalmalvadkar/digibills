import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/balance_sheet_model.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';
import 'auth_service.dart';

class BalanceSheetService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<BalanceSheetData> generateBalanceSheet(DateTime asOnDate) async {
    final tenantId = _authService.currentTenantId;
    
    // Filter cut-off to end of the selected day
    final cutoff = DateTime(asOnDate.year, asOnDate.month, asOnDate.day, 23, 59, 59);

    // 1. Fetch Bills (with Payments)
    // We query ALL bills for tenant. Optimization: Could limit by date but Balance Sheet is cumulative.
    // Fetching bill_payments relation is CRITICAL.
    final billsData = await _supabase
        .from('bills')
        .select('*, bill_payments(*)')
        .eq('tenant_id', tenantId);

    double totalInvoiced = 0;
    double totalTax = 0;
    double totalReceived = 0;

    for (var json in billsData) {
      final bill = BillModel.fromMap(json);
      if (bill.billDate.isAfter(cutoff)) continue;

      totalInvoiced += bill.totalAmount;
      totalTax += bill.taxAmount;

      // Calculate Amount Received up to cutoff
      if (bill.payments.isNotEmpty) {
        // Sum payments made before cutoff
        for (var payment in bill.payments) {
          if (payment.date.isBefore(cutoff) || payment.date.isAtSameMomentAs(cutoff)) {
            totalReceived += payment.amount;
          }
        }
      } else {
        // Fallback: Use advanceAmount if bill created <= cutoff
        if (bill.createdAt.isBefore(cutoff)) {
           totalReceived += bill.advanceAmount;
        }
      }
    }

    // 2. Fetch Expenses
    final expensesData = await _supabase
        .from('expenses')
        .select()
        .eq('tenant_id', tenantId);

    double totalExpense = 0;
    for (var json in expensesData) {
      final expense = ExpenseModel.fromMap(json);
      if (expense.date.isAfter(cutoff)) continue;
      
      totalExpense += expense.amount;
    }

    // 3. Calculate Components

    // REVENUE (Net)
    final double netRevenue = totalInvoiced - totalTax;

    // ASSETS
    // Cash = Money In - Money Out
    final double cashAndBank = totalReceived - totalExpense;
    // Receivables = Invoiced - Received
    final double accountsReceivable = totalInvoiced - totalReceived;
    
    final double totalAssets = cashAndBank + accountsReceivable;

    // LIABILITIES
    // GST Payable = Tax Collected
    final double gstPayable = totalTax;
    final double totalLiabilities = gstPayable;

    // EQUITY
    // Net Profit = Net Revenue - Expenses
    final double netProfit = netRevenue - totalExpense;
    final double totalEquity = netProfit;

    return BalanceSheetData(
      asOnDate: asOnDate,
      cashAndBank: cashAndBank,
      accountsReceivable: accountsReceivable,
      totalAssets: totalAssets,
      gstPayable: gstPayable,
      totalLiabilities: totalLiabilities,
      netProfit: netProfit,
      totalEquity: totalEquity,
    );
  }
}

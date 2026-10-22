import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';
import 'auth_service.dart';

class TrialBalanceEntry {
  final String accountName;
  final String group; // Asset, Liability, Income, Expense
  final double debit;
  final double credit;

  TrialBalanceEntry({
    required this.accountName,
    required this.group,
    this.debit = 0,
    this.credit = 0,
  });
}

class TrialBalanceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<List<TrialBalanceEntry>> fetchTrialBalance(DateTime start, DateTime end) async {
    final tenantId = _authService.currentTenantId;
    
    // Data fetching logic using tenantId

    // 1. Fetch Bills
    final billsData = await _supabase
        .from('bills')
        .select('*, bill_payments(*)')
        .eq('tenant_id', tenantId)
        .gte('bill_date', start.toIso8601String())
        .lte('bill_date', end.toIso8601String());

    double totalInvoiced = 0;
    double totalTax = 0;
    double totalReceived = 0;

    for (var json in billsData) {
      final bill = BillModel.fromMap(json);
      // Data already filtered by DB range

      totalInvoiced += bill.totalAmount;
      totalTax += bill.taxAmount;

      // Calculate Amount Received
      // Note: In Trial Balance for a period, strictly we should check when payment was received.
      // But for simplicity in this "One Click" context, we usually align with Balance Sheet logic.
      if (bill.payments.isNotEmpty) {
        for (var payment in bill.payments) {
           totalReceived += payment.amount;
        }
      } else {
         totalReceived += bill.advanceAmount;
      }
    }

    // 2. Fetch Expenses
    final expensesData = await _supabase
        .from('expenses')
        .select()
        .eq('tenant_id', tenantId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String());

    double totalExpense = 0;
    for (var json in expensesData) {
      final expense = ExpenseModel.fromMap(json);
      totalExpense += expense.amount;
    }

    // 3. Calculate Heads
    final double sales = totalInvoiced - totalTax; // Credit
    final double outputGst = totalTax; // Credit
    final double expenses = totalExpense; // Debit
    final double receivables = totalInvoiced - totalReceived; // Debit
    final double cashInHand = totalReceived - totalExpense; // Debit

    List<TrialBalanceEntry> ledger = [];

    // ASSETS (Debit)
    if (cashInHand >= 0) {
      ledger.add(TrialBalanceEntry(accountName: 'Cash & Bank', group: 'Current Assets', debit: cashInHand));
    } else {
      // Overdraft?
      ledger.add(TrialBalanceEntry(accountName: 'Cash & Bank (Overdraft)', group: 'Liability', credit: cashInHand.abs()));
    }

    ledger.add(TrialBalanceEntry(accountName: 'Accounts Receivable', group: 'Current Assets', debit: receivables));

    // EXPENSES (Debit)
    ledger.add(TrialBalanceEntry(accountName: 'Business Expenses', group: 'Expenses', debit: expenses));

    // INCOME (Credit)
    ledger.add(TrialBalanceEntry(accountName: 'Sales Account', group: 'Revenue', credit: sales));

    // LIABILITY (Credit)
    ledger.add(TrialBalanceEntry(accountName: 'GST Payable', group: 'Current Liabilities', credit: outputGst));

    return ledger;
  }
}

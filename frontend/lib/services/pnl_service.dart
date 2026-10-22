import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pnl_data_model.dart';
import '../models/annual_summary_model.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';
import 'auth_service.dart';

class PnLService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<PnLData> fetchPnL(DateTime start, DateTime end) async {
    final tenantId = _authService.currentTenantId;

    // 1. Fetch Income (Bills)
    // Filter by date range at DB level for efficiency
    final billsData = await _supabase
        .from('bills')
        .select()
        .eq('tenant_id', tenantId)
        .gte('bill_date', start.toIso8601String())
        .lte('bill_date', end.toIso8601String());

    double totalIncome = 0;
    for (var json in billsData) {
      final bill = BillModel.fromMap(json);
      totalIncome += bill.totalAmount;
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

    // 3. Fetch Purchases (as Expense)
    final purchasesData = await _supabase
        .from('purchases')
        .select('total_amount')
        .eq('tenant_id', tenantId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String());

    for (var json in purchasesData) {
      totalExpense += (json['total_amount'] as num?)?.toDouble() ?? 0;
    }

    return PnLData(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netProfit: totalIncome - totalExpense,
      date: start,
    );
  }

  Future<AnnualSummary> fetchAnnualSummary(int year) async {
    final tenantId = _authService.currentTenantId;
    final startOfYear = DateTime(year, 1, 1).toIso8601String();
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59).toIso8601String();

    // 1. Fetch ALL data for the year
    final billsData = await _supabase
        .from('bills')
        .select()
        .eq('tenant_id', tenantId)
        .gte('bill_date', startOfYear)
        .lte('bill_date', endOfYear);
    
    final expensesData = await _supabase
        .from('expenses')
        .select()
        .eq('tenant_id', tenantId)
        .gte('date', startOfYear)
        .lte('date', endOfYear);

    final purchasesData = await _supabase
        .from('purchases')
        .select('date, total_amount')
        .eq('tenant_id', tenantId)
        .gte('date', startOfYear)
        .lte('date', endOfYear);

    // 2. Bucketing by Month
    List<MonthlyPnLData> monthlyData = [];
    double yearIncome = 0;
    double yearExpense = 0;

    for (int month = 1; month <= 12; month++) {
      double mIncome = 0;
      double mExpense = 0;

      // Filter Bills
      for (var json in billsData) {
        final bill = BillModel.fromMap(json);
        if (bill.billDate.month == month) {
          mIncome += bill.totalAmount;
        }
      }

      // Filter Expenses
      for (var json in expensesData) {
        final expense = ExpenseModel.fromMap(json);
        if (expense.date.month == month) {
          mExpense += expense.amount;
        }
      }

      // Filter Purchases
      for (var json in purchasesData) {
        final date = DateTime.parse(json['date']);
        if (date.month == month) {
          mExpense += (json['total_amount'] as num?)?.toDouble() ?? 0;
        }
      }

      monthlyData.add(MonthlyPnLData(
        month: month,
        income: mIncome,
        expense: mExpense,
        profit: mIncome - mExpense,
      ));

      yearIncome += mIncome;
      yearExpense += mExpense;
    }

    return AnnualSummary(
      year: year,
      totalIncome: yearIncome,
      totalExpense: yearExpense,
      netProfit: yearIncome - yearExpense,
      monthlyData: monthlyData,
    );
  }
}

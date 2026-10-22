import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bill_model.dart';
import '../models/client_receivable_model.dart';
import 'auth_service.dart';

class ReceivablesService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<List<ClientReceivableModel>> fetchReceivables() async {
    final tenantId = _authService.currentTenantId;

    // 1. Fetch all Pending Bills
    // We filter by payment_status != 'Paid' (Pending or Partial)
    // Note: 'Pending' in legacy code generally means anything not fully paid.
    // Based on previous files, 'Paid' is the completion status.
    final response = await _supabase
        .from('bills')
        .select()
        .eq('tenant_id', tenantId)
        .neq('payment_status', 'Paid');

    if (response.isEmpty) return [];

    // 2. Aggregate Data locally
    final Map<String, List<BillModel>> groupedBills = {};

    for (var json in response) {
      final bill = BillModel.fromMap(json);
      final key = bill.clientId.isNotEmpty ? bill.clientId : bill.customerName; // Fallback to name if ID missing
      
      if (!groupedBills.containsKey(key)) {
        groupedBills[key] = [];
      }
      groupedBills[key]!.add(bill);
    }

    // 3. Create Models
    final List<ClientReceivableModel> receivables = [];
    final now = DateTime.now();

    groupedBills.forEach((key, bills) {
      double total = 0;
      DateTime? oldestDate;
      String name = bills.first.customerName; // Default name from first bill
      String id = bills.first.clientId;

      for (var bill in bills) {
        // Calculate pending amount: Total - Advance (if any)
        // If paymentStatus is Partial, advanceAmount holds what's paid? 
        // Or logic in AccountSummary was (Total - Advance). Let's stick to that.
        // Legacy code used `bill.totalAmount` for totalPending? 
        // Line 44: `total += bill.totalAmount;`
        // This implies legacy didn't account for partial payments in the aggregation sum?
        // Wait, Receivables usually cares about what is LEFT to pay.
        // If I have a bill of 1000, and paid 200 (Partial), receivable is 800.
        // If legacy code just summed totalAmount, it was arguably "Total Value of Pending Bills" vs "Total Receivable Amount".
        // Use (Total - Advance) to be more accurate.
        total += (bill.totalAmount - bill.advanceAmount);

        if (oldestDate == null || bill.billDate.isBefore(oldestDate)) {
          oldestDate = bill.billDate;
        }
      }

      final overdueDuration = now.difference(oldestDate!).inDays;

      receivables.add(ClientReceivableModel(
        clientName: name,
        clientId: id,
        totalPending: total,
        billCount: bills.length,
        oldestBillDate: oldestDate,
        overdueDays: overdueDuration,
      ));
    });

    return receivables;
  }
}

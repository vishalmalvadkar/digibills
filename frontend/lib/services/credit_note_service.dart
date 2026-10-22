import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/credit_note_model.dart';
import 'auth_service.dart';
import 'product_service.dart';
import 'package:uuid/uuid.dart';

class CreditNoteService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();
  final ProductService _productService = ProductService();

  // Create Credit Note
  Future<void> createCreditNote(CreditNoteModel note) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final noteData = note.toMap();
    // Default ID if missing
    if (note.id.isEmpty) noteData['id'] = const Uuid().v4();

    noteData['tenant_id'] = await _authService.getEffectiveTenantId();
    noteData['created_by'] = user.id;
    
    noteData.remove('credit_note_items'); // Insert separately

    // 2. Insert Header
    final response = await _supabase
        .from('credit_notes')
        .insert(noteData)
        .select()
        .single();
    
    final newId = response['id'] as String;

    // 3. Insert Items
    if (note.items.isNotEmpty) {
      final itemsData = note.items.map((item) {
        final map = item.toMap();
        map['credit_note_id'] = newId;
        map['tenant_id'] = noteData['tenant_id'];
        map.remove('id');
        return map;
      }).toList();
      
      await _supabase.from('credit_note_items').insert(itemsData);

      // 4. Update Inventory (Increment Stock)
      for (var item in note.items) {
        if (item.productId != null && item.productId!.isNotEmpty) {
           // Increment stock because items are returned
           await _productService.updateStock(item.productId!, item.quantity);
        }
      }
    }

    // 5. Update Bill Return Amount & Status
    await _updateBillAfterReturn(note.billId);
  }

  // Helper to recalculate bill status
  Future<void> _updateBillAfterReturn(String billId) async {
    // 1. Calculate Total Returned Amount for this Bill
    final result = await _supabase
        .from('credit_notes')
        .select('total_amount')
        .eq('bill_id', billId);
    
    double totalReturned = 0;
    for (var r in result) {
      totalReturned += (r['total_amount'] as num).toDouble();
    }

    // 2. Check Bill Totals
    final bill = await _supabase.from('bills').select('total_amount, advance_amount').eq('bill_id', billId).single();
    final billTotal = (bill['total_amount'] as num).toDouble();
    final paidAmount = (bill['advance_amount'] as num).toDouble();

    final netPayable = billTotal - totalReturned;
    
    // 3. Determine New Status
    String newStatus = 'Pending';
    if (paidAmount >= netPayable && netPayable >= 0) {
      newStatus = 'Paid';
    } else if (paidAmount > 0) {
      newStatus = 'Partial';
    }
    
    // 4. Update Bill
    await _supabase.from('bills').update({
       'return_amount': totalReturned,
       'payment_status': newStatus
    }).eq('bill_id', billId);
  }

  // Fetch Returns by Bill ID
  Future<List<CreditNoteModel>> getCreditNotesForBill(String billId) async {
    final data = await _supabase
        .from('credit_notes')
        .select('*, credit_note_items(*)')
        .eq('bill_id', billId)
        .order('created_at', ascending: false);
        
    return (data as List).map((json) => CreditNoteModel.fromMap(json)).toList();
  }

  // Fetch All Returns for Tenant
  Stream<List<CreditNoteModel>> streamCreditNotes({String? clientId}) {
    final tenantId = _supabase.auth.currentUser?.id ?? '';
    
    return _supabase
        .from('credit_notes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final notes = data.map((e) => CreditNoteModel.fromMap(e)).toList();
          return notes.where((note) {
            final matchesTenant = note.tenantId == tenantId;
            final matchesClient = clientId == null || clientId.isEmpty || note.clientId == clientId;
            return matchesTenant && matchesClient;
          }).toList();
        });
  }
}

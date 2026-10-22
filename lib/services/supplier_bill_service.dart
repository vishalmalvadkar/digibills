import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier_bill_model.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

import 'dart:io'; // NEW

class SupplierBillService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Upload Bill Image
  Future<String?> uploadBillImage(File imageFile) async {
    try {
      final userId = _supabase.auth.currentUser?.id ?? 'unknown';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';
      
      // Upload to "supplier_bills" bucket
      await _supabase.storage.from('supplier_bills').upload(path, imageFile);
      
      // Get Public URL
      final publicUrl = _supabase.storage.from('supplier_bills').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Upload Error: $e');
      // Fallback: If bucket doesn't exist or permission denied, return null to avoid crash
      return null;
    }
  }

  // Create Supplier Bill
  Future<void> addBill(SupplierBillModel bill) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final String finalBillId = bill.id.isEmpty ? const Uuid().v4() : bill.id;
    final effectiveTenantId = await _authService.getEffectiveTenantId();
    
    // Prepare Data
    final billData = bill.toMap();
    billData['id'] = finalBillId; // Fix: Use 'id' match model
    billData['tenant_id'] = effectiveTenantId;
    // billData['created_by'] = user.id; // REMOVED: Column does not exist in DB
    
    billData.remove('items'); 

    // Insert Header
    await _supabase.from('supplier_bills').insert(billData);

    // Insert Items
    if (bill.items.isNotEmpty) {
      final itemsData = bill.items.map((item) {
        final map = item.toMap();
        map['id'] = item.id ?? const Uuid().v4();
        map['bill_id'] = finalBillId;
        map['tenant_id'] = effectiveTenantId;
        return map;
      }).toList();
      
      await _supabase.from('supplier_bill_items').insert(itemsData);
    }
  }

  // Update Supplier Bill
  Future<void> updateBill(SupplierBillModel bill) async {
    await _supabase
        .from('supplier_bills')
        .update(bill.toMap())
        .eq('id', bill.id); // Fix: Use 'id'
  }

  // Delete Supplier Bill
  Future<void> deleteBill(String id) async {
    await _supabase.from('supplier_bills').delete().eq('id', id); // Fix: Use 'id'
  }

  // Stream Bills (Standard)
  Stream<List<SupplierBillModel>> streamBills() {
    final String tId = _authService.currentTenantId;
    if (tId.isEmpty) return Stream.value([]);
    
    return _supabase
        .from('supplier_bills')
        .stream(primaryKey: ['id']) // Fix: Use 'id'
        .eq('tenant_id', tId)
        .order('date', ascending: false)
        .map((data) => data.map((json) => SupplierBillModel.fromMap(json)).toList());
  }

  // Fetch single bill with items
  Future<SupplierBillModel?> getBillById(String billId) async {
      final response = await _supabase
          .from('supplier_bills')
          .select('*, supplier_bill_items(*)')
          .eq('id', billId) // Fix: Use 'id'
          .single();
      
      return SupplierBillModel.fromMap(response);
  }

  // Fetch Bills for a specific period
  Future<List<SupplierBillModel>> fetchBillsByDateRange(DateTime start, DateTime end) async {
    final String tId = _authService.currentTenantId;
    final response = await _supabase
        .from('supplier_bills')
        .select()
        .eq('tenant_id', tId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String())
        .order('date', ascending: false);

    return (response as List).map((e) => SupplierBillModel.fromMap(e)).toList();
  }
}

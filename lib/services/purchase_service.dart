import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase_model.dart';
import 'auth_service.dart';

class PurchasesService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<PurchaseModel?> getPurchaseById(String id) async {
    final response = await _supabase
        .from('purchases')
        .select('*, purchase_items(*)')
        .eq('purchase_id', id)
        .single();
    
    if (response == null) return null;

    final items = (response['purchase_items'] as List)
        .map((i) => PurchaseItem.fromMap(i))
        .toList();
    return PurchaseModel.fromMap(response, items);
  }

  Future<void> addPurchase(PurchaseModel purchase) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final tenantId = await _authService.getEffectiveTenantId();
    
    // 1. Insert Purchase Header
    final purchaseMap = purchase.toMap();
    purchaseMap['tenant_id'] = tenantId;
    
    final response = await _supabase
        .from('purchases')
        .insert(purchaseMap)
        .select()
        .single();
    
    final String purchaseId = response['purchase_id'];

    // 2. Insert Purchase Items
    if (purchase.items.isNotEmpty) {
      final itemsData = purchase.items.map((item) {
        final map = item.toMap();
        map['purchase_id'] = purchaseId;
        return map;
      }).toList();

      await _supabase.from('purchase_items').insert(itemsData);
    }
  }

  Future<List<PurchaseModel>> getPurchases() async {
    final tenantId = await _authService.getEffectiveTenantId();
    
    final response = await _supabase
        .from('purchases')
        .select('*, purchase_items(*)')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    
    return (response as List).map((data) {
      final items = (data['purchase_items'] as List)
          .map((i) => PurchaseItem.fromMap(i))
          .toList();
      return PurchaseModel.fromMap(data, items);
    }).toList();
  }

  Future<void> deletePurchase(String id) async {
    await _supabase.from('purchases').delete().eq('purchase_id', id);
  }
}

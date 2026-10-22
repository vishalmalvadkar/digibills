import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase_order_model.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

class PurchaseOrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<PurchaseOrderModel>> getPOsStream() {
    final tenantId = AuthService().currentTenantId;
    if (tenantId.isEmpty) return Stream.value([]); 

    return _supabase
        .from('purchase_orders')
        .stream(primaryKey: ['po_id'])
        .eq('tenant_id', tenantId)
        .order('date', ascending: false)
        .map((data) => data.map((e) => PurchaseOrderModel.fromMap(e)).toList());
  }

  Future<void> addPO(PurchaseOrderModel po) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    final data = po.toMap();
    data['po_id'] = const Uuid().v4(); // Generate ID
    data['tenant_id'] = AuthService().currentTenantId;
    data['created_by'] = user.id;

    await _supabase.from('purchase_orders').insert(data);
  }

  Future<void> updateStatus(String poId, String status) async {
     await _supabase.from('purchase_orders').update({'status': status}).eq('po_id', poId);
  }

  Future<void> deletePO(String poId) async {
    await _supabase.from('purchase_orders').delete().eq('po_id', poId);
  }

  Future<PurchaseOrderModel?> getPO(String poId) async {
    final data = await _supabase.from('purchase_orders').select().eq('po_id', poId).maybeSingle();
    if (data == null) return null;
    return PurchaseOrderModel.fromMap(data);
  }
}

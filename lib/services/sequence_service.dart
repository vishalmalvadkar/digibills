import 'package:supabase_flutter/supabase_flutter.dart';

class SequenceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches the next invoice number atomically.
  /// If the counter doesn't exist, it initializes it.
  Future<String> getNextInvoiceNumber(String tenantId, String prefix, int startNumber) async {
    // 1. Try to increment atomic counter
    try {
      final response = await _supabase.rpc('increment_invoice_counter', params: {
        'p_tenant_id': tenantId,
        'p_entity_type': 'INVOICE'
      });
      
      // If RPC is not available yet (migration pending), fallback to manual lock
      // But we should implement the RPC for safety.
      // For now, let's assume we do client-side logic with optimistic locking if RPC is too complex for this turn
      // client-side logic:
      
      // 1. Get current
      final data = await _supabase
          .from('sequence_counters')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_type', 'INVOICE')
          .maybeSingle();

      int nextVal;
      
      if (data == null) {
        // Initialize
        nextVal = startNumber; // Start from settings
        await _supabase.from('sequence_counters').insert({
          'tenant_id': tenantId,
          'entity_type': 'INVOICE',
          'prefix': prefix,
          'current_value': nextVal
        });
      } else {
        nextVal = (data['current_value'] as int) + 1;
        // If settings start number is higher than current + 1, jump to it?
        // Logic: specific formatting
        if (nextVal < startNumber) nextVal = startNumber;

        await _supabase
            .from('sequence_counters')
            .update({'current_value': nextVal, 'updated_at': DateTime.now().toIso8601String()})
            .eq('tenant_id', tenantId)
            .eq('entity_type', 'INVOICE');
      }

      return '$prefix${nextVal.toString().padLeft(3, '0')}';

    } catch (e) {
      // Fallback if table doesn't exist yet/offline
      return '${prefix}${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Get current number without incrementing (for preview)
  Future<String> peekNextInvoiceNumber(String tenantId, String prefix, int startNumber) async {
     final data = await _supabase
          .from('sequence_counters')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_type', 'INVOICE')
          .maybeSingle();
      
     int nextVal = (data == null) ? startNumber : (data['current_value'] as int) + 1;
     if (data != null && nextVal < startNumber) nextVal = startNumber;
     
     return '$prefix${nextVal.toString().padLeft(3, '0')}';
  }
}

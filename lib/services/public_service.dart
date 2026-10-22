import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bill_model.dart';
import '../models/quote_model.dart';
import '../models/purchase_order_model.dart';
import '../models/credit_note_model.dart';
import '../models/settings_model.dart';

class PublicService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch Public Credit Note
  Future<CreditNoteModel?> getPublicCreditNote(String id) async {
    try {
      final response = await _supabase
          .rpc('get_public_credit_note', params: {'query_id': id});

      if (response == null) return null;
      
      // The RPC returns a JSON object with 'items' array.
      // CreditNoteModel.fromMap expects 'items' or 'credit_note_items'.
      return CreditNoteModel.fromMap(response);
    } catch (e) {
      print('Fetch Error Public CN: $e');
      throw 'Fetch Error: $e';
    }
  }

  // Fetch Public Bill with Credit Notes (Direct SDK)
  Future<({BillModel bill, List<CreditNoteModel> creditNotes})?> getPublicBill(String id) async {
    try {
      // 1. Fetch Bill + Items + Payments
      final billData = await _supabase
          .from('bills')
          .select('*, bill_items(*), bill_payments(*)')
          .eq('bill_id', id)
          .maybeSingle();

      if (billData == null) return null;
      
      final bill = BillModel.fromMap(billData);

      // 2. Fetch Credit Notes + Nested Items
      final creditNoteData = await _supabase
          .from('credit_notes')
          .select('*, credit_note_items(*)')
          .eq('bill_id', id);

      final creditNotes = (creditNoteData as List)
          .map((e) => CreditNoteModel.fromMap(e))
          .toList();

      return (bill: bill, creditNotes: creditNotes);
    } catch (e) {
      print('Fetch Error Public Bill: $e');
      throw 'Fetch Error: $e';
    }
  }

  // Fetch Public Quote
  Future<QuoteModel?> getPublicQuote(String id) async {
    try {
      // SECURE RPC CALL
      final response = await _supabase
          .rpc('get_public_quote', params: {'quote_uuid': id});

      if (response == null) return null;
      return QuoteModel.fromMap(response);
    } catch (e) {
       print('Fetch Error Public Quote RPC: $e');
      throw 'Fetch Error: $e';
    }
  }

  // Fetch Public PO
  Future<PurchaseOrderModel?> getPublicPO(String id) async {
    try {
      // SECURE RPC CALL
       final response = await _supabase
          .rpc('get_public_po', params: {'p_po_id': id});

      if (response == null) return null;
       
      final data = Map<String, dynamic>.from(response);
      // RPC returns 'items' directly? Let's check the SQL. 
      // SQL says: 'items', (SELECT jsonb_agg...) -> So it returns 'items'.
      // But just in case generic mapping is needed:
      if (data['bill_items'] != null && data['items'] == null) {
        data['items'] = data['bill_items'];
      }

      return PurchaseOrderModel.fromMap(data);
    } catch (e) {
       print('Fetch Error Public PO RPC: $e');
      throw 'Fetch Error: $e';
    }
  }

  // Fetch Public Settings (Branding) - Direct SDK
  Future<AppSettings?> getPublicSettings(String tenantId, {String? createdBy}) async {
    try {
      Map<String, dynamic>? data;

      // 1. Try fetching by User ID/Tenant ID in the 'user_id' column
      if (tenantId.isNotEmpty) {
        data = await _supabase
            .from('settings')
            .select()
            .eq('user_id', tenantId)
            .maybeSingle();
      }

      // 2. Logic to determine the correct display name if settings are missing or default
      String? fallbackName;
      try {
        // A. Try User Profile Name first (Most accurate for individual/owner)
        if (tenantId.isNotEmpty) {
          final userDoc = await _supabase.from('users').select('name').eq('uid', tenantId).maybeSingle();
          if (userDoc != null && userDoc['name'] != null) {
            fallbackName = userDoc['name'].toString();
          }
        }

        // B. Try Client Profile if User Name is missing or looks generic
        if (fallbackName == null || fallbackName.isEmpty) {
          final clientData = await _supabase
              .from('clients')
              .select('business_name')
              .eq('client_id', tenantId)
              .maybeSingle();
          if (clientData != null && clientData['business_name'] != null) {
            fallbackName = clientData['business_name'].toString();
          }
        }
      } catch (e) {
        print('Error in name fallback: $e');
      }

      AppSettings settings;
      if (data == null) {
        settings = AppSettings(
            tenantName: fallbackName ?? 'Start-Up Agency',
            contactEmail: '',
            contactPhone: '',
            bankName: '',
            accountNumber: '',
            ifscCode: '',
            accountHolderName: '',
            upiId: '',
            payeeName: '',
            gstNumber: '',
            address: '',
            city: '',
            district: '',
            pincode: '',
         );
      } else {
        settings = AppSettings.fromMap(data);
        // If settings exist but name is default, use fallback
        if (settings.tenantName == 'Start-Up Agency' && fallbackName != null) {
           settings = settings.copyWith(tenantName: fallbackName);
        }
      }

      return settings;

    } catch (e) {
      print('Error fetching public settings: $e');
      return AppSettings(
            tenantName: 'Start-Up Agency',
            contactEmail: '',
            contactPhone: '',
            bankName: '',
            accountNumber: '',
            ifscCode: '',
            accountHolderName: '',
            upiId: '',
            payeeName: '',
            gstNumber: '',
            address: '',
            city: '',
            district: '',
            pincode: '',
            logoBase64: null,
         );
    }
  }
}

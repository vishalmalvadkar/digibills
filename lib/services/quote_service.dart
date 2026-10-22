import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quote_model.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

class QuoteService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Stream Quotes
  Stream<List<QuoteModel>> streamQuotes() {
  final String currentTenantId = _authService.currentTenantId;
    if (currentTenantId.isEmpty) {
      return Stream.value([]);
    }

    return _supabase
        .from('quotations')
        .stream(primaryKey: ['quote_id'])
        .eq('tenant_id', currentTenantId)
        .order('date', ascending: false)
        .map((data) => data.map((e) => QuoteModel.fromMap(e)).toList());
  }

  // Create Quote
  Future<void> addQuote(QuoteModel quote) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final quoteData = quote.toMap();
    // Ensure ID
    if (quote.quoteId.isEmpty) {
      quoteData['quote_id'] = const Uuid().v4();
    }
    
    quoteData['tenant_id'] = await _authService.getEffectiveTenantId();
    quoteData['created_by'] = user.id;

    await _supabase.from('quotations').insert(quoteData);
  }

  // Update Quote
  Future<void> updateQuote(QuoteModel quote) async {
    await _supabase
        .from('quotations')
        .update(quote.toMap())
        .eq('quote_id', quote.quoteId);
  }

  // Delete Quote
  Future<void> deleteQuote(String quoteId) async {
    await _supabase.from('quotations').delete().eq('quote_id', quoteId);
  }

  // Update Status
  Future<void> updateStatus(String quoteId, String status) async {
    await _supabase.from('quotations').update({'status': status}).eq('quote_id', quoteId);
  }

  // Get Single Quote Stream
  Stream<QuoteModel> getQuoteStream(String quoteId) {
    return _supabase.from('quotations').stream(primaryKey: ['quote_id']).eq('quote_id', quoteId).map((data) => QuoteModel.fromMap(data.first));
  }
}

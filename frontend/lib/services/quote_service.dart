import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/quote_model.dart';
import 'api_client.dart';

class QuoteService {
  final ApiClient _api = ApiClient();
  final List<QuoteModel> _cachedQuotes = [];
  final StreamController<List<QuoteModel>> _controller =
      StreamController<List<QuoteModel>>.broadcast();
  bool _initialized = false;

  QuoteService() {
    _api.realtimeEvents.listen((event) {
      if (event['table'] == 'quotations') {
        final action = event['action'];
        final data = event['data'] as Map<String, dynamic>;

        if (action == 'INSERT') {
          final quote = QuoteModel.fromMap(data);
          _cachedQuotes.removeWhere((q) => q.quoteId == quote.quoteId);
          _cachedQuotes.add(quote);
          _sortAndEmit();
        } else if (action == 'UPDATE') {
          final quote = QuoteModel.fromMap(data);
          final index = _cachedQuotes.indexWhere((q) => q.quoteId == quote.quoteId);
          if (index != -1) {
            _cachedQuotes[index] = quote;
          } else {
            _cachedQuotes.add(quote);
          }
          _sortAndEmit();
        } else if (action == 'DELETE') {
          final quoteId = data['quote_id'];
          _cachedQuotes.removeWhere((q) => q.quoteId == quoteId);
          _sortAndEmit();
        }
      }
    });
  }

  void _sortAndEmit() {
    _cachedQuotes.sort((a, b) => b.date.compareTo(a.date));
    _controller.add(List.unmodifiable(_cachedQuotes));
  }

  Future<void> _fetchInitial() async {
    try {
      final res = await _api.get('/api/v1/quotations');
      if (res is List) {
        _cachedQuotes.clear();
        for (var item in res) {
          _cachedQuotes.add(QuoteModel.fromMap(Map<String, dynamic>.from(item)));
        }
        _sortAndEmit();
      }
    } catch (_) {
      _controller.add(List.unmodifiable(_cachedQuotes));
    }
  }

  // Stream Quotes
  Stream<List<QuoteModel>> streamQuotes() {
    if (!_initialized) {
      _initialized = true;
      _fetchInitial();
    } else {
      Future.microtask(() => _controller.add(List.unmodifiable(_cachedQuotes)));
    }
    return _controller.stream;
  }

  // Create Quote
  Future<void> addQuote(QuoteModel quote) async {
    final quoteData = quote.toMap();
    if (quote.quoteId.isEmpty) {
      quoteData['quote_id'] = const Uuid().v4();
    }
    await _api.post('/api/v1/quotations', body: quoteData);
  }

  // Update Quote
  Future<void> updateQuote(QuoteModel quote) async {
    await _api.put('/api/v1/quotations/${quote.quoteId}', body: quote.toMap());
  }

  // Delete Quote
  Future<void> deleteQuote(String quoteId) async {
    await _api.delete('/api/v1/quotations/$quoteId');
  }

  // Update Status
  Future<void> updateStatus(String quoteId, String status) async {
    await _api.put('/api/v1/quotations/$quoteId', body: {'status': status});
  }

  // Get Single Quote Stream
  Stream<QuoteModel> getQuoteStream(String quoteId) {
    return streamQuotes().map((list) => list.firstWhere((q) => q.quoteId == quoteId));
  }

  Future<QuoteModel?> getQuoteById(String quoteId) async {
    final cached = _cachedQuotes.where((q) => q.quoteId == quoteId).firstOrNull;
    if (cached != null) return cached;
    try {
      final res = await _api.get('/api/v1/quotations/$quoteId');
      if (res is Map<String, dynamic>) {
        return QuoteModel.fromMap(res);
      }
    } catch (_) {}
    return null;
  }
}

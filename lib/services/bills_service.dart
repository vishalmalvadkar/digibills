import 'dart:async';
import '../models/bill_model.dart';
import 'api_client.dart';

class BillsService {
  final ApiClient _api = ApiClient();

  final List<BillModel> _cachedBills = [];
  final StreamController<List<BillModel>> _controller =
      StreamController<List<BillModel>>.broadcast();
  bool _initialized = false;

  BillsService() {
    // Listen to real-time events from FastAPI WebSockets
    _api.realtimeEvents.listen((event) {
      if (event['table'] == 'bills') {
        final action = event['action'];
        final data = event['data'] as Map<String, dynamic>;

        if (action == 'INSERT') {
          final bill = BillModel.fromMap(data);
          _cachedBills.removeWhere((b) => b.billId == bill.billId);
          _cachedBills.add(bill);
          _sortAndEmit();
        } else if (action == 'UPDATE') {
          final bill = BillModel.fromMap(data);
          final index = _cachedBills.indexWhere((b) => b.billId == bill.billId);
          if (index != -1) {
            _cachedBills[index] = bill;
          } else {
            _cachedBills.add(bill);
          }
          _sortAndEmit();
        } else if (action == 'DELETE') {
          final billId = data['bill_id'];
          _cachedBills.removeWhere((b) => b.billId == billId);
          _sortAndEmit();
        }
      }
    });
  }

  void _sortAndEmit() {
    _cachedBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _controller.add(List.unmodifiable(_cachedBills));
  }

  Future<void> _fetchInitial({String? clientId, String? staffId}) async {
    try {
      final query = <String, String>{};
      if (clientId != null) query['client_id'] = clientId;
      if (staffId != null) query['created_by'] = staffId;

      final res = await _api.get('/api/v1/bills', queryParams: query);
      if (res is List) {
        _cachedBills.clear();
        for (var item in res) {
          _cachedBills.add(BillModel.fromMap(Map<String, dynamic>.from(item)));
        }
        _sortAndEmit();
      }
    } catch (_) {
      _controller.add(List.unmodifiable(_cachedBills));
    }
  }

  Stream<List<BillModel>> streamBills({String? clientId, String? staffId}) {
    if (!_initialized) {
      _initialized = true;
      _fetchInitial(clientId: clientId, staffId: staffId);
    } else {
      Future.microtask(() => _controller.add(List.unmodifiable(_cachedBills)));
    }
    return _controller.stream;
  }

  Stream<List<BillModel>> streamUserRelevantBills(String uid) {
    return streamBills();
  }

  Future<void> addBill(BillModel bill) async {
    final body = bill.toMap();
    await _api.post('/api/v1/bills', body: body);
  }

  Future<void> updateBill(BillModel bill) async {
    final body = bill.toMap();
    await _api.put('/api/v1/bills/${bill.billId}', body: body);
  }

  Future<void> deleteBill(String billId) async {
    await _api.delete('/api/v1/bills/$billId');
  }

  Future<BillModel?> getBillById(String billId) async {
    final cached = _cachedBills.where((b) => b.billId == billId).firstOrNull;
    if (cached != null) return cached;
    return null;
  }
}

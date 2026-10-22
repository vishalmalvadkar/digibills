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

  Future<List<BillModel>> fetchBillsSnapshot({String? clientId, String? staffId}) async {
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
    } catch (_) {}
    return List.unmodifiable(_cachedBills);
  }

  Future<List<BillModel>> getUserRelevantBills(String uid) async {
    return fetchBillsSnapshot();
  }

  Future<String> addBill(BillModel bill) async {
    final body = bill.toMap();
    final res = await _api.post('/api/v1/bills', body: body);
    if (res is Map<String, dynamic> && res['bill_id'] != null) {
      return res['bill_id'] as String;
    }
    return bill.billId;
  }

  Future<void> updateBill(BillModel bill) async {
    final body = bill.toMap();
    await _api.put('/api/v1/bills/${bill.billId}', body: body);
  }

  Future<void> updateBillStatus(String billId, String status, DateTime? paymentReceivedDate) async {
    final body = {
      'payment_status': status,
      if (paymentReceivedDate != null)
        'payment_received_date': paymentReceivedDate.toIso8601String(),
    };
    await _api.put('/api/v1/bills/$billId', body: body);
  }

  Future<void> addPayment(String billId, PaymentRecord payment) async {
    final currentBill = await getBillById(billId);
    final updatedPayments = [
      if (currentBill != null) ...currentBill.payments,
      payment,
    ];
    final totalPaid = updatedPayments.fold<double>(0.0, (acc, p) => acc + p.amount);
    final totalAmount = currentBill?.totalAmount ?? 0.0;
    final newStatus = totalPaid >= totalAmount ? 'Paid' : (totalPaid > 0 ? 'Partial' : 'Pending');

    final body = {
      'payments': updatedPayments.map((p) => p.toMap()).toList(),
      'payment_status': newStatus,
    };
    await _api.put('/api/v1/bills/$billId', body: body);
  }

  Future<void> deletePayment(String billId, String paymentId) async {
    final currentBill = await getBillById(billId);
    if (currentBill == null) return;
    final updatedPayments = currentBill.payments.where((p) => p.id != paymentId).toList();
    final totalPaid = updatedPayments.fold<double>(0.0, (acc, p) => acc + p.amount);
    final totalAmount = currentBill.totalAmount;
    final newStatus = totalPaid >= totalAmount ? 'Paid' : (totalPaid > 0 ? 'Partial' : 'Pending');

    final body = {
      'payments': updatedPayments.map((p) => p.toMap()).toList(),
      'payment_status': newStatus,
    };
    await _api.put('/api/v1/bills/$billId', body: body);
  }

  Future<void> deleteBill(String billId) async {
    await _api.delete('/api/v1/bills/$billId');
  }

  Future<BillModel?> getBillById(String billId) async {
    final cached = _cachedBills.where((b) => b.billId == billId).firstOrNull;
    if (cached != null) return cached;
    try {
      final res = await _api.get('/api/v1/bills/$billId');
      if (res is Map<String, dynamic>) {
        return BillModel.fromMap(res);
      }
    } catch (_) {}
    return null;
  }
}

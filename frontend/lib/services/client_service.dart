import 'dart:async';
import '../models/client_model.dart';
import '../models/license_model.dart';
import '../models/bill_model.dart';
import 'api_client.dart';

class ClientService {
  final ApiClient _api = ApiClient();
  final List<ClientModel> _cachedClients = [];
  final StreamController<List<ClientModel>> _controller =
      StreamController<List<ClientModel>>.broadcast();
  bool _initialized = false;

  ClientService() {
    _api.realtimeEvents.listen((event) {
      if (event['table'] == 'clients') {
        final action = event['action'];
        final data = event['data'] as Map<String, dynamic>;

        if (action == 'INSERT') {
          final client = ClientModel.fromMap(data);
          _cachedClients.removeWhere((c) => c.clientId == client.clientId);
          _cachedClients.add(client);
          _sortAndEmit();
        } else if (action == 'UPDATE') {
          final client = ClientModel.fromMap(data);
          final index = _cachedClients.indexWhere((c) => c.clientId == client.clientId);
          if (index != -1) {
            _cachedClients[index] = client;
          } else {
            _cachedClients.add(client);
          }
          _sortAndEmit();
        } else if (action == 'DELETE') {
          final clientId = data['client_id'];
          _cachedClients.removeWhere((c) => c.clientId == clientId);
          _sortAndEmit();
        }
      }
    });
  }

  void _sortAndEmit() {
    _cachedClients.sort((a, b) => a.businessName.toLowerCase().compareTo(b.businessName.toLowerCase()));
    _controller.add(List.unmodifiable(_cachedClients));
  }

  Future<void> _fetchInitial() async {
    try {
      final res = await _api.get('/api/v1/clients');
      if (res is List) {
        _cachedClients.clear();
        for (var item in res) {
          _cachedClients.add(ClientModel.fromMap(Map<String, dynamic>.from(item)));
        }
        _sortAndEmit();
      }
    } catch (_) {
      _controller.add(List.unmodifiable(_cachedClients));
    }
  }

  Stream<List<ClientModel>> streamClients() {
    if (!_initialized) {
      _initialized = true;
      _fetchInitial();
    } else {
      Future.microtask(() => _controller.add(List.unmodifiable(_cachedClients)));
    }
    return _controller.stream;
  }

  Future<void> updateClient({
    required String clientId,
    required String businessName,
    required String ownerName,
    required String email,
    required String whatsappNumber,
    required LicenseModel license,
    String? state,
    String? gstNumber,
    double amount = 0.0,
    String paymentMode = 'Cash',
    String paymentStatus = 'Pending',
    double taxPercentage = 0.0,
    List<PaymentRecord> advances = const [],
  }) async {
    final updateData = {
      'business_name': businessName,
      'owner_name': ownerName,
      'email': email,
      'whatsapp_number': whatsappNumber,
      'license': license.toMap(),
      if (state != null) 'state': state,
      if (gstNumber != null) 'gst_number': gstNumber,
      'amount': amount,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
      'tax_percentage': taxPercentage,
    };

    await _api.put('/api/v1/clients/$clientId', body: updateData);
  }

  Future<void> addClient(ClientModel client) async {
    await _api.post('/api/v1/clients', body: client.toMap());
  }

  Future<void> deleteClient(String clientId) async {
    await _api.delete('/api/v1/clients/$clientId');
  }

  Future<ClientModel?> getClientById(String clientId) async {
    final cached = _cachedClients.where((c) => c.clientId == clientId).firstOrNull;
    if (cached != null) return cached;
    try {
      final res = await _api.get('/api/v1/clients/$clientId');
      if (res is Map<String, dynamic>) {
        return ClientModel.fromMap(res);
      }
    } catch (_) {}
    return null;
  }

  Future<ClientModel?> getClient(String clientId) async {
    return getClientById(clientId);
  }

  Future<void> createClient({
    required String businessName,
    required String ownerName,
    required String email,
    required String whatsappNumber,
    required LicenseModel license,
    String? state,
    String? gstNumber,
    double amount = 0.0,
    double taxPercentage = 0.0,
    String paymentMode = 'Cash',
    String paymentStatus = 'Pending',
    List<PaymentRecord> advances = const [],
  }) async {
    final client = ClientModel(
      clientId: '',
      businessName: businessName,
      ownerName: ownerName,
      email: email,
      whatsappNumber: whatsappNumber,
      state: state ?? '',
      gstNumber: gstNumber ?? '',
      license: license,
      amount: amount,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      taxPercentage: taxPercentage,
      advances: advances,
      createdAt: DateTime.now(),
    );
    await addClient(client);
  }

  Future<void> syncMissingStates() async {
    // No-op for FastAPI backend as states are handled in DB
  }
}

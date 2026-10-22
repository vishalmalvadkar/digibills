import 'dart:async';
import '../models/product_model.dart';
import 'api_client.dart';

class ProductService {
  final ApiClient _api = ApiClient();
  final List<ProductModel> _cachedProducts = [];
  final StreamController<List<ProductModel>> _controller =
      StreamController<List<ProductModel>>.broadcast();
  bool _initialized = false;

  ProductService() {
    // Listen to real-time events from FastAPI WebSockets
    _api.realtimeEvents.listen((event) {
      if (event['table'] == 'products') {
        final action = event['action'];
        final data = event['data'] as Map<String, dynamic>;

        if (action == 'INSERT') {
          final prod = ProductModel.fromMap(data);
          _cachedProducts.removeWhere((p) => p.productId == prod.productId);
          _cachedProducts.add(prod);
          _sortAndEmit();
        } else if (action == 'UPDATE') {
          final prod = ProductModel.fromMap(data);
          final index = _cachedProducts.indexWhere((p) => p.productId == prod.productId);
          if (index != -1) {
            _cachedProducts[index] = prod;
          } else {
            _cachedProducts.add(prod);
          }
          _sortAndEmit();
        } else if (action == 'DELETE') {
          final prodId = data['product_id'];
          _cachedProducts.removeWhere((p) => p.productId == prodId);
          _sortAndEmit();
        }
      }
    });
  }

  void _sortAndEmit() {
    _cachedProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _controller.add(List.unmodifiable(_cachedProducts));
  }

  Future<void> _fetchInitial() async {
    try {
      final res = await _api.get('/api/v1/products');
      if (res is List) {
        _cachedProducts.clear();
        for (var item in res) {
          _cachedProducts.add(ProductModel.fromMap(Map<String, dynamic>.from(item)));
        }
        _sortAndEmit();
      }
    } catch (e) {
      // If error, keep cached or emit empty
      _controller.add(List.unmodifiable(_cachedProducts));
    }
  }

  Stream<List<ProductModel>> streamProducts() {
    if (!_initialized) {
      _initialized = true;
      _fetchInitial();
    } else {
      // Emit current cache immediately for new listeners
      Future.microtask(() => _controller.add(List.unmodifiable(_cachedProducts)));
    }
    return _controller.stream;
  }

  Future<ProductModel?> getProductByScanCode(String scancode) async {
    try {
      final match = _cachedProducts.where((p) => p.scancode == scancode).firstOrNull;
      if (match != null) return match;

      final res = await _api.get('/api/v1/products');
      if (res is List) {
        for (var item in res) {
          final prod = ProductModel.fromMap(Map<String, dynamic>.from(item));
          if (prod.scancode == scancode) return prod;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveProduct(ProductModel product) async {
    final body = product.toMap();
    if (product.productId == null || product.productId!.isEmpty) {
      await _api.post('/api/v1/products', body: body);
    } else {
      await _api.put('/api/v1/products/${product.productId}', body: body);
    }
  }

  Future<void> saveProducts(List<ProductModel> products) async {
    for (final prod in products) {
      await saveProduct(prod);
    }
  }

  Future<void> deleteProduct(String productId) async {
    await _api.delete('/api/v1/products/$productId');
  }
}

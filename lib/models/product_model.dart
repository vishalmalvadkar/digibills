class ProductModel {
  final String? productId;
  final String tenantId;
  final String name;
  final String? description;
  final String scancode;
  final double unitPrice;
  final String unit;
  final double stockQuantity;
  final double alertThreshold;
  final bool isStockTracked;
  final DateTime? createdAt;
  final String? hsnCode; // NEW

  ProductModel({
    this.productId,
    required this.tenantId,
    required this.name,
    this.description,
    required this.scancode,
    required this.unitPrice,
    this.unit = 'qty',
    this.stockQuantity = 0,
    this.alertThreshold = 5,
    this.isStockTracked = true,
    this.createdAt,
    this.hsnCode,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      productId: map['product_id'],
      tenantId: map['tenant_id'],
      name: map['name'] ?? '',
      description: map['description'],
      scancode: map['scancode'] ?? '',
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'qty',
      stockQuantity: (map['stock_quantity'] ?? 0).toDouble(),
      alertThreshold: (map['alert_threshold'] ?? 5).toDouble(),
      isStockTracked: map['is_stock_tracked'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      hsnCode: map['hsn_code'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (productId != null) 'product_id': productId,
      'tenant_id': tenantId,
      'name': name,
      'description': description,
      'scancode': scancode,
      'unit_price': unitPrice,
      'unit': unit,
      'stock_quantity': stockQuantity,
      'alert_threshold': alertThreshold,
      'is_stock_tracked': isStockTracked,
      'hsn_code': hsnCode,
    };
  }
}

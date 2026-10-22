import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../theme/app_colors.dart';
import '../widgets/scanner_overlay.dart';
import '../utils/snackbar_helper.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:typed_data'; // NEW
import '../utils/file_download_helper.dart'; // NEW

class InventoryScreen extends StatefulWidget {
  final VoidCallback? onAdd;
  const InventoryScreen({super.key, this.onAdd});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Stream<List<ProductModel>> _productStream;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _productStream = _productService.streamProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showProductDialog({ProductModel? product}) {
    final nameCtrl = TextEditingController(text: product?.name);
    final priceCtrl = TextEditingController(text: product?.unitPrice.toString());
    final scancodeCtrl = TextEditingController(text: product?.scancode);
    final hsnCtrl = TextEditingController(text: product?.hsnCode); 
    final unitCtrl = TextEditingController(text: product?.unit ?? 'qty');
    final stockCtrl = TextEditingController(text: product?.stockQuantity.toString() ?? '0');
    final thresholdCtrl = TextEditingController(text: product?.alertThreshold.toString() ?? '5');
    bool isTracked = product?.isStockTracked ?? true;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), // Professional size on desktop
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product == null ? 'Add Product' : 'Edit Product',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textGrey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDialogField(nameCtrl, 'Product Name', Icons.inventory_2_outlined),
                  const SizedBox(height: 16),
                  _buildDialogField(priceCtrl, 'Selling Price', Icons.currency_rupee, isNumber: true),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _buildDialogField(scancodeCtrl, 'Barcode / Scancode', Icons.qr_code_outlined),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                          onPressed: () async {
                            final code = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(builder: (_) => const ScannerOverlay()),
                            );
                            if (code != null) {
                              scancodeCtrl.text = code;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDialogField(hsnCtrl, 'HSN/SAC Code (Optional)', Icons.tag),
                  const SizedBox(height: 16),
                  
                  _buildDialogField(unitCtrl, 'Unit (qty, kg, etc.)', Icons.straighten_outlined),
                  const SizedBox(height: 16),
                  StatefulBuilder(builder: (ctx, setLocalState) {
                    return Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Track Stock Inventory', style: TextStyle(fontSize: 14)),
                          value: isTracked, 
                          onChanged: (v) => setLocalState(() => isTracked = v),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (isTracked) ...[
                          Row(
                            children: [
                              Expanded(child: _buildDialogField(stockCtrl, 'Current Stock', Icons.inventory, isNumber: true)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDialogField(thresholdCtrl, 'Alert At', Icons.notification_important_outlined, isNumber: true)),
                            ],
                          ),
                        ],
                      ],
                    );
                  }),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty || scancodeCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                           SnackbarHelper.showError(context, 'Please fill all required fields');
                           return;
                        }

                        final userId = _productService.auth.currentUser?.id;
                        if (userId == null) return;

                        final updatedProduct = ProductModel(
                          productId: product?.productId,
                          tenantId: userId,
                          name: nameCtrl.text,
                          scancode: scancodeCtrl.text,
                          hsnCode: hsnCtrl.text.trim().isEmpty ? null : hsnCtrl.text.trim(),
                          unitPrice: double.tryParse(priceCtrl.text) ?? 0,
                          unit: unitCtrl.text,
                          stockQuantity: double.tryParse(stockCtrl.text) ?? 0,
                          alertThreshold: double.tryParse(thresholdCtrl.text) ?? 5,
                          isStockTracked: isTracked,
                        );

                        try {
                          await _productService.saveProduct(updatedProduct);
                          if (mounted) {
                            Navigator.pop(ctx);
                            _loadProducts();
                            SnackbarHelper.showSuccess(context, 'Product saved successfully');
                          }
                        } catch (e) {
                          debugPrint('Save Error: $e');
                          if (mounted) {
                             String errorMsg = e.toString();
                             if (errorMsg.contains('hsn_code')) {
                                errorMsg = "Database error: 'hsn_code' column missing. Please run the SQL migration in Supabase.";
                             }
                             SnackbarHelper.showError(context, 'Error: $errorMsg');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _productService.deleteProduct(product.productId!);
                _loadProducts();
                if (mounted) SnackbarHelper.showSuccess(context, 'Product deleted');
              } catch (e) {
                if (mounted) SnackbarHelper.showError(context, 'Failed to delete: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textGrey),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Inventory / Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.primary, size: 20),
            tooltip: 'Export CSV',
            onPressed: () => _exportToCSV(),
          ),
          IconButton(
            icon: const Icon(Icons.upload, color: AppColors.textGrey, size: 20),
            tooltip: 'Import CSV',
            onPressed: () => _showImportInstructions(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ProductModel>>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final products = snapshot.data?.where((p) => 
                  p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                  p.scancode.contains(_searchQuery)
                ).toList() ?? [];

                if (products.isEmpty) {
                  return const Center(child: Text('No products found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${p.scancode} • ₹${p.unitPrice} / ${p.unit}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showProductDialog(product: p)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red), 
                            onPressed: () => _confirmDelete(p),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showProductDialog();
          if (widget.onAdd != null) {
            Future.delayed(Duration.zero, () => widget.onAdd!());
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
  Future<void> _exportToCSV() async {
    try {
      final products = await _productService.streamProducts().first;
      List<List<dynamic>> rows = [
        ['Name', 'Scancode', 'Price', 'Unit', 'Stock', 'Threshold', 'IsTracked']
      ];

      for (var p in products) {
        rows.add([
          p.name,
          p.scancode,
          p.unitPrice,
          p.unit,
          p.stockQuantity,
          p.alertThreshold,
          p.isStockTracked ? 1 : 0
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      // await Share.share(csvData, subject: 'Inventory_Export.csv');
      await FileDownloadHelper.downloadFile(
        utf8.encode(csvData), 
        'Inventory_Export', 
        'csv',
        mimeType: 'text/csv'
      );
    } catch (e) {
      SnackbarHelper.showError(context, 'Export failed: $e');
    }
  }

  void _showImportInstructions() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Import (CSV)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste your CSV data below.\nFormat: Name,Scancode,Price,Unit,Stock,Threshold,IsTracked (0 or 1)',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'e.g. Apple,123,50,kg,100,10,1',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _importCSV(textCtrl.text);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _importCSV(String csvData) async {
    final cleanedData = csvData.trim();
    if (cleanedData.isEmpty) return;
    
    try {
      // Split by any common newline character
      final lines = cleanedData.split(RegExp(r'\r?\n'));
      if (lines.isEmpty) {
        SnackbarHelper.showError(context, 'No lines found in data');
        return;
      }

      List<ProductModel> productsToSave = [];
      final userId = _productService.auth.currentUser?.id;
      if (userId == null) return;

      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        
        // Simple manual split for pasted data - handle basic CSV logic
        // We trim each field to be safe
        final row = line.split(',').map((e) => e.trim()).toList();
        
        if (row.isEmpty) continue;
        
        // Skip header
        final firstCol = row[0].toLowerCase();
        if (firstCol == 'name' || firstCol.isEmpty) continue;

        // Minimum required: Name, Scancode, Price
        if (row.length < 3) continue; 

        try {
          productsToSave.add(ProductModel(
            tenantId: userId,
            name: row[0],
            scancode: row[1],
            unitPrice: double.tryParse(row[2]) ?? 0,
            unit: row.length > 3 ? row[3] : 'qty',
            stockQuantity: row.length > 4 ? (double.tryParse(row[4]) ?? 0) : 0,
            alertThreshold: row.length > 5 ? (double.tryParse(row[5]) ?? 5) : 5,
            isStockTracked: row.length > 6 ? (row[6] == '1' || row[6].toLowerCase() == 'true') : true,
          ));
        } catch (itemError) {
          print('Error parsing row ($line): $itemError');
          // continue to next row
        }
      }

      if (productsToSave.isNotEmpty) {
        await _productService.saveProducts(productsToSave);
        _loadProducts(); // Fresh Stream
        SnackbarHelper.showSuccess(context, 'Imported ${productsToSave.length} products successfully');
      } else {
        SnackbarHelper.showError(context, 'No valid products found in pasted data. Check the format.');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Import failed: $e');
    }
  }
}

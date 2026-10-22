import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../services/bills_service.dart';
import '../theme/app_colors.dart';
import 'package:flutter/services.dart'; 
import '../utils/validators.dart';
import '../utils/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/client_service.dart';
import 'mou_screen.dart';
import '../widgets/scanner_overlay.dart';
import '../services/product_service.dart';
import '../models/product_model.dart';
import '../services/settings_service.dart';
import 'dart:async';
import '../models/settings_model.dart';
import '../models/client_model.dart';
import '../providers/shell_provider.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import '../widgets/license_scope.dart';
import '../l10n/app_localizations.dart';

class EditBillScreen extends StatefulWidget {
  final BillModel bill;
  const EditBillScreen({super.key, required this.bill});

  @override
  State<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends State<EditBillScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _customerController;
  late TextEditingController _whatsappController;
  late TextEditingController _addressController;
  late TextEditingController _invoiceNoController;
  late TextEditingController _taxController;
  late TextEditingController _clientIdController;
  late TextEditingController _gstNumberController;
  
  String _selectedState = '';
  AppSettings? _appSettings;
  
  bool _showEwayBillDetails = false;
  bool _thresholdToastShown = false;
  late TextEditingController _ewayBillNoController;
  late TextEditingController _vehicleNoController;
  String _selectedTransportMode = 'Road';
  final List<String> _transportModes = ['Road', 'Rail', 'Air', 'Ship'];

  // Shipped To Controllers
  bool _shipToDifferentAddress = false;
  late TextEditingController _shippingNameController;
  late TextEditingController _shippingAddressController;
  
  // Items
  final List<TextEditingController> _serviceControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _unitPriceControllers = [];
  final List<TextEditingController> _amountControllers = [];
  final List<TextEditingController> _hsnControllers = [];
  final List<String> _selectedUnits = [];
  final List<String?> _productIds = [];
  
  // Payment
  final List<TextEditingController> _paymentAmounts = [];
  final List<String> _paymentModes = []; 
  final List<DateTime> _paymentDates = [];

  final List<String> _unitOptions = [
    'qty', 'kg', 'gram', 'liter', 'ml', 
    'pcs', 'box', 'meter', 'ft', 'sq.ft', 'sq.m', 
    'dozen', 'set', 'packet', 'bundle', 'ton', 
    'day', 'hour', 'mo'
  ];

  List<BillModel> _allBills = [];
  List<ProductModel> _allProducts = [];
  late DateTime _billDate;
  Timer? _debounce;

  final BillsService _billsService = BillsService();
  final ProductService _productService = ProductService();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initData();
  }

  void _initializeControllers() {
    final b = widget.bill;
    _customerController = TextEditingController(text: b.customerName);
    _whatsappController = TextEditingController(text: b.whatsappNumber.startsWith('91') ? b.whatsappNumber.substring(2) : b.whatsappNumber);
    _addressController = TextEditingController(text: b.clientAddress);
    _invoiceNoController = TextEditingController(text: b.invoiceNumber);
    _taxController = TextEditingController(text: b.taxPercentage.toString());
    _clientIdController = TextEditingController(text: b.clientId);
    _gstNumberController = TextEditingController(text: b.gstNumber ?? '');
    _selectedState = b.placeOfSupply;
    _billDate = b.billDate;

    _showEwayBillDetails = b.ewayBillNo != null || b.vehicleNo != null;
    _ewayBillNoController = TextEditingController(text: b.ewayBillNo ?? '');
    _vehicleNoController = TextEditingController(text: b.vehicleNo ?? '');
    if (b.transportMode != null) _selectedTransportMode = b.transportMode!;

    _shipToDifferentAddress = b.shippingName != null || b.shippingAddress != null;
    _shippingNameController = TextEditingController(text: b.shippingName ?? '');
    _shippingAddressController = TextEditingController(text: b.shippingAddress ?? '');

    // Items
    for (var item in b.items) {
      _serviceControllers.add(TextEditingController(text: item.description));
      _quantityControllers.add(TextEditingController(text: item.quantity.toString()));
      _unitPriceControllers.add(TextEditingController(text: item.unitPrice.toString()));
      _amountControllers.add(TextEditingController(text: item.amount.toString()));
      _hsnControllers.add(TextEditingController(text: item.hsnCode ?? ''));
      _selectedUnits.add(item.unit);
      _productIds.add(item.productId);
    }
    // Ensure at least one item row
    if (_serviceControllers.isEmpty) _addItem();

    // Payments
    for (var p in b.payments) {
      _paymentAmounts.add(TextEditingController(text: p.amount.toString()));
      _paymentModes.add(p.mode);
      _paymentDates.add(p.date);
    }

    // Default Settings will be loaded in _initData
  }

  Future<void> _initData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final results = await Future.wait<dynamic>([
        ClientService().getClient(user.id),
        BillsService().fetchBillsSnapshot(),
        SettingsService().fetchSettings(),
        ProductService().getProducts(),
      ]);

      final client = results[0] as ClientModel?;
      final bills = results[1] as List<BillModel>;
      final settings = results[2] as AppSettings?;
      final products = results[3] as List<ProductModel>;

      if (mounted) {
        setState(() {
          _allBills = bills;
          _allProducts = products;
          _appSettings = settings;
        });
      }
    } catch (e) {
      debugPrint('Error initializing edit bill data: $e');
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _invoiceNoController.dispose();
    _taxController.dispose();
    _clientIdController.dispose();
    _gstNumberController.dispose();
    _ewayBillNoController.dispose();
    _vehicleNoController.dispose();
    _shippingNameController.dispose();
    _shippingAddressController.dispose();
    
    for (var c in _serviceControllers) c.dispose();
    for (var c in _amountControllers) c.dispose();
    for (var c in _quantityControllers) c.dispose();
    for (var c in _unitPriceControllers) c.dispose();
    for (var c in _hsnControllers) c.dispose();
    for (var c in _paymentAmounts) c.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _serviceControllers.add(TextEditingController());
      _amountControllers.add(TextEditingController(text: '0'));
      _quantityControllers.add(TextEditingController(text: '1'));
      _unitPriceControllers.add(TextEditingController());
      _hsnControllers.add(TextEditingController());
      _selectedUnits.add('qty');
      _productIds.add(null);
    });
  }

  void _removeItem(int index) {
    if (_serviceControllers.length > 1) {
      setState(() {
        _serviceControllers[index].dispose();
        _amountControllers[index].dispose();
        _quantityControllers[index].dispose();
        _unitPriceControllers[index].dispose();
        _hsnControllers[index].dispose();
        
        _serviceControllers.removeAt(index);
        _amountControllers.removeAt(index);
        _quantityControllers.removeAt(index);
        _unitPriceControllers.removeAt(index);
        _hsnControllers.removeAt(index);
        _selectedUnits.removeAt(index);
        _productIds.removeAt(index);
      });
      _calculateTotal(); // Recalc
    }
  }

  void _addPayment() {
    setState(() {
      _paymentAmounts.add(TextEditingController());
      _paymentModes.add('Cash');
      _paymentDates.add(DateTime.now());
    });
  }

  void _removePayment(int index) {
    setState(() {
      _paymentAmounts[index].dispose();
      _paymentAmounts.removeAt(index);
      _paymentModes.removeAt(index);
      _paymentDates.removeAt(index);
    });
  }

  void _calculateItemTotal(int index) {
    double qty = double.tryParse(_quantityControllers[index].text) ?? 0;
    double price = double.tryParse(_unitPriceControllers[index].text) ?? 0;
    double total = qty * price;
    _amountControllers[index].text = total.toStringAsFixed(2);
    setState(() {});
  }

  double _calculateSubTotal() {
    double subTotal = 0;
    for (var c in _amountControllers) {
      if (c.text.isNotEmpty) subTotal += double.tryParse(c.text) ?? 0;
    }
    return subTotal;
  }

  double _calculateTaxAmount() {
    double subTotal = _calculateSubTotal();
    double taxPercent = double.tryParse(_taxController.text) ?? 0;
    return (subTotal * taxPercent) / 100;
  }

  double _calculateTotal() {
    return _calculateSubTotal() + _calculateTaxAmount();
  }

  // .. Scanning Logic (Simplified Copy) ..
  Future<void> _startScanning() async {
     final String? code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerOverlay()),
    );
    if (code != null) _handleScannedCode(code);
  }

   Future<void> _handleScannedCode(String scancode) async {
    final product = await _productService.getProductByScanCode(scancode);
    if (product != null) {
      _addProductToInvoice(product);
    } else {
      SnackbarHelper.showInfo(context, 'Product not found for $scancode');
    }
  }

  void _addProductToInvoice(ProductModel product) {
    setState(() {
      int existingIndex = _serviceControllers.indexWhere((c) => c.text == product.name);
      if (existingIndex != -1) {
        double currentQty = double.tryParse(_quantityControllers[existingIndex].text) ?? 1;
        _quantityControllers[existingIndex].text = (currentQty + 1).toString();
        _productIds[existingIndex] = product.productId;
        if (product.hsnCode != null) _hsnControllers[existingIndex].text = product.hsnCode!;
        _calculateItemTotal(existingIndex);
      } else {
        if (_serviceControllers.length == 1 && _serviceControllers[0].text.isEmpty) {
           _serviceControllers[0].text = product.name;
           _unitPriceControllers[0].text = product.unitPrice.toString();
           _quantityControllers[0].text = '1';
           _selectedUnits[0] = product.unit;
           _productIds[0] = product.productId;
           if (product.hsnCode != null) _hsnControllers[0].text = product.hsnCode!;
           _calculateItemTotal(0);
        } else {
           _serviceControllers.add(TextEditingController(text: product.name));
           _amountControllers.add(TextEditingController(text: product.unitPrice.toString()));
           _quantityControllers.add(TextEditingController(text: '1'));
           _unitPriceControllers.add(TextEditingController(text: product.unitPrice.toString()));
           _hsnControllers.add(TextEditingController(text: product.hsnCode ?? ''));
           _selectedUnits.add(product.unit);
           _productIds.add(product.productId);
           _calculateItemTotal(_serviceControllers.length - 1);
        }
      }
    });
  }

  bool _isSaving = false;

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // 1. Revert Old Stock (if tracked)
      // We iterate over ORIGINAL details
      for (var item in widget.bill.items) {
        if (item.productId != null) {
          try {
            await _productService.updateStock(item.productId!, item.quantity); // Add back
          } catch (_) {}
        }
      }

      // 2. Prepare New Bill Data
      List<BillItem> items = [];
      for (int i = 0; i < _serviceControllers.length; i++) {
        items.add(BillItem(
          productId: _productIds[i],
          description: _serviceControllers[i].text.trim(),
          amount: double.tryParse(_amountControllers[i].text.trim()) ?? 0,
          quantity: double.tryParse(_quantityControllers[i].text.trim()) ?? 1,
          unit: _selectedUnits[i],
          unitPrice: double.tryParse(_unitPriceControllers[i].text.trim()) ?? 0,
          hsnCode: _hsnControllers[i].text.trim().isNotEmpty ? _hsnControllers[i].text.trim() : null,
        ));
      }

      final subTotal = _calculateSubTotal();
      final taxPercentage = double.tryParse(_taxController.text) ?? 0;
      final taxAmount = (subTotal * taxPercentage) / 100;

      // Tax Split (Reuse Logic)
      double cgst = 0, sgst = 0, igst = 0;
      String supplierState = _appSettings?.state ?? '';
      if (taxAmount > 0) {
        if (supplierState.isNotEmpty && supplierState.toLowerCase() == _selectedState.toLowerCase()) {
           cgst = taxAmount / 2;
           sgst = taxAmount / 2;
        } else {
           igst = taxAmount;
        }
      }

      // Payments
      List<PaymentRecord> payments = [];
      double totalAdvance = 0;
      for (int i = 0; i < _paymentAmounts.length; i++) {
          final val = double.tryParse(_paymentAmounts[i].text) ?? 0;
          if (val > 0) {
            payments.add(PaymentRecord(
              date: _paymentDates[i],
              amount: val,
              mode: _paymentModes[i],
            ));
            totalAdvance += val;
          }
      }

      final updatedBill = widget.bill.copyWith(
        customerName: _customerController.text,
        clientId: _clientIdController.text, // Can edit client ID? Sure.
        serviceName: items.isNotEmpty ? items.first.description : 'Service',
        billDate: _billDate,
        price: subTotal,
        taxPercentage: taxPercentage,
        taxAmount: taxAmount,
        cgstAmount: cgst,
        sgstAmount: sgst,
        igstAmount: igst,
        advanceAmount: totalAdvance,
        totalAmount: subTotal + taxAmount,
        paymentStatus: (totalAdvance >= (subTotal + taxAmount)) ? 'Paid' : (totalAdvance > 0 ? 'Partial' : 'Pending'),
        paymentReceivedDate: totalAdvance >= (subTotal + taxAmount) ? DateTime.now() : null,
        whatsappNumber: _whatsappController.text.length == 10 ? '91${_whatsappController.text}' : _whatsappController.text,
        clientAddress: _addressController.text,
        invoiceNumber: _invoiceNoController.text, // Allowing edit of invoice number? Maybe not wise, but user might need to fix it.
        items: items,
        payments: payments,
        placeOfSupply: _selectedState,
        gstNumber: _gstNumberController.text.trim(),
        ewayBillNo: _showEwayBillDetails ? _ewayBillNoController.text.trim() : null,
        vehicleNo: _showEwayBillDetails ? _vehicleNoController.text.trim() : null,
        transportMode: _showEwayBillDetails && _selectedTransportMode.isNotEmpty ? _selectedTransportMode : null,
        shippingAddress: _shipToDifferentAddress && _shippingAddressController.text.isNotEmpty ? _shippingAddressController.text : null,
        shippingName: _shipToDifferentAddress && _shippingNameController.text.isNotEmpty ? _shippingNameController.text : null,
      );

      // 3. Update Bill
      await _billsService.updateBill(updatedBill);

      // 4. Deduct New Stock
      for (var item in items) {
        if (item.productId != null) {
          try {
            await _productService.updateStock(item.productId!, -item.quantity);
          } catch (_) {}
        }
      }

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Invoice updated successfully');
        Navigator.pop(context, true); // Return true to refresh
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Error updating bill: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // .. UI Build similar to CreateBill ..
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Invoice'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildCard([
                 _buildTextField(_invoiceNoController, 'Invoice Number', Icons.receipt, readOnly: true), // Keep Invoice No ReadOnly
                 const SizedBox(height: 16),
                 _buildTextField(_customerController, 'Customer Name', Icons.person),
                 const SizedBox(height: 16),
                 _buildTextField(_whatsappController, 'WhatsApp Number', Icons.phone),
                 const SizedBox(height: 16),
                 _buildTextField(_addressController, 'Address', Icons.location_on),
                 const SizedBox(height: 16),
                 _buildTextField(_gstNumberController, 'GSTIN', Icons.assignment),
               ]),
               
               const SizedBox(height: 16),
               
               // Items Section
               _buildCard([
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _startScanning),
                    ],
                  ),
                  ...List.generate(_serviceControllers.length, (index) => _buildItemRow(index)),
                  TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add Item')),
               ]),

               const SizedBox(height: 16),

               // Totals
               _buildCard([
                  _buildTextField(_taxController, 'Tax (%)', Icons.percent, onChanged: (_) => setState((){})),
                  const SizedBox(height: 16),
                  
                  // Summary
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sub Total'), Text('₹${_calculateSubTotal().toStringAsFixed(2)}')]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tax Amount'), Text('₹${_calculateTaxAmount().toStringAsFixed(2)}')]),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('₹${_calculateTotal().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                  ]),
               ]),

               const SizedBox(height: 24),
               
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton(
                   onPressed: _isSaving ? null : _saveBill,
                   style: ElevatedButton.styleFrom(
                     padding: const EdgeInsets.all(16),
                     backgroundColor: AppColors.primary,
                   ),
                   child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Update Invoice'),
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool readOnly = false, Function(String)? onChanged}) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (val) => val != null && val.isEmpty && !readOnly ? 'Required' : null, // Simple validation
    );
  }

  Widget _buildItemRow(int index) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: _buildTextField(_serviceControllers[index], 'Product', Icons.shopping_bag)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildTextField(_amountControllers[index], 'Amount', Icons.currency_rupee, readOnly: true)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeItem(index)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField(_quantityControllers[index], 'Qty', Icons.numbers, onChanged: (_) => _calculateItemTotal(index))),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(_unitPriceControllers[index], 'Price', Icons.price_change, onChanged: (_) => _calculateItemTotal(index))),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedUnits[index],
                  items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setState(() => _selectedUnits[index] = v!),
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8)),
                )
              ),
            ],
          ),
          const Divider(),
        ],
      );
  }
}

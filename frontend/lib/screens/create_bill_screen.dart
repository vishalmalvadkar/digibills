import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../services/bills_service.dart';

import '../theme/app_colors.dart';
import 'package:flutter/services.dart'; 
import '../utils/validators.dart'; // NEW
import '../utils/snackbar_helper.dart'; // NEW
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/client_service.dart'; // NEW
import 'mou_screen.dart'; // NEW
import '../widgets/scanner_overlay.dart';
import '../services/product_service.dart';
import '../models/product_model.dart';
import '../services/settings_service.dart'; // NEW
import 'dart:async'; // NEW for Debounce
import '../models/settings_model.dart'; // NEW
import '../models/client_model.dart';
import '../providers/shell_provider.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import '../core/responsive/breakpoints.dart';
import '../core/responsive/max_width_container.dart';
import '../widgets/license_scope.dart';
import '../l10n/app_localizations.dart'; 
import '../services/sequence_service.dart'; // NEW
import 'bill_view_screen.dart'; // Navigate after save

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();

  final _customerController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  final _taxController = TextEditingController(); // Start empty to fetch from settings
  final _clientIdController = TextEditingController(); // NEW
  final _gstNumberController = TextEditingController(); // NEW
  final _cityController = TextEditingController(); // NEW
  String _selectedState = ''; // NEW
  AppSettings? _appSettings; // NEW: Store settings for logic
  
  bool _showEwayBillDetails = false; // NEW
  bool _thresholdToastShown = false; // NEW
  final _ewayBillNoController = TextEditingController(); // NEW
  final _vehicleNoController = TextEditingController(); // NEW
  String _selectedTransportMode = 'Road'; // NEW
  final List<String> _transportModes = ['Road', 'Rail', 'Air', 'Ship']; 

  // Data Lists
  List<BillModel> _allBills = [];
  List<ProductModel> _allProducts = [];
  final List<String> _unitOptions = ['qty', 'kg', 'g', 'L', 'ml', 'm', 'cm', 'pcs', 'box', 'pkt', 'doz', 'set'];

  // Item Controllers
  final List<TextEditingController> _serviceControllers = [];
  final List<TextEditingController> _amountControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _unitPriceControllers = [];
  final List<TextEditingController> _hsnControllers = [];
  String _invoiceHsnType = 'HSN'; // NEW: Global for invoice
  final List<String> _selectedUnits = [];
  final List<String?> _productIds = [];

  // Shipping
  bool _shipToDifferentAddress = false;
  final _shippingNameController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  
  // Payment Installments
  final List<TextEditingController> _paymentAmounts = [];
  final List<DateTime> _paymentDates = [];
  final List<String> _paymentModes = [];
  
  DateTime _billDate = DateTime.now();
  Timer? _debounce;


  @override
  void initState() {
    super.initState();
    _addItem(); // Start with one empty item
    _initData();
    
    // Listen to WhatsApp for autofill
    _whatsappController.addListener(_onWhatsAppChanged);
  }

  void _onWhatsAppChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _lookupClientByPhone(_whatsappController.text);
    });
  }

  void _lookupClientByPhone(String phone) {
    if (phone.length < 4) return; // Wait for at least 4 digits
    
    // Find client with this phone
    // Normalize? For now exact match or contains
    final existingBillIndex = _allBills.indexWhere((b) => b.whatsappNumber == phone || b.whatsappNumber.endsWith(phone));
    
    if (existingBillIndex != -1) {
       final existing = _allBills[existingBillIndex];
       if (mounted) {
         setState(() {
           // Only autofill if other fields are empty to avoid overwriting user edits
           if (_customerController.text.isEmpty) _customerController.text = existing.customerName;
           if (_clientIdController.text.isEmpty) _clientIdController.text = existing.clientId;
           if (_addressController.text.isEmpty) _addressController.text = existing.clientAddress;
           if (_cityController.text.isEmpty) _cityController.text = existing.clientCity ?? ''; // NEW
           
           if (_selectedState.isEmpty) _selectedState = existing.placeOfSupply;
           if (_gstNumberController.text.isEmpty) _gstNumberController.text = existing.gstNumber ?? '';
         });
       }
    }
  }

  // ... (Dispose, etc)

  @override
  void dispose() {
    _customerController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _invoiceNoController.dispose();
    _taxController.dispose();
    _clientIdController.dispose();
    _gstNumberController.dispose(); // NEW
    _cityController.dispose(); // NEW
    // ...
    // Dispose other controllers
    for (var c in _serviceControllers) c.dispose();
    for (var c in _amountControllers) c.dispose();
    for (var c in _quantityControllers) c.dispose(); // NEW
    for (var c in _unitPriceControllers) c.dispose(); // NEW
    // Dispose payment controllers
    for (var c in _paymentAmounts) c.dispose();
    _debounce?.cancel(); // NEW
    _ewayBillNoController.dispose();
    _vehicleNoController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _allProducts = await _productService.getProducts();
      _allBills = await _billsService.getUserRelevantBills(user.id);
      
      // Load Settings
      _appSettings = await SettingsService().fetchSettings();
      if (_appSettings != null) {
        // Auto-populate GST if empty or '0'
        if (_taxController.text.isEmpty || _taxController.text == '0') {
           _taxController.text = _appSettings!.defaultGstRate.toStringAsFixed(0);
        }
      }
      if (mounted) setState(() {});
      
      _generateInvoiceNumber();
      _checkMouStatus();
    }
  }

  Future<void> _generateInvoiceNumber() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
       final nextInv = await SequenceService().peekNextInvoiceNumber(
          user.id, 
          _appSettings?.invoicePrefix ?? 'INV-', 
          _appSettings?.invoiceStartNumber ?? 1,
       );
       if (mounted) {
         setState(() {
           _invoiceNoController.text = nextInv;
         });
       }
    }
  }

  void _addPayment() {
    setState(() {
      _paymentAmounts.add(TextEditingController());
      _paymentDates.add(DateTime.now());
      _paymentModes.add('Cash');
    });
  }

  void _removePayment(int index) {
    setState(() {
      _paymentAmounts[index].dispose();
      _paymentAmounts.removeAt(index);
      _paymentDates.removeAt(index);
      _paymentModes.removeAt(index);
    });
  }

  double _calculateAdvanceTotal() {
    double total = 0;
    for (var c in _paymentAmounts) {
      total += double.tryParse(c.text) ?? 0;
    }
    return total;
  }


  void _generateClientId(String name) {
    if (name.isEmpty) {
      if (mounted) {
        setState(() {
          // Don't clear everything effectively on backspace, irritating for user
          // Just clear ID if empty
          // _clientIdController.clear(); 
        });
      }
      return;
    }

    // Check if customer already exists (Case Insensitive Match)
    final existingBillIndex = _allBills.indexWhere((b) => b.customerName.toLowerCase() == name.toLowerCase());
    
    if (existingBillIndex != -1) {
      // Found Existing Customer -> Autofill Details
      final existing = _allBills[existingBillIndex];
      setState(() {
        _clientIdController.text = existing.clientId;
        // User asked to "impliment the auto filling feature", so yes.
        if (_whatsappController.text.isEmpty) _whatsappController.text = existing.whatsappNumber;
        if (_addressController.text.isEmpty) _addressController.text = existing.clientAddress;
        if (_cityController.text.isEmpty) _cityController.text = existing.clientCity ?? ''; // NEW
        
        // Auto-fill State and GST
        _selectedState = existing.placeOfSupply;
        _gstNumberController.text = existing.gstNumber ?? '';
      });
    } else {
      // New Customer -> Generate ID
      final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final prefix = cleanName.length >= 3 ? cleanName.substring(0, 3) : cleanName.padRight(3, 'X');
      final hash = name.hashCode.abs().toString().padRight(4, '0');
      final suffix = hash.substring(hash.length - 4);
      
      setState(() {
        _clientIdController.text = 'CLI-$prefix-$suffix';
      });
    }
  }

  void _addItem() {
    setState(() {
      _serviceControllers.add(TextEditingController());
      _amountControllers.add(TextEditingController(text: '0'));
      _quantityControllers.add(TextEditingController(text: '1')); // Default 1
      _unitPriceControllers.add(TextEditingController());
      _hsnControllers.add(TextEditingController()); // NEW
      _selectedUnits.add('qty'); // Default unit
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
        _hsnControllers[index].dispose(); // NEW
        
        _serviceControllers.removeAt(index);
        _amountControllers.removeAt(index);
        _quantityControllers.removeAt(index);
        _unitPriceControllers.removeAt(index);
        _hsnControllers.removeAt(index); // NEW
        _selectedUnits.removeAt(index);
        _productIds.removeAt(index); 
      });
    }
  }

  void _calculateItemTotal(int index) {
    double qty = double.tryParse(_quantityControllers[index].text) ?? 0;
    double price = double.tryParse(_unitPriceControllers[index].text) ?? 0;
    double total = qty * price;
    _amountControllers[index].text = total.toStringAsFixed(2);
    
    // Trigger UI update for Grand Total
    setState(() {}); 
  }

  double _calculateSubTotal() {
    double subTotal = 0;
    for (var c in _amountControllers) {
      if (c.text.isNotEmpty) {
        subTotal += double.tryParse(c.text) ?? 0;
      }
    }
    return subTotal;
  }

  double _calculateTaxAmount() {
    double subTotal = _calculateSubTotal();
    double taxPercent = double.tryParse(_taxController.text) ?? 0;
    return (subTotal * taxPercent) / 100;
  }

  double _calculateTotal() {
    final total = _calculateSubTotal() + _calculateTaxAmount();
    _checkEwayBillThreshold(total);
    return total;
  }

  void _checkEwayBillThreshold(double total) {
    if (total >= 50000 && !_thresholdToastShown) {
      _thresholdToastShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.showInfo(
          context, 
          'Invoice exceeds ₹50,000. You might need to generate an e-Way Bill.',
        );
      });
    } else if (total < 50000) {
      _thresholdToastShown = false; // Reset if they reduce the total
    }
  }

  String _paymentStatus = 'Pending';
  bool _isSaving = false;

  final BillsService _billsService = BillsService();
  final ProductService _productService = ProductService();

  Future<void> _startScanning() async {
    final String? code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerOverlay()),
    );

    if (code != null) {
      _handleScannedCode(code);
    }
  }

  Future<void> _handleScannedCode(String scancode) async {
    // 1. Check if product already in current invoice items
    int existingItemIndex = -1;
    for (int i = 0; i < _serviceControllers.length; i++) {
      // We look for a match in the description or ideally we'd store the scancode in the BillItem
      // For now, let's just check if we have a match in the product service cache
      // Better: Store the scancode in a persistent Map for the current session
    }

    // 2. Fetch product from DB
    final product = await _productService.getProductByScanCode(scancode);

    if (product != null) {
      _addProductToInvoice(product);
    } else {
      // 3. Not found? Show Quick Add
      _showQuickAddProductDialog(scancode);
    }
  }

  void _addProductToInvoice(ProductModel product) {
    setState(() {
      // Search if name already exists in items to increment quantity
      int existingIndex = _serviceControllers.indexWhere((c) => c.text == product.name);
      
      if (existingIndex != -1) {
        // Increment quantity
        double currentQty = double.tryParse(_quantityControllers[existingIndex].text) ?? 1;
        _quantityControllers[existingIndex].text = (currentQty + 1).toString();
        _productIds[existingIndex] = product.productId; 
        if (product.hsnCode != null) {
          _hsnControllers[existingIndex].text = product.hsnCode!; // NEW
        }
        _calculateItemTotal(existingIndex);
      } else {
        // Add new item
        // Check if first item is empty
        if (_serviceControllers.length == 1 && _serviceControllers[0].text.isEmpty) {
          _serviceControllers[0].text = product.name;
          _unitPriceControllers[0].text = product.unitPrice.toString();
          _quantityControllers[0].text = '1';
          _selectedUnits[0] = product.unit;
          _productIds[0] = product.productId; 
          if (product.hsnCode != null) {
            _hsnControllers[0].text = product.hsnCode!; // NEW
          }
          _calculateItemTotal(0);
        } else {
          _serviceControllers.add(TextEditingController(text: product.name));
          _amountControllers.add(TextEditingController(text: product.unitPrice.toString()));
          _quantityControllers.add(TextEditingController(text: '1'));
          _unitPriceControllers.add(TextEditingController(text: product.unitPrice.toString()));
          _hsnControllers.add(TextEditingController(text: product.hsnCode ?? '')); // NEW
          _selectedUnits.add(product.unit);
          _productIds.add(product.productId); 
          _calculateItemTotal(_serviceControllers.length - 1);
        }
      }
    });

    // Stock Alert Notification
    if (product.isStockTracked && product.stockQuantity <= product.alertThreshold) {
      SnackbarHelper.showWarning(
        context, 
        AppLocalizations.of(context)?.lowStockWarning(product.name, product.stockQuantity.toInt().toString(), product.unit) ?? 
            'Low Stock for ${product.name}! Only ${product.stockQuantity.toInt()} ${product.unit} remaining.'
      );
    } else {
      SnackbarHelper.showSuccess(context, AppLocalizations.of(context)?.productAdded(product.name) ?? '${product.name} added');
    }
  }

  void _showQuickAddProductDialog(String scancode) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.newProductFound ?? 'New Product Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${AppLocalizations.of(context)?.barcode ?? "Barcode"}: $scancode', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)?.productName ?? 'Product Name', border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppLocalizations.of(context)?.sellingPrice ?? 'Selling Price', border: const OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
              
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;

              final newProduct = ProductModel(
                tenantId: user.id,
                name: nameCtrl.text,
                scancode: scancode,
                unitPrice: double.tryParse(priceCtrl.text) ?? 0,
              );

              try {
                await _productService.saveProduct(newProduct);
                if (mounted) {
                  Navigator.pop(ctx);
                  _addProductToInvoice(newProduct);
                }
              } catch (e) {
                if (mounted) SnackbarHelper.showError(context, 'Error: $e');
              }
            }, 
            child: Text(AppLocalizations.of(context)?.saveAndAdd ?? 'Save & Add')
          ),
        ],
      ),
    );
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      List<BillItem> items = [];
      for (int i = 0; i < _serviceControllers.length; i++) {
        items.add(BillItem(
          productId: _productIds[i], // NEW: Store link
          description: _serviceControllers[i].text.trim(),
          amount: double.tryParse(_amountControllers[i].text.trim()) ?? 0,
          quantity: double.tryParse(_quantityControllers[i].text.trim()) ?? 1,
          unit: _selectedUnits[i],
          unitPrice: double.tryParse(_unitPriceControllers[i].text.trim()) ?? 0,
          hsnCode: _hsnControllers[i].text.trim().isNotEmpty ? _hsnControllers[i].text.trim() : null, // NEW
          hsnType: _invoiceHsnType, // Global Selection
        ));
      }

      double subTotal = 0;
      for (var item in items) {
        subTotal += item.amount;
      }

      final taxPercentage = double.tryParse(_taxController.text) ?? 0;
      final taxAmount = (subTotal * taxPercentage) / 100; // Calculate GST

      // Collect Payments
      List<PaymentRecord> payments = [];
      double totalAdvance = 0;
      
      for (int i = 0; i < _paymentAmounts.length; i++) {
          final amount = double.tryParse(_paymentAmounts[i].text) ?? 0;
          if (amount > 0) {
            payments.add(PaymentRecord(
              date: _paymentDates[i],
              amount: amount,
              mode: _paymentModes[i],
            ));
            totalAdvance += amount;
          }
      }

      double cgst = 0;
      double sgst = 0;
      double igst = 0;

      // Determine Tax Split Logic
      // 1. We need the "Business State" (Place of Supplier)
      // 2. We have "Client State" (Place of Supply) -> _selectedState
      
      String supplierState = _appSettings?.state ?? '';
      
      if (taxAmount > 0) {
         // Determine if Intra-State (CGST+SGST) or Inter-State (IGST)
         // Logic: If both states are present and same -> Intra. Else -> Inter.
         if (supplierState.isNotEmpty && 
             _selectedState.isNotEmpty && 
             supplierState.toLowerCase() == _selectedState.toLowerCase()) {
             cgst = taxAmount / 2;
             sgst = taxAmount / 2;
         } else {
             igst = taxAmount;
         }
      }

      // GENERATE FINAL INVOICE NUMBER ATOMICALLY
      String finalInvoiceNumber = _invoiceNoController.text;
      
      try {
         final user = Supabase.instance.client.auth.currentUser;
         if (user != null) {
             final actualNumber = await SequenceService().getNextInvoiceNumber(
                user.id, 
                _appSettings?.invoicePrefix ?? 'INV-', 
                _appSettings?.invoiceStartNumber ?? 1
             );
             finalInvoiceNumber = actualNumber; 
         }
      } catch (e) {
         SnackbarHelper.showError(context, 'Failed to generate compliant invoice number. Please try again.');
         setState(() => _isSaving = false);
         return;
      }

      final bill = BillModel(
        billId: '', // Service will generate UUID
        customerName: _customerController.text,
        clientId: _clientIdController.text,
        serviceName: items.isNotEmpty ? items.first.description : 'Service', 
        billDate: _billDate,
        price: subTotal, 
        taxPercentage: taxPercentage,
        taxAmount: taxAmount, 
        cgstAmount: cgst, // NEW
        sgstAmount: sgst, // NEW
        igstAmount: igst, // NEW
        advanceAmount: totalAdvance,
        totalAmount: subTotal + taxAmount,
        paymentStatus: (totalAdvance >= (subTotal + taxAmount)) 
            ? 'Paid' 
            : (totalAdvance > 0 ? 'Partial' : 'Pending'),
        paymentReceivedDate: totalAdvance >= (subTotal + taxAmount) ? DateTime.now() : null,
        whatsappNumber: _whatsappController.text.length == 10 
            ? '91${_whatsappController.text}' 
            : _whatsappController.text,
        createdAt: DateTime.now(),
        clientAddress: _addressController.text,
        invoiceNumber: _invoiceNoController.text,
        items: items,
        payments: payments,
        tenantId: '', 
        placeOfSupply: _selectedState, 
        gstNumber: _gstNumberController.text.trim(), 
        ewayBillNo: _showEwayBillDetails ? _ewayBillNoController.text.trim() : null,
        vehicleNo: _showEwayBillDetails ? _vehicleNoController.text.trim() : null,
        transportMode: _showEwayBillDetails && _selectedTransportMode.isNotEmpty ? _selectedTransportMode : null,
        shippingAddress: _shipToDifferentAddress && _shippingAddressController.text.isNotEmpty ? _shippingAddressController.text : null,
        shippingName: _shipToDifferentAddress && _shippingNameController.text.isNotEmpty ? _shippingNameController.text : null,
        clientCity: _cityController.text, // NEW
      );

      final newBillId = await _billsService.addBill(bill); // CHANGED: Returns ID

      // STOCK DEDUCTION
      for (var item in items) {
        if (item.productId != null) {
          try {
            await _productService.updateStock(item.productId!, -item.quantity);
          } catch (e) {
            print('Stock deduction failed for ${item.description}: $e');
            // We don't block the bill saving for stock deduction errors
          }
        }
      }

      // Reset Form
      if (mounted) {
        setState(() {
          _customerController.clear();
          _whatsappController.clear();
          _addressController.clear();
          _taxController.text = '0'; 
          _clientIdController.clear(); 
          _gstNumberController.clear();
          _selectedState = '';
          _ewayBillNoController.clear();
          _vehicleNoController.clear();
          _showEwayBillDetails = false;
          _thresholdToastShown = false;
          _cityController.clear(); // NEW
          
          for (var c in _serviceControllers) c.dispose();
          for (var c in _amountControllers) c.dispose();
          for (var c in _quantityControllers) c.dispose();
          for (var c in _unitPriceControllers) c.dispose();
          for (var c in _hsnControllers) c.dispose(); // NEW
          _serviceControllers.clear();
          _amountControllers.clear();
          _quantityControllers.clear();
          _unitPriceControllers.clear();
          _hsnControllers.clear();
          _selectedUnits.clear();
          _productIds.clear(); // NEW

          for (var c in _paymentAmounts) c.dispose();
          _paymentAmounts.clear();
          _paymentModes.clear();
          _paymentDates.clear();

          _addItem(); 
          _generateInvoiceNumber();

          _paymentStatus = 'Pending';
          _billDate = DateTime.now();
        });
      }

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Bill created successfully');
        // Navigate to the newly created bill
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BillViewScreen(billId: newBillId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Fallback to standard error
        SnackbarHelper.showError(context, 'Error creating bill: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _checkMouStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Check if user is a client (by role in metadata or just try fetch client)
       // Optimization: Only check if we suspect they are a client?
       // For now, let's try to fetch client record.
       final client = await ClientService().getClient(user.id);
       
       if (client != null) {
          // It is a client
          if (!client.mouAccepted) {
            if (mounted) _showMouBlockDialog();
          }
       }
    }
  }

  void _showMouBlockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('MOU Pending'),
        content: const Text('You must accept the Memorandum of Understanding (MOU) before creating bills.'),
        actions: [
          TextButton(
            onPressed: () {
               Navigator.pop(ctx); 
               Navigator.pop(context); 
            },
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () async {
               Navigator.pop(ctx);
               final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const MouScreen()));
               if (result == true) {
                 _checkMouStatus();
               } else {
                 if (mounted) Navigator.pop(context); // Go back if they cancelled MOU
               }
            }, 
            child: const Text('Sign MOU')
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true, // Prevents bottom overflow when virtual keyboard opens
      appBar: Responsive.isDesktop(context) 
        ? null 
        : AppBar(
            title: Text(AppLocalizations.of(context)?.newBillTitle ?? 'New Bill'),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textDark,
            elevation: 0,
            centerTitle: true, 
            leading: const BackButton(),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppColors.border, height: 1),
            ),
          ),
      body: MaxWidthContainer.form(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24), // Reduced padding
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Title Removed (Moved to AppBar)
              
              Text(
                AppLocalizations.of(context)?.createInvoiceSubtitle ?? 'Create a new invoice for a customer',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16), // Reduced padding from 24
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Customer Name with Autocomplete
                    _buildTextField(
                      _customerController, 
                      AppLocalizations.of(context)?.customerNameLabel ?? 'Customer Name', 
                      Icons.person_outline,
                      validator: (value) => _customerController.text.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 12),

                    // WhatsApp Number (Moved Here)
                    _buildTextField(
                      _whatsappController, 
                      AppLocalizations.of(context)?.contactNumber ?? 'WhatsApp Number', 
                      Icons.phone_android, 
                      isNumber: true,
                      inputFormatters: [LengthLimitingTextInputFormatter(10)],
                      validator: Validators.validateMobile,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 12),
                    
                    // Client ID with Autocomplete
                    _buildTextField(
                      _clientIdController, 
                      AppLocalizations.of(context)?.clientId ?? 'Client ID', 
                      Icons.badge_outlined,
                      readOnly: false,
                    ),
                    /*
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<BillModel>.empty();
                            }
                            final query = textEditingValue.text.toLowerCase();
                            final seen = <String>{};
                            return _allBills.where((bill) {
                              final id = bill.clientId.toLowerCase();
                              if (id.contains(query) && !seen.contains(id)) {
                                seen.add(id);
                                return true;
                              }
                              return false;
                            });
                          },
                          displayStringForOption: (BillModel option) => option.clientId,
                          onSelected: (BillModel selection) {
                             setState(() {
                              _clientIdController.text = selection.clientId;
                              _customerController.text = selection.customerName; 
                              _whatsappController.text = selection.whatsappNumber;
                              _addressController.text = selection.clientAddress;
                              _cityController.text = selection.clientCity ?? ''; // NEW
                              
                              _selectedState = selection.placeOfSupply;
                              _gstNumberController.text = selection.gstNumber ?? '';
                            });
                          },
                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                             if (textEditingController.text != _clientIdController.text) {
                               textEditingController.value = textEditingController.value.copyWith(
                                 text: _clientIdController.text,
                                 selection: TextSelection.collapsed(offset: _clientIdController.text.length),
                               );
                             }
                             return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                onChanged: (val) => _clientIdController.text = val,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)?.clientId ?? 'Client ID',
                                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textGrey, size: 20),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                                ),
                                validator: (value) => _clientIdController.text.isEmpty ? 'Required' : null,
                             );
*/
                    const SizedBox(height: 12),
                                          
                    // Address
                    _buildTextField(
                      _addressController, 
                      AppLocalizations.of(context)?.address ?? 'Address', 
                      Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),

                    // City (NEW)
                    _buildTextField(
                      _cityController, 
                      'City', 
                      Icons.location_city,
                    ),
                    const SizedBox(height: 12),

                    // Invoice No (Read Only)
                    _buildTextField(_invoiceNoController, AppLocalizations.of(context)?.invoiceNo ?? 'Invoice No', Icons.receipt, readOnly: true),
                    const SizedBox(height: 12),

                    // State Dropdown (NEW)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedState.isNotEmpty ? _selectedState : null,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.placeOfSupply ?? 'Client State (Place of Supply)',
                        prefixIcon: const Icon(Icons.map_outlined, color: AppColors.textGrey, size: 20),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      items: [
                        'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 
                        'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 
                        'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 
                        'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 
                        'Uttarakhand', 'West Bengal', 'Delhi', 'Jammu & Kashmir', 'Ladakh', 'Puducherry', 'Chandigarh',
                        'Dadra and Nagar Haveli and Daman and Diu', 'Andaman and Nicobar Islands', 'Lakshadweep'
                      ].map((state) => DropdownMenuItem(
                        value: state, 
                        child: Text(state, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedState = val);
                        }
                      },
                      validator: (val) {
                         if (val == null || val.isEmpty) return 'Required for GST';
                         return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // GST Number (NEW)
                    _buildTextField(
                      _gstNumberController, 
                      AppLocalizations.of(context)?.gstNumber ?? 'Client GSTIN (Optional)', 
                      Icons.assignment_outlined, 
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) => Validators.validateGSTIN(val, isOptional: true), // Purchaser Optional
                    ),
                    const SizedBox(height: 16),

                    // SHIPPED TO SECTION
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        title: const Text('Ship to different address?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        value: _shipToDifferentAddress,
                        onChanged: (val) {
                          setState(() {
                            _shipToDifferentAddress = val;
                            if (!val) {
                              _shippingNameController.clear();
                              _shippingAddressController.clear();
                            } else {
                              // Auto fill from customer if empty
                              if (_shippingNameController.text.isEmpty) _shippingNameController.text = _customerController.text;
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_shipToDifferentAddress) ...[
                      const SizedBox(height: 8),
                      _buildTextField(
                        _shippingNameController,
                        'Shipping Name',
                        Icons.person_pin_circle_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _shippingAddressController,
                        'Shipping Address',
                        Icons.local_shipping_outlined,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Date Picker (Moved below Address)
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _billDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  onSurface: AppColors.textDark,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedDate != null) {
                          setState(() {
                            _billDate = pickedDate;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: AppColors.textGrey, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('dd MMM yyyy').format(_billDate),
                              style: const TextStyle(color: AppColors.textDark, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Multiple Items Section
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.billItems ?? 'Items',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Premium Sliding Toggle for HSN/SAC
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _invoiceHsnType = _invoiceHsnType == 'HSN' ? 'SAC' : 'HSN';
                                  });
                                },
                                child: Container(
                                  width: 100,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Stack(
                                    children: [
                                      AnimatedAlign(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                        alignment: _invoiceHsnType == 'HSN' ? Alignment.centerLeft : Alignment.centerRight,
                                        child: Container(
                                          width: 50,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary.withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: Text(
                                                'HSN',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _invoiceHsnType == 'HSN' ? Colors.white : AppColors.textGrey,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: Text(
                                                'SAC',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _invoiceHsnType == 'SAC' ? Colors.white : AppColors.textGrey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _startScanning,
                                icon: const Icon(Icons.qr_code_scanner, size: 18, color: Colors.orange),
                                label: Text(AppLocalizations.of(context)?.scanBarcode ?? 'Scan', style: const TextStyle(color: Colors.orange)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  minimumSize: const Size(40, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                label: Text(AppLocalizations.of(context)?.addItem ?? 'Add Item'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  minimumSize: const Size(40, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: List.generate(_serviceControllers.length, (index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            key: ValueKey(index),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Service / Item (Full Width)
                              Autocomplete<ProductModel>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<ProductModel>.empty();
                                  }
                                  final query = textEditingValue.text.toLowerCase();
                                  return _allProducts.where((p) => p.name.toLowerCase().contains(query));
                                },
                                displayStringForOption: (ProductModel p) => p.name,
                                onSelected: (ProductModel p) {
                                  setState(() {
                                    _serviceControllers[index].text = p.name;
                                    _unitPriceControllers[index].text = p.unitPrice.toString();
                                    _selectedUnits[index] = p.unit;
                                    _hsnControllers[index].text = p.hsnCode ?? '';
                                    _productIds[index] = p.productId; 
                                    _calculateItemTotal(index);
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  if (controller.text != _serviceControllers[index].text && _serviceControllers[index].text.isNotEmpty) {
                                    controller.text = _serviceControllers[index].text;
                                  }
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onChanged: (val) {
                                      _serviceControllers[index].text = val;
                                    },
                                    decoration: InputDecoration(
                                      labelText: AppLocalizations.of(context)?.itemDescription ?? 'Description',
                                      prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.textGrey, size: 20),
                                      filled: true,
                                      fillColor: AppColors.background,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              
                              // HSN/SAC Input
                              _buildTextField(
                                _hsnControllers[index], 
                                _invoiceHsnType, // Dynamic Label: HSN or SAC
                                Icons.confirmation_number_outlined, 
                                isNumber: true,
                              ),
                              const SizedBox(height: 12),

                              // Row 2: Rate + Qty
                              Row(
                                children: [
                                  // Unit Price
                                  Expanded(
                                    flex: 1, 
                                    child: _buildTextField(
                                      _unitPriceControllers[index], 
                                      AppLocalizations.of(context)?.rate ?? 'Rate', 
                                      Icons.currency_rupee, 
                                      isNumber: true,
                                      onChanged: (_) => _calculateItemTotal(index),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Quantity
                                  Expanded(
                                    flex: 1, 
                                    child: TextFormField(
                                      controller: _quantityControllers[index],
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => _calculateItemTotal(index),
                                      decoration: InputDecoration(
                                        labelText: AppLocalizations.of(context)?.quantity ?? 'Qty',
                                        prefixIcon: const Icon(Icons.numbers, color: AppColors.textGrey, size: 20),
                                        filled: true,
                                        fillColor: AppColors.background,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                        suffixIcon: Container(
                                          margin: const EdgeInsets.only(right: 4),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedUnits[index],
                                              items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  _selectedUnits[index] = val ?? 'qty';
                                                });
                                              },
                                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textGrey),
                                              selectedItemBuilder: (context) {
                                                return _unitOptions.map((u) {
                                                  return Center(child: Text(u, style: const TextStyle(fontSize: 13, color: AppColors.textDark)));
                                                }).toList();
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Row 3: Amount (Full Width) + Delete (Icon Only)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      _amountControllers[index], 
                                      AppLocalizations.of(context)?.amount ?? 'Amount', 
                                      Icons.currency_rupee, 
                                      isNumber: true,
                                      readOnly: true,
                                    ),
                                  ),
                                  if (_serviceControllers.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                      onPressed: () => _removeItem(index),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _taxController, 
                            AppLocalizations.of(context)?.taxRate ?? 'Tax / GST %', 
                            Icons.percent, 
                            isNumber: true,
                            onChanged: (_) => setState(() {}),
                            validator: Validators.validateTax,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Payments Section (Multiple Installments)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)?.paymentDetails ?? 'Payments (Advance/Installments)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addPayment, // defined below
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: Text(AppLocalizations.of(context)?.addPayment ?? 'Add Payment'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (_paymentAmounts.isEmpty)
                      Text(AppLocalizations.of(context)?.noPaymentsAdded ?? 'No payments added yet.', style: const TextStyle(color: AppColors.textGrey, fontStyle: FontStyle.italic))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _paymentAmounts.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                // Amount
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _paymentAmounts[index],
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}), // Recalc totals
                                    decoration: InputDecoration(
                                      labelText: AppLocalizations.of(context)?.amount ?? 'Amount',
                                      prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.textGrey, size: 16),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      filled: true,
                                      fillColor: AppColors.background,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Mode Dropdown
                                Expanded(
                                  flex: 3, 
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _paymentModes[index],
                                    items: ['Cash', 'UPI', 'Cheque', 'Net Banking'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _paymentModes[index] = val ?? 'Cash';
                                      });
                                    },
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                                      filled: true,
                                      fillColor: AppColors.background,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Date Icon Button
                                IconButton(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _paymentDates[index],
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _paymentDates[index] = picked;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, color: AppColors.primary),
                                  tooltip: DateFormat('dd MMM').format(_paymentDates[index]),
                                ),

                                // Delete
                                IconButton(
                                  onPressed: () => _removePayment(index),
                                  icon: const Icon(Icons.close, color: AppColors.error),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 24),
                    
                    // e-Way Bill Section (NEW)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile(
                            title: Text(
                              AppLocalizations.of(context)?.transportDetails ?? 'Add e-Way Bill Details',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              AppLocalizations.of(context)?.manualEwayBillOption ?? 'Manual Option A: Enter details from GST portal',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _showEwayBillDetails,
                            onChanged: (val) => setState(() => _showEwayBillDetails = val),
                            activeColor: Colors.orange,
                            contentPadding: EdgeInsets.zero,
                          ),
                          ),
                          if (_showEwayBillDetails) ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              _ewayBillNoController, 
                              AppLocalizations.of(context)?.ewayBillNo ?? 'e-Way Bill Number', 
                              Icons.pin_outlined,
                              isNumber: true,
                              validator: (val) {
                                if (_showEwayBillDetails && (val == null || val.length != 12)) {
                                  return 'Enter 12-digit EWB Number';
                                }
                                return null;
                              }
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              _vehicleNoController, 
                              AppLocalizations.of(context)?.vehicleNo ?? 'Vehicle Number', 
                              Icons.local_shipping_outlined,
                              textCapitalization: TextCapitalization.characters,
                              validator: (val) {
                                if (_showEwayBillDetails && (val == null || val.isEmpty)) {
                                  return 'Required for EWB';
                                }
                                return null;
                              }
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedTransportMode,
                              items: _transportModes.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) => setState(() => _selectedTransportMode = val ?? 'Road'),
                              decoration: InputDecoration(
                                labelText: 'Transport Mode',
                                prefixIcon: const Icon(Icons.alt_route_outlined, color: AppColors.textGrey, size: 20),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppLocalizations.of(context)?.subTotal ?? 'Subtotal', style: const TextStyle(color: AppColors.textDark)),
                              Text(
                                '₹${_calculateSubTotal().toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_calculateTaxAmount() > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Tax (${_taxController.text}%)', style: const TextStyle(color: AppColors.textDark)),
                                  Text(
                                    '+ ₹${_calculateTaxAmount().toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppLocalizations.of(context)?.grandTotal ?? 'Total Amount', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                              Text(
                                '₹${_calculateTotal().toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppLocalizations.of(context)?.advancePaid ?? 'Advance Paid', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.success)),
                              Text(
                                '₹${_calculateAdvanceTotal().toStringAsFixed(2)}', // Use Sum of Payments
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppLocalizations.of(context)?.balanceDue ?? 'Pending Amount', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.error)),
                              Text(
                                '₹${(_calculateTotal() - _calculateAdvanceTotal()).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // _buildTextField(_whatsappController, AppLocalizations.of(context)?.contactNumber ?? 'WhatsApp Number', Icons.phone_android, isNumber: true),
                    // const SizedBox(height: 24),

                    // Dropdown
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _paymentStatus,
                      items: ['Pending', 'Paid', 'Partial'].map((status) { 
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _paymentStatus = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.updatePaymentStatus ?? 'Payment Status',
                        prefixIcon: const Icon(Icons.payment_outlined, color: AppColors.textGrey, size: 20),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),


                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveBill,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                        ),
                        child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : Text(AppLocalizations.of(context)?.saveBill ?? 'Save Bill', style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }



  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {
      bool isNumber = false, 
      Function(String)? onChanged, 
      bool readOnly = false, 
      String? Function(String?)? validator, 
      AutovalidateMode? autovalidateMode, 
      List<TextInputFormatter>? inputFormatters,
      TextCapitalization textCapitalization = TextCapitalization.none,
    }
  ) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      autovalidateMode: autovalidateMode,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      ),
      validator: validator,
    );
  }
}

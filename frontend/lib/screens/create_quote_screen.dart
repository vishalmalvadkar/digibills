import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/quote_model.dart';
import '../models/bill_model.dart';
import '../services/quote_service.dart';
import '../services/bills_service.dart'; 
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../utils/snackbar_helper.dart';

class CreateQuoteScreen extends StatefulWidget {
  final String initialDocType;
  const CreateQuoteScreen({super.key, this.initialDocType = 'Quote'});

  @override
  State<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends State<CreateQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isInterState = false; // Added to fix potential missing variable

  final _customerController = TextEditingController();
  final _whatsappController = TextEditingController(); 
  final _emailController = TextEditingController(); // NEW
  final _addressController = TextEditingController();
  final _quoteNoController = TextEditingController(); 
  final _clientIdController = TextEditingController();
  final _taxController = TextEditingController(text: '0');

  // Items
  final List<TextEditingController> _serviceControllers = [];
  final List<TextEditingController> _hsnControllers = []; // NEW
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _unitPriceControllers = [];
  final List<TextEditingController> _amountControllers = [];
  final List<String> _selectedUnits = [];
  
  final List<String> _unitOptions = [
    'qty', 'kg', 'gram', 'liter', 'ml', 
    'pcs', 'box', 'meter', 'ft', 'sq.ft', 'sq.m', 
    'dozen', 'set', 'packet', 'bundle', 'ton', 
    'day', 'hour', 'mo'
  ];

  List<BillModel> _customerHistory = []; 
  DateTime _quoteDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7)); 
  late String _docType;


  // Shipped To Controllers
  bool _shipToDifferentAddress = false;
  final _shippingNameController = TextEditingController();
  final _shippingAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _docType = widget.initialDocType;
    _generateQuoteNumber();
    _addItem(); 
    _loadHistoryForAutofill();
  }

  Future<void> _loadHistoryForAutofill() async {
    try {
      final bills = await BillsService().fetchBillsSnapshot();
      if (mounted) {
        setState(() {
          _customerHistory = bills;
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }

  void _generateQuoteNumber() {
    final id = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final prefix = _docType == 'Quote' ? 'QT' : 'PI';
    _quoteNoController.text = '$prefix-$id';
  }

  void _generateClientId(String name) {
    if (name.isEmpty) {
      setState(() => _clientIdController.clear());
      return;
    }
    final existingIndex = _customerHistory.indexWhere((b) => b.customerName.toLowerCase() == name.toLowerCase());
    
    if (existingIndex != -1) {
      final existing = _customerHistory[existingIndex];
      setState(() {
        _clientIdController.text = existing.clientId;
        if (_whatsappController.text.isEmpty) _whatsappController.text = existing.whatsappNumber;
        if (_addressController.text.isEmpty) _addressController.text = existing.clientAddress;
      });
    } else {
      final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final prefix = cleanName.length >= 3 ? cleanName.substring(0, 3) : cleanName.padRight(3, 'X');
      final hash = name.hashCode.abs().toString().padRight(4, '0');
      final suffix = hash.substring(hash.length - 4);
      setState(() {
        _clientIdController.text = 'CLI-$prefix-$suffix';
      });
    }
  }

  // ... (existing item methods) ...
  void _addItem() {
    setState(() {
      _serviceControllers.add(TextEditingController());
      _hsnControllers.add(TextEditingController()); // NEW
      _amountControllers.add(TextEditingController(text: '0'));
      _quantityControllers.add(TextEditingController(text: '1'));
      _unitPriceControllers.add(TextEditingController());
      _selectedUnits.add('qty');
    });
  }

  void _removeItem(int index) {
    if (_serviceControllers.length > 1) {
      setState(() {
        _serviceControllers[index].dispose();
        _hsnControllers[index].dispose(); // NEW
        _amountControllers[index].dispose();
        _quantityControllers[index].dispose();
        _unitPriceControllers[index].dispose();
        _serviceControllers.removeAt(index);
        _hsnControllers.removeAt(index); // NEW
        _amountControllers.removeAt(index);
        _quantityControllers.removeAt(index);
        _unitPriceControllers.removeAt(index);
        _selectedUnits.removeAt(index);
      });
    }
  }

  void _calculateItemTotal(int index) {
    double qty = double.tryParse(_quantityControllers[index].text) ?? 0;
    double price = double.tryParse(_unitPriceControllers[index].text) ?? 0;
    double total = qty * price;
    _amountControllers[index].text = total.toStringAsFixed(2);
    setState(() {}); 
  }

  double _calculateSubTotal() {
    double total = 0;
    for (var c in _amountControllers) {
      total += double.tryParse(c.text) ?? 0;
    }
    return total;
  }

  double _calculateTaxAmount() {
    final sub = _calculateSubTotal();
    final tax = double.tryParse(_taxController.text) ?? 0;
    return (sub * tax) / 100;
  }

  double _calculateTotal() {
    return _calculateSubTotal() + _calculateTaxAmount();
  }

  bool _isSaving = false;

  Future<void> _saveQuote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      List<BillItem> items = [];
      for (int i = 0; i < _serviceControllers.length; i++) {
        items.add(BillItem(
          description: _serviceControllers[i].text.trim(),
          hsnCode: _hsnControllers[i].text.trim(), // NEW
          amount: double.tryParse(_amountControllers[i].text.trim()) ?? 0,
          quantity: double.tryParse(_quantityControllers[i].text.trim()) ?? 1,
          unit: _selectedUnits[i],
          unitPrice: double.tryParse(_unitPriceControllers[i].text.trim()) ?? 0,
        ));
      }

      final quote = QuoteModel(
        quoteId: DateTime.now().millisecondsSinceEpoch.toString(),
        customerName: _customerController.text,
        clientId: _clientIdController.text,
        date: _quoteDate,
        expiryDate: _expiryDate,
        totalAmount: _calculateTotal(),
        status: 'Sent', 
        items: items,
        tenantId: '', 
        quoteNumber: _quoteNoController.text,
        whatsappNumber: _whatsappController.text,
        customerEmail: _emailController.text.trim(),
        taxPercentage: double.tryParse(_taxController.text) ?? 0,
        notes: '', 
        docType: _docType, // Saved
        placeOfSupply: _isInterState ? 'Inter-state' : 'Intra-state', // NEW
        shippingAddress: _shipToDifferentAddress && _shippingAddressController.text.isNotEmpty ? _shippingAddressController.text : null,
        shippingName: _shipToDifferentAddress && _shippingNameController.text.isNotEmpty ? _shippingNameController.text : null,
      );

      await QuoteService().addQuote(quote);

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Quote created successfully');
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save quote: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textGrey, size: 20) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  @override
  void dispose() {
    _customerController.dispose();
    _whatsappController.dispose();
    _emailController.dispose(); // NEW
    _addressController.dispose();
    _quoteNoController.dispose();
    _clientIdController.dispose();
    _taxController.dispose();
    for (var c in _serviceControllers) c.dispose();
    for (var c in _hsnControllers) c.dispose(); // NEW
    for (var c in _quantityControllers) c.dispose();
    for (var c in _unitPriceControllers) c.dispose();
    for (var c in _amountControllers) c.dispose();
    super.dispose();
  }
  
  // ... (existing helper methods)

  Widget _buildCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 16),
          // Customer Name (existing)
          _buildTextField(
            controller: _customerController,
            label: 'Customer Name',
            icon: Icons.person_outline,
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onChanged: (val) {
              if (val.isNotEmpty) _generateClientId(val);
            },
          ),
          const SizedBox(height: 12),
          // Client ID (existing)
          _buildTextField(
            controller: _clientIdController, 
            label: 'Client ID', 
            icon: Icons.badge_outlined,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          // WhatsApp & Email Row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _whatsappController,
                  label: 'WhatsApp',
                  icon: FontAwesomeIcons.whatsapp,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _emailController,
                  label: 'Email (Optional)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Address (existing)
          _buildTextField(
            controller: _addressController,
            label: 'Address',
            icon: Icons.location_on_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          // SHIPPED TO SECTION
          SwitchListTile(
            title: const Text('Ship to different address?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            value: _shipToDifferentAddress,
            onChanged: (val) {
              setState(() {
                _shipToDifferentAddress = val;
                if (!val) {
                  _shippingNameController.clear();
                  _shippingAddressController.clear();
                } else {
                  // Auto fill if empty
                  if (_shippingNameController.text.isEmpty) _shippingNameController.text = _customerController.text;
                }
              });
            },
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          
          if (_shipToDifferentAddress) ...[
             const SizedBox(height: 8),
             _buildTextField(
                controller: _shippingNameController,
                label: 'Shipping Name',
                icon: Icons.person_pin_circle_outlined,
             ),
             const SizedBox(height: 12),
             _buildTextField(
                controller: _shippingAddressController,
                label: 'Shipping Address',
                icon: Icons.local_shipping_outlined,
             ),
          ],
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('New ${_docType == 'Quote' ? 'Quotation' : 'Proforma Invoice'}'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: const BackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: _typeSelector('Quote', 'Quotation')),
                    Expanded(child: _typeSelector('Proforma', 'Proforma Invoice')),
                  ],
                ),
               ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                     TextFormField(
                        controller: _customerController,
                        onChanged: (val) => _generateClientId(val),
                        decoration: _inputDeco('Customer Name', Icons.person_outline),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                     ),
                     const SizedBox(height: 16),
                     TextFormField(
                        controller: _whatsappController, 
                        keyboardType: TextInputType.phone,
                        decoration: _inputDeco('WhatsApp Number', FontAwesomeIcons.whatsapp),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                     ),
                     const SizedBox(height: 16),
                     TextFormField(
                        controller: _emailController, 
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco('Email (Optional)', Icons.email_outlined),
                     ),
                     const SizedBox(height: 16),
                     TextFormField(
                        controller: _clientIdController,
                        decoration: _inputDeco('Client ID', Icons.badge_outlined),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                     ),
                     const SizedBox(height: 16),
                     TextFormField(
                       controller: _addressController,
                       decoration: _inputDeco('Address', Icons.location_on_outlined),
                     ),
                     const SizedBox(height: 16),

                     // SHIPPED TO SECTION
                     SwitchListTile(
                        title: const Text('Ship to different address?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        value: _shipToDifferentAddress,
                        onChanged: (val) {
                          setState(() {
                            _shipToDifferentAddress = val;
                            if (!val) {
                              _shippingNameController.clear();
                              _shippingAddressController.clear();
                            } else {
                              // Auto fill if empty
                              if (_shippingNameController.text.isEmpty) _shippingNameController.text = _customerController.text;
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      if (_shipToDifferentAddress) ...[
                         const SizedBox(height: 8),
                         TextFormField(
                            controller: _shippingNameController,
                            decoration: _inputDeco('Shipping Name', Icons.person_pin_circle_outlined),
                         ),
                         const SizedBox(height: 16),
                         TextFormField(
                            controller: _shippingAddressController,
                            decoration: _inputDeco('Shipping Address', Icons.local_shipping_outlined),
                         ),
                         const SizedBox(height: 16),
                      ],
                     const SizedBox(height: 16),
                     
                     Row(
                       children: [
                         Expanded(child: _datePickerField('Date', _quoteDate, (d) => setState(() => _quoteDate = d))),
                         const SizedBox(width: 12),
                         Expanded(child: _datePickerField('Expiry', _expiryDate, (d) => setState(() => _expiryDate = d), isRed: true)),
                       ],
                     ),
                     const SizedBox(height: 24),

                     Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add'))
                      ],
                     ),
                     Column(
                       children: List.generate(_serviceControllers.length, (index) {
                         return Container(
                           margin: const EdgeInsets.only(bottom: 12),
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(
                             color: AppColors.background,
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Column(
                             children: [
                                Row(children: [
                                 Expanded(flex: 3, child: TextFormField(controller: _serviceControllers[index], decoration: _inputDeco('Item', null))),
                                 const SizedBox(width: 8),
                                 Expanded(flex: 2, child: TextFormField(
                                    controller: _quantityControllers[index], 
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => _calculateItemTotal(index),
                                    decoration: InputDecoration(
                                      labelText: 'Qty',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                                            style: const TextStyle(color: AppColors.textDark, fontSize: 13),
                                            selectedItemBuilder: (context) {
                                              return _unitOptions.map((u) {
                                                return Center(child: Text(u, style: const TextStyle(fontSize: 13, color: AppColors.textDark)));
                                              }).toList();
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                 )),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  // NEW: HSN Field
                                 Expanded(child: TextFormField(controller: _hsnControllers[index], decoration: _inputDeco('HSN/SAC', null))),
                                 const SizedBox(width: 8),
                                 Expanded(child: TextFormField(
                                    controller: _unitPriceControllers[index], 
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => _calculateItemTotal(index),
                                    decoration: _inputDeco('Rate', null)
                                 )),
                                 const SizedBox(width: 8),
                                 Expanded(child: TextFormField(
                                    controller: _amountControllers[index], 
                                    readOnly: true,
                                    decoration: _inputDeco('Amt', null)
                                 )),
                                 IconButton(onPressed: () => _removeItem(index), icon: const Icon(Icons.delete, color: Colors.red)),
                                ]),
                             ],
                           ),
                         );
                       }),
                     ),

                     const SizedBox(height: 24),
                     const Divider(),
                     const SizedBox(height: 16),
                     
                     Row(
                       children: [
                         Expanded(
                            child: Row(
                              children: [
                                const Text('Tax / GST (%)', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: _taxController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.end,
                                    decoration: _inputDeco('%', null),
                                    onChanged: (_) => setState((){}),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // IGST Checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: _isInterState, 
                                onChanged: (val) => setState(() => _isInterState = val ?? false),
                                activeColor: AppColors.primary,
                              ),
                              const Text('Inter-state (IGST)', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                       ],
                     ),
                     const SizedBox(height: 12),
                     _summaryRow('Subtotal', _calculateSubTotal()),
                     const SizedBox(height: 8),
                     // Tax Breakdown
                      if (_isInterState)
                        _summaryRow('IGST (${_taxController.text}%)', _calculateTaxAmount(), isGrey: true)
                      else ...[
                        _summaryRow('CGST (${(double.tryParse(_taxController.text) ?? 0)/2}%)', _calculateTaxAmount() / 2, isGrey: true),
                        const SizedBox(height: 4),
                        _summaryRow('SGST (${(double.tryParse(_taxController.text) ?? 0)/2}%)', _calculateTaxAmount() / 2, isGrey: true),
                      ],
                     const SizedBox(height: 8),
                     _summaryRow('Grand Total', _calculateTotal(), isBold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Estimate', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                Text(
                  '₹${_calculateTotal().toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveQuote,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Send Quote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isBold = false, bool isGrey = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: isBold ? 16 : 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isGrey ? AppColors.textGrey : AppColors.textDark,
        )),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? AppColors.primary : AppColors.textDark,
          ),
        ),
      ],
    );
  }



  InputDecoration _inputDeco(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textGrey, size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      // Fixed: Visible Border
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }


  Widget _datePickerField(String label, DateTime date, Function(DateTime) onPick, {bool isRed = false}) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime(2030));
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRed ? Colors.red.shade50 : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isRed ? Colors.red.shade100 : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: isRed ? Colors.red : AppColors.textGrey)),
            const SizedBox(height: 4),
            Text(DateFormat('dd MMM').format(date), style: TextStyle(fontWeight: FontWeight.bold, color: isRed ? Colors.red : AppColors.textDark)),
          ],
        ),
      ),
    );
  }




  Widget _typeSelector(String type, String label) {
    final isSelected = _docType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _docType = type;
          _generateQuoteNumber(); // Regenerate number with correct prefix
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.textDark : AppColors.textGrey,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_model.dart';
import '../../services/purchase_service.dart';
import '../../services/settings_service.dart';
import '../../models/settings_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive.dart';
import '../../utils/snackbar_helper.dart';

class CreatePurchaseScreen extends StatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  State<CreatePurchaseScreen> createState() => _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends State<CreatePurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final PurchasesService _purchasesService = PurchasesService();
  final SettingsService _settingsService = SettingsService();

  // Supplier Details
  final _supplierNameController = TextEditingController();
  final _supplierGstinController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _cityController = TextEditingController();
  String _selectedState = 'Maharashtra'; // Default

  // Bill Details
  final _invoiceNoController = TextEditingController();
  DateTime _billDate = DateTime.now();
  final _taxPercentController = TextEditingController(text: '18');
  final _roundOffController = TextEditingController(text: '0');

  // Items
  final List<TextEditingController> _itemControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _hsnControllers = [];
  final List<TextEditingController> _rateControllers = [];
  final List<TextEditingController> _amountControllers = [];
  final List<TextEditingController> _discountControllers = [];
  final List<String> _selectedUnits = [];
  final List<String> _hsnTypes = []; // 'HSN' or 'SAC'
  String _globalHsnType = 'HSN';

  final List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 
    'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 
    'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Delhi', 'Jammu & Kashmir', 'Ladakh'
  ];

  final List<String> _unitOptions = [
    'qty', 'kg', 'gram', 'liter', 'ml', 'pcs', 'box', 'meter', 'ft', 'dozen', 'set', 'packet'
  ];

  AppSettings? _appSettings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _addItem();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.fetchSettings();
    setState(() {
      _appSettings = settings;
    });
  }

  void _addItem() {
    setState(() {
      _itemControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController(text: '1'));
      _hsnControllers.add(TextEditingController());
      _rateControllers.add(TextEditingController());
      _amountControllers.add(TextEditingController(text: '0'));
      _discountControllers.add(TextEditingController(text: '0'));
      _selectedUnits.add('qty');
      _hsnTypes.add(_globalHsnType);
    });
  }

  void _removeItem(int index) {
    if (_itemControllers.length > 1) {
      setState(() {
        _itemControllers.removeAt(index);
        _quantityControllers.removeAt(index);
        _hsnControllers.removeAt(index);
        _rateControllers.removeAt(index);
        _amountControllers.removeAt(index);
        _discountControllers.removeAt(index);
        _selectedUnits.removeAt(index);
        _hsnTypes.removeAt(index);
      });
    }
  }

  void _calculateItemTotal(int index) {
    double qty = double.tryParse(_quantityControllers[index].text) ?? 0;
    double rate = double.tryParse(_rateControllers[index].text) ?? 0;
    double disc = double.tryParse(_discountControllers[index].text) ?? 0;
    
    double total = (qty * rate) - disc;
    _amountControllers[index].text = total.toStringAsFixed(2);
    setState(() {});
  }

  double _calculateSubtotal() {
    double total = 0;
    for (var controller in _amountControllers) {
      total += double.tryParse(controller.text) ?? 0;
    }
    return total;
  }

  double _calculateTotalQuantity() {
    double total = 0;
    for (var controller in _quantityControllers) {
      total += double.tryParse(controller.text) ?? 0;
    }
    return total;
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final List<PurchaseItem> items = [];
      for (int i = 0; i < _itemControllers.length; i++) {
        items.add(PurchaseItem(
          description: _itemControllers[i].text.trim(),
          quantity: double.tryParse(_quantityControllers[i].text) ?? 0,
          unit: _selectedUnits[i],
          rate: double.tryParse(_rateControllers[i].text) ?? 0,
          amount: double.tryParse(_amountControllers[i].text) ?? 0,
          hsnCode: _hsnControllers[i].text.trim(),
          hsnType: _hsnTypes[i],
          discountAmount: double.tryParse(_discountControllers[i].text) ?? 0,
        ));
      }

      final subtotal = _calculateSubtotal();
      final totalQty = _calculateTotalQuantity();
      final taxPercent = double.tryParse(_taxPercentController.text) ?? 0;
      final roundOff = double.tryParse(_roundOffController.text) ?? 0;
      
      // Fixed: Round tax amount to 2 decimal places for accounting accuracy
      final taxAmount = double.parse((subtotal * (taxPercent / 100)).toStringAsFixed(2));
      
      double cgst = 0, sgst = 0, igst = 0;
      
      if (_appSettings?.state.toLowerCase() == _selectedState.toLowerCase()) {
        cgst = double.parse((taxAmount / 2).toStringAsFixed(2));
        sgst = double.parse((taxAmount - cgst).toStringAsFixed(2)); // Remaining to avoid losing .01
      } else {
        igst = taxAmount;
      }

      final totalAmount = double.parse((subtotal + taxAmount + roundOff).toStringAsFixed(2));

      final purchase = PurchaseModel(
        purchaseId: '',
        tenantId: '', // Set by service
        supplierName: _supplierNameController.text.trim(),
        supplierGstin: _supplierGstinController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        state: _selectedState,
        city: _cityController.text.trim(),
        invoiceNumber: _invoiceNoController.text.trim(),
        date: _billDate,
        subtotal: subtotal,
        taxAmount: taxAmount,
        taxPercentage: taxPercent,
        roundOff: roundOff,
        totalQuantity: totalQty,
        totalAmount: totalAmount,
        cgst: cgst,
        sgst: sgst,
        igst: igst,
        placeOfSupply: _selectedState,
        items: items,
        createdAt: DateTime.now(),
      );

      await _purchasesService.addPurchase(purchase);

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Purchase Bill saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Error saving purchase: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Purchase Bill', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        color: AppColors.background, // Ensure background fills entire screen for web
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              _sectionTitle('Supplier Details'),
              _card(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildTextField(_supplierNameController, 'Supplier Name', Icons.business, required: true),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_supplierGstinController, 'Supplier GSTIN', Icons.confirmation_number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_contactNumberController, 'Contact Number', Icons.phone, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedState,
                            isDense: true,
                            decoration: _inputDeco('State', Icons.map),
                            items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) => setState(() => _selectedState = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_cityController, 'City', Icons.location_city)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Bill Details'),
              _card(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(child: _buildTextField(_invoiceNoController, 'Invoice Number', Icons.receipt_long, required: true)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(context: context, initialDate: _billDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (date != null) setState(() => _billDate = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border), 
                            borderRadius: BorderRadius.circular(12), 
                            color: Colors.white
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textGrey),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Invoice Date', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                                  Text(DateFormat('dd MMM yyyy').format(_billDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildItemListSection(),
              const SizedBox(height: 24),
              _buildSummaryCard(),
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    ),
  ),
),
    );
  }

  Widget _buildSaveButton() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _savePurchase,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, 
            minimumSize: const Size(double.infinity, 56), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: AppColors.primary.withOpacity(0.3),
          ),
          child: _isSaving 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Text('Save Purchase Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildItemListSection() {
    final isMobile = Responsive.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Items & Goods'),
            Row(
              children: [
                _buildGlobalHsnToggle(),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: _addItem, 
                  icon: const Icon(Icons.add_circle_outline, size: 20), 
                  label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!isMobile) _buildItemsHeader(),
        ...List.generate(_itemControllers.length, (index) {
          return isMobile ? _buildMobileItemCard(index) : _buildDesktopItemRow(index);
        }),
      ],
    );
  }

  Widget _buildItemsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('DESCRIPTION', style: _headerStyle())),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('HSN/SAC', style: _headerStyle())),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('RATE', style: _headerStyle())),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('QTY', style: _headerStyle())),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('DISCOUNT', style: _headerStyle())),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('AMOUNT', style: _headerStyle())),
          const SizedBox(width: 48), // Space for delete button
        ],
      ),
    );
  }

  TextStyle _headerStyle() => const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGrey, letterSpacing: 1.0);

  Widget _buildDesktopItemRow(int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: AppColors.border.withOpacity(0.5)),
          right: BorderSide(color: AppColors.border.withOpacity(0.5)),
          bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 4, child: _buildItemField(_itemControllers[index], 'Item name...', required: true)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _buildItemField(_hsnControllers[index], 'HSN/SAC Code', isNumber: true)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _buildItemField(_rateControllers[index], '0.00', isNumber: true, onChanged: (_) => _calculateItemTotal(index))),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _buildItemField(
            _quantityControllers[index], 
            '1', 
            isNumber: true, 
            onChanged: (_) => _calculateItemTotal(index),
            suffix: _buildUnitDropdown(index),
          )),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _buildItemField(_discountControllers[index], '0.00', isNumber: true, onChanged: (_) => _calculateItemTotal(index))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _buildItemField(_amountControllers[index], '0.00', readOnly: true)),
          SizedBox(width: 48, child: IconButton(onPressed: () => _removeItem(index), icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20)))),
        ],
      ),
    );
  }

  Widget _buildMobileItemCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: _buildItemField(_itemControllers[index], 'Item Name', required: true, label: 'Description')),
              const SizedBox(width: 12),
              GestureDetector(onTap: () => _removeItem(index), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20))),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _buildItemField(_hsnControllers[index], 'Code', isNumber: true, label: 'HSN/SAC')), const SizedBox(width: 12), Expanded(child: _buildItemField(_rateControllers[index], '0.00', isNumber: true, label: 'Rate', onChanged: (_) => _calculateItemTotal(index)))]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _buildItemField(_quantityControllers[index], '1', isNumber: true, label: 'Quantity', onChanged: (_) => _calculateItemTotal(index), suffix: _buildUnitDropdown(index))), const SizedBox(width: 12), Expanded(child: _buildItemField(_discountControllers[index], '0.00', isNumber: true, label: 'Disc. Amt', onChanged: (_) => _calculateItemTotal(index)))]),
          const Divider(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Item Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textGrey)), Text('₹${_amountControllers[index].text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary))]),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final subtotal = _calculateSubtotal();
    final totalQty = _calculateTotalQuantity();
    final taxPercent = double.tryParse(_taxPercentController.text) ?? 0;
    final roundOff = double.tryParse(_roundOffController.text) ?? 0;
    final taxAmount = double.parse((subtotal * (taxPercent / 100)).toStringAsFixed(2));
    final grandTotal = double.parse((subtotal + taxAmount + roundOff).toStringAsFixed(2));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _summaryRow('Total Items', _itemControllers.length.toString()),
                _summaryRow('Total Quantity', totalQty.toStringAsFixed(2)),
                const Divider(height: 32),
                _summaryRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Tax (%)', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _taxPercentController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text('₹${taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Round Off', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: _roundOffController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        onChanged: (_) => setState(() {}),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemField(TextEditingController controller, String hint, {bool isNumber = false, bool required = false, bool readOnly = false, String? label, Function(String)? onChanged, Widget? suffix}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.normal),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        isDense: true,
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: readOnly ? AppColors.background : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
      validator: required ? (val) => val!.isEmpty ? '!' : null : null,
    );
  }

  Widget _buildGlobalHsnToggle() {
    return Container(
      height: 36,
      width: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade50, 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: AppColors.border)
      ),
      child: Row(
        children: [
          Expanded(child: InkWell(
            onTap: () => setState(() {
              _globalHsnType = 'HSN';
              for (int i = 0; i < _hsnTypes.length; i++) _hsnTypes[i] = 'HSN';
            }),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _globalHsnType == 'HSN' ? AppColors.primary : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
              ),
              child: Text('HSN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _globalHsnType == 'HSN' ? Colors.white : AppColors.textGrey)),
            ),
          )),
          Expanded(child: InkWell(
            onTap: () => setState(() {
              _globalHsnType = 'SAC';
              for (int i = 0; i < _hsnTypes.length; i++) _hsnTypes[i] = 'SAC';
            }),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _globalHsnType == 'SAC' ? AppColors.primary : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
              ),
              child: Text('SAC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _globalHsnType == 'SAC' ? Colors.white : AppColors.textGrey)),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown(int index) {
    return Container(
      width: 60,
      padding: const EdgeInsets.only(right: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedUnits[index],
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
          items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
          onChanged: (val) => setState(() => _selectedUnits[index] = val!),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 14}) {
// ... (unchanged)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? AppColors.textDark : AppColors.textGrey)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: isBold ? AppColors.primary : AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4, top: 8), 
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGrey, letterSpacing: 1.1))
  );

  Widget _card({required Widget child, EdgeInsets? margin, EdgeInsets? padding, Color? color}) => Container(
    margin: margin, 
    padding: padding ?? const EdgeInsets.all(20), 
    decoration: BoxDecoration(
      color: color ?? Colors.white, 
      borderRadius: BorderRadius.circular(20), 
      border: Border.all(color: AppColors.border.withOpacity(0.5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03), 
          blurRadius: 20, 
          offset: const Offset(0, 8)
        )
      ]
    ), 
    child: child
  );

  Widget _buildTextField(TextEditingController controller, String label, IconData? icon, {bool isNumber = false, bool required = false, bool readOnly = false, Function(String)? onChanged, int? maxLines = 1}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      onChanged: onChanged,
      decoration: _inputDeco(label, icon),
      validator: required ? (val) => val!.isEmpty ? 'Required' : null : null,
    );
  }

  InputDecoration _inputDeco(String label, IconData? icon) => InputDecoration(
    labelText: label, 
    labelStyle: const TextStyle(fontSize: 13, color: AppColors.textGrey),
    prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.primary.withOpacity(0.7)) : null, 
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)), 
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)), 
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    filled: true, 
    fillColor: Colors.white, 
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
  );
}

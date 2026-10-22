import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_order_model.dart';
import '../../models/bill_model.dart';
import '../../services/purchase_order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_helper.dart';

class CreatePOScreen extends StatefulWidget {
  const CreatePOScreen({super.key});

  @override
  State<CreatePOScreen> createState() => _CreatePOScreenState();
}

class _CreatePOScreenState extends State<CreatePOScreen> {
  final _formKey = GlobalKey<FormState>();

  final _vendorNameController = TextEditingController();
  final _vendorContactController = TextEditingController();
  final _vendorAddressController = TextEditingController(); 
  final _vendorGstController = TextEditingController(); 
  final _poNoController = TextEditingController();
  final _taxController = TextEditingController(text: '0'); 
  
  // Items
  final List<TextEditingController> _itemControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _unitPriceControllers = [];
  final List<TextEditingController> _amountControllers = [];
  final List<String> _selectedUnits = [];
  
  final List<String> _unitOptions = [
    'qty', 'kg', 'gram', 'liter', 'ml', 
    'pcs', 'box', 'meter', 'ft', 'sq.ft', 'sq.m', 
    'dozen', 'set', 'packet', 'bundle', 'ton'
  ];

  DateTime _poDate = DateTime.now();
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 14)); 
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _generatePONumber();
    _addItem(); 
  }

  void _generatePONumber() {
    final id = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _poNoController.text = 'PO-$id';
  }

  void _addItem() {
    setState(() {
      _itemControllers.add(TextEditingController());
      _amountControllers.add(TextEditingController(text: '0'));
      _quantityControllers.add(TextEditingController(text: '1'));
      _unitPriceControllers.add(TextEditingController());
      _selectedUnits.add('qty');
    });
  }

  void _removeItem(int index) {
    if (_itemControllers.length > 1) {
      setState(() {
        _itemControllers[index].dispose();
        _amountControllers[index].dispose();
        _quantityControllers[index].dispose();
        _unitPriceControllers[index].dispose();
        
        _itemControllers.removeAt(index);
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

  double _calculateSubtotal() {
    double subtotal = 0;
    for (var c in _amountControllers) {
      subtotal += double.tryParse(c.text) ?? 0;
    }
    return subtotal;
  }

  double _calculateTotal() {
    double subtotal = _calculateSubtotal();
    double tax = double.tryParse(_taxController.text) ?? 0;
    return subtotal + (subtotal * tax / 100);
  }

  Future<void> _savePO() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      List<BillItem> items = [];
      for (int i = 0; i < _itemControllers.length; i++) {
        items.add(BillItem(
          description: _itemControllers[i].text.trim(),
          amount: double.tryParse(_amountControllers[i].text.trim()) ?? 0,
          quantity: double.tryParse(_quantityControllers[i].text.trim()) ?? 1,
          unit: _selectedUnits[i],
          unitPrice: double.tryParse(_unitPriceControllers[i].text.trim()) ?? 0,
        ));
      }

      final po = PurchaseOrderModel(
        poId: '', 
        poNumber: _poNoController.text,
        vendorName: _vendorNameController.text.trim(),
        vendorContact: _vendorContactController.text.trim(),
        vendorAddress: _vendorAddressController.text.trim(),
        vendorGst: _vendorGstController.text.trim(),
        date: _poDate,
        expectedDeliveryDate: _deliveryDate,
        totalAmount: _calculateTotal(),
        taxPercentage: double.tryParse(_taxController.text) ?? 0, 
        status: 'Sent', 
        items: items,
        tenantId: '', 
        notes: '', 
      );

      await PurchaseOrderService().addPO(po);
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Purchase Order created successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save PO: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Purchase Order', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Vendor Details'),
              _card(
                  child: Column(
                children: [
                  TextFormField(
                      controller: _vendorNameController,
                      decoration: _deco('Shop / Dealer Name', Icons.store),
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                            controller: _vendorContactController,
                            decoration: _deco('Contact', Icons.phone))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                            controller: _vendorGstController,
                            decoration: _deco('GSTIN Number', Icons.confirmation_number))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _vendorAddressController,
                      decoration: _deco('Address', Icons.location_on),
                      maxLines: 2),
                ],
              )),
              const SizedBox(height: 20),
              _sectionHeader('Order Details'),
              _card(
                  child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: TextFormField(
                              controller: _poNoController,
                              decoration: _deco('Invoice No', Icons.receipt))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _dateField('Invoice Date', _poDate,
                              (d) => setState(() => _poDate = d))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _dateField('Expected Delivery', _deliveryDate,
                              (d) => setState(() => _deliveryDate = d),
                              isRed: true)),
                    ],
                  ),
                ],
              )),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _sectionHeader('Descriptions & Items'),
                TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'))
              ]),
              ...List.generate(_itemControllers.length, (i) => _itemRow(i)),
              const SizedBox(height: 20),
              _summaryCard(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _itemRow(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(children: [
            Expanded(flex: 3, child: TextFormField(controller: _itemControllers[i], decoration: _deco('Item Description', null), validator: (v) => v!.isEmpty ? '*' : null)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _qtyField(i)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
             Expanded(child: TextFormField(controller: _unitPriceControllers[i], keyboardType: TextInputType.number, onChanged: (_) => _calculateItemTotal(i), decoration: _deco('Rate', null))),
             const SizedBox(width: 8),
             Expanded(child: TextFormField(controller: _amountControllers[i], readOnly: true, decoration: _deco('Total', null))),
             IconButton(onPressed: () => _removeItem(i), icon: const Icon(Icons.delete, color: Colors.red)),
          ])
        ],
      ),
    );
  }

  Widget _qtyField(int i) {
    return TextFormField(
      controller: _quantityControllers[i],
      keyboardType: TextInputType.number,
      onChanged: (_) => _calculateItemTotal(i),
      decoration: InputDecoration(
        labelText: 'Qty',
        filled: true, fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        suffixIcon: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedUnits[i],
            items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _selectedUnits[i] = v!),
            icon: const Icon(Icons.arrow_drop_down, size: 16),
          ),
        )
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 14)),
              Text('₹${_calculateSubtotal().toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Text('Tax (%)', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: _taxController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState((){}),
                    decoration: const InputDecoration(
                      isDense: true, 
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
              ]),
              Text('₹${(_calculateSubtotal() * (double.tryParse(_taxController.text) ?? 0) / 100).toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('₹${_calculateTotal().toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
     return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,-5))]),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _savePO,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Purchase Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
     );
  }

  Widget _sectionHeader(String title) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textGrey)));
  
  Widget _card({required Widget child}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: child);
  
  InputDecoration _deco(String label, IconData? icon) => InputDecoration(labelText: label, prefixIcon: icon != null ? Icon(icon, size: 18) : null, filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));

  Widget _dateField(String label, DateTime date, Function(DateTime) onPick, {bool isRed = false}) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isRed ? Colors.red.shade50 : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: isRed ? Colors.red : Colors.grey)),
          Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(fontWeight: FontWeight.bold, color: isRed ? Colors.red : Colors.black)),
        ]),
      ),
    );
  }
}

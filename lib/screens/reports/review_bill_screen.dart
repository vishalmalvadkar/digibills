import 'package:flutter/material.dart';
import '../../models/supplier_bill_model.dart';
import '../../services/supplier_bill_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ReviewBillScreen extends StatefulWidget {
  final SupplierBillModel bill;

  const ReviewBillScreen({super.key, required this.bill});

  @override
  State<ReviewBillScreen> createState() => _ReviewBillScreenState();
}

class _ReviewBillScreenState extends State<ReviewBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupplierBillService();
  bool _isSaving = false;

  late TextEditingController _supplierNameController;
  late TextEditingController _gstController;
  late TextEditingController _invoiceController;
  late TextEditingController _totalController;
  late TextEditingController _discountController; // NEW
  late TextEditingController _taxController;
  late DateTime _selectedDate;
  late List<SupplierBillItem> _items;
  late Map<String, TextEditingController> _metadataControllers; // NEW

  @override
  void initState() {
    super.initState();
    _supplierNameController = TextEditingController(text: widget.bill.supplierName);
    _gstController = TextEditingController(text: widget.bill.supplierGst);
    _invoiceController = TextEditingController(text: widget.bill.invoiceNumber);
    _totalController = TextEditingController(text: widget.bill.totalAmount.toStringAsFixed(2));
    _discountController = TextEditingController(text: widget.bill.discount.toStringAsFixed(2));
    _taxController = TextEditingController(text: widget.bill.taxAmount.toStringAsFixed(2));
    _selectedDate = widget.bill.date;
    _items = List.from(widget.bill.items);
    
    // Initialize metadata controllers
    _metadataControllers = {};
    widget.bill.metadata.forEach((key, value) {
      _metadataControllers[key] = TextEditingController(text: value);
    });
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _gstController.dispose();
    _invoiceController.dispose();
    _totalController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _metadataControllers.forEach((_, c) => c.dispose()); // NEW
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String? uploadedImageUrl = widget.bill.imageUrl;

      if (uploadedImageUrl != null && !uploadedImageUrl.startsWith('http')) {
        final file = File(uploadedImageUrl);
        if (await file.exists()) {
          final url = await _service.uploadBillImage(file);
          if (url != null) {
            uploadedImageUrl = url;
          }
        }
      }

      // Collect dynamic metadata
      final Map<String, String> finalMetadata = {};
      _metadataControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          finalMetadata[key] = controller.text;
        }
      });

      final finalBill = SupplierBillModel(
        id: widget.bill.id,
        supplierName: _supplierNameController.text,
        supplierGst: _gstController.text.isEmpty ? null : _gstController.text,
        invoiceNumber: _invoiceController.text.isEmpty ? null : _invoiceController.text,
        date: _selectedDate,
        totalAmount: double.tryParse(_totalController.text) ?? 0,
        discount: double.tryParse(_discountController.text) ?? 0,
        taxAmount: double.tryParse(_taxController.text) ?? 0,
        imageUrl: uploadedImageUrl,
        items: _items,
        metadata: finalMetadata, // NEW: Saved dynamic fields
        tenantId: widget.bill.tenantId,
        createdAt: DateTime.now(),
      );

      await _service.addBill(finalBill);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Scanned Bill'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.bill.imageUrl != null && widget.bill.imageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Card(
                     elevation: 0,
                     color: Colors.white,
                     shape: RoundedRectangleBorder(
                       side: BorderSide(color: Colors.grey.shade300),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: ExpansionTile(
                       initiallyExpanded: false, // Default collapsed for better form view
                       shape: const Border(),
                       leading: const Icon(Icons.image, color: AppColors.primary),
                       title: const Text('Scanned Bill Image', style: TextStyle(fontWeight: FontWeight.bold)),
                       children: [
                         Padding(
                           padding: const EdgeInsets.all(12),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: widget.bill.imageUrl!.startsWith('http')
                                 ? Image.network(
                                     widget.bill.imageUrl!,
                                     height: 400,
                                     width: double.infinity,
                                     fit: BoxFit.contain,
                                     loadingBuilder: (context, child, loadingProgress) {
                                       if (loadingProgress == null) return child;
                                       return const SizedBox(
                                         height: 200,
                                         child: Center(child: CircularProgressIndicator()),
                                       );
                                     },
                                     errorBuilder: (context, error, stackTrace) => const Center(child: Text("Failed to load cloud image")),
                                   )
                                 : Image.file(
                                     File(widget.bill.imageUrl!),
                                     height: 400,
                                     width: double.infinity,
                                     fit: BoxFit.contain,
                                     errorBuilder: (ctx, err, stack) => const Center(child: Text("Failed to load local image")),
                                   ),
                           ),
                         ),
                       ],
                     ),
                  ),
                ),

              const Text('Standard Bill Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              
              _buildField('Supplier Name', _supplierNameController, Icons.business),
              _buildField('Supplier GST (Optional)', _gstController, Icons.tag),
              _buildField('Invoice Number', _invoiceController, Icons.receipt_long),
              
              const SizedBox(height: 12),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                title: const Text('Bill Date'),
                subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 12),

              // DYNAMIC SECTION: Each and Every Detail
              if (_metadataControllers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Additional Scanned Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      onPressed: () {
                         setState(() {
                            _metadataControllers['New Field ${_metadataControllers.length + 1}'] = TextEditingController();
                         });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Field'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._metadataControllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildField(entry.key, entry.value, Icons.info_outline),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _metadataControllers.remove(entry.key);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              const SizedBox(height: 24),
              const Text('Financial Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _buildField('Total Amount', _totalController, Icons.currency_rupee, isNumber: true),
              
              Row(
                children: [
                  Expanded(child: _buildField('Tax Amount', _taxController, Icons.percent, isNumber: true)),
                  SizedBox(width: 12),
                  Expanded(child: _buildField('Discount', _discountController, Icons.discount, isNumber: true)),
                ],
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extracted Line Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${_items.length} items', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              
              if (_items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No individual items detected. Total only.')),
                  ),
                )
              else
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(item.description),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${item.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.red),
                            onPressed: () => setState(() => _items.removeAt(idx)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('SAVE BILL DIGITAL RECORD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('Digital Record Verified. Image attached securely.', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_helper.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  // GST fields
  final _supplierGstCtrl = TextEditingController();
  final _invoiceNoCtrl = TextEditingController();
  final _taxAmountCtrl = TextEditingController();
  final _hsnCtrl = TextEditingController();
  String? _selectedTaxType;
  bool _isItcEligible = false;

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Other';
  bool _isSaving = false;

  final List<String> _categories = ['Rent', 'Internet', 'Travel', 'Salary', 'Other'];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final expense = ExpenseModel(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _selectedCategory,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        supplierGstNumber: _supplierGstCtrl.text.trim().isEmpty ? null : _supplierGstCtrl.text.trim(),
        invoiceNumber: _invoiceNoCtrl.text.trim().isEmpty ? null : _invoiceNoCtrl.text.trim(),
        taxAmount: double.tryParse(_taxAmountCtrl.text.trim()) ?? 0,
        taxType: _selectedTaxType,
        hsnCode: _hsnCtrl.text.trim().isEmpty ? null : _hsnCtrl.text.trim(),
        isItcEligible: _isItcEligible,
      );

      await ExpenseService().addExpense(expense);
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Expense added successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Error adding expense');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_titleController, 'Description', Icons.description),
              const SizedBox(height: 16),
              _buildTextField(_amountController, 'Amount (₹)', Icons.currency_rupee, isNumber: true),
              const SizedBox(height: 16),
              
              // Category Dropdown
              const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(_notesController, 'Notes (Optional)', Icons.note, maxLines: 3),
              const SizedBox(height: 16),

              // GST / ITC Details (Collapsible)
              ExpansionTile(
                title: const Text('GST & ITC Details (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                tilePadding: EdgeInsets.zero,
                children: [
                  _buildTextField(_supplierGstCtrl, 'Supplier GSTIN', Icons.store),
                  const SizedBox(height: 12),
                  _buildTextField(_invoiceNoCtrl, 'Invoice Number', Icons.receipt),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_taxAmountCtrl, 'Tax Amount', Icons.currency_rupee, isNumber: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_hsnCtrl, 'HSN/SAC Code', Icons.tag)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedTaxType,
                    decoration: InputDecoration(
                       labelText: 'Tax Type',
                       filled: true,
                       fillColor: Colors.white,
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    items: ['CGST_SGST','IGST', 'Nil', 'Exempt'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _selectedTaxType = v),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Eligible for ITC?', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: _isItcEligible, 
                    onChanged: (v) => setState(() => _isItcEligible = v ?? false),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: (val) {
        if (maxLines == 1 && (val == null || val.isEmpty)) return 'Required';
        if (isNumber && double.tryParse(val!) == null) return 'Invalid Amount';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textGrey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

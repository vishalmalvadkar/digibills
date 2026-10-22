import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/license_model.dart';
import '../../models/bill_model.dart'; // NEW
import '../../services/client_service.dart';
import '../../theme/app_colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/validators.dart'; // NEW
import 'package:flutter/services.dart'; // NEW

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  
  // New Payment Fields
  final _amountCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  String _paymentMode = 'Cash'; // Main Mode
  String _paymentStatus = 'Pending'; // NEW
  
  // Multiple Advance Payments
  final List<TextEditingController> _advanceAmounts = [];
  final List<String> _advanceModes = [];
  final List<DateTime> _advanceDates = [];

  // License Defaults
  bool _isActive = true;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_updateSummary);
    _taxCtrl.addListener(_updateSummary);
  }

  void _updateSummary() {
    setState(() {});
  }

  void _addAdvance() {
    setState(() {
      final ctrl = TextEditingController();
      ctrl.addListener(_updateSummary);
      _advanceAmounts.add(ctrl);
      _advanceModes.add('Cash');
      _advanceDates.add(DateTime.now());
    });
  }

  void _removeAdvance(int index) {
    setState(() {
      _advanceAmounts[index].dispose();
      _advanceAmounts.removeAt(index);
      _advanceModes.removeAt(index);
      _advanceDates.removeAt(index);
    });
  }

  Future<void> _pickAdvanceDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _advanceDates[index],
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _advanceDates[index] = picked;
      });
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _amountCtrl.dispose();
    _taxCtrl.dispose();
    _stateCtrl.dispose();
    _gstCtrl.dispose();
    for (var c in _advanceAmounts) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final license = LicenseModel(
        isActive: _isActive,
        plan: 'Standard', // Default plan
        startDate: _startDate,
        endDate: _endDate,
      );

      // Collect Advances
      List<PaymentRecord> advances = [];
      for(int i=0; i<_advanceAmounts.length; i++) {
        final amt = double.tryParse(_advanceAmounts[i].text) ?? 0;
        if(amt > 0) {
          advances.add(PaymentRecord(
            date: _advanceDates[i],
            amount: amt,
            mode: _advanceModes[i],
          ));
        }
      }

      await ClientService().createClient(
        businessName: _businessNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        whatsappNumber: _whatsappCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        gstNumber: _gstCtrl.text.trim(),
        license: license,
        amount: double.tryParse(_amountCtrl.text) ?? 0,
        taxPercentage: double.tryParse(_taxCtrl.text) ?? 0,
        paymentMode: _paymentMode,
        paymentStatus: _paymentStatus, // NEW
        advances: advances,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client provisioned successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Auto-adjust end date if start is after it
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate.add(const Duration(days: 365));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Provision New Client'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('Client Details'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _businessNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailCtrl,
                autovalidateMode: AutovalidateMode.onUserInteraction, // NEW
                validator: Validators.validateEmail, // NEW
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'client@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _whatsappCtrl,
                autovalidateMode: AutovalidateMode.onUserInteraction, // NEW
                validator: Validators.validateMobile, // NEW (10 digits)
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number',
                  prefixIcon: FaIcon(FontAwesomeIcons.whatsapp), // Changed Icon
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                   Expanded(
                    child: TextFormField(
                      controller: _stateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Business State',
                        prefixIcon: Icon(Icons.map),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _gstCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GST Number',
                        prefixIcon: Icon(Icons.verified_user),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              _buildHeader('Financials'),
              const SizedBox(height: 16),
              
              Row(
                children: [
                   Expanded(
                     child: TextFormField(
                        controller: _amountCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction, // NEW
                        validator: (v) => Validators.validateRequired(v, 'Amount') ?? Validators.validateAmount(v), // NEW
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(labelText: 'Base Amount', prefixIcon: Icon(Icons.currency_rupee)),
                        keyboardType: TextInputType.number,
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: TextFormField(
                        controller: _taxCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction, // NEW
                        validator: Validators.validateTax, // NEW
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(labelText: 'Tax %', prefixIcon: Icon(Icons.percent)),
                        keyboardType: TextInputType.number,
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: ['Cash', 'UPI', 'Cheque', 'Net Banking']
                          .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                          .toList(),
                      onChanged: (val) => setState(() => _paymentMode = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentStatus,
                      decoration: const InputDecoration(
                        labelText: 'Payment Status',
                        prefixIcon: Icon(Icons.info_outline),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      items: ['Paid', 'Partial', 'Pending']
                          .map((val) => DropdownMenuItem(
                                value: val, 
                                child: Text(val, style: TextStyle(
                                  color: val == 'Paid' ? Colors.green 
                                       : val == 'Pending' ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.bold
                                ))
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _paymentStatus = val!),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHeader('Advance Payments'),
                  TextButton.icon(
                    onPressed: _addAdvance,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Advance'),
                  )
                ],
              ),
              const SizedBox(height: 8),
              if (_advanceAmounts.isEmpty)
                 const Text('No advance payments added.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              
              ...List.generate(_advanceAmounts.length, (index) => Container(
                 margin: const EdgeInsets.only(bottom: 12),
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   border: Border.all(color: AppColors.border),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Column(
                   children: [
                      Row(
                        children: [
                           Expanded(
                             child: TextFormField(
                               controller: _advanceAmounts[index],
                               decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹'),
                               keyboardType: TextInputType.number,
                               inputFormatters: [
                                 FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                               ],
                             ),
                           ),
                           const SizedBox(width: 12),
                           IconButton(
                             icon: const Icon(Icons.calendar_today, color: AppColors.primary),
                             onPressed: () => _pickAdvanceDate(index),
                           ),
                           Text(DateFormat('dd MMM').format(_advanceDates[index])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                           Expanded(
                             child: DropdownButtonFormField<String>(
                                value: _advanceModes[index],
                                decoration: const InputDecoration(labelText: 'Mode', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                                items: ['Cash', 'UPI', 'Cheque', 'Net Banking']
                                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                                    .toList(),
                                onChanged: (val) => setState(() => _advanceModes[index] = val!),
                             ),
                           ),
                           IconButton(
                             icon: const Icon(Icons.delete, color: AppColors.error),
                             onPressed: () => _removeAdvance(index),
                           ),
                        ],
                      )
                   ],
                 ),
              )),

              const SizedBox(height: 32),
              _buildHeader('License Configuration'),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Initial Status: Active', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: _isActive,
                      activeColor: AppColors.success,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(_startDate)),
                      trailing: const Icon(Icons.calendar_today, size: 20),
                      onTap: () => _selectDate(true),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(_endDate)),
                      trailing: const Icon(Icons.calendar_today, size: 20),
                      onTap: () => _selectDate(false),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const SizedBox(height: 32),
              _buildHeader('Financial Summary'),
              const SizedBox(height: 16),
              _summaryCard(),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Provisioning...' : 'Provision Client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final baseAmount = double.tryParse(_amountCtrl.text) ?? 0;
    final taxPercent = double.tryParse(_taxCtrl.text) ?? 0;
    
    // Exclusive Tax Calculation (Client Style)
    final subTotal = baseAmount;
    final taxAmount = (baseAmount * taxPercent) / 100;
    final grandTotal = baseAmount + taxAmount;
    
    // Advances
    double totalAdvance = 0;
    for (var c in _advanceAmounts) {
      totalAdvance += double.tryParse(c.text) ?? 0;
    }

    final balance = grandTotal - totalAdvance;
    final isPaid = balance <= 0 && totalAdvance >= grandTotal;
    
    // Calculate suggested status for display (Does not override dropdown automatically to prevent user frustration)
    String suggestedStatus = 'Pending';
    if (balance <= 0) suggestedStatus = 'Paid';
    else if (totalAdvance > 0) suggestedStatus = 'Partial';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _summaryRow('Base Amount', '₹${subTotal.toStringAsFixed(2)}'),
          _summaryRow('Tax (${taxPercent.toStringAsFixed(0)}%)', '₹${taxAmount.toStringAsFixed(2)}'),
          const Divider(),
          _summaryRow('Grand Total', '₹${grandTotal.toStringAsFixed(2)}', isBold: true),
          const SizedBox(height: 8),
          _summaryRow('Total Paid (Advances)', '- ₹${totalAdvance.toStringAsFixed(2)}', color: Colors.green),
          const Divider(),
          _summaryRow('Balance Due', '₹${balance.toStringAsFixed(2)}', isBold: true, color: balance <= 0 ? Colors.green : Colors.red),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               const Text('Recommended Status:', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
               InkWell(
                 onTap: () {
                   setState(() {
                     _paymentStatus = suggestedStatus;
                   });
                 },
                 child: Text(
                   suggestedStatus.toUpperCase(), 
                   style: TextStyle(
                     fontWeight: FontWeight.bold, 
                     color: suggestedStatus == 'Paid' ? Colors.green : (suggestedStatus == 'Pending' ? Colors.red : Colors.orange),
                     decoration: TextDecoration.underline,
                   ),
                 ),
               ),
            ],
          )
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.textGrey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textGrey,
        letterSpacing: 1.2,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../../models/client_model.dart';
import '../../models/license_model.dart';
import '../../models/bill_model.dart';
import '../../services/client_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

import 'package:url_launcher/url_launcher.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'admin_client_mou_view.dart';
import '../../utils/snackbar_helper.dart';

class ClientDetailScreen extends StatefulWidget {
  final ClientModel client;
  final String? notificationId;
  const ClientDetailScreen({super.key, required this.client, this.notificationId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _businessNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _whatsappCtrl;
  
  // Financial Fields
  late TextEditingController _amountCtrl;
  late TextEditingController _taxCtrl;
  late String _paymentMode;
  late String _paymentStatus;
  
  // Advance Payments
  final List<TextEditingController> _advanceAmounts = [];
  final List<String> _advanceModes = [];
  final List<DateTime> _advanceDates = [];

  // License Fields
  late bool _isActive;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _plan;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _businessNameCtrl = TextEditingController(text: c.businessName);
    _ownerNameCtrl = TextEditingController(text: c.ownerName);
    _emailCtrl = TextEditingController(text: c.email);
    _whatsappCtrl = TextEditingController(text: c.whatsappNumber);
    
    // Financials
    _amountCtrl = TextEditingController(text: c.amount.toString());
    _taxCtrl = TextEditingController(text: c.taxPercentage.toString());
    _paymentMode = c.paymentMode.isNotEmpty ? c.paymentMode : 'Cash';
    _paymentStatus = c.paymentStatus.isNotEmpty ? c.paymentStatus : 'Pending';
    
    // Listeners for summary update
    _amountCtrl.addListener(_updateSummary);
    _taxCtrl.addListener(_updateSummary);
    
    // Initialize Advances
    for (var adv in c.advances) {
      final ctrl = TextEditingController(text: adv.amount.toString());
      ctrl.addListener(_updateSummary); // Add listener to existing
      _advanceAmounts.add(ctrl);
      _advanceModes.add(adv.mode);
      _advanceDates.add(adv.date);
    }

    _isActive = c.license.isActive;
    _startDate = c.license.startDate;
    _endDate = c.license.endDate;
    _plan = c.license.plan;
  }

  void _updateSummary() {
    setState(() {});
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _amountCtrl.dispose();
    _taxCtrl.dispose();
    for (var ctrl in _advanceAmounts) ctrl.dispose();
    super.dispose();
  }
  
  // --- Advance Logic ---
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
      builder: (context, child) => _datePickerTheme(child),
    );
    if (picked != null) {
      setState(() {
        _advanceDates[index] = picked;
      });
    }
  }

  Widget _datePickerTheme(Widget? child) {
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
  }

  Future<void> _shareInvoice() async {
    final phone = _whatsappCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''); 
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No WhatsApp number available')));
      return;
    }

    final invoiceUrl = 'https://digibills-c97a9.web.app/#/license-invoice/${widget.client.clientId}';
    final message = 'Dear ${_businessNameCtrl.text},\n\nHere is your invoice for your DigiInvi Annual Plan.\n\nView & Download: $invoiceUrl\n\nThank you for your business!';
    
    final whatsappUrl = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final newLicense = LicenseModel(
        isActive: _isActive,
        plan: _plan,
        startDate: _startDate,
        endDate: _endDate,
      );
      
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

      await ClientService().updateClient(
        clientId: widget.client.clientId,
        businessName: _businessNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        whatsappNumber: _whatsappCtrl.text.trim(),
        license: newLicense,
        amount: double.tryParse(_amountCtrl.text) ?? 0,
        taxPercentage: double.tryParse(_taxCtrl.text) ?? 0,
        paymentMode: _paymentMode,
        paymentStatus: _paymentStatus,
        advances: advances,
      );

      // Dismiss notification if it was a renewal flow
      if (widget.notificationId != null) {
        await NotificationService().deleteNotification(widget.notificationId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
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
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Edit Client', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _shareInvoice,
              icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
              tooltip: 'Share Invoice',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernSection(
                title: 'Business Identity',
                icon: Icons.business_center_rounded,
                children: [
                   _buildTextField(
                    controller: _businessNameCtrl,
                    label: 'Business Name',
                    icon: Icons.business,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _ownerNameCtrl,
                    label: 'Owner Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    icon: Icons.alternate_email,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _whatsappCtrl,
                    label: 'WhatsApp Number',
                    icon: FontAwesomeIcons.whatsapp,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              _buildModernSection(
                title: 'Financial Configuration',
                icon: Icons.account_balance_wallet_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _amountCtrl,
                          label: 'Base Amount',
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _taxCtrl,
                          label: 'Tax %',
                          icon: Icons.percent,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: _paymentMode,
                          label: 'Payment Mode',
                          icon: Icons.payment_rounded,
                          items: ['Cash', 'UPI', 'Cheque', 'Net Banking'],
                          onChanged: (val) => setState(() => _paymentMode = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          value: _paymentStatus,
                          label: 'Payment Status',
                          icon: Icons.info_outline_rounded,
                          items: ['Paid', 'Partial', 'Pending'],
                          onChanged: (val) => setState(() => _paymentStatus = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildAdvancePaymentsSection(),

              const SizedBox(height: 24),
              _buildModernSection(
                title: 'License Management',
                icon: Icons.verified_user_rounded,
                children: [
                   SwitchListTile(
                    title: const Text('License Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(_isActive ? 'User has full access' : 'User is currently blocked', style: const TextStyle(fontSize: 12)),
                    value: _isActive,
                    activeColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                  const Divider(height: 24),
                  _buildDatePickerRow('Start Date', _startDate, () => _selectDate(true)),
                  const SizedBox(height: 12),
                  _buildDatePickerRow('End Date', _endDate, () => _selectDate(false)),
                  if (DateTime.now().isAfter(_endDate)) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 8),
                          Text('This license has expired', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),
              _summaryCard(),

              const SizedBox(height: 24),
              _buildModernSection(
                title: 'Diagnostics',
                icon: Icons.bug_report_rounded,
                children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.amber.shade50,
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.amber.shade200),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text('Tenant ID: ${widget.client.tenantId}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.brown)),
                          const SizedBox(height: 4),
                          Text(widget.client.mouAccepted ? 'MOU Status: Accepted ✅' : 'MOU Status: Pending ⏳', 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.client.mouAccepted ? Colors.green : Colors.orange)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 12),
                   SizedBox(
                     width: double.infinity,
                     child: OutlinedButton.icon(
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => AdminClientMouView(client: widget.client)));
                        },
                        icon: const Icon(Icons.description_rounded, size: 18),
                        label: const Text('View MOU Agreement'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 48),
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
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSaving 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildModernSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required dynamic icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon is IconData
            ? Icon(icon, size: 20, color: AppColors.textGrey)
            : FaIcon(icon, size: 20, color: AppColors.textGrey),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textGrey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
      ),
      items: items.map((val) => DropdownMenuItem(
        value: val, 
        child: Text(val, style: TextStyle(
          color: val == 'Paid' ? Colors.green 
               : val == 'Pending' ? Colors.red : AppColors.textDark,
          fontWeight: (val == 'Paid' || val == 'Pending') ? FontWeight.bold : FontWeight.normal,
        ))
      )).toList(),
    );
  }

  Widget _buildDatePickerRow(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            Row(
              children: [
                Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_month, size: 18, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancePaymentsSection() {
    return _buildModernSection(
      title: 'Advance Collections',
      icon: Icons.payments_rounded,
      children: [
        if (_advanceAmounts.isEmpty)
           const Padding(
             padding: EdgeInsets.symmetric(vertical: 20),
             child: Center(
               child: Text('No advance payments recorded', style: TextStyle(color: AppColors.textGrey, fontSize: 12, fontStyle: FontStyle.italic)),
             ),
           )
        else
          ...List.generate(_advanceAmounts.length, (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _advanceAmounts[index],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Amount', 
                          prefixText: '₹ ',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                      onPressed: () => _pickAdvanceDate(index),
                    ),
                    Text(DateFormat('dd MMM').format(_advanceDates[index]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        onPressed: () => _removeAdvance(index),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _advanceModes[index],
                  decoration: const InputDecoration(
                    labelText: 'Mode', 
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  items: ['Cash', 'UPI', 'Cheque', 'Net Banking']
                      .map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (val) => setState(() => _advanceModes[index] = val!),
                ),
              ],
            ),
          )),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _addAdvance,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Payment'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    final baseAmount = double.tryParse(_amountCtrl.text) ?? 0;
    final taxPercent = double.tryParse(_taxCtrl.text) ?? 0;
    
    final taxAmount = (baseAmount * taxPercent) / 100;
    final grandTotal = baseAmount + taxAmount;
    
    double totalAdvance = 0;
    for (var c in _advanceAmounts) {
      totalAdvance += double.tryParse(c.text) ?? 0;
    }

    final balance = (_paymentStatus == 'Paid') ? 0.0 : (grandTotal - totalAdvance);
    final isPaid = (_paymentStatus == 'Paid') || (balance <= 0 && totalAdvance >= grandTotal);
        
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _summaryRow('Base Amount', '₹${baseAmount.toStringAsFixed(2)}', white: true),
          _summaryRow('Tax (${taxPercent.toStringAsFixed(0)}%)', '₹${taxAmount.toStringAsFixed(2)}', white: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white24),
          ),
          _summaryRow('Grand Total', '₹${grandTotal.toStringAsFixed(2)}', isBold: true, white: true),
          _summaryRow('Total Paid', '- ₹${totalAdvance.toStringAsFixed(2)}', white: true, subtitle: '(Advances)'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white24, thickness: 1.5),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Balance Due', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isPaid ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${(balance < 0 ? 0 : balance).toStringAsFixed(2)}', 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          if (isPaid) ... [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text('FULLY PAID', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool white = false, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
                color: white ? Colors.white.withOpacity(0.7) : AppColors.textGrey,
                fontSize: 13,
              )),
              if (subtitle != null) ... [
                const SizedBox(width: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
              ],
            ],
          ),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
            color: white ? Colors.white : AppColors.textDark,
            fontSize: 14,
          )),
        ],
      ),
    );
  }
}

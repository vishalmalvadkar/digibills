import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart'; // NEW
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../models/settings_model.dart';
import '../../services/settings_service.dart';
import '../../services/auth_service.dart'; // For Logout
import '../../theme/app_colors.dart';
import '../../utils/validators.dart'; 
import 'mou_management_hub_screen.dart'; // NEW


class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _appNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // Contact
  final _phoneCtrl = TextEditingController(); // Contact
  final _gstCtrl = TextEditingController();
  
  // Address
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  // Bank
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _holderNameCtrl = TextEditingController();
  final _upiIdCtrl = TextEditingController();
  final _payeeNameCtrl = TextEditingController();



  // Logo
  String? _logoBase64;
  double _logoWidth = 100;
  double _logoHeight = 100;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.fetchSettings();
      _appNameCtrl.text = settings.tenantName;
      _emailCtrl.text = settings.contactEmail;
      _phoneCtrl.text = settings.contactPhone;
      
      _addressCtrl.text = settings.address;
      _cityCtrl.text = settings.city;
      _districtCtrl.text = settings.district;
      _pincodeCtrl.text = settings.pincode;

      _gstCtrl.text = settings.gstNumber;

      _bankNameCtrl.text = settings.bankName;
      _accountNumberCtrl.text = settings.accountNumber;
      _ifscCtrl.text = settings.ifscCode;
      _holderNameCtrl.text = settings.accountHolderName;
      _upiIdCtrl.text = settings.upiId;
      _payeeNameCtrl.text = settings.payeeName;

      _logoBase64 = settings.logoBase64;
      _logoWidth = settings.logoWidth;
      _logoHeight = settings.logoHeight;


      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      // Handle error
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 200,
        minWidth: 200,
        quality: 80,
        format: CompressFormat.png,
      );
      
      setState(() {
        _logoBase64 = base64Encode(compressed);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // Fetch current settings again to ensure we have latest MOU config
      final current = await _settingsService.fetchSettings();

      final newSettings = AppSettings(
        tenantName: _appNameCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        
        gstNumber: _gstCtrl.text.trim(),

        bankName: _bankNameCtrl.text.trim(),
        accountNumber: _accountNumberCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim(),
        accountHolderName: _holderNameCtrl.text.trim(),
        upiId: _upiIdCtrl.text.trim(),
        payeeName: _payeeNameCtrl.text.trim(),
        
        logoBase64: _logoBase64,
        logoWidth: _logoWidth,
        logoHeight: _logoHeight,
        
        // Preserve MOU Settings
        mouPdfHeaderTitle: current.mouPdfHeaderTitle,
        mouPdfSubHeader: current.mouPdfSubHeader,
        showLogoOnPdf: current.showLogoOnPdf,
      );

      await _settingsService.saveSettings(newSettings);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Admin Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Confidential configuration for SuperAdmin',
                style: TextStyle(fontSize: 14, color: AppColors.textGrey),
              ),
              const SizedBox(height: 32),

              const SizedBox(height: 32),

              // 1. Company Profile Section
              _buildSectionCard(
                title: 'Company Profile',
                icon: Icons.business,
                children: [
                  _buildTextField(
                    _appNameCtrl, 
                    'Company Name', 
                    Icons.store, 
                    validator: (v) => v == null || v.isEmpty ? 'Company Name is required' : null
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_emailCtrl, 'Support Email', Icons.email, validator: Validators.validateEmail),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneCtrl, 'Support Phone', Icons.phone, validator: Validators.validateMobile),
                  const SizedBox(height: 16),
                  _buildTextField(_addressCtrl, 'Head Office Address', Icons.location_on),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_cityCtrl, 'City', Icons.location_city)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(_districtCtrl, 'District', Icons.map)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_pincodeCtrl, 'Pincode', Icons.pin_drop, isNumber: true),
                  const SizedBox(height: 16),
                  _buildTextField(_gstCtrl, 'GST Number', Icons.assignment, textCapitalization: TextCapitalization.characters),
                ],
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 24),
              
              // 3. Banking Details
              _buildSectionCard(
                title: 'Banking Details',
                icon: Icons.account_balance,
                children: [
                   _buildTextField(_bankNameCtrl, 'Bank Name', Icons.account_balance),
                   const SizedBox(height: 16),
                   _buildTextField(_accountNumberCtrl, 'Account Number', Icons.numbers, isNumber: true),
                   const SizedBox(height: 16),
                   _buildTextField(_ifscCtrl, 'IFSC Code', Icons.qr_code, textCapitalization: TextCapitalization.characters),
                   const SizedBox(height: 16),
                   _buildTextField(_holderNameCtrl, 'Account Holder Name', Icons.person),
                   const SizedBox(height: 16),
                   _buildTextField(_upiIdCtrl, 'UPI ID', Icons.payment, validator: Validators.validateUPI),
                   const SizedBox(height: 16),
                   _buildTextField(_payeeNameCtrl, 'Payee Name (for UPI)', Icons.person_outline),
                ],
              ),
              const SizedBox(height: 24),

              // 4. Branding / Logo
              _buildSectionCard(
                title: 'App Branding',
                icon: Icons.brush,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          height: 120, width: 120,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!)
                          ),
                          child: _logoBase64 != null
                              ? Image.memory(base64Decode(_logoBase64!), width: _logoWidth, height: _logoHeight, fit: BoxFit.contain)
                              : const Icon(Icons.business, size: 40, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Upload Logo'),
                            ),
                            if (_logoBase64 != null)
                              TextButton.icon(
                                onPressed: () => setState(() => _logoBase64 = null),
                                icon: const Icon(Icons.delete, color: AppColors.error),
                                label: const Text('Remove', style: TextStyle(color: AppColors.error)),
                              ),
                          ],
                        ),
                        if (_logoBase64 != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Width: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Slider(
                                  value: _logoWidth,
                                  min: 20, 
                                  max: 200,
                                  divisions: 180,
                                  label: _logoWidth.toInt().toString(),
                                  onChanged: (v) => setState(() => _logoWidth = v),
                                ),
                              ),
                              Text('${_logoWidth.toInt()} px'),
                            ],
                          ),
                          Row(
                            children: [
                              const Text('Height: '),
                              Expanded(
                                child: Slider(
                                  value: _logoHeight,
                                  min: 20, 
                                  max: 200,
                                  divisions: 180,
                                  label: _logoHeight.toInt().toString(),
                                  onChanged: (v) => setState(() => _logoHeight = v),
                                ),
                              ),
                              Text('${_logoHeight.toInt()} px'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
             

              
              const SizedBox(height: 24),



              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                     ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                     : const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 40),
              
               Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await AuthService().signOut(); 
                    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text('Logout', style: TextStyle(color: AppColors.error)),
                ),
              ),
               const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
     return Container(
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: AppColors.border),
         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
       ),
       child: Theme(
         data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
         child: ExpansionTile(
           initiallyExpanded: true,
           title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
           leading: Icon(icon, color: AppColors.primary),
           childrenPadding: const EdgeInsets.all(24),
           children: children,
         ),
       ),
     );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {
      String? Function(String?)? validator,
      TextCapitalization textCapitalization = TextCapitalization.none,
      bool isNumber = false,
    }
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
      textCapitalization: textCapitalization,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}

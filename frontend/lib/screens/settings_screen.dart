import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart'; // NEW
import '../models/settings_model.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart'; // NEW
import '../services/security_service.dart'; // NEW
import '../models/user_model.dart'; // NEW
import '../services/user_service.dart'; // NEW
import '../services/license_service.dart'; // NEW
import 'lock_screen.dart'; // NEW
import '../theme/app_colors.dart';
import '../utils/snackbar_helper.dart'; // NEW
import '../widgets/license_scope.dart'; // NEW
import 'mou_screen.dart'; // NEW
import '../utils/responsive.dart'; // RESTORED
import 'package:provider/provider.dart'; // NEW
import '../providers/shell_provider.dart'; // NEW
import '../providers/locale_provider.dart'; // NEW
import '../l10n/app_localizations.dart'; // NEW
import '../utils/validators.dart'; // NEW
import 'settings/manage_users/manage_staff_screen.dart'; // NEW




class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  final _securityService = SecurityService();
  final _userService = UserService(); // NEW

  final _tenantController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _payeeNameController = TextEditingController();
  final _gstController = TextEditingController(); // NEW
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  String? _logoBase64;
  
  final _gstRateController = TextEditingController();
  final _invoicePrefixController = TextEditingController(); // NEW
  final _invoiceStartNumberController = TextEditingController(); // NEW
  String _selectedState = '';
  double _logoWidth = 60.0;
  double _logoHeight = 60.0;
  String _printFormat = 'A4'; // NEW
  
  bool _isPinSet = false;
  bool _isPinLockEnabled = false;
  bool _biometricEnabled = false;
  bool _canCheckBiometrics = false;
  bool _isAuditTrailEnabled = false;
  
  UserModel? _currentUser; // NEW

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? ''; 
    
    try {
      // Parallel Fetch
      final results = await Future.wait([
         _service.fetchSettings(), // Cached
         if (uid.isNotEmpty) _userService.getUser(uid) else Future.value(null), // Cached
      ]);

      final settings = results[0] as AppSettings;
      _currentUser = results[1] as UserModel?;

      // Fallback: If user doc missing, use basic placeholder to ensure UI renders
      if (_currentUser == null && uid.isNotEmpty) {
         _currentUser = UserModel(
           uid: uid,
           role: 'client',
           tenantId: uid,
           createdAt: DateTime.now(),
         );
      }

      _tenantController.text = settings.tenantName;
      _emailController.text = settings.contactEmail;
      _phoneController.text = settings.contactPhone;
      _bankNameController.text = settings.bankName;
      _accountNumberController.text = settings.accountNumber;
      _ifscCodeController.text = settings.ifscCode;
      _accountHolderNameController.text = settings.accountHolderName;
      _upiIdController.text = settings.upiId;
      _payeeNameController.text = settings.payeeName;
      _gstController.text = settings.gstNumber;
      _addressController.text = settings.address;
      _cityController.text = settings.city;
      _districtController.text = settings.district;
      _pincodeController.text = settings.pincode;
      _gstRateController.text = settings.defaultGstRate.toString();
      _invoicePrefixController.text = settings.invoicePrefix;
      _invoiceStartNumberController.text = settings.invoiceStartNumber.toString();
      _selectedState = settings.state;
      _printFormat = settings.printFormat; // Load
      _logoBase64 = settings.logoBase64;
      _logoWidth = settings.logoWidth;
      _logoHeight = settings.logoHeight;
      _isAuditTrailEnabled = settings.isAuditTrailEnabled; // NEW
      
      // Load Security State
      try {
        _isPinSet = await _securityService.isPinSet();
        _isPinLockEnabled = await _securityService.isPinEnabled();
        _biometricEnabled = await _securityService.isBiometricEnabled();
        _canCheckBiometrics = await _securityService.canCheckBiometrics();
      } catch (e) {
        debugPrint('Error loading security settings: $e');
        _isPinSet = false;
        _biometricEnabled = false;
        _canCheckBiometrics = false;
      }

      // Client Read-Only Logic
      // If current user is a Client, fetch Business Name from clients table (set by Superadmin)
      if (_currentUser != null && _currentUser!.role == 'client' && uid.isNotEmpty) {
        try {
          final clientData = await Supabase.instance.client
              .from('clients')
              .select('business_name')
              .eq('client_id', uid)
              .maybeSingle();
          
          if (clientData != null && clientData['business_name'] != null) {
            _tenantController.text = clientData['business_name'];
          } else if (_currentUser!.name != null && _currentUser!.name!.isNotEmpty) {
            _tenantController.text = _currentUser!.name!;
          }
        } catch (e) {
          debugPrint('Error fetching client business name: $e');
          // Fallback to user name
          if (_currentUser!.name != null && _currentUser!.name!.isNotEmpty) {
            _tenantController.text = _currentUser!.name!;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load settings. Please check your connection.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final settings = AppSettings(
        tenantName: _tenantController.text.trim(),
        contactEmail: _emailController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        ifscCode: _ifscCodeController.text.trim(),
        accountHolderName: _accountHolderNameController.text.trim(),
        upiId: _upiIdController.text.trim(),
        payeeName: _payeeNameController.text.trim(),
        gstNumber: _gstController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        district: _districtController.text.trim(),
        pincode: _pincodeController.text.trim(),
        state: _selectedState,
        defaultGstRate: double.tryParse(_gstRateController.text) ?? 18.0,
        printFormat: _printFormat, // Fixed: Added missing field
        logoBase64: _logoBase64,
        logoWidth: _logoWidth,
        logoHeight: _logoHeight,
        isAuditTrailEnabled: _isAuditTrailEnabled,
        invoicePrefix: _invoicePrefixController.text.trim(),
        invoiceStartNumber: int.tryParse(_invoiceStartNumberController.text.trim()) ?? 1,
      );

      await _service.saveSettings(settings);

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Settings saved successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save settings: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handlePinToggle(bool value) async {
    if (value) {
      if (!_isPinSet) {
        // Setup PIN first
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LockScreen(
              mode: LockScreenMode.setup,
              onSuccess: () async {
                await _securityService.setPinEnabled(true);
                setState(() {
                  _isPinSet = true;
                  _isPinLockEnabled = true;
                });
                Navigator.pop(context);
                SnackbarHelper.showSuccess(context, 'PIN setup and lock enabled');
              },
              onCancel: () => Navigator.pop(context),
            ),
          ),
        );
      } else {
        // Just enable it
        await _securityService.setPinEnabled(true);
        setState(() => _isPinLockEnabled = true);
        SnackbarHelper.showSuccess(context, 'App lock enabled');
      }
    } else {
      // Disable PIN Lock (Verification NOT mandatory to disable lock, but 
      // usually good practice. Let's keep it simple as per user request "app will open without asking")
      // Actually, require PIN to turn OFF security is a safety standard.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LockScreen(
            mode: LockScreenMode.verify,
            allowBiometric: true,
            onSuccess: () async {
              await _securityService.setPinEnabled(false);
              setState(() => _isPinLockEnabled = false);
              Navigator.pop(context);
              SnackbarHelper.showSuccess(context, 'App lock disabled');
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  Future<void> _changePin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LockScreen(
          mode: LockScreenMode.verify,
          onSuccess: () {
            Navigator.pop(context);
            // After verifying current, setup new one
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LockScreen(
                  mode: LockScreenMode.setup,
                  onSuccess: () {
                    setState(() => _isPinSet = true);
                    Navigator.pop(context);
                    SnackbarHelper.showSuccess(context, 'PIN changed successfully');
                  },
                  onCancel: () => Navigator.pop(context),
                ),
              ),
            );
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _handleBiometricToggle(bool value) async {
    if (value) {
      // Enable: Verify biometric first
      final success = await _securityService.authenticatedBiometric();
      if (success) {
        await _securityService.setBiometricEnabled(true);
        setState(() => _biometricEnabled = true);
      } else {
         SnackbarHelper.showError(context, 'Biometric authentication failed');
      }
    } else {
      // Disable
      await _securityService.setBiometricEnabled(false);
      setState(() => _biometricEnabled = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 300, 
        minWidth: 300,
        quality: 90, 
        format: CompressFormat.png, // PNG supports transparency
      );
      
      setState(() {
        _logoBase64 = base64Encode(compressedBytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: Responsive.isDesktop(context) ? 800 : double.infinity,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!Responsive.isDesktop(context)) ...[
                  const Text(
                    'Settings', // Keep as title if not localized, or add to arb
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                   Text(
                    AppLocalizations.of(context)?.generalDetails ?? 'Manage your business profile and bank details',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // License Details Card (NEW - Collapsible)
                if (_currentUser != null && _currentUser!.license != null) ...[
                  _buildExpansionCard(
                    title: AppLocalizations.of(context)?.licenseInformation ?? 'License Information',
                    icon: Icons.verified,
                    children: [
                      _infoRow(AppLocalizations.of(context)?.status ?? 'Status', 
                        _currentUser!.license!.isActive 
                          ? (AppLocalizations.of(context)?.active ?? 'Active') 
                          : (AppLocalizations.of(context)?.inactive ?? 'Inactive')),
                      _infoRow(AppLocalizations.of(context)?.subscriptionStart ?? 'Subscription Start', DateFormat('dd MMM yyyy').format(_currentUser!.license!.startDate)),
                      _infoRow(AppLocalizations.of(context)?.subscriptionEnd ?? 'Subscription End', DateFormat('dd MMM yyyy').format(_currentUser!.license!.endDate)),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text(AppLocalizations.of(context)?.remainingDays ?? 'Remaining Days', style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context)?.days(LicenseService().daysRemaining(_currentUser!).toString()) ?? '${LicenseService().daysRemaining(_currentUser!)} days',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: LicenseService().daysRemaining(_currentUser!) < 30 ? AppColors.error : AppColors.success,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // General Details Drawer
                _buildExpansionCard(
                  title: AppLocalizations.of(context)?.generalDetails ?? 'General Details',
                  icon: Icons.business,
                  children: [
                    // Logo Upload Section
                    Center(
                      child: Column(
                        children: [
                          Container(
                            height: 100,
                            width: 100,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _logoBase64 != null
                                ? Image.memory(
                                    base64Decode(_logoBase64!),
                                    width: _logoWidth,
                                    height: _logoHeight,
                                    fit: BoxFit.contain,
                                  )
                                : Icon(Icons.business, size: 40, color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.cloud_upload),
                                label: Text(AppLocalizations.of(context)?.uploadLogo ?? 'Upload Logo'),
                              ),
                              if (_logoBase64 != null)
                                TextButton.icon(
                                  onPressed: () => setState(() => _logoBase64 = null),
                                  icon: const Icon(Icons.delete, color: AppColors.error),
                                  label: Text(AppLocalizations.of(context)?.remove ?? 'Remove', style: const TextStyle(color: AppColors.error)),
                                ),
                            ],
                          ),
                          if (_logoBase64 != null) ...[
                            const SizedBox(height: 16),
                            _sectionHeader('${AppLocalizations.of(context)?.logoHeight ?? 'Logo Height'}: ${_logoHeight.toInt()}'),
                            Slider(
                              value: _logoHeight,
                              min: 20,
                              max: 150,
                              divisions: 130,
                              label: _logoHeight.toInt().toString(),
                              onChanged: (v) => setState(() => _logoHeight = v),
                            ),
                             _sectionHeader('${AppLocalizations.of(context)?.logoWidth ?? 'Logo Width'}: ${_logoWidth.toInt()}'),
                            Slider(
                              value: _logoWidth,
                              min: 20,
                              max: 150,
                              divisions: 130,
                              label: _logoWidth.toInt().toString(),
                              onChanged: (v) => setState(() => _logoWidth = v),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                const SizedBox(height: 24),
    
                // Security Settings
                _buildExpansionCard(
                  title: AppLocalizations.of(context)?.security ?? 'Security',
                  icon: Icons.security,
                  children: [
                    SwitchListTile(
                      title: Text(AppLocalizations.of(context)?.enablePin ?? 'App Lock'),
                      subtitle: Text('Enable/disable PIN lock on startup'),
                      value: _isPinLockEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (value) => _handlePinToggle(value),
                    ),
                    ListTile(
                      title: Text(_isPinSet ? 'Change PIN' : 'Set PIN'),
                      subtitle: Text(_isPinSet ? 'Update your 4-digit security code' : 'Create a PIN for app security'),
                      leading: const Icon(Icons.password, color: AppColors.primary),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
                      onTap: _isPinSet ? _changePin : () => _handlePinToggle(true),
                    ),
                    if (_isPinSet && _canCheckBiometrics)
                       SwitchListTile(
                        title: Text(AppLocalizations.of(context)?.biometricLogin ?? 'Biometric Login'),
                        subtitle: Text(AppLocalizations.of(context)?.useFingerprint ?? 'Use Fingerprint or Face ID'),
                        value: _biometricEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (value) => _handleBiometricToggle(value),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: Text(AppLocalizations.of(context)?.enableAuditTrail ?? 'Enable Audit Trail'),
                        subtitle: Text(AppLocalizations.of(context)?.trackInvoiceEdits ?? 'Track invoice edits and deletions for compliance'),
                        value: _isAuditTrailEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (value) => setState(() => _isAuditTrailEnabled = value),
                      ),
                  ],
                ),
                    const SizedBox(height: 24),
    
                    // MOU Section
                    ListTile(
                      title: Text(AppLocalizations.of(context)?.mouTerms ?? 'MOU and Terms & Conditions'),
                      subtitle: Text(AppLocalizations.of(context)?.viewSignAgreement ?? 'View and sign agreement'),
                      leading: const Icon(Icons.description, color: AppColors.primary),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const MouScreen()));
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
    
                    _buildTextField(
                      _tenantController, 
                      AppLocalizations.of(context)?.businessName ?? 'Business Name', 
                      Icons.store,
                      readOnly: _currentUser?.role != 'superAdmin', // Only SuperAdmin can edit
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_emailController, AppLocalizations.of(context)?.contactEmail ?? 'Contact Email', Icons.email),
                    const SizedBox(height: 16),
                    _buildTextField(_phoneController, AppLocalizations.of(context)?.contactPhone ?? 'Contact Phone', Icons.phone),
                    const SizedBox(height: 16),
                    _buildTextField(_addressController, AppLocalizations.of(context)?.streetAddress ?? 'Street Address', Icons.location_on),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_cityController, AppLocalizations.of(context)?.city ?? 'City', Icons.location_city)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_districtController, AppLocalizations.of(context)?.district ?? 'District', Icons.map)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_pincodeController, AppLocalizations.of(context)?.pincode ?? 'Pincode', Icons.pin_drop, textCapitalization: TextCapitalization.none),
                    const SizedBox(height: 16),
                  
                   Text(
                    AppLocalizations.of(context)?.gstTaxDetails ?? 'GST & Tax Details',
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                    _buildTextField(
                    _gstController, 
                    AppLocalizations.of(context)?.gstNumber ?? 'GST Number', 
                    Icons.assignment_outlined,
                    textCapitalization: TextCapitalization.characters,
                    validator: (val) => Validators.validateGSTIN(val, isOptional: true), // Seller GSTIN optional? User implied strict, but usually it's optional if not registered. Let's make it optional but validated if entered.
                  ),
                  const SizedBox(height: 16),
                
                  // State Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedState.isNotEmpty ? _selectedState : null,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.businessState ?? 'Business State',
                      prefixIcon: const Icon(Icons.map_outlined, color: AppColors.textGrey, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    items: [
                      'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 
                      'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 
                      'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 
                      'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 
                      'Uttarakhand', 'West Bengal', 'Delhi', 'Jammu & Kashmir', 'Ladakh', 'Puducherry', 'Chandigarh',
                      'Dadra and Nagar Haveli and Daman and Diu', 'Andaman and Nicobar Islands', 'Lakshadweep'
                    ].map((state) => DropdownMenuItem(value: state, child: Text(state))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedState = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
    
                  // Default GST Rate
                    TextField(
                      controller: _gstRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.defaultGstRate ?? 'Default GST Rate (%)',
                        prefixIcon: const Icon(Icons.percent, color: AppColors.textGrey, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 24),

                // Invoice Settings Card (Moved out of General Details)
                _buildExpansionCard(
                  title: AppLocalizations.of(context)?.invoiceSettings ?? 'Invoice Settings',
                  icon: Icons.receipt_long,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _invoicePrefixController,
                            AppLocalizations.of(context)?.invoicePrefix ?? 'Prefix (e.g. INV-)',
                            Icons.text_fields,
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            _invoiceStartNumberController,
                            AppLocalizations.of(context)?.nextNumber ?? 'Next Number',
                            Icons.format_list_numbered,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // Printer Format (Kept separate or general)
                _buildExpansionCard(
                  title: 'Printing Preferences', 
                  icon: Icons.print,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _printFormat,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.printerFormat ?? 'Printer Format',
                        prefixIcon: const Icon(Icons.print, color: AppColors.textGrey, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A4', child: Text('Standard A4 / Letter')),
                        DropdownMenuItem(value: 'Thermal58', child: Text('Thermal Receipt (58mm)')),
                        DropdownMenuItem(value: 'Thermal80', child: Text('Thermal Receipt (80mm)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _printFormat = val);
                        }
                      },
                    ),
                  ],
                ),
    
                const SizedBox(height: 24),

                // Manage Staff (Removed as per user request)
                /*
                if (_currentUser?.role == 'client') ...[
                   _buildExpansionCard(
                    title: 'Manage Staff',
                    icon: Icons.people,
                    children: [
                       ListTile(
                        title: const Text('Staff Members'),
                        subtitle: const Text('Add and manage staff access'),
                        leading: const Icon(Icons.person_add, color: AppColors.primary),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStaffScreen())); 
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                */

                // Bank Details Drawer
                _buildExpansionCard(
                  title: AppLocalizations.of(context)?.bankDetails ?? 'Bank Details',
                  icon: Icons.account_balance,
                  children: [
                    _buildTextField(_bankNameController, AppLocalizations.of(context)?.bankName ?? 'Bank Name', Icons.account_balance),
                    const SizedBox(height: 16),
                    _buildTextField(_accountNumberController, AppLocalizations.of(context)?.accountNumber ?? 'Account Number', Icons.numbers),
                    const SizedBox(height: 16),
                    _buildTextField(_ifscCodeController, AppLocalizations.of(context)?.ifscCode ?? 'IFSC Code', Icons.qr_code, textCapitalization: TextCapitalization.characters),
                    const SizedBox(height: 16),
                    _buildTextField(_accountHolderNameController, AppLocalizations.of(context)?.accountHolderName ?? 'Account Holder Name', Icons.person),
                    const SizedBox(height: 16),
                    _buildTextField(_upiIdController, AppLocalizations.of(context)?.upiId ?? 'UPI ID', Icons.payment),
                    const SizedBox(height: 16),
                    _buildTextField(_payeeNameController, AppLocalizations.of(context)?.payeeName ?? 'Payee Name (for UPI)', Icons.person_outline),
                  ],
                ),
    
                const SizedBox(height: 24),

            // App Preferences (Language)
             _buildExpansionCard(
              title: AppLocalizations.of(context)?.language ?? 'Language',
              icon: Icons.language,
              children: [
                Consumer<LocaleProvider>(
        builder: (context, provider, child) {
          return DropdownButtonFormField<Locale>(
            value: provider.locale ?? const Locale('en'),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)?.selectLanguage ?? 'Select Language',
              prefixIcon: const Icon(Icons.translate, color: AppColors.textGrey, size: 20),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: Locale('en'),
                child: Text('English'),
              ),
              const DropdownMenuItem(
                value: Locale('hi'),
                child: Text('हिंदी (Hindi)'),
              ),
            ],
            onChanged: (Locale? newLocale) {
              if (newLocale != null) {
                provider.setLocale(newLocale);
              }
            },
          );
        },
      ),
              ],
            ),
    
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: LicenseScope.isReadOnlyMode(context) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)?.saveChanges ?? 'Save Changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                 const SizedBox(height: 24),
                 SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                       // Clear navigation stack and sign out
                       await AuthService().signOut();
                       
                       // After sign out, the Auth Stream in main.dart will handle navigation to Login
                       // But to be safe and clear the stack:
                       if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                       }
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: Text(
                      AppLocalizations.of(context)?.logOut ?? 'Log Out', 
                      style: const TextStyle(
                        color: AppColors.error, 
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'DigiInvi v1.0 . DigiWebia', 
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          childrenPadding: const EdgeInsets.all(24),
          children: children,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, 
      String label, 
      IconData icon, 
      {TextCapitalization textCapitalization = TextCapitalization.sentences, 
       bool readOnly = false,
       TextInputType? keyboardType, // Added
       String? Function(String?)? validator}) { 
    return TextFormField( 
      controller: controller,
      keyboardType: keyboardType, // Added
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      validator: validator, 
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
        filled: true,
        fillColor: readOnly ? Colors.grey[200] : const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/settings_model.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';
import 'mou_templates_screen.dart';

class MouSettingsScreen extends StatefulWidget {
  const MouSettingsScreen({super.key});

  @override
  State<MouSettingsScreen> createState() => _MouSettingsScreenState();
}

class _MouSettingsScreenState extends State<MouSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  bool _isLoading = true;
  bool _isSaving = false;

  // MOU PDF Config Controllers
  final _mouHeaderCtrl = TextEditingController();
  final _mouSubHeaderCtrl = TextEditingController();
  bool _showLogoOnPdf = true;

  // We need to keep other settings intact when saving, so we load them all
  late AppSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _currentSettings = await _settingsService.fetchSettings();
      
      _mouHeaderCtrl.text = _currentSettings.mouPdfHeaderTitle;
      _mouSubHeaderCtrl.text = _currentSettings.mouPdfSubHeader;
      _showLogoOnPdf = _currentSettings.showLogoOnPdf;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // Create new settings object based on current one + updates
      // We must copy all existing fields from _currentSettings to avoid losing data
      final newSettings = AppSettings(
        tenantName: _currentSettings.tenantName,
        contactEmail: _currentSettings.contactEmail,
        contactPhone: _currentSettings.contactPhone,
        bankName: _currentSettings.bankName,
        accountNumber: _currentSettings.accountNumber,
        ifscCode: _currentSettings.ifscCode,
        accountHolderName: _currentSettings.accountHolderName,
        upiId: _currentSettings.upiId,
        payeeName: _currentSettings.payeeName,
        gstNumber: _currentSettings.gstNumber,
        address: _currentSettings.address,
        city: _currentSettings.city,
        district: _currentSettings.district,
        pincode: _currentSettings.pincode,
        logoBase64: _currentSettings.logoBase64,
        logoWidth: _currentSettings.logoWidth,
        logoHeight: _currentSettings.logoHeight,
        
        // Updated Fields
        mouPdfHeaderTitle: _mouHeaderCtrl.text.trim(),
        mouPdfSubHeader: _mouSubHeaderCtrl.text.trim(),
        showLogoOnPdf: _showLogoOnPdf,
      );

      await _settingsService.saveSettings(newSettings);
      
      // Update local reference
      _currentSettings = newSettings;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MOU Settings saved'), backgroundColor: AppColors.success),
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
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MOU Management'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Template Management Section
              _buildSectionHeader('Templates'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  title: const Text('Manage MOU Templates'),
                  subtitle: const Text('Create and publish MOU versions'),
                  leading: const Icon(Icons.description, color: AppColors.primary),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const MouTemplatesScreen())
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 2. PDF Design Section
              _buildSectionHeader('PDF Design Configuration'),
              const Text(
                'Customize how the downloaded MOU PDF looks for clients.',
                 style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _mouHeaderCtrl,
                decoration: const InputDecoration(
                  labelText: 'PDF Header Title',
                  hintText: 'Memorandum of Understanding',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // SubHeader is now auto-generated from Company Profile (Address/Contact)
              
              SwitchListTile(
                 title: const Text('Show Company Logo on PDF'),
                 subtitle: const Text('Display your business logo on the letterhead'),
                 value: _showLogoOnPdf,
                 activeColor: AppColors.primary,
                 onChanged: (val) => setState(() => _showLogoOnPdf = val),
                 contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Save Configuration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

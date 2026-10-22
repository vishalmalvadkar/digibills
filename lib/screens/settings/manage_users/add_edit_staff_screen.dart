import 'package:flutter/material.dart';
import '../../../../models/staff_model.dart';
import '../../../../services/staff_service.dart';
import '../../../../theme/app_colors.dart'; // NEW

class AddEditStaffScreen extends StatefulWidget {
  final StaffModel? staff;
  const AddEditStaffScreen({super.key, this.staff});

  @override
  State<AddEditStaffScreen> createState() => _AddEditStaffScreenState();
}

class _AddEditStaffScreenState extends State<AddEditStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  final StaffService _staffService = StaffService();
  bool _isLoading = false;

  // Permission Flags
  final Map<String, bool> _permissions = {
    'create_bills': true,
    'view_reports': false,
    'view_dashboard': false,
    'manage_settings': false,
    'manage_inventory': false,
    'manage_returns': false,
  };

  final Map<String, String> _permissionLabels = {
    'create_bills': 'Create & Edit Invoices',
    'view_reports': 'View Reports',
    'view_dashboard': 'View Dashboard',
    'manage_settings': 'Manage Settings',
    'manage_inventory': 'Manage Inventory',
    'manage_returns': 'Process Returns',
  };

  @override
  void initState() {
    super.initState();
    if (widget.staff != null) {
      _nameCtrl.text = widget.staff!.name;
      _emailCtrl.text = widget.staff!.email;
      
      // Load existing permissions
      for (var key in _permissions.keys) {
        if (widget.staff!.permissions.contains(key)) {
          _permissions[key] = true;
        } else {
          _permissions[key] = false;
        }
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final selectedPermissions = _permissions.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      if (widget.staff == null) {
        // Add New
        await _staffService.addStaff(
          _emailCtrl.text.trim(),
          _nameCtrl.text.trim(),
          selectedPermissions,
        );
      } else {
        // Update
        await _staffService.updateStaff(
          widget.staff!.id,
          _nameCtrl.text.trim(),
          selectedPermissions,
        );
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)), // Gray-200
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.staff != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Staff' : 'Add Staff', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: () async {
                 final confirm = await showDialog<bool>(
                   context: context,
                   builder: (c) => AlertDialog(
                     title: const Text('Remove Staff?'),
                     content: const Text('This will remove their access immediately.'),
                     actions: [
                       TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                       TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                     ],
                   ),
                 );
                 
                 if (confirm == true) {
                   await _staffService.deleteStaff(widget.staff!.id);
                   if (mounted) Navigator.pop(context);
                 }
              },
            )
        ],
      ),
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              if (!isEditing)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Staff members must use "Staff First Time Login" on the app login screen to set their password.',
                          style: TextStyle(fontSize: 13, color: AppColors.primary.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ),

              const Text('Staff Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nameCtrl,
                decoration: _buildInputDecoration('Full Name', Icons.person),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: _buildInputDecoration('Email Address', Icons.email),
                enabled: !isEditing,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Access Permissions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Control what this staff member can do.', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: _permissions.keys.map((key) {
                    final isLast = key == _permissions.keys.last;
                    return Column(
                      children: [
                        CheckboxListTile(
                          title: Text(_permissionLabels[key]!, style: const TextStyle(fontWeight: FontWeight.w500)),
                          activeColor: AppColors.primary,
                          value: _permissions[key],
                          onChanged: (val) {
                            setState(() {
                              _permissions[key] = val ?? false;
                            });
                          },
                        ),
                        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : Text(isEditing ? 'Save Changes' : 'Send Invite', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/platform_governance_service.dart';
import '../../models/platform_config_model.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'mou_management_hub_screen.dart';

class AdminGovernanceTab extends StatefulWidget {
  const AdminGovernanceTab({super.key});

  @override
  State<AdminGovernanceTab> createState() => _AdminGovernanceTabState();
}

class _AdminGovernanceTabState extends State<AdminGovernanceTab> {
  final _announcementCtrl = TextEditingController();
  final _maintenanceMsgCtrl = TextEditingController();
  final _mouNameCtrl = TextEditingController();
  final _mouAddressCtrl = TextEditingController();
  final _mouFooterCtrl = TextEditingController();
  final _mouHeaderTitleCtrl = TextEditingController();
  
  String? _mouLogoBase64;
  String? _mouWatermarkBase64;

  late Stream<PlatformConfigModel> _configStream;
  String? _announcementType;
  bool _isSaving = false;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _configStream = PlatformGovernanceService().streamConfig();
  }

  @override
  void dispose() {
    _announcementCtrl.dispose();
    _maintenanceMsgCtrl.dispose();
    _mouNameCtrl.dispose();
    _mouAddressCtrl.dispose();
    _mouFooterCtrl.dispose();
    _mouHeaderTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMOUAsset(bool isLogo) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);
      setState(() {
        if (isLogo) {
          _mouLogoBase64 = base64;
        } else {
          _mouWatermarkBase64 = base64;
        }
      });
    }
  }

  Widget _buildAssetPreview(String label, String base64, VoidCallback onClear) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 60,
              width: 80,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(base64Decode(base64), fit: BoxFit.contain),
            ),
            Positioned(
              top: -8, right: -8,
              child: IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
      ],
    );
  }

  Future<void> _updateConfig(PlatformConfigModel current, {bool? maintenanceMode}) async {
    setState(() => _isSaving = true);
    try {
      final newConfig = current.copyWith(
        maintenanceMode: maintenanceMode,
        announcementText: _announcementCtrl.text.trim(),
        announcementType: _announcementType,
        maintenanceMessage: _maintenanceMsgCtrl.text.trim(),
        mouAppName: _mouNameCtrl.text.trim(),
        mouAddress: _mouAddressCtrl.text.trim(),
        mouFooter: _mouFooterCtrl.text.trim(),
        mouHeaderTitle: _mouHeaderTitleCtrl.text.trim(),
        mouLogoBase64: _mouLogoBase64,
        mouWatermarkBase64: _mouWatermarkBase64,
        updatedAt: DateTime.now(),
      );

      await PlatformGovernanceService().updateConfig(newConfig);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Platform configuration updated')),
        );
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlatformConfigModel>(
      stream: _configStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = snapshot.data!;
        
        // Initialize controllers and state if first load
        if (!_initialLoaded) {
          _announcementCtrl.text = config.announcementText ?? '';
          _maintenanceMsgCtrl.text = config.maintenanceMessage;
          _mouNameCtrl.text = config.mouAppName;
          _mouAddressCtrl.text = config.mouAddress;
          _mouFooterCtrl.text = config.mouFooter;
          _mouHeaderTitleCtrl.text = config.mouHeaderTitle;
          _mouLogoBase64 = config.mouLogoBase64;
          _mouWatermarkBase64 = config.mouWatermarkBase64;
          _announcementType = config.announcementType;
          _initialLoaded = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('Maintenance Mode'),
              const SizedBox(height: 16),
              _buildModernCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Maintenance Mode Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text('Prevents all clients from using the app.', style: TextStyle(fontSize: 13)),
                      value: config.maintenanceMode,
                      activeColor: AppColors.error,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => _updateConfig(config, maintenanceMode: val),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _maintenanceMsgCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Maintenance Message',
                        hintText: 'Enter message to show during maintenance...',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              _buildHeader('Global Announcement'),
              const SizedBox(height: 16),
              _buildModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _announcementCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Banner Text',
                        hintText: 'e.g., System Update at 10 PM...',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _announcementType,
                      decoration: const InputDecoration(labelText: 'Banner Priority'),
                      items: const [
                        DropdownMenuItem(value: 'info', child: _TypeItem(color: AppColors.primary, label: 'Standard (Info)', icon: Icons.info_outline)),
                        DropdownMenuItem(value: 'success', child: _TypeItem(color: AppColors.success, label: 'Success (Green)', icon: Icons.check_circle_outline)),
                        DropdownMenuItem(value: 'warning', child: _TypeItem(color: AppColors.warning, label: 'Warning (Amber)', icon: Icons.warning_amber_rounded)),
                        DropdownMenuItem(value: 'error', child: _TypeItem(color: AppColors.error, label: 'Critical (Red)', icon: Icons.error_outline)),
                      ],
                      onChanged: (val) => setState(() => _announcementType = val!),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _updateConfig(config),
                        icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                        label: const Text('Apply Changes Globally'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (config.announcementText != null && config.announcementText!.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextButton.icon(
                            onPressed: () {
                              _announcementCtrl.clear();
                              _updateConfig(config);
                            },
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                            label: const Text('Clear Banner', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              _buildHeader('MOU Management'),
              const SizedBox(height: 16),
              _buildModernCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.description_outlined, color: AppColors.primary),
                  ),
                  title: const Text('MOU Management Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: const Text('Manage global branding, logos, and MOU version templates in one place.', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGrey),
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const MouManagementHubScreen())
                  ),
                ),
              ),

              const SizedBox(height: 32),
              _buildHeader('App Version Audit'),
              const SizedBox(height: 16),
              _buildVersionAuditList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVersionAuditList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: PlatformGovernanceService().fetchVersionAudit(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final users = snapshot.data!;
        
        return _buildModernCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              final version = user['app_version'] ?? 'Unknown';
              final lastActive = user['last_active_at'] != null 
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(user['last_active_at']))
                  : 'Never';
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: user['role'] == 'superAdmin' ? Colors.purple : AppColors.primary,
                  child: Text(
                    (user['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user['name'] ?? user['email'] ?? 'Unnamed Client'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Version: $version', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Last Active: $lastActive', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                trailing: user['role'] == 'superAdmin' 
                    ? const Chip(label: Text('Admin', style: TextStyle(fontSize: 10)), backgroundColor: Colors.purpleAccent, labelStyle: TextStyle(color: Colors.white))
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textGrey, letterSpacing: 1.5),
    );
  }

  Widget _buildModernCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _TypeItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const _TypeItem({required this.color, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

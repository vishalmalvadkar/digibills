import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/platform_config_model.dart';
import '../../models/mou_template_model.dart';
import '../../services/platform_governance_service.dart';
import '../../services/mou_service.dart';
import '../../theme/app_colors.dart';
import 'mou_edit_screen.dart';

class MouManagementHubScreen extends StatefulWidget {
  const MouManagementHubScreen({super.key});

  @override
  State<MouManagementHubScreen> createState() => _MouManagementHubScreenState();
}

class _MouManagementHubScreenState extends State<MouManagementHubScreen> {
  // Branding Controllers
  final _mouNameCtrl = TextEditingController();
  final _mouAddressCtrl = TextEditingController();
  final _mouFooterCtrl = TextEditingController();
  final _mouHeaderTitleCtrl = TextEditingController();
  
  String? _mouLogoBase64;
  String? _mouWatermarkBase64;

  late Stream<PlatformConfigModel> _configStream;
  bool _isSavingBranding = false;
  bool _initialBrandingLoaded = false;

  @override
  void initState() {
    super.initState();
    _configStream = PlatformGovernanceService().streamConfig();
  }

  @override
  void dispose() {
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

  Future<void> _updateBranding(PlatformConfigModel current) async {
    setState(() => _isSavingBranding = true);
    try {
      final newConfig = current.copyWith(
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
          const SnackBar(content: Text('MOU branding updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBranding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('MOU Management Hub'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.brush), text: 'Branding'),
              Tab(icon: Icon(Icons.description), text: 'Templates'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
          ),
        ),
        body: TabBarView(
          children: [
            _buildBrandingTab(),
            _buildTemplatesTab(),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            if (tabController.index == 1) {
              return FloatingActionButton(
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add),
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const MouEditScreen())
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildBrandingTab() {
    return StreamBuilder<PlatformConfigModel>(
      stream: _configStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = snapshot.data!;
        
        if (!_initialBrandingLoaded) {
          _mouNameCtrl.text = config.mouAppName;
          _mouAddressCtrl.text = config.mouAddress;
          _mouFooterCtrl.text = config.mouFooter;
          _mouHeaderTitleCtrl.text = config.mouHeaderTitle;
          _mouLogoBase64 = config.mouLogoBase64;
          _mouWatermarkBase64 = config.mouWatermarkBase64;
          _initialBrandingLoaded = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Global Branding'),
              const SizedBox(height: 16),
              _buildModernCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _mouHeaderTitleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Main Header Title',
                        hintText: 'e.g., MEMORANDUM OF UNDERSTANDING',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mouNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Organization App Name',
                        hintText: 'e.g., DigiInvi',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mouAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Organization Address (MOU)',
                        hintText: 'e.g., Pune, Maharashtra',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mouFooterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sticky Footer (MOU)',
                        hintText: 'e.g., DigiInvi - developed by DigiWebia',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Visual Assets'),
              const SizedBox(height: 16),
              _buildModernCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickMOUAsset(true),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('MOU Logo'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickMOUAsset(false),
                            icon: const Icon(Icons.layers_outlined),
                            label: const Text('Watermark'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_mouLogoBase64 != null || _mouWatermarkBase64 != null) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (_mouLogoBase64 != null)
                             _buildAssetPreview('Logo', _mouLogoBase64!, () => setState(() => _mouLogoBase64 = null)),
                          if (_mouWatermarkBase64 != null)
                            _buildAssetPreview('Watermark', _mouWatermarkBase64!, () => setState(() => _mouWatermarkBase64 = null)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSavingBranding ? null : () => _updateBranding(config),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSavingBranding 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Save MOU Branding', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplatesTab() {
    return StreamBuilder<List<MouTemplateModel>>(
      stream: MouService().streamTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final templates = snapshot.data ?? [];
        
        if (templates.isEmpty) {
           MouService().getActiveTemplate(); 
           return const Center(child: Text('Loading default template...'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: templates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final template = templates[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: template.isActive 
                    ? const BorderSide(color: AppColors.primary, width: 2) 
                    : BorderSide.none,
              ),
              child: ListTile(
                title: Text(
                  'Version: ${template.version}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Updated: ${DateFormat('dd MMM yyyy, HH:mm').format(template.updatedAt)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (template.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('ACTIVE', style: TextStyle(
                          color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12
                        )),
                      )
                    else 
                      TextButton(
                        onPressed: () => _confirmPublish(context, template),
                        child: const Text('Publish'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => MouEditScreen(template: template))
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmPublish(BuildContext context, MouTemplateModel template) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Publish Version?'),
        content: Text('This will make version ${template.version} the active MOU for all new clients. Existing active template will be deactivated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await MouService().publishTemplate(template.id);
            }, 
            child: const Text('Publish')
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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
              child: Image.memory(base64Decode(label == 'Logo' ? base64 : base64), fit: BoxFit.contain),
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
}

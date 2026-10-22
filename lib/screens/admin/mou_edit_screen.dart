import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/mou_template_model.dart';
import '../../models/settings_model.dart'; // NEW
import '../../services/mou_service.dart';
import '../../services/settings_service.dart'; // NEW
import '../../theme/app_colors.dart';

class MouEditScreen extends StatefulWidget {
  final MouTemplateModel? template;

  const MouEditScreen({super.key, this.template});

  @override
  State<MouEditScreen> createState() => _MouEditScreenState();
}

class _MouEditScreenState extends State<MouEditScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _versionController;
  late TabController _tabController;
  
  final Map<String, TextEditingController> _contentControllers = {};
  final List<String> _languages = ['en', 'hi'];
  final Map<String, String> _langLabels = {'en': 'English', 'hi': 'Hindi'};

  // Header Config Controllers (Global Settings)
  bool _isLoadingSettings = true;
  AppSettings? _currentSettings;
  final _companyNameCtrl = TextEditingController(); // Maps to tenantName
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController(); // Maps to phone
  String? _logoBase64;
  double _logoWidth = 60;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _versionController = TextEditingController(text: widget.template?.version ?? '');
    _tabController = TabController(length: 3, vsync: this);

    _loadSettings(); // NEW: Load Global Settings

    for (var lang in _languages) {
      String existingContent = widget.template?.content[lang] ?? '';
      
      // Pre-fill default template for new items to mimic old hardcoded intro
      if (existingContent.isEmpty && widget.template == null && lang == 'en') {
        existingContent = '''
Date: {{date}}

This Agreement is between **{{company_name}}** (Service Provider) and **{{client_business_name}}** (Client).

# Terms & Conditions
1. Services provided include...
2. Payment terms are...
''';
      }

      _contentControllers[lang] = TextEditingController(text: existingContent);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService().fetchSettings();
      setState(() {
        _currentSettings = settings;
        _companyNameCtrl.text = settings.tenantName;
        _addressCtrl.text = settings.address;
        _contactCtrl.text = settings.contactPhone;
        _logoBase64 = settings.logoBase64;
        _logoWidth = settings.logoWidth;
        _isLoadingSettings = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
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

  @override
  void dispose() {
    _versionController.dispose();
    _tabController.dispose();
    _companyNameCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    for (var controller in _contentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      // 1. SAVE GLOBAL SETTINGS (Header Config)
      if (_currentSettings != null) {
         final newSettings = AppSettings(
           tenantName: _companyNameCtrl.text.trim(),
           contactEmail: _currentSettings!.contactEmail, // Keep
           contactPhone: _contactCtrl.text.trim(),
           bankName: _currentSettings!.bankName,
           accountNumber: _currentSettings!.accountNumber,
           ifscCode: _currentSettings!.ifscCode,
           accountHolderName: _currentSettings!.accountHolderName,
           upiId: _currentSettings!.upiId,
           payeeName: _currentSettings!.payeeName,
           gstNumber: _currentSettings!.gstNumber,
           address: _addressCtrl.text.trim(),
           city: _currentSettings!.city,
           district: _currentSettings!.district,
           pincode: _currentSettings!.pincode,
           logoBase64: _logoBase64,
           logoWidth: _logoWidth,
           logoHeight: _currentSettings!.logoHeight,
           mouPdfHeaderTitle: _currentSettings!.mouPdfHeaderTitle,
           mouPdfSubHeader: _currentSettings!.mouPdfSubHeader,
           showLogoOnPdf: _currentSettings!.showLogoOnPdf,
         );
         await SettingsService().saveSettings(newSettings);
      }

      // 2. SAVE TEMPLATE (Content)
      final contentMap = _contentControllers.map((key, value) => MapEntry(key, value.text));
      
      final newTemplate = MouTemplateModel(
        id: widget.template?.id ?? '', // Service handles new ID if empty
        version: _versionController.text.trim(),
        isActive: widget.template?.isActive ?? false, 
        updatedAt: DateTime.now(),
        content: contentMap,
      );

      await MouService().saveTemplate(newTemplate);
      
      if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved Template & Header Config')));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSettings) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'New Template' : 'Edit Template & Header'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('Save All', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // --- HEADER CONFIGURATION SECTION ---
                    ExpansionTile(
                      initiallyExpanded: true,
                      title: const Text('PDF Header Configuration (Global)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      subtitle: const Text('Edit Company Name, Logo and Address appearing on all MOUs'),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo Upload
                            Column(
                              children: [
                                InkWell(
                                  onTap: _pickLogo,
                                  child: Container(
                                    height: 80, width: 80,
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                                    child: _logoBase64 != null 
                                      ? Image.memory(base64Decode(_logoBase64!), fit: BoxFit.contain)
                                      : const Icon(Icons.add_a_photo, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text('Logo', style: TextStyle(fontSize: 12)),
                                if (_logoBase64 != null)
                                  TextButton(onPressed: () => setState(() => _logoBase64 = null), child: const Text('Remove', style: TextStyle(fontSize: 10, color: Colors.red)))
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _companyNameCtrl,
                                    decoration: const InputDecoration(labelText: 'Company/Provider Name', isDense: true, border: OutlineInputBorder()),
                                    validator: (v) => v!.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _addressCtrl,
                                    decoration: const InputDecoration(labelText: 'Head Office Address', isDense: true, border: OutlineInputBorder()),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _contactCtrl,
                                    decoration: const InputDecoration(labelText: 'Contact Phone', isDense: true, border: OutlineInputBorder()),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                      ],
                    ),

                    // --- CONTENT EDITING SECTION ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextFormField(
                        controller: _versionController,
                        decoration: const InputDecoration(
                          labelText: 'Template Version (e.g. v2.0)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.verified),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    
                    Container(
                      color: Colors.grey[100],
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.primary,
                        tabs: _languages.map((l) => Tab(text: _langLabels[l])).toList(),
                      ),
                    ),
                    
                    // Formatting Toolbar
                    Container(
                      color: Colors.grey[200],
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          IconButton(onPressed: () => _insertText('**', '**'), icon: const Text('B', style: TextStyle(fontWeight: FontWeight.bold))),
                          IconButton(onPressed: () => _insertText('<u>', '</u>'), icon: const Text('U', style: TextStyle(decoration: TextDecoration.underline))),
                          const VerticalDivider(width: 20),
                          IconButton(onPressed: () => _insertText('{{company_name}}', ''), icon: const Text('{Co}', style: TextStyle(color: Colors.blue)), tooltip: 'Insert Company Name'),
                          IconButton(onPressed: () => _insertText('{{client_business_name}}', ''), icon: const Text('{Client}', style: TextStyle(color: Colors.green)), tooltip: 'Insert Client Business Name'),
                          IconButton(onPressed: () => _insertText('{{date}}', ''), icon: const Icon(Icons.calendar_today, size: 16), tooltip: 'Insert Date'),
                        ],
                      ),
                    ),
                    
                    SizedBox(
                      height: 400, // Fixed height for editor
                      child: TabBarView(
                        controller: _tabController,
                        children: _languages.map((lang) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextFormField(
                              controller: _contentControllers[lang],
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: 'Enter agreement content here...',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _insertText(String prefix, String suffix) {
    final lang = _languages[_tabController.index];
    final controller = _contentControllers[lang]!;
    final text = controller.text;
    final selection = controller.selection;
    
    if (selection.start == -1) {
       controller.text = '$text$prefix$suffix';
    } else {
       final newText = text.replaceRange(selection.start, selection.end, '$prefix${text.substring(selection.start, selection.end)}$suffix');
       controller.value = TextEditingValue(
         text: newText,
         selection: TextSelection.collapsed(offset: selection.start + prefix.length + (selection.end - selection.start) + suffix.length),
       );
    }
  }
}

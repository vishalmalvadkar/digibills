import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../services/mou_service.dart';
import '../models/mou_template_model.dart';
import '../models/client_model.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../utils/mou_pdf_helper.dart';
import '../utils/snackbar_helper.dart';
import '../utils/file_download_helper.dart';
import '../services/platform_governance_service.dart';
import '../models/platform_config_model.dart';

class MouScreen extends StatefulWidget {
  const MouScreen({super.key});

  @override
  State<MouScreen> createState() => _MouScreenState();
}

class _MouScreenState extends State<MouScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  
  // State
  ClientModel? _client;
  AppSettings? _settings; // NEW: Fetch settings for display
  PlatformConfigModel? _platformConfig; // NEW: Global branding
  MouTemplateModel? _template; // Active or Accepted Template
  String? _content; // Display Content
  
  // Acceptance State
  bool _isChecked = false;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );
  
  String _selectedLang = 'en'; // Default
  final List<String> _languages = ['en', 'hi'];
  final Map<String, String> _langLabels = {'en': 'English', 'hi': 'Hindi'};

  // Signature Upload State
  bool _isSignatureUpload = false;
  String? _uploadedSignatureBase64;
  final ImagePicker _picker = ImagePicker();
  StreamSubscription? _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _signatureController.dispose();
    _configSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Not logged in';

      // 1. Fetch Client
      final clientData = await Supabase.instance.client
          .from('clients')
          .select()
          .eq('client_id', user.id)
          .maybeSingle();
          
      if (clientData == null) throw 'Client record not found';
      
      _client = ClientModel.fromMap(clientData);
      
      // 2. Fetch Settings (for Company Name)
      _settings = await SettingsService().fetchTenantSettings(_client!.tenantId);

      // 2.5 Fetch Platform Config then setup Listener for Global Branding
      _platformConfig = await PlatformGovernanceService().fetchConfig();
      _updateContent(); // Initial update with fetched config

      _configSubscription?.cancel();
      _configSubscription = PlatformGovernanceService().streamConfig().listen((config) {
        if (mounted) {
          setState(() {
             _platformConfig = config;
             _updateContent();
          });
        }
      });

      // 3. Determine Template
      if (_client!.mouAccepted && _client!.mouMeta != null) {
        // ALREADY ACCEPTED -> Load Specific Version
        final version = _client!.mouMeta!['version'];
        _selectedLang = _client!.mouMeta!['language'] ?? 'en';
        _template = await MouService().getTemplateByVersion(version);
      } else {
        // PENDING -> Load Active Template
        _template = await MouService().getActiveTemplate();
        if (_template == null) throw 'No active MOU template found. Please contact support.';
      }

      _updateContent();

    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateContent() {
    if (_template != null) {
      String rawContent = _template!.content[_selectedLang] ?? _template!.content['en'] ?? '';
      
      // Dynamic Replacement for Display
      if (_settings != null) {
          rawContent = rawContent.replaceAll('{{company_name}}', _platformConfig?.mouAppName ?? _settings!.tenantName);
          rawContent = rawContent.replaceAll('[Company Name]', _platformConfig?.mouAppName ?? _settings!.tenantName);
      }
      
      // Dynamic Placeholders for "Complete Control"
      if (_client != null) {
         // Determine date: Signed Date if accepted, or Today if pending
         DateTime dateObj;
         if (_client!.mouAccepted && _client!.mouMeta != null && _client!.mouMeta!['signedAt'] != null) {
             final raw = _client!.mouMeta!['signedAt'];
             if (raw is String) {
               dateObj = DateTime.parse(raw);
             } else {
               dateObj = DateTime.now(); // Fallback
             }
         } else {
             dateObj = DateTime.now();
         }
         
         final date = DateFormat('dd MMM yyyy').format(dateObj);
         
         rawContent = rawContent.replaceAll('{{date}}', date);
         rawContent = rawContent.replaceAll('{{client_name}}', _client!.ownerName);
         rawContent = rawContent.replaceAll('{{client_business_name}}', _client!.businessName);
      }

      setState(() {
        _content = rawContent;
      });
    }
  }

  Future<void> _pickSignature() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // Built-in compression to avoid external lib issues
        maxWidth: 600,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _uploadedSignatureBase64 = base64Encode(bytes);
          _signatureController.clear(); 
        });
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Error picking image: $e');
    }
  }

  Future<void> _submitAcceptance() async {
    if (!_isChecked) {
      if (mounted) SnackbarHelper.showError(context, 'Please accept the terms');
      return;
    }
    
    String finalSignature;
    
    if (_uploadedSignatureBase64 != null) {
       finalSignature = _uploadedSignatureBase64!;
    } else if (_signatureController.isNotEmpty) {
       final signatureBytes = await _signatureController.toPngBytes();
       if (signatureBytes == null) throw 'Failed to capture signature';
       finalSignature = base64Encode(signatureBytes);
    } else {
       if (mounted) SnackbarHelper.showError(context, 'Please sign or upload a signature');
       return;
    }

    setState(() => _isSaving = true);

    try {
      await MouService().acceptMou(
        clientId: _client!.clientId,
        tenantId: _client!.tenantId,
        version: _template!.version,
        language: _selectedLang,
        signatureData: finalSignature,
      );

      if (mounted) SnackbarHelper.showSuccess(context, 'MOU Accepted Successfully');
      
      // Return true to caller if they are waiting
      if (mounted) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _downloadPdf() async {
      if (_client == null || !_client!.mouAccepted) return;
      
      try {
         _settings = await SettingsService().fetchTenantSettings(_client!.tenantId);
      } catch (e) {
         // Fallback
      }

      if (_settings == null) return;
      
      // Build Contact Strings
      String contactInfo = '';
      if (_settings!.contactEmail.isNotEmpty) contactInfo += 'Email: ${_settings!.contactEmail}\n';
      if (_settings!.contactPhone.isNotEmpty) contactInfo += 'Phone: ${_settings!.contactPhone}';

      final sigBase64 = await MouService().getSignatureData(_client!.clientId);
      
      DateTime dateObj = DateTime.now();
      if (_client!.mouMeta != null && _client!.mouMeta!['signedAt'] != null) {
         final raw = _client!.mouMeta!['signedAt'];
         if (raw is String) dateObj = DateTime.parse(raw);
      }
      
      final date = DateFormat('dd MMM yyyy').format(dateObj);
      
      final providerName = _settings!.tenantName.isNotEmpty 
          ? _settings!.tenantName 
          : 'Company Name Not Set';

      final pdfBytes = await MouPdfHelper.generate(
        content: _content ?? '', 
        businessName: _client!.businessName.isNotEmpty ? _client!.businessName : (Supabase.instance.client.auth.currentUser?.email ?? ''),
        ownerName: _client!.ownerName,
        date: date,
        signatureBase64: sigBase64,
        mouLogoBase64: _platformConfig?.mouLogoBase64,
        mouWatermarkBase64: _platformConfig?.mouWatermarkBase64,
        mouAppName: _platformConfig?.mouAppName ?? 'DigiInvi',
        mouAddress: _platformConfig?.mouAddress ?? (_settings?.address ?? 'Technology Solutions Provider'),
        mouFooter: _platformConfig?.mouFooter ?? 'DigiInvi - developed by DigiWebia',
        headerTitle: _platformConfig?.mouHeaderTitle ?? (_settings!.mouPdfHeaderTitle.isNotEmpty ? _settings!.mouPdfHeaderTitle : 'MEMORANDUM OF UNDERSTANDING'),
      );

      await FileDownloadHelper.downloadFile(
        Uint8List.fromList(pdfBytes), 
        'MOU_Signed', 
        'pdf'
      );
  }

  Future<void> _deleteMou() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Accepted MOU?'),
        content: const Text('This will reset the agreement status. You will need to sign again to create bills.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await MouService().deleteClientMou(_client!.clientId);
        
        // Reset acceptance state
        setState(() {
           _isChecked = false;
           _uploadedSignatureBase64 = null;
           _signatureController.clear();
        });

        if (mounted) SnackbarHelper.showSuccess(context, 'MOU Deleted');
        await _loadData(); // Reload
      } catch (e) {
        if (mounted) SnackbarHelper.showError(context, 'Error: $e');
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAccepted = _client?.mouAccepted ?? false;
    final primaryColor = AppColors.primary;

    // Helper for date display
    String signedDateStr = '?';
    if (_client?.mouMeta != null && _client!.mouMeta!['signedAt'] != null) {
       final raw = _client!.mouMeta!['signedAt'];
       if (raw is String) {
          signedDateStr = DateFormat('d MMMM yyyy').format(DateTime.parse(raw));
       }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('MOU Agreement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
        actions: [
          if (isAccepted) ...[
             IconButton(onPressed: _deleteMou, icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Delete MOU'),
             IconButton(onPressed: _downloadPdf, icon: const Icon(Icons.download_rounded), tooltip: 'Download Signed PDF'),
          ]
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor)) 
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header / Intro
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.description_outlined, size: 32, color: primaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isAccepted ? 'Agreement Signed' : 'Review Agreement',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isAccepted 
                          ? 'You have successfully accepted the Memorandum of Understanding.'
                          : 'Please review the terms below carefully before accepting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Status Card (If Accepted)
                if (isAccepted)
                   Container(
                     margin: const EdgeInsets.only(bottom: 24),
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Colors.green.shade50,
                       border: Border.all(color: Colors.green.shade200),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Row(
                       children: [
                         const Icon(Icons.check_circle, color: Colors.green, size: 28),
                         const SizedBox(width: 16),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               const Text('Signed & Verified', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                               const SizedBox(height: 4),
                               Text(
                                 'Version ${_template?.version ?? '?'} • $signedDateStr',
                                 style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                               ),
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),

                // Language Selector (Pending only)
                if (!isAccepted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Read in: ', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedLang,
                            isDense: true,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                            items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(_langLabels[l]!, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedLang = val;
                                  _updateContent();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                Stack(
                  children: [
                    // Content Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // Letterhead in UI
                            if (_platformConfig != null) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _platformConfig!.mouAppName,
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _platformConfig!.mouAddress,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('OFFICIAL DOCUMENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_platformConfig!.mouLogoBase64 != null && _platformConfig!.mouLogoBase64!.isNotEmpty)
                                    Container(
                                      width: 70, height: 70,
                                      margin: const EdgeInsets.only(left: 12),
                                      child: Image.memory(base64Decode(_platformConfig!.mouLogoBase64!), fit: BoxFit.contain),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(thickness: 1.5, color: AppColors.primary),
                              const SizedBox(height: 12),
                            ],
                            
                            Center(
                              child: Text(
                                _platformConfig?.mouHeaderTitle ?? 'MEMORANDUM OF UNDERSTANDING',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                              ),
                            ),
                            const SizedBox(height: 16),
    
                           MarkdownBody(
                             data: _content ?? 'No Content',
                             styleSheet: MarkdownStyleSheet(
                               p: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                               h1: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                               h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                             ),
                           ),
                           
                           // Footer in UI
                           if (_platformConfig != null) ...[
                             const SizedBox(height: 40),
                             const Divider(color: AppColors.border),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.end,
                               children: [
                                  Text(_platformConfig!.mouFooter, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                               ],
                             ),
                           ],
                        ],
                      ),
                    ),
                    
                    // Watermark Over Content
                    if (_platformConfig?.mouWatermarkBase64 != null)
                      Positioned.fill(
                        child: Center(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.05,
                              child: Image.memory(
                                base64Decode(_platformConfig!.mouWatermarkBase64!),
                                width: 250,
                                height: 250,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 32),

                // Action Area
                if (!isAccepted) ...[
                   const Text('Acceptance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   Container(
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.grey[200]!),
                     ),
                     child: CheckboxListTile(
                       value: _isChecked,
                       activeColor: primaryColor,
                       onChanged: (v) => setState(() => _isChecked = v ?? false),
                       title: const Text('I have carefully read and I agree to the terms and conditions stated above.', style: TextStyle(fontSize: 14)),
                       controlAffinity: ListTileControlAffinity.leading,
                       contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                     ),
                   ),
                   const SizedBox(height: 24),
                   
                   // Signature Section
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const Text('Your Signature', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                       TextButton.icon(
                         onPressed: _pickSignature,
                         icon: const Icon(Icons.upload_file, size: 18),
                         label: const Text('Upload Image'),
                       ),
                     ],
                   ),
                   const SizedBox(height: 12),
                   
                   if (_uploadedSignatureBase64 != null) 
                     Stack(
                       children: [
                          Container(
                             height: 150,
                             width: double.infinity,
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(
                               border: Border.all(color: Colors.grey.shade300),
                               borderRadius: BorderRadius.circular(12),
                               color: Colors.white,
                             ),
                             child: Image.memory(base64Decode(_uploadedSignatureBase64!), fit: BoxFit.contain),
                          ),
                          Positioned(
                             top: 8, right: 8,
                             child: IconButton(
                               onPressed: () => setState(() => _uploadedSignatureBase64 = null),
                               icon: const Icon(Icons.close, color: Colors.red),
                             ),
                          ),
                       ],
                     )
                   else
                     Stack(
                       children: [
                         Container(
                           height: 180,
                           decoration: BoxDecoration(
                             color: Colors.white,
                             border: Border.all(color: Colors.grey[300]!),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(12),
                             child: Signature(
                               controller: _signatureController,
                               backgroundColor: Colors.transparent,
                               height: 180,
                             ),
                           ),
                         ),
                         Positioned(
                           bottom: 8, 
                           right: 8,
                           child: TextButton.icon(
                             onPressed: () => _signatureController.clear(),
                             icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                             label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12)),
                             style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8)),
                           ),
                         ),
                         Positioned(
                           top: 8, left: 16,
                           child: Text('Sign Here', style: TextStyle(color: Colors.grey[300], fontSize: 24, fontWeight: FontWeight.bold)),
                         ),
                       ],
                     ),
                   
                   const SizedBox(height: 32),
                   
                   SizedBox(
                     height: 54,
                     child: ElevatedButton(
                       onPressed: _isSaving ? null : _submitAcceptance,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: primaryColor,
                         foregroundColor: Colors.white,
                         elevation: 2,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       child: _isSaving 
                         ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                         : const Text('ACCEPT AGREEMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                     ),
                   ),
                   const SizedBox(height: 20),
                ] else ...[
                   // Accepted Signature View
                   Center(
                     child: Column(
                       children: [
                         Text('Digital Signature', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                         const SizedBox(height: 12),
                         FutureBuilder<String?>(
                           future: MouService().getSignatureData(_client!.clientId),
                           builder: (context, snapshot) {
                             if (snapshot.connectionState == ConnectionState.waiting) {
                               return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
                             }
                             
                             if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                                return const Text('Signature not available', style: TextStyle(color: AppColors.error));
                             }

                             return Container(
                               height: 120, 
                               width: 220,
                               padding: const EdgeInsets.all(8),
                               decoration: BoxDecoration(
                                 color: Colors.white,
                                 border: Border.all(color: Colors.grey[300]!),
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               child: Image.memory(
                                 base64Decode(snapshot.data!), 
                                 fit: BoxFit.contain,
                                 errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error_outline, color: AppColors.error)),
                               ),
                             );
                           },
                         ),
                       ],
                     ),
                   ),
                ],
              ],
            ),
          ),
    );
  }
}

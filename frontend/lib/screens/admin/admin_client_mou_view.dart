import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../../models/client_model.dart';
import '../../models/mou_template_model.dart';
import '../../services/mou_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';
import '../../models/settings_model.dart';
import '../../utils/mou_pdf_helper.dart';
import '../../utils/file_download_helper.dart';
import '../../services/platform_governance_service.dart';
import '../../models/platform_config_model.dart';

class AdminClientMouView extends StatefulWidget {
  final ClientModel client;

  const AdminClientMouView({super.key, required this.client});

  @override
  State<AdminClientMouView> createState() => _AdminClientMouViewState();
}

class _AdminClientMouViewState extends State<AdminClientMouView> {
  String? _content;
  String? _signatureBase64;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final meta = widget.client.mouMeta;
      if (meta == null) {
        throw 'No MOU Metadata found';
      }

      final version = meta['version'] as String;
      final lang = meta['language'] as String? ?? 'en';
      
      // 1. Fetch Template
      final template = await MouService().getTemplateByVersion(version);
      if (template != null) {
        _content = template.content[lang] ?? template.content['en'];
      } else {
        _content = 'Template version $version not found.';
      }

      // 2. Fetch Signature
      _signatureBase64 = await MouService().getSignatureData(widget.client.clientId);

    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_content == null) return;
    
    // Get Company Logo from Settings
    final settings = await SettingsService().fetchSettings();

    // Handle Timestamp / String date
    final signedAtRaw = widget.client.mouMeta!['signedAt'];
    DateTime date;
    if (signedAtRaw is String) {
       date = DateTime.parse(signedAtRaw);
    } else {
       date = DateTime.now(); // Fallback
    }
    
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    
    // Build Contact Strings for Admin view as well
    String contactInfo = '';
    if (settings.contactEmail.isNotEmpty) contactInfo += 'Email: ${settings.contactEmail}\n';
    if (settings.contactPhone.isNotEmpty) contactInfo += 'Phone: ${settings.contactPhone}';

    // Get Global Branding Config
    final platformConfig = await PlatformGovernanceService().fetchConfig();

    final pdfBytes = await MouPdfHelper.generate(
      content: _content!,
      businessName: widget.client.businessName,
      ownerName: widget.client.ownerName,
      date: dateStr,
      signatureBase64: _signatureBase64,
      mouLogoBase64: platformConfig.mouLogoBase64,
      mouWatermarkBase64: platformConfig.mouWatermarkBase64,
      mouAppName: platformConfig.mouAppName,
      mouAddress: platformConfig.mouAddress,
      mouFooter: platformConfig.mouFooter,
      headerTitle: platformConfig.mouHeaderTitle,
    );
    
    await FileDownloadHelper.downloadFile(
       Uint8List.fromList(pdfBytes),
       'MOU_${widget.client.businessName}',
       'pdf'
    );
  }

  @override
  Widget build(BuildContext context) {
    // Helper to get formatted date
    String formattedDate = 'Unknown';
    if (widget.client.mouMeta != null && widget.client.mouMeta!['signedAt'] != null) {
         final raw = widget.client.mouMeta!['signedAt'];
         if (raw is String) {
             formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(raw));
         }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('MOU - ${widget.client.businessName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: (_isLoading || _content == null) ? null : _downloadPdf,
            icon: const Icon(Icons.download),
            tooltip: 'Download PDF',
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _errorMessage.isNotEmpty 
          ? Center(child: Text('Error: $_errorMessage')) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified, color: AppColors.success),
                      title: Text('Version: ${widget.client.mouMeta?['version']}'),
                      subtitle: Text('Signed: $formattedDate'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Content
                  Text(
                    'Memorandum of Understanding',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _content ?? 'No Content',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const Divider(height: 48),
                  
                  // Debug Info (Added for Support)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FutureBuilder<AppSettings>(
                       future: SettingsService().fetchTenantSettings(widget.client.tenantId),
                       builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) return const Text('Loading Debug Info...');
                          if (snap.hasError) return Text('Debug Error: ${snap.error}');
                          return SelectableText( // Selectable to copy ID
                            'DEBUG:\nTenant ID: ${widget.client.tenantId}\nCompany Name: ${snap.data?.tenantName}\nPayee Name: ${snap.data?.payeeName}',
                            style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.amber.shade900),
                          );
                       },
                    )
                  ),
                  const SizedBox(height: 16),

                  // FIX BUTTON: Link to Current Admin
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                         final currentUser = Supabase.instance.client.auth.currentUser; // Get Admin ID
                         if (currentUser == null) return;
                         
                         final confirm = await showDialog<bool>(
                           context: context,
                           builder: (ctx) => AlertDialog(
                             title: const Text('Fix Branding Link?'),
                             content: const Text('This will link this Client to YOUR current Admin Settings (Digiwebia).\n\nThis fixes the "Charlie" / Wrong Name issue.'),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                               ElevatedButton(
                                 onPressed: () => Navigator.pop(ctx, true), 
                                 child: const Text('Link to Me'),
                               ),
                             ],
                           ),
                         );
                         
                         if (confirm == true) {
                            setState(() => _isLoading = true);
                            try {
                               await Supabase.instance.client.from('clients').update({
                                 'tenant_id': currentUser.id,
                               }).eq('client_id', widget.client.clientId);
                               
                               if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fixed! Client now linked to your Branding.')));
                                  setState(() { _isLoading = false; }); // Refresh UI
                                  Navigator.pop(context); // Close
                               }
                            } catch (e) {
                               if (mounted) setState(() => _isLoading = false);
                               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                         }
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('Fix Branding (Link to Me)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Signature
                  const Text('Accepted By:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_signatureBase64 != null)
                     Container(
                       height: 80,
                       width: 150,
                       decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                       child: Image.memory(base64Decode(_signatureBase64!), fit: BoxFit.contain),
                     )
                  else
                     const Text('Signature not found (Old version?)'),
                     
                  Text(widget.client.businessName),
                  Text(widget.client.ownerName),
                ],
              ),
            ),
    );
  }
}

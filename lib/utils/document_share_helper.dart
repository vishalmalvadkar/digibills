import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_colors.dart';
import 'file_download_helper.dart';

class DocumentShareHelper {
  /// Shows a bottom sheet with Share options (WhatsApp vs PDF)
  static void showShareOptions({
    required BuildContext context,
    required String documentName,
    required VoidCallback onWhatsAppShare,
    required Future<Uint8List> Function() onPdfGenerate,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share $documentName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareOption(
                  icon: FontAwesomeIcons.whatsapp,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    onWhatsAppShare();
                  },
                ),
                _ShareOption(
                  icon: kIsWeb ? Icons.download : Icons.picture_as_pdf,
                  label: kIsWeb ? 'Download PDF' : 'Share PDF',
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    await sharePdfFile(
                      context: context,
                      fileName: '${documentName.replaceAll(' ', '_')}.pdf',
                      onPdfGenerate: onPdfGenerate,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Generates and shares a PDF file directly
  static Future<void> sharePdfFile({
    required BuildContext context,
    required String fileName,
    required Future<Uint8List> Function() onPdfGenerate,
  }) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final bytes = await onPdfGenerate();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Reliable close
      }

      if (kIsWeb) {
        // On Web, system share for files is limited, so we download it
        await FileDownloadHelper.downloadFile(
          bytes,
          fileName.replaceAll('.pdf', ''),
          'pdf',
        );
      } else {
        // On Mobile, use share_plus with XFile.fromData
        // This avoids needing path_provider directly in this helper
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
          subject: 'Sharing $fileName',
        );
      }
    } catch (e) {
      if (context.mounted) {
        try {
           Navigator.of(context, rootNavigator: true).pop(); 
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            FaIcon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

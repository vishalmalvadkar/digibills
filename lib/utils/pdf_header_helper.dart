import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/settings_model.dart';
import 'package:intl/intl.dart';

class PdfHeaderHelper {
  static pw.Widget buildHeader({
    required AppSettings settings,
    required String title,
    String? subtitle,
    DateTime? date,
    bool showDate = true,
  }) {
    // Decode Logo
    pw.MemoryImage? profileLogo;
    if (settings.logoBase64 != null && settings.logoBase64!.isNotEmpty) {
      try {
        profileLogo = pw.MemoryImage(base64Decode(settings.logoBase64!));
      } catch (e) {
        // Ignore invalid logo
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Side: Business Details
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.tenantName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (settings.fullAddress.isNotEmpty)
                    pw.Text(
                      settings.fullAddress,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  if (settings.contactPhone.isNotEmpty || settings.contactEmail.isNotEmpty)
                    pw.Text(
                      '${settings.contactPhone} ${settings.contactEmail}'.trim(),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  if (settings.gstNumber.isNotEmpty)
                    pw.Text(
                      'GSTIN: ${settings.gstNumber}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                ],
              ),
            ),
            
            // Right Side: Logo or Spacer
            if (profileLogo != null)
              pw.Container(
                height: settings.logoHeight,
                width: settings.logoWidth,
                margin: const pw.EdgeInsets.only(left: 20),
                child: pw.Image(
                  profileLogo,
                  fit: pw.BoxFit.contain,
                ),
              ),
          ],
        ),
        
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.SizedBox(height: 8),

        // Report Title Row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5, color: PdfColors.blueGrey800),
                ),
                if (subtitle != null)
                  pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            if (showDate)
              pw.Text(
                date != null 
                    ? DateFormat('dd MMM yyyy').format(date)
                    : DateFormat('dd MMM yyyy').format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
              ),
          ],
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }
}

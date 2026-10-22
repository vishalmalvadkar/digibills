import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class MouPdfHelper {
  static Future<List<int>> generate({
    required String content,
    required String businessName,
    required String ownerName,
    required String date,
    required String? signatureBase64,
    required String? mouLogoBase64,
    required String? mouWatermarkBase64,
    required String mouAppName,
    required String mouAddress,
    required String mouFooter,
    required String headerTitle,
  }) async {
    final pdf = pw.Document();
    
    final font = await PdfGoogleFonts.hindRegular(); 
    final fontBold = await PdfGoogleFonts.hindBold();

    pw.MemoryImage? logoImage;
    if (mouLogoBase64 != null && mouLogoBase64.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(mouLogoBase64));
      } catch (_) {}
    }

    pw.MemoryImage? watermarkImage;
    if (mouWatermarkBase64 != null && mouWatermarkBase64.isNotEmpty) {
      try {
        watermarkImage = pw.MemoryImage(base64Decode(mouWatermarkBase64));
      } catch (_) {}
    }

    // signature image
    pw.MemoryImage? signatureImage;
    if (signatureBase64 != null && signatureBase64.isNotEmpty) {
      try {
        signatureImage = pw.MemoryImage(base64Decode(signatureBase64));
      } catch (_) {}
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      buildBackground: (context) {
        if (watermarkImage == null) return pw.SizedBox();
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.1,
              child: pw.Image(watermarkImage, width: 300, height: 300, fit: pw.BoxFit.contain),
            ),
          ),
        );
      },
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        
        // HEADER
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 15),
            margin: const pw.EdgeInsets.only(bottom: 25),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.blue900)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // BRAND DETAILS (LEFT)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(mouAppName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 5),
                      pw.Text(mouAddress, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
                        ),
                        child: pw.Text('OFFICIAL DOCUMENT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),
                
                // LOGO (RIGHT)
                if (logoImage != null)
                  pw.Container(
                    width: 80, height: 80,
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
              ],
            ),
          );
        },

        // FOOTER
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Text(mouFooter, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ],
            ),
          );
        },

        build: (context) {
          return [
            pw.Center(
               child: pw.Text(headerTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline))
            ),
            pw.SizedBox(height: 30),

            // Parsed Content
            ..._parseMarkdown(content, font, fontBold),
            
            pw.SizedBox(height: 20),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('For, $mouAppName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.SizedBox(height: 10),
                    
                    // Organization Signature Box (Mirroring Client style)
                    pw.Container(
                      height: 70,
                      width: 140,
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Center(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('VERIFIED', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                            pw.Text('BY $mouAppName', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                    ),
                    
                    pw.SizedBox(height: 10),
                    pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 11)),
                    
                    pw.SizedBox(height: 6),
                    pw.Container(
                       padding: const pw.EdgeInsets.all(5),
                       decoration: pw.BoxDecoration(
                         border: pw.Border.all(color: PdfColors.green300, width: 1.2), 
                         borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))
                       ),
                       child: pw.Text('DIGITALLY SIGNED', style: pw.TextStyle(fontSize: 7, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Accepted By (Client):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    
                    if (signatureImage != null) ...[
                      pw.SizedBox(height: 10),
                      pw.Container(
                        height: 70,
                        width: 140,
                        padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
                        child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                      ),
                    ],
                    pw.SizedBox(height: 10),
                    pw.Text(businessName.isNotEmpty ? businessName : 'Business Name', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(ownerName.isNotEmpty ? ownerName : 'Authorized Signatory', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                    
                    pw.SizedBox(height: 12),
                    pw.Container(
                       padding: const pw.EdgeInsets.all(6),
                       decoration: pw.BoxDecoration(
                         border: pw.Border.all(color: PdfColors.green300, width: 1.5), 
                         borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))
                       ),
                       child: pw.Text('DIGITALLY SIGNED', style: pw.TextStyle(fontSize: 8, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Simple Markdown Parser for PDF
  static List<pw.Widget> _parseMarkdown(String text, pw.Font font, pw.Font fontBold) {
    List<pw.Widget> widgets = [];
    List<String> lines = text.split('\n');
    
    for (var line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('# ')) {
        // H1
        widgets.add(pw.Header(level: 0, child: pw.Text(line.substring(2), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))));
      } else if (line.startsWith('## ')) {
        // H2
        widgets.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 8, bottom: 4), child: pw.Text(line.substring(3), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))));
      } else {
        // Paragraph with basic inline formatting (**bold**, <u>underline</u>)
        // Note: Regex split
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.RichText(
            text: _parseInline(line, font, fontBold)
          )
        ));
      }
    }
    return widgets;
  }

  static pw.TextSpan _parseInline(String text, pw.Font font, pw.Font fontBold) {
    final List<pw.TextSpan> spans = [];
    
    // Split by markers. A simple stack based parser or regex split would be robust, 
    // but for simple cases, let's just handle bold OR underline for now, or simple mix.
    // Let's use a simpler tokenizing approach for robustness.
    
    final RegExp exp = RegExp(r'(\*\*.*?\*\*)|(<u>.*?</u>)');
    int start = 0;
    
    for (final match in exp.allMatches(text)) {
      if (match.start > start) {
        spans.add(pw.TextSpan(text: text.substring(start, match.start), style: const pw.TextStyle(fontSize: 10)));
      }
      
      String matchText = match.group(0)!;
      if (matchText.startsWith('**')) {
        spans.add(pw.TextSpan(text: matchText.substring(2, matchText.length - 2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)));
      } else if (matchText.startsWith('<u>')) {
        spans.add(pw.TextSpan(text: matchText.substring(3, matchText.length - 4), style: pw.TextStyle(fontSize: 10, decoration: pw.TextDecoration.underline)));
      }
      
      start = match.end;
    }
    
    if (start < text.length) {
      spans.add(pw.TextSpan(text: text.substring(start), style: const pw.TextStyle(fontSize: 10)));
    }

    return pw.TextSpan(children: spans);
  }
}

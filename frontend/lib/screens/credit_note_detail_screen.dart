import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/credit_note_model.dart';
import '../utils/pdf_credit_note_helper.dart'; // NEW
import '../theme/app_colors.dart';
import '../providers/shell_provider.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';

class CreditNoteDetailScreen extends StatefulWidget {
  final CreditNoteModel note;

  const CreditNoteDetailScreen({super.key, required this.note});

  @override
  State<CreditNoteDetailScreen> createState() => _CreditNoteDetailScreenState();
}

class _CreditNoteDetailScreenState extends State<CreditNoteDetailScreen> {

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateShell();
  }

  void _updateShell() {
    if (Responsive.isDesktop(context)) {
      final note = widget.note;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ShellState>().update(
            title: 'Return: ${note.creditNoteNumber}',
            leading: BackButton(onPressed: () => Navigator.of(context).pop()),
            actions: [
               IconButton(
                icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                onPressed: () => PdfCreditNoteHelper.openWhatsApp(context, note),
                tooltip: 'Share',
              ),
              IconButton(
                 icon: const Icon(Icons.download, size: 20),
                 onPressed: () => PdfCreditNoteHelper.generateAndDownload(note),
                 tooltip: 'Download',
              )
            ],
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: Responsive.isDesktop(context) 
        ? null 
        : AppBar(
        title: const Text('Return Details'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
            onPressed: () => PdfCreditNoteHelper.openWhatsApp(context, note),
          ),
          IconButton(
             icon: const Icon(Icons.download),
             onPressed: () => PdfCreditNoteHelper.generateAndDownload(note),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.assignment_return, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('CREDIT NOTE ISSUED', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                ],
              ),
            ),

            // Main Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CN #${note.creditNoteNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(DateFormat('dd MMM yyyy').format(note.returnDate), style: const TextStyle(color: AppColors.textGrey)),
                      ],
                    ),
                    const Divider(height: 30),
                    _infoRow('Original Invoice', note.invoiceNumber),
                    if (note.reason.isNotEmpty) _infoRow('Reason', note.reason),
                    _infoRow('Items Returned', '${note.items.length}'),
                    
                    const SizedBox(height: 20),
                    const Text('Returned Items', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                    const SizedBox(height: 10),
                    
                    Container(
                      decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: note.items.map((item) => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                               Expanded(child: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w500))),
                               Text('${item.quantity} x ₹${(item.unitPrice).toStringAsFixed(2)}'),
                               const SizedBox(width: 12),
                               Text('₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),
                    
                    // Totals
                    _infoRow('Subtotal', '₹${note.subtotal.toStringAsFixed(2)}'),
                    if (note.taxAmount > 0) _infoRow('Tax Reversed', '₹${note.taxAmount.toStringAsFixed(2)}'),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Refund', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('₹${note.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error)),
                      ],
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

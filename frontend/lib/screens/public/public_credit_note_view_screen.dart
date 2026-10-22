import 'package:flutter/material.dart';
import '../../models/credit_note_model.dart';
import '../../models/settings_model.dart';
import '../../services/public_service.dart';
import '../../utils/pdf_credit_note_helper.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

class PublicCreditNoteViewScreen extends StatefulWidget {
  final String noteId;
  const PublicCreditNoteViewScreen({super.key, required this.noteId});

  @override
  State<PublicCreditNoteViewScreen> createState() => _PublicCreditNoteViewScreenState();
}

class _PublicCreditNoteViewScreenState extends State<PublicCreditNoteViewScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  CreditNoteModel? _note;
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      // Fetch Note (Requires public RPC)
      final note = await PublicService().getPublicCreditNote(widget.noteId); // Need to implement this in service
      if (note == null) throw 'Credit Note not found';

      final settings = await PublicService().getPublicSettings(note.tenantId, createdBy: note.createdBy);

      if (mounted) {
        setState(() {
          _note = note;
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage.isNotEmpty) return Scaffold(body: Center(child: Text(_errorMessage)));
    if (_note == null || _settings == null) return const Scaffold(body: Center(child: Text('Note not found')));

    final note = _note!;
    final settings = _settings!;
    final date = DateFormat('dd MMM yyyy').format(note.returnDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(settings.tenantName), 
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Note Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                    'CREDIT NOTE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppColors.error,
                                    ),
                                   ),
                                   Text(
                                    '#${note.creditNoteNumber}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                   ),
                                 ],
                               ),
                             ),
                             Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'RETURNED',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const Divider(height: 40, color: AppColors.border),

                        _infoRow('Original Invoice', note.invoiceNumber),
                        _infoRow('Date', date),
                        if (note.reason != null) _infoRow('Reason', note.reason!),
                        if (settings.gstNumber.isNotEmpty) _infoRow('Seller GST', settings.gstNumber),
                        
                        const SizedBox(height: 12),
                        const Text('Returned Items', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                         ...note.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.description} (x${item.quantity})',
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textDark),
                                ),
                              ),
                              Text(
                                '₹${item.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                            ],
                          ),
                        )),

                        const Divider(height: 40, color: AppColors.border),

                        // Calculation Section
                        _infoRow('Subtotal', '₹${note.subtotal.toStringAsFixed(2)}'),
                        
                        if (note.igstAmount > 0)
                           _infoRow('IGST', '₹${note.igstAmount.toStringAsFixed(2)}'),
                        
                        if (note.cgstAmount > 0)
                           _infoRow('CGST', '₹${note.cgstAmount.toStringAsFixed(2)}'),

                        if (note.sgstAmount > 0)
                           _infoRow('SGST', '₹${note.sgstAmount.toStringAsFixed(2)}'),

                        Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text(
                             'Total Refund',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.w600,
                               color: AppColors.textDark,
                             ),
                           ),
                           Text(
                             '₹${note.totalAmount.toStringAsFixed(2)}',
                             style: const TextStyle(
                               fontSize: 24,
                               fontWeight: FontWeight.bold,
                               color: AppColors.success,
                             ),
                           ),
                         ],
                       ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => PdfCreditNoteHelper.generateAndDownload(_note!, overrideSettings: _settings), 
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Safe & Secure by DigiInvi', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isAmount = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../services/bills_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../utils/pdf_statement_helper.dart';
import '../utils/snackbar_helper.dart';
import '../utils/file_download_helper.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';
import '../../services/credit_note_service.dart';
import '../../models/credit_note_model.dart';
import '../screens/credit_note_detail_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String clientAddress;
  final String? ownerName;

  const ClientDetailScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.clientAddress,
    this.ownerName,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late Stream<List<Map<String, dynamic>>> _clientStream;
  late Stream<List<BillModel>> _billsStream;
  late Stream<List<CreditNoteModel>> _creditNotesStream;

  String _getLocalizedStatus(BuildContext context, String status) {
    if (status == 'Paid') return AppLocalizations.of(context)?.paid ?? 'Paid';
    if (status == 'Partial') return AppLocalizations.of(context)?.partial ?? 'Partial';
    return AppLocalizations.of(context)?.pending ?? 'Pending';
  }

  @override
  void initState() {
    super.initState();
    _clientStream = Supabase.instance.client
        .from('clients')
        .stream(primaryKey: ['client_id'])
        .eq('client_id', widget.clientId);
    
    // Reverted to fetching all bills to support client-side filtering for legacy data
    _billsStream = BillsService().streamBills();
    
    // Fetch ALL credit notes to support client-side filtering (match with Bills logic)
    _creditNotesStream = CreditNoteService().streamCreditNotes();
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)?.clientStatement ?? 'Client Statement', style: const TextStyle(fontSize: 16)),
            Text(widget.clientName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _clientStream,
        builder: (context, clientSnapshot) {
          ClientModel? client;
          if (clientSnapshot.hasData && clientSnapshot.data!.isNotEmpty) {
            client = ClientModel.fromMap(clientSnapshot.data!.first);
          }
          
          return StreamBuilder<List<BillModel>>(
            stream: _billsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) return const Center(child: Text('No data'));

              final allBills = snapshot.data!;
              
              final clientBills = allBills.where((b) {
                // 1. Exact ID Match (Strongest)
                if (widget.clientId.isNotEmpty && b.clientId == widget.clientId) return true;

                // 2. Name Match (Fallback for Legacy Data)
                final billName = b.customerName.trim().toLowerCase();
                final targetName = widget.clientName.trim().toLowerCase();
                final ownerName = widget.ownerName?.trim().toLowerCase() ?? '';

                if (billName.isNotEmpty) {
                   if (billName == targetName) return true;
                   if (ownerName.isNotEmpty && billName == ownerName) return true;
                }

                return false;
              }).toList();
              
              return StreamBuilder<List<CreditNoteModel>>(
                stream: _creditNotesStream,
                builder: (context, cnSnapshot) {
                   final allCreditNotes = cnSnapshot.data ?? [];
                   
                   // Filter Credit Notes (Same logic as Bills: ID + Name Match)
                   final creditNotes = allCreditNotes.where((cn) {
                      // 1. Exact ID Match
                      if (widget.clientId.isNotEmpty && cn.clientId == widget.clientId) return true;

                      // 2. Name Match (Fallback) - Note: CreditNoteModel doesn't always have customerName, 
                      // but we can rely on Bill ID link or fetch it. However, simplest for now is:
                      // If specific client ID is present, we trust it. 
                      // For legacy support, we might need a joined query, but let's stick to ID match primarily 
                      // and try to match bill IDs from the filtered 'clientBills' list.
                      
                      // Better approach: If the Credit Note's 'billId' exists in our filtered 'clientBills', include it.
                      // This automatically inherits the robust name matching from the bill filtering.
                      return clientBills.any((b) => b.billId == cn.billId);
                   }).toList();
                   
                   double totalBilled = 0;
                   double totalPaid = 0;
                   double totalPending = 0;
                   double totalReturns = 0;

                   for (var bill in clientBills) {
                      totalBilled += bill.totalAmount;
                      if (bill.paymentStatus == 'Paid') {
                        totalPaid += bill.totalAmount;
                      } else {
                        totalPaid += bill.advanceAmount;
                        totalPending += (bill.totalAmount - bill.advanceAmount);
                      }
                   }

                   for (var cn in creditNotes) {
                      totalReturns += cn.totalAmount;
                   }
                   
                   totalPending = totalPending - totalReturns;

                   return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Financial Summary Cards
                        Row(
                          children: [
                            Expanded(child: _buildSummaryCard(AppLocalizations.of(context)?.totalBilled ?? 'Total Billed', '₹${totalBilled.toStringAsFixed(2)}', Colors.blue)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSummaryCard(AppLocalizations.of(context)?.paid ?? 'Paid', '₹${totalPaid.toStringAsFixed(2)}', Colors.green)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSummaryCard(AppLocalizations.of(context)?.pending ?? 'Pending', '₹${totalPending.toStringAsFixed(2)}', Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              String clientPhone = '';
                              for (var bill in clientBills) {
                                if (bill.whatsappNumber.isNotEmpty) {
                                  clientPhone = bill.whatsappNumber;
                                  break;
                                }
                              }

                              final settings = await SettingsService().fetchSettings();
                              final pdfData = await PdfStatementHelper.generate(
                                settings: settings,
                                clientName: widget.clientName,
                                clientId: widget.clientId,
                                clientAddress: widget.clientAddress,
                                clientPhone: clientPhone,
                                bills: clientBills,
                                totalBilled: totalBilled,
                                totalPaid: totalPaid,
                                totalPending: totalPending,
                              );
                              
                              await FileDownloadHelper.downloadFile(
                                pdfData, 
                                'Statement_${widget.clientName}', 
                                'pdf'
                              );
                            } catch (e) {
                              SnackbarHelper.showError(context, 'Error generating PDF: $e');
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text(AppLocalizations.of(context)?.downloadPdf ?? 'Download PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bills Table (Restored & Optimized for Full Width)
                        Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48), // Padding balanced
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.grey[200]),
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                                    dataRowColor: MaterialStateProperty.resolveWith((states) => Colors.white),
                                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                                    dataRowMaxHeight: 65,
                                    columnSpacing: 20,
                                    horizontalMargin: 12,
                                    dividerThickness: 1,
                                    columns: [
                                      DataColumn(label: Text(AppLocalizations.of(context)?.invoiceNo ?? 'Invoice #')),
                                      DataColumn(label: Text(AppLocalizations.of(context)?.date ?? 'Date')),
                                      DataColumn(label: Text(AppLocalizations.of(context)?.service ?? 'Service')),
                                      DataColumn(label: Text(AppLocalizations.of(context)?.total ?? 'Total'), numeric: true),
                                      DataColumn(label: Text(AppLocalizations.of(context)?.received ?? 'Received'), numeric: true),
                                      DataColumn(label: Text(AppLocalizations.of(context)?.balance ?? 'Balance'), numeric: true),
                                      DataColumn(label: Text(AppLocalizations.of(context)?.status ?? 'Status')),
                                    ],
                                    rows: clientBills.map((bill) {
                                      final double netPayable = bill.totalAmount - bill.returnAmount;
                                      double received = 0;
                                      double balance = 0;
                                      
                                      if (bill.paymentStatus == 'Paid') {
                                         balance = 0;
                                         received = bill.advanceAmount; 
                                         if (received < netPayable) received = netPayable; 
                                      } else {
                                         received = bill.advanceAmount;
                                         balance = netPayable - received;
                                      }
                                      if (balance < 0) balance = 0;

                                      String serviceText = bill.serviceName.isNotEmpty ? bill.serviceName : (bill.items.isNotEmpty ? bill.items.first.description : 'Service');
                                      if (serviceText.length > 20) serviceText = '${serviceText.substring(0, 20)}...';

                                      return DataRow(cells: [
                                        DataCell(Text('#${bill.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(DateFormat('dd/MM/yy').format(bill.billDate))),
                                        DataCell(Text(serviceText)),
                                        DataCell(Text('₹${netPayable.toStringAsFixed(0)}')),
                                        DataCell(Text('₹${received.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                        DataCell(Text('₹${balance.toStringAsFixed(0)}', style: TextStyle(color: balance > 0 ? Colors.red : Colors.grey, fontWeight: FontWeight.bold))),
                                        DataCell(Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getLocalizedStatus(context, bill.paymentStatus) == 'Paid' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: _getLocalizedStatus(context, bill.paymentStatus) == 'Paid' ? Colors.green : Colors.orange),
                                          ),
                                          child: Text(
                                            _getLocalizedStatus(context, bill.paymentStatus),
                                            style: TextStyle(
                                              fontSize: 10, 
                                              fontWeight: FontWeight.bold,
                                              color: _getLocalizedStatus(context, bill.paymentStatus) == 'Paid' ? Colors.green : Colors.orange
                                            ),
                                          ),
                                        )),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Credit Notes Section
                        if (creditNotes.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(AppLocalizations.of(context)?.salesReturns ?? 'Sales Returns / Credit Notes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                            child: Column(
                              children: creditNotes.map((note) => ListTile(
                                leading: const Icon(Icons.undo, color: AppColors.error),
                                title: Text(note.creditNoteNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(DateFormat('dd MMM yyyy').format(note.returnDate)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('- ₹${note.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                                onTap: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => CreditNoteDetailScreen(note: note)));
                                },
                              )).toList(),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

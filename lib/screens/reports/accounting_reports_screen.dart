import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart'; // Fixed import path
import 'package:intl/intl.dart';
import '../../services/report_service.dart';
import '../../services/gstr_service.dart'; // NEW
import '../../utils/file_download_helper.dart';
import '../../utils/pdf_report_helper.dart'; 
import '../../theme/app_colors.dart';
import '../../services/settings_service.dart'; 
import '../../widgets/license_scope.dart'; 
import 'income_tax_report_screen.dart'; 
import '../../services/ca_export_service.dart'; // NEW

class AccountingReportsScreen extends StatefulWidget {
  const AccountingReportsScreen({super.key});

  @override
  State<AccountingReportsScreen> createState() => _AccountingReportsScreenState();
}

class _AccountingReportsScreenState extends State<AccountingReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  ReportType _selectedType = ReportType.income;
  bool _isLoading = false;
  final ReportService _service = ReportService();
  final GSTRService _gstrService = GSTRService();
  final CaExportService _caExportService = CaExportService(); // NEW

  void _showCaPackLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.indigo.shade900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white24),
                        ),
                      ),
                      const Icon(Icons.folder_zip_rounded, size: 50, color: Colors.white),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Colors.indigo.shade200),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "CA Pack is under process...",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Please wait while we bundle your reports.\nDo not close the app or this screen.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportCaPack() async {
    // Show Dialog to select Financial Year
    final year = await showDialog<int>(
      context: context,
      builder: (context) {
        final now = DateTime.now();
        final currentFYStartYear = now.month >= 4 ? now.year : now.year - 1;
        
        return SimpleDialog(
          title: const Text('Select Financial Year'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, currentFYStartYear),
              child: Text('FY $currentFYStartYear-${(currentFYStartYear + 1).toString().substring(2)} (Current)'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, currentFYStartYear - 1),
              child: Text('FY ${currentFYStartYear - 1}-${currentFYStartYear.toString().substring(2)} (Previous)'),
            ),
          ],
        );
      }
    );

    if (year != null) {
      _showCaPackLoadingDialog();
      try {
        await _caExportService.downloadCaPack(year, context);
      } finally {
        if (mounted) Navigator.pop(context); // Close loading dialog
      }
    }
  }

  Future<void> _export(ExportFormat format) async {
    setState(() => _isLoading = true);
    try {
      // Special Handling for GSTR
      if (_selectedType == ReportType.gstr1) {
         if (format == ExportFormat.csv) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GSTR-1 is available in Excel only')));
            return;
         }
         final bytes = await _gstrService.generateGSTR1(_startDate, _endDate);
         if (bytes != null) {
            await FileDownloadHelper.downloadFile(bytes, 'GSTR1_${DateFormat('MMMyy').format(_startDate)}', 'xlsx');
         }
         return;
      }
      
      if (_selectedType == ReportType.gstr3b) {
         // GSTR-3B isn't a file export usually, but we can export the summary as CSV/Excel if needed
         // For now, let's just show a snackbar or export summary
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)?.gstr3bMsg ?? 'View Summary below. Export coming soon.')));
         return;
      }

      List<dynamic> data = [];
      String fileName = '${_selectedType.name}_report';

      // Fetch Data
      if (_selectedType == ReportType.income) {
        data = await _service.fetchIncome(_startDate, _endDate);
      } else if (_selectedType == ReportType.expense) {
        data = await _service.fetchExpenses(_startDate, _endDate);
      } else if (_selectedType == ReportType.receivables) {
        data = await _service.fetchReceivables();
        fileName = 'receivables_report';
      }

      if (data.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)?.noDataReport ?? 'No data found for selected period')));
        return;
      }

      // Generate File
      List<int> bytes = [];
      String extension = '';
      if (format == ExportFormat.csv) {
        bytes = _service.generateCsv(data, _selectedType);
        extension = 'csv';
      } else {
        bytes = _service.generateExcel(data, _selectedType);
        extension = 'xlsx';
      }

      // Download
      await FileDownloadHelper.downloadFile(bytes, fileName, extension);

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  List<List<dynamic>> _reportData = [];

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _reportData = [];
    });
    try {
      if (_selectedType == ReportType.income) {
        final raw = await _service.fetchIncome(_startDate, _endDate);
        _reportData = raw.map((e) => [
          DateFormat('dd MMM yyyy').format(e.billDate), 
          e.customerName.isNotEmpty ? e.customerName : 'Unknown Client', 
          e.totalAmount.toStringAsFixed(2), 
        ]).toList();
      } else if (_selectedType == ReportType.expense) {
        final raw = await _service.fetchExpenses(_startDate, _endDate);
        _reportData = raw.map((e) => [
          DateFormat('dd MMM yyyy').format(e.date), 
          e.category, 
          e.title, 
          e.amount.toStringAsFixed(2), 
        ]).toList();
      } else if (_selectedType == ReportType.receivables) {
        final raw = await _service.fetchReceivables();
        _reportData = raw.map((e) => [
          e.customerName, 
          e.totalAmount.toStringAsFixed(2), 
          e.advanceAmount.toStringAsFixed(2), 
          (e.totalAmount - e.advanceAmount).toStringAsFixed(2), 
        ]).toList();
      } else if (_selectedType == ReportType.gstr1) {
         // Preview simply counts validation warnings or summary
         final bytes = await _gstrService.generateGSTR1(_startDate, _endDate);
         if (bytes != null) {
            _reportData = [['GSTR-1 Generated', 'Ready to Download', '']];
         }
      } else if (_selectedType == ReportType.gstr3b) {
         final summary = await _gstrService.generateGSTR3B(_startDate, _endDate);
         final outward = summary['outward'];
         final itc = summary['itc'];
         
         _reportData = [
           ['Outward Taxable', '', outward['taxable'].toStringAsFixed(2)],
           ['Outward IGST', '', outward['igst'].toStringAsFixed(2)],
           ['Outward CGST', '', outward['cgst'].toStringAsFixed(2)],
           ['Outward SGST', '', outward['sgst'].toStringAsFixed(2)],
           ['Total Tax Liability', '', outward['total_tax'].toStringAsFixed(2)],
           ['---', '---', '---'],
           ['ITC IGST', '', itc['igst'].toStringAsFixed(2)],
           ['ITC CGST', '', itc['cgst'].toStringAsFixed(2)],
           ['ITC SGST', '', itc['sgst'].toStringAsFixed(2)],
           ['Total ITC Available', '', itc['total'].toStringAsFixed(2)],
         ];
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  List<DataColumn> _getColumns() {
    if (_selectedType == ReportType.income) {
      return [
        DataColumn(label: Text(AppLocalizations.of(context)?.date ?? 'Date')),
        DataColumn(label: Text(AppLocalizations.of(context)?.details ?? 'Details')),
        DataColumn(label: Text(AppLocalizations.of(context)?.amount ?? 'Amount'), numeric: true),
      ];
    } else if (_selectedType == ReportType.expense) {
      return [
        DataColumn(label: Text(AppLocalizations.of(context)?.date ?? 'Date')),
        DataColumn(label: Text(AppLocalizations.of(context)?.category ?? 'Category')),
        DataColumn(label: Text(AppLocalizations.of(context)?.description ?? 'Description')),
        DataColumn(label: Text(AppLocalizations.of(context)?.amount ?? 'Amount'), numeric: true),
      ];
    } else if (_selectedType == ReportType.receivables) { 
      return [
        DataColumn(label: Text(AppLocalizations.of(context)?.customer ?? 'Client')),
        DataColumn(label: Text(AppLocalizations.of(context)?.totalBilled ?? 'Billed'), numeric: true),
        DataColumn(label: Text(AppLocalizations.of(context)?.paid ?? 'Paid'), numeric: true),
        DataColumn(label: Text(AppLocalizations.of(context)?.pending ?? 'Pending'), numeric: true),
      ];
    } else if (_selectedType == ReportType.gstr3b) {
       return [
        DataColumn(label: Text(AppLocalizations.of(context)?.head ?? 'Head')),
        DataColumn(label: const Text('')),
        DataColumn(label: Text(AppLocalizations.of(context)?.value ?? 'Value'), numeric: true),
      ];
    } else {
       return [
        DataColumn(label: Text(AppLocalizations.of(context)?.info ?? 'Info')),
        DataColumn(label: Text(AppLocalizations.of(context)?.status ?? 'Status')),
        DataColumn(label: const Text('')),
      ];
    }
  }

  Future<void> _exportPdf() async {
    // Only support PDF for Income/Expense/Receivables for now
    if (_selectedType == ReportType.gstr1 || _selectedType == ReportType.gstr3b) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)?.pdfNotSupportedGstr ?? 'PDF not supported for GSTR reports yet.')));
       return;
    }
    setState(() => _isLoading = true);
    // ... (Existing Logic)
    try {
      final columns = _getColumns().map((e) => (e.label as Text).data!).toList();
      final data = _reportData.map((row) => row.map((cell) => cell.toString()).toList()).toList();
      
      // Calculate Total for Summary
      double totalAmount = 0;
      if (_reportData.isNotEmpty) {
         if (_selectedType == ReportType.income) totalAmount = _reportData.fold(0, (sum, row) => sum + double.parse(row.last.toString().replaceAll(RegExp(r'[^0-9.]'), '')));
         if (_selectedType == ReportType.expense) totalAmount = _reportData.fold(0, (sum, row) => sum + double.parse(row.last.toString().replaceAll(RegExp(r'[^0-9.]'), '')));
         if (_selectedType == ReportType.receivables) totalAmount = _reportData.fold(0, (sum, row) => sum + double.parse(row.last.toString().replaceAll(RegExp(r'[^0-9.]'), '')));
      }

      final settings = await SettingsService().fetchSettings();
      final bytes = await PdfReportHelper.generateReport(
        settings: settings,

        title: '${toBeginningOfSentenceCase(_selectedType.name)} Report',
        columns: columns,
        data: data,
        summaries: {'Total Amount': totalAmount},
      );

      await FileDownloadHelper.downloadFile(bytes, '${_selectedType.name}_report', 'pdf');
      
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.accountingReports ?? 'Accounting Reports'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.border, height: 1)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;
          final horizontalPadding = isDesktop ? 64.0 : (isTablet ? 32.0 : 16.0);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : (isTablet ? 800 : double.infinity)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // REPORT TYPE
                    Text(AppLocalizations.of(context)?.reportType ?? 'Report Type', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ReportType>(
                          value: _selectedType,
                          isExpanded: true,
                          items: ReportType.values.where((e) => e != ReportType.pnl).map((type) {
                             String label = _getLocalizedReportName(context, type);
                            return DropdownMenuItem(
                              value: type,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() {
                             _selectedType = val!;
                             _reportData = []; // Clear old data
                          }),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // DATE RANGE (Show only if not Receivables)
                    if (_selectedType != ReportType.receivables) ...[
                      Text(AppLocalizations.of(context)?.dateRange ?? 'Date Range', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDateButton(AppLocalizations.of(context)?.start ?? 'Start', _startDate, (d) => setState(() => _startDate = d))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDateButton(AppLocalizations.of(context)?.end ?? 'End', _endDate, (d) => setState(() => _endDate = d))),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // VIEW BUTTON
                    ElevatedButton(
                      onPressed: _isLoading ? null : _fetchData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : Text(AppLocalizations.of(context)?.viewReport ?? 'View Report / Summary', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    
                    const SizedBox(height: 32),

                    // PREVIEW TABLE
                    if (_reportData.isNotEmpty) ...[
                      Text(
                         _selectedType == ReportType.gstr3b ? (AppLocalizations.of(context)?.gstr3bSummary ?? 'GSTR-3B Summary') : (AppLocalizations.of(context)?.reportPreview ?? 'Report Preview'), 
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: isDesktop ? 900 : (isTablet ? 600 : constraints.maxWidth - (horizontalPadding * 2)),
                            ),
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                              dataRowColor: MaterialStateProperty.resolveWith((states) => Colors.white),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 13),
                              dataRowMaxHeight: 60,
                              columnSpacing: isDesktop ? 48 : 24,
                              horizontalMargin: 20,
                              border: TableBorder.symmetric(inside: BorderSide(color: AppColors.border, width: 0.5)),
                              columns: _getColumns(),
                              rows: _reportData.take(20).map((row) { 
                                final cells = <DataCell>[];
                                for (int i = 0; i < row.length; i++) {
                                   bool isNumeric = false;
                                   
                                   if (_selectedType == ReportType.income && i == 2) isNumeric = true;
                                   if (_selectedType == ReportType.expense && i == 3) isNumeric = true;
                                   if (_selectedType == ReportType.receivables && i > 0) isNumeric = true;
                                   if (_selectedType == ReportType.gstr3b && i == 2) isNumeric = true;

                                   final content = row[i].toString();
                                   // Only add symbol if it's a monetary value, logic specific
                                   final text = isNumeric && !content.startsWith('₹') ? '₹$content' : content;
                                   
                                   cells.add(DataCell(
                                     Text(text, style: TextStyle(fontSize: 13, fontWeight: isNumeric ? FontWeight.bold : FontWeight.normal)),
                                   ));
                                }
                                return DataRow(cells: cells); 
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // EXPORT BUTTONS
                    if (_reportData.isNotEmpty && _selectedType != ReportType.gstr3b) // GSTR-3B view only for now
                      Column(
                        children: [
                           if (_selectedType != ReportType.gstr1) ...[ // Standard Reports
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: LicenseScope.isReadOnlyMode(context) ? null : () => _export(ExportFormat.csv),
                                    icon: const Icon(Icons.table_chart_outlined, color: Colors.teal),
                                    label: Text(AppLocalizations.of(context)?.downloadCsv ?? 'CSV', style: const TextStyle(color: Colors.teal)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: LicenseScope.isReadOnlyMode(context) ? null : () => _export(ExportFormat.excel),
                                    icon: const Icon(Icons.grid_on, color: Colors.green),
                                    label: Text(AppLocalizations.of(context)?.downloadExcel ?? 'Excel', style: const TextStyle(color: Colors.green)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: LicenseScope.isReadOnlyMode(context) ? null : _exportPdf, // Call PDF export
                                icon: const Icon(Icons.picture_as_pdf),
                                label: Text(AppLocalizations.of(context)?.downloadPdf ?? 'Download PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                           ] else ...[ // GSTR-1 Only
                             SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: LicenseScope.isReadOnlyMode(context) ? null : () => _export(ExportFormat.excel),
                                icon: const Icon(Icons.download, color: Colors.white),
                                label: Text(AppLocalizations.of(context)?.downloadGstr1 ?? 'Download GSTR-1 Excel Utility'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                           ]
                        ],
                      ),
                    
                    
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context)?.downloadNote ?? 'Note: Files will be downloaded or shared depending on your device capability.',
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),

                    // CA PACK EXPORT
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.indigo.shade800, Colors.indigo.shade500]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.folder_zip, color: Colors.white, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            "One-Click CA Export", 
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Download Trial Balance, P&L, Balance Sheet, GST & Aging in one Zip file.",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: LicenseScope.isReadOnlyMode(context) ? null : _exportCaPack,
                              icon: const Icon(Icons.download_rounded, color: Colors.indigo),
                              label: const Text("Download CA Pack", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),

                    // TAX TOOLS SECTION
                    Text("Tax Tools", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.calculate, color: Colors.purple),
                      ),
                      title: Text(AppLocalizations.of(context)?.incomeTaxComputation ?? 'Income Tax Computation', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(AppLocalizations.of(context)?.incomeTaxComputationDesc ?? 'Estimate taxable income & tax liability'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeTaxReportScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime date, Function(DateTime) onSelect) {
// ... (unchanged)
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context, 
          initialDate: date, 
          firstDate: DateTime(2020), 
          lastDate: DateTime.now()
        );
        if(d != null) onSelect(d);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 4),
            Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _getLocalizedReportName(BuildContext context, ReportType type) {
    switch (type) {
      case ReportType.income: return AppLocalizations.of(context)?.income ?? 'Income';
      case ReportType.expense: return AppLocalizations.of(context)?.expense ?? 'Expense';
      case ReportType.receivables: return AppLocalizations.of(context)?.receivables ?? 'Receivables';
      case ReportType.gstr1: return AppLocalizations.of(context)?.gstr1Sales ?? 'GSTR-1 (Sales)';
      case ReportType.gstr3b: return AppLocalizations.of(context)?.gstr3b ?? 'GSTR-3B (Summary)';
      default: return toBeginningOfSentenceCase(type.name)!;
    }
  }
}

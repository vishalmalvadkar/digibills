import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart'; 
import 'package:intl/intl.dart';
import '../../services/tax_service.dart';
import '../../services/settings_service.dart'; 
import '../../theme/app_colors.dart';
import '../../utils/pdf_tax_report_helper.dart';
import '../../utils/file_download_helper.dart'; 
import '../../widgets/license_scope.dart'; 

class TaxLedgerScreen extends StatefulWidget {
  const TaxLedgerScreen({super.key});

  @override
  State<TaxLedgerScreen> createState() => _TaxLedgerScreenState();
}

class _TaxLedgerScreenState extends State<TaxLedgerScreen> with SingleTickerProviderStateMixin {
  DateTime _currentDate = DateTime.now();
  String _viewMode = 'Month'; // 'Month', 'Year'
  final _service = TaxService();
  bool _isExporting = false;
  Future<TaxReportData>? _reportFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshData() {
    DateTime start, end;
    if (_viewMode == 'Month') {
      start = DateTime(_currentDate.year, _currentDate.month, 1);
      end = DateTime(_currentDate.year, _currentDate.month + 1, 0, 23, 59, 59);
    } else {
      start = DateTime(_currentDate.year, 1, 1);
      end = DateTime(_currentDate.year, 12, 31, 23, 59, 59);
    }
    _reportFuture = _service.fetchTaxReport(start, end);
  }

  void _changeDate(int offset) {
    setState(() {
      if (_viewMode == 'Month') {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + offset);
      } else {
        _currentDate = DateTime(_currentDate.year + offset, 1);
      }
      _refreshData();
    });
  }

  void _toggleView() {
    setState(() {
      _viewMode = _viewMode == 'Month' ? 'Year' : 'Month';
      _refreshData();
    });
  }

  Future<void> _exportReport(TaxReportData data) async {
    setState(() => _isExporting = true);
    try {
      final isYear = _viewMode == 'Year';
      final period = isYear 
          ? 'GSTR-9 Annual Summary (${DateFormat('yyyy').format(_currentDate)})'
          : DateFormat('MMMM yyyy').format(_currentDate);
      
      final settings = await SettingsService().fetchSettings();
      await PdfTaxReportHelper().generateAndDownloadReport(data, period, settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppLocalizations.of(context)?.error ?? 'Error'}: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // Excel Export
  Future<void> _exportExcel(TaxReportData data) async {
    setState(() => _isExporting = true);
    try {
      final isYear = _viewMode == 'Year';
      final period = isYear 
          ? 'GSTR9_Annual_${DateFormat('yyyy').format(_currentDate)}'
          : DateFormat('MMMM yyyy').format(_currentDate);
      
      final bytes = _service.generateDetailedExcel(data, period);
      
      await FileDownloadHelper.downloadFile(bytes, 'GST_Ledger_$period', 'xlsx', text: AppLocalizations.of(context)?.exportReport('GST_Ledger_$period'));
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)?.excelExported ?? 'Excel exported successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppLocalizations.of(context)?.error ?? 'Error'}: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          final padding = isDesktop ? 32.0 : 16.0;

          return FutureBuilder<TaxReportData>(
            future: _reportFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final data = snapshot.hasData ? snapshot.data! : TaxReportData(
                  totalTaxable: 0, 
                  totalOutputTax: 0, 
                  totalInvoiceValue: 0, 
                  bills: [],
                  totalInputTax: 0,
                  netPayable: 0,
                  outputIgst: 0, outputCgst: 0, outputSgst: 0,
                  inputIgst: 0, inputCgst: 0, inputSgst: 0,
                  expenses: [],
                  stateWiseSales: {},
              );

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      title: Text(AppLocalizations.of(context)?.gstTaxLedger ?? 'GST Tax Ledger'),
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textDark,
                      elevation: 0,
                      pinned: true,
                      forceElevated: innerBoxIsScrolled,
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(1),
                        child: Container(color: AppColors.border, height: 1),
                      ),
                      actions: [
                        IconButton(
                          onPressed: LicenseScope.isReadOnlyMode(context) || _isExporting ? null : () => _exportExcel(data),
                          icon: const Icon(Icons.grid_on, color: Colors.green),
                          tooltip: AppLocalizations.of(context)?.downloadExcel ?? 'Download Excel',
                        ),
                        IconButton(
                          onPressed: LicenseScope.isReadOnlyMode(context) || _isExporting ? null : () => _exportReport(data),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          tooltip: AppLocalizations.of(context)?.downloadPdf ?? 'Download PDF',
                        ),
                        IconButton(
                          onPressed: () => _refreshData(),
                          icon: const Icon(Icons.refresh, color: AppColors.primary),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(child: _buildControls(data)),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: isDesktop ? Row(
                              children: [
                                Expanded(child: _buildGradientCard('Output Tax', data.totalOutputTax, [Colors.orange.shade700, Colors.orange.shade400], Icons.trending_up)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildGradientCard('Input Tax', data.totalInputTax, [Colors.teal.shade700, Colors.teal.shade400], Icons.trending_down)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildGradientCard('Net Payable', data.netPayable, data.netPayable > 0 ? [AppColors.primary, const Color(0xFF4A90E2)] : [Colors.green.shade600, Colors.green.shade400], Icons.account_balance_wallet, isNet: true)),
                              ],
                            ) : Column(
                              children: [
                                _buildGradientCard('Output Tax', data.totalOutputTax, [Colors.orange.shade700, Colors.orange.shade400], Icons.trending_up),
                                const SizedBox(height: 12),
                                _buildGradientCard('Input Tax', data.totalInputTax, [Colors.teal.shade700, Colors.teal.shade400], Icons.trending_down),
                                const SizedBox(height: 12),
                                _buildGradientCard('Net Payable', data.netPayable, data.netPayable > 0 ? [AppColors.primary, const Color(0xFF4A90E2)] : [Colors.green.shade600, Colors.green.shade400], Icons.account_balance_wallet, isNet: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(padding, 24, padding, 32),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: isDesktop ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildTaxBreakupCard('Liability Breakdown (Output)', data.outputIgst, data.outputCgst, data.outputSgst, Colors.orange.shade50, Colors.orange.shade800)),
                                const SizedBox(width: 24),
                                Expanded(child: _buildTaxBreakupCard('Credit Breakdown (Input)', data.inputIgst, data.inputCgst, data.inputSgst, Colors.teal.shade50, Colors.teal.shade800)),
                              ],
                            ) : Column(
                              children: [
                                _buildTaxBreakupCard('Liability Breakdown (Output)', data.outputIgst, data.outputCgst, data.outputSgst, Colors.orange.shade50, Colors.orange.shade800),
                                const SizedBox(height: 16),
                                _buildTaxBreakupCard('Credit Breakdown (Input)', data.inputIgst, data.inputCgst, data.inputSgst, Colors.teal.shade50, Colors.teal.shade800),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              TabBar(
                                controller: _tabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                labelColor: AppColors.primary,
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: AppColors.primary,
                                indicatorWeight: 3,
                                dividerColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                tabs: [
                                  Tab(height: 48, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.receipt_long, size: 16), const SizedBox(width: 8), Text('Sales Ledger (${data.bills.length})')])),
                                  Tab(height: 48, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.shopping_bag_outlined, size: 16), const SizedBox(width: 8), Text('Purchase Ledger (${data.expenses.length})')])),
                                  Tab(height: 48, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.map, size: 16), const SizedBox(width: 8), const Text('State-wise Summary')])),
                                ],
                              ),
                              const Divider(height: 1, color: AppColors.border),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSalesLedger(data),
                    _buildPurchaseLedger(data),
                    _buildStateWiseSummary(data),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildControls(TaxReportData data) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        _buildToggleBtn('Month', _viewMode == 'Month'),
                        _buildToggleBtn('Year', _viewMode == 'Year'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded), 
                    onPressed: () => _changeDate(-1),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                         _viewMode == 'Month' 
                            ? DateFormat('MMMM yyyy').format(_currentDate) 
                            : DateFormat('yyyy').format(_currentDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (_viewMode == 'Year')
                        Text('GSTR-9 View', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded), 
                    onPressed: () => _changeDate(1),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildToggleBtn(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        if (!isSelected) _toggleView();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientCard(String title, double amount, List<Color> colors, IconData icon, {bool isNet = false}) {
     return Container(
       height: 130, // Increased height slightly to prevent bottom overflow
       padding: const EdgeInsets.all(16), // Reduced padding
       decoration: BoxDecoration(
         gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
         borderRadius: BorderRadius.circular(16),
         boxShadow: [
            BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
         ],
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
            Row(
              children: [
                 Container(
                   padding: const EdgeInsets.all(6),
                   decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                   child: Icon(icon, size: 16, color: Colors.white), // Reduced icon size
                 ),
                 const SizedBox(width: 8),
                 Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox( // Prevent text overflow
                  child: Text(
                     '₹${amount.abs().toStringAsFixed(0)}',
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
                  ),
                ),
                if (isNet)
                 Text(
                   amount > 0 ? 'To be paid' : 'Credit Balance', 
                   style: const TextStyle(color: Colors.white70, fontSize: 10),
                   overflow: TextOverflow.ellipsis,
                 )
              ],
            ),
         ],
       ),
     );
  }

  Widget _buildTaxBreakupCard(String title, double igst, double cgst, double sgst, Color bgColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
         color: bgColor,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 14)),
           const SizedBox(height: 12), // Reduced spacing
           _buildDetailRow('IGST', igst),
           const Divider(height: 16),
           _buildDetailRow('CGST', cgst),
           const Divider(height: 16),
           _buildDetailRow('SGST', sgst),
           const Divider(height: 16),
           _buildDetailRow('Total', igst + cgst + sgst, isBold: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double amount, {bool isBold = false}) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
            Text(label, style: TextStyle(
              fontSize: 13, 
              color: isBold ? AppColors.textDark : Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal
            )),
            Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
         ],
       ),
     );
  }

  Widget _buildSalesLedger(TaxReportData data) {
     if (data.bills.isEmpty) {
       return _buildEmptyState('No sales invoices found for this period');
     }
     
     return SingleChildScrollView(
       child: SingleChildScrollView(
         scrollDirection: Axis.horizontal,
         child: DataTable(
           headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
           dataRowHeight: 60,
           columns: const [
             DataColumn(label: Text('Date'), numeric: false),
             DataColumn(label: Text('Invoice'), numeric: false),
             DataColumn(label: Text('Party Name'), numeric: false),
             DataColumn(label: Text('Taxable'), numeric: true),
             DataColumn(label: Text('Tax'), numeric: true),
             DataColumn(label: Text('Total'), numeric: true),
           ],
           rows: data.bills.map((bill) {
             return DataRow(cells: [
               DataCell(Text(DateFormat('dd MMM').format(bill.billDate))),
               DataCell(Text(bill.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
               DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: Text(bill.customerName, overflow: TextOverflow.ellipsis))),
               DataCell(Text('₹${bill.price.toStringAsFixed(2)}')),
               DataCell(Text('₹${bill.taxAmount.toStringAsFixed(2)}', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold))),
               DataCell(Text('₹${bill.totalAmount.toStringAsFixed(2)}')),
             ]);
           }).toList(),
         ),
       ),
     );
  }

  Widget _buildPurchaseLedger(TaxReportData data) {
     if (data.expenses.isEmpty) {
       return _buildEmptyState('No purchase/expenses found for this period');
     }

     return SingleChildScrollView(
       child: SingleChildScrollView(
         scrollDirection: Axis.horizontal,
         child: DataTable(
           headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
           dataRowHeight: 60,
           columns: const [
             DataColumn(label: Text('Date'), numeric: false),
             DataColumn(label: Text('Category'), numeric: false),
             DataColumn(label: Text('Description'), numeric: false),
             DataColumn(label: Text('Amount'), numeric: true),
             DataColumn(label: Text('Input Tax'), numeric: true),
           ],
           rows: data.expenses.map((exp) {
             return DataRow(cells: [
               DataCell(Text(DateFormat('dd MMM').format(exp.date))),
               DataCell(Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                 decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                 child: Text(exp.category, style: const TextStyle(fontSize: 12))
               )),
               DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text(exp.title, overflow: TextOverflow.ellipsis))),
               DataCell(Text('₹${exp.amount.toStringAsFixed(2)}')),
               DataCell(Text('₹${exp.taxAmount.toStringAsFixed(2)}', style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold))),
             ]);
           }).toList(),
         ),
       ),
     );
  }
  
  Widget _buildStateWiseSummary(TaxReportData data) {
    if (data.stateWiseSales.isEmpty) return _buildEmptyState('No state-wise data available');

    final sortedStates = data.stateWiseSales.keys.toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedStates.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final state = sortedStates[index];
        final summary = data.stateWiseSales[state]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(state, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                  child: Text('₹${summary.taxAmount.toStringAsFixed(2)} Tax', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildStateMiniItem('Taxable', summary.taxableValue)),
                Expanded(child: _buildStateMiniItem('Total', summary.totalAmount, isBold: true)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStateMiniItem(String label, double amount, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }



  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._child);
  final Widget _child;
  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => _child;
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}


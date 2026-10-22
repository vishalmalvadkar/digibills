import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // NEW: Charting
import '../../models/balance_sheet_model.dart';
import '../../services/balance_sheet_service.dart';
import '../../services/settings_service.dart';
import '../../utils/pdf_balance_sheet_helper.dart';
import '../../theme/app_colors.dart';
import '../../widgets/license_scope.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> with SingleTickerProviderStateMixin {
  DateTime _asOnDate = DateTime.now();
  final _service = BalanceSheetService();
  final _pdfHelper = PdfBalanceSheetHelper();
  bool _isExporting = false;
  Future<BalanceSheetData>? _future;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _future = _service.generateBalanceSheet(_asOnDate);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _asOnDate) {
      setState(() => _asOnDate = picked);
      _loadData();
    }
  }

  Future<void> _downloadPdf(BalanceSheetData data) async {
    setState(() => _isExporting = true);
    try {
      final settings = await SettingsService().fetchSettings();
      await _pdfHelper.generateAndDownload(data, settings);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppLocalizations.of(context)?.exportFailed ?? 'Export Failed:'} $e")));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey-blue background
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.balanceSheet ?? 'Balance Sheet',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
               if (_future != null) {
                 final data = await _future;
                 if (data != null) _downloadPdf(data);
               }
            },
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)?.asOnDate ?? 'Financial Position As On',
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(_asOnDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<BalanceSheetData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text("No Data Available"));
                }

                final data = snapshot.data!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Top Summary Cards
                      SizedBox(
                        height: 110,
                        child: Row(
                          children: [
                            Expanded(child: _buildSummaryCard('Total Assets', data.totalAssets, Colors.teal, Icons.account_balance_wallet)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSummaryCard('Liabilities', data.totalLiabilities, Colors.orange, Icons.money_off)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSummaryCard('Equity', data.totalEquity, Colors.purple, Icons.pie_chart)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Toggle / Charts Section
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            TabBar(
                              controller: _tabController,
                              labelColor: AppColors.primary,
                              unselectedLabelColor: AppColors.textGrey,
                              indicatorColor: AppColors.primary,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              tabs: const [
                                Tab(text: 'Assets Breakdown'),
                                Tab(text: 'Liabilities & Equity'),
                              ],
                            ),
                            SizedBox(
                              height: 300,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildAssetChart(data),
                                  _buildLiabilityChart(data),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Detailed List View
                      _buildDetailedList(data),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
             children: [
               Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
               const SizedBox(width: 6),
               Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500)),
             ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_formatCurrency(amount)}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)} L';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildAssetChart(BalanceSheetData data) {
    final sections = [
      if (data.cashAndBank > 0)
        PieChartSectionData(
          color: Colors.teal,
          value: data.cashAndBank,
          title: '${((data.cashAndBank/data.totalAssets)*100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      if (data.accountsReceivable > 0)
        PieChartSectionData(
          color: Colors.teal.shade300,
          value: data.accountsReceivable,
          title: '${((data.accountsReceivable/data.totalAssets)*100).toStringAsFixed(0)}%',
          radius: 50,
           titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
    ];
    
    if (data.totalAssets == 0) return const Center(child: Text('No Assets Data'));

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        Expanded(
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _chartLegend('Cash & Bank', Colors.teal, data.cashAndBank),
               const SizedBox(height: 12),
               _chartLegend('Receivables', Colors.teal.shade300, data.accountsReceivable),
             ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiabilityChart(BalanceSheetData data) {
    final total = data.totalLiabilities + data.totalEquity;
    if (total == 0) return const Center(child: Text('No Data'));

    final sections = [
      if (data.totalLiabilities > 0)
        PieChartSectionData(
          color: Colors.orange,
          value: data.totalLiabilities,
          title: '${((data.totalLiabilities/total)*100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      if (data.totalEquity > 0)
        PieChartSectionData(
          color: Colors.purple,
          value: data.totalEquity,
          title: '${((data.totalEquity/total)*100).toStringAsFixed(0)}%',
          radius: 50,
            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
    ];

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
         Expanded(
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _chartLegend('Liabilities (GST)', Colors.orange, data.totalLiabilities),
               const SizedBox(height: 12),
               _chartLegend('Equity (Profit)', Colors.purple, data.totalEquity),
             ],
          ),
        ),
      ],
    );
  }

  Widget _chartLegend(String label, Color color, double value) {
     return Row(
       children: [
         Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
         const SizedBox(width: 8),
         Expanded(
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
               Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
             ],
           ),
         )
       ],
     );
  }

  Widget _buildDetailedList(BalanceSheetData data) {
    return Column(
      children: [
        _buildSectionGroup(
          'Assets', 
          Colors.teal,
          [
            _RowItem('Cash & Bank', data.cashAndBank, Icons.account_balance),
            _RowItem('Accounts Receivable', data.accountsReceivable, Icons.people),
          ],
          data.totalAssets,
        ),
        const SizedBox(height: 20),
        _buildSectionGroup(
          'Liabilities', 
          Colors.orange,
          [
             _RowItem('GST Payable', data.gstPayable, Icons.description),
          ],
          data.totalLiabilities,
        ),
         const SizedBox(height: 20),
        _buildSectionGroup(
          'Equity', 
          Colors.purple,
          [
             _RowItem('Net Profit (Retained Earnings)', data.netProfit, Icons.trending_up),
          ],
          data.totalEquity,
        ),
      ],
    );
  }
  
  Widget _buildSectionGroup(String title, Color color, List<_RowItem> items, double total) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.list, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          trailing: Text(
            '₹${total.toStringAsFixed(2)}',
             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          children: [
             Padding(
               padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
               child: Column(
                 children: items.map((item) => Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8),
                   child: Row(
                     children: [
                       Icon(item.icon, size: 18, color: AppColors.textGrey),
                       const SizedBox(width: 12),
                       Expanded(child: Text(item.label, style: const TextStyle(color: AppColors.textDark))),
                       Text('₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                     ],
                   ),
                 )).toList(),
               ),
             )
          ],
        ),
      ),
    );
  }
}

class _RowItem {
  final String label;
  final double amount;
  final IconData? icon;
  _RowItem(this.label, this.amount, this.icon);
}

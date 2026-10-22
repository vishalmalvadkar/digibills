import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart'; // NEW
import 'package:intl/intl.dart';
import '../../models/pnl_data_model.dart';
import '../../services/pnl_service.dart';
import '../../theme/app_colors.dart';

class PnLScreen extends StatefulWidget {
  const PnLScreen({super.key});

  @override
  State<PnLScreen> createState() => _PnLScreenState();
}

class _PnLScreenState extends State<PnLScreen> {
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'Month'; // 'Daily', 'Month', 'Year'
  final _service = PnLService();

  DateTime get _startDate {
    if (_viewMode == 'Daily') {
      return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    } else if (_viewMode == 'Month') {
      return DateTime(_selectedDate.year, _selectedDate.month, 1);
    } else {
      return DateTime(_selectedDate.year, 1, 1);
    }
  }

  DateTime get _endDate {
    if (_viewMode == 'Daily') {
      return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
    } else if (_viewMode == 'Month') {
      return DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
    } else {
      return DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
    }
  }

  Future<PnLData>? _pnlFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _pnlFuture = _service.fetchPnL(_startDate, _endDate);
    });
  }

  void _changeDate(int offset) {
    setState(() {
      if (_viewMode == 'Daily') {
        _selectedDate = _selectedDate.add(Duration(days: offset));
      } else if (_viewMode == 'Month') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, _selectedDate.day);
      } else {
        _selectedDate = DateTime(_selectedDate.year + offset, _selectedDate.month, _selectedDate.day);
      }
      _refreshData();
    });
  }

  void _setViewMode(String mode) {
    setState(() {
      _viewMode = mode;
      _refreshData();
    });
  }

  String _getDateLabel() {
    if (_viewMode == 'Daily') {
      return DateFormat('dd MMM yyyy').format(_selectedDate);
    } else if (_viewMode == 'Month') {
      return DateFormat('MMMM yyyy').format(_selectedDate);
    } else {
      return DateFormat('yyyy').format(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.profitAndLoss ?? 'Profit & Loss'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return Column(
            children: [
              // FILTERS
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _filterChip(AppLocalizations.of(context)?.daily ?? 'Daily', 'Daily'),
                            const SizedBox(width: 8),
                            _filterChip(AppLocalizations.of(context)?.month ?? 'Month', 'Month'),
                            const SizedBox(width: 8),
                            _filterChip(AppLocalizations.of(context)?.year ?? 'Year', 'Year'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => _changeDate(-1),
                            ),
                            Text(
                              _getDateLabel(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => _changeDate(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              Expanded(
                child: FutureBuilder<PnLData>(
                  future: _pnlFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(child: Text("${AppLocalizations.of(context)?.error ?? 'Error'}: ${snapshot.error}"));
                    }

                    final data = snapshot.data!;
                    
                     return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
                          child: Column(
                            children: [
                              // SUMMARY CARDS
                              Row(
                                children: [
                                  Expanded(child: _summaryCard(AppLocalizations.of(context)?.income ?? 'Income', data.totalIncome, AppColors.success, Icons.arrow_downward)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _summaryCard(AppLocalizations.of(context)?.expense ?? 'Expense', data.totalExpense, AppColors.error, Icons.arrow_upward)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _netProfitCard(data.netProfit),

                              const SizedBox(height: 32),
                              
                              // CHART
                              Container(
                                height: 300,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Text(
                                       AppLocalizations.of(context)?.financialOverview ?? 'Financial Overview',
                                       style: TextStyle(
                                         fontSize: 16, 
                                         fontWeight: FontWeight.bold,
                                         color: AppColors.textGrey
                                       ),
                                     ),
                                     const SizedBox(height: 24),
                                     Expanded(
                                       child: BarChart(
                                         BarChartData(
                                           alignment: BarChartAlignment.spaceAround,
                                           maxY: (data.totalIncome > data.totalExpense ? data.totalIncome : data.totalExpense) * 1.2,
                                           barTouchData: BarTouchData(
                                             touchTooltipData: BarTouchTooltipData(
                                               getTooltipColor: (_) => Colors.blueGrey,
                                               getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                 return BarTooltipItem(
                                                   '₹${rod.toY.toInt()}',
                                                   const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                 );
                                               },
                                             ),
                                           ),
                                           titlesData: FlTitlesData(
                                             show: true,
                                             bottomTitles: AxisTitles(
                                               sideTitles: SideTitles(
                                                 showTitles: true,
                                                 reservedSize: 30, // FIX: Added Space
                                                 getTitlesWidget: (value, meta) {
                                                   const style = TextStyle(
                                                     color: AppColors.textGrey,
                                                     fontWeight: FontWeight.bold,
                                                     fontSize: 12, // Adjusted font size
                                                   );
                                                   Widget text;
                                                   switch (value.toInt()) {
                                                     case 0: text = const Text('Income', style: style); break;
                                                     case 1: text = const Text('Expense', style: style); break;
                                                     case 2: text = const Text('Profit', style: style); break;
                                                     default: text = const Text('');
                                                   }
                                                   return SideTitleWidget(
                                                     axisSide: meta.axisSide,
                                                     space: 4,
                                                     child: text,
                                                   );
                                                 },
                                               ),
                                             ),
                                             leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                             topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                             rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                           ),
                                           gridData: FlGridData(show: false),
                                           borderData: FlBorderData(show: false),
                                           barGroups: [
                                             BarChartGroupData(
                                               x: 0,
                                               barRods: [
                                                 BarChartRodData(
                                                   toY: data.totalIncome,
                                                   color: AppColors.success,
                                                   width: 30,
                                                   borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                   backDrawRodData: BackgroundBarChartRodData(
                                                      show: true,
                                                      toY: (data.totalIncome > data.totalExpense ? data.totalIncome : data.totalExpense) * 1.2,
                                                      color: AppColors.success.withOpacity(0.1),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                             BarChartGroupData(
                                               x: 1,
                                               barRods: [
                                                 BarChartRodData(
                                                   toY: data.totalExpense,
                                                   color: AppColors.error,
                                                   width: 30,
                                                   borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                   backDrawRodData: BackgroundBarChartRodData(
                                                      show: true,
                                                      toY: (data.totalIncome > data.totalExpense ? data.totalIncome : data.totalExpense) * 1.2,
                                                      color: AppColors.error.withOpacity(0.1),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                             BarChartGroupData(
                                               x: 2,
                                               barRods: [
                                                 BarChartRodData(
                                                   toY: data.netProfit > 0 ? data.netProfit : 0,
                                                   color: Colors.blue,
                                                   width: 30,
                                                   borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                   backDrawRodData: BackgroundBarChartRodData(
                                                      show: true,
                                                      toY: (data.totalIncome > data.totalExpense ? data.totalIncome : data.totalExpense) * 1.2,
                                                      color: Colors.blue.withOpacity(0.1),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ],
                                         ),
                                       ),
                                     ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _viewMode == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) _setViewMode(value);
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _summaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _netProfitCard(double profit) {
    bool isPositive = profit >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive 
            ? [Colors.blue.shade600, Colors.blue.shade400]
            : [Colors.red.shade600, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: (isPositive ? Colors.blue : Colors.red).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          Text(AppLocalizations.of(context)?.netProfitRetained ?? 'Net Profit', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '₹${profit.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

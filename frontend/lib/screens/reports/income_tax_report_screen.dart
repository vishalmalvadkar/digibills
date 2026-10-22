import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/settings_service.dart'; // NEW
import '../../models/settings_model.dart'; // NEW
import 'package:intl/intl.dart';


class IncomeTaxReportScreen extends StatefulWidget {
  const IncomeTaxReportScreen({super.key});

  @override
  State<IncomeTaxReportScreen> createState() => _IncomeTaxReportScreenState();
}

class _IncomeTaxReportScreenState extends State<IncomeTaxReportScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, 4, 1); // Start of Financial Year (approx)
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  final ReportService _service = ReportService();
  
  Map<String, double> _taxData = {
    'income': 0,
    'expense': 0,
    'netProfit': 0,
    'estimatedTax': 0,
  };

  @override
  void initState() {
    super.initState();
    // Adjust start date to previous April 1st if today is before April
    if (DateTime.now().month < 4) {
      _startDate = DateTime(DateTime.now().year - 1, 4, 1);
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.calculateIncomeTax(_startDate, _endDate);
      setState(() {
        _taxData = data;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.incomeTaxComputation ?? 'Income Tax Computation'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Date Range Picker (Simplified)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)?.dateRange ?? 'Date Range', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      Text('${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                       final picked = await showDateRangePicker(
                         context: context, 
                         firstDate: DateTime(2020), 
                         lastDate: DateTime.now(),
                         initialDateRange: DateTimeRange(start: _startDate, end: _endDate)
                       );
                       if (picked != null) {
                         setState(() {
                           _startDate = picked.start;
                           _endDate = picked.end;
                         });
                         _fetchData();
                       }
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  // Gross Income
                  _buildSummaryCard(
                    AppLocalizations.of(context)?.grossTotalIncome ?? 'Gross Total Income',
                    _taxData['income']!,
                    Colors.teal,
                    Icons.arrow_downward
                  ),
                  const SizedBox(height: 12),
                  
                  // Expenses
                  _buildSummaryCard(
                    AppLocalizations.of(context)?.totalExpenses ?? 'Total Expenses',
                    _taxData['expense']!,
                    Colors.orange,
                    Icons.arrow_upward
                  ),
                  const SizedBox(height: 12),

                  // Net Profit / Taxable Income
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.of(context)?.netTaxableIncome ?? 'Net Taxable Income',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_taxData['netProfit']!.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Estimated Tax
                  Container(
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.red.shade100),
                     ),
                     child: Column(
                       children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(Icons.calculate, color: Colors.red.shade700),
                             const SizedBox(width: 8),
                             Text(
                               AppLocalizations.of(context)?.estimatedTax ?? 'Estimated Tax',
                               style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 18),
                             ),
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text('(Old Regime Slabs)', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                         const SizedBox(height: 12),
                         Text(
                           '₹${_taxData['estimatedTax']!.toStringAsFixed(2)}',
                           style: TextStyle(color: Colors.red.shade700, fontSize: 28, fontWeight: FontWeight.bold),
                         ),
                       ],
                     ),
                  ),

                  const SizedBox(height: 32),


                  
                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)?.taxDisclaimer ?? 'This is an estimated calculation. Please consult a Chartered Accountant.',
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
